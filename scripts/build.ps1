[CmdletBinding()]
param(
    [string]$CodexTag = "rust-v0.114.0",
    [string]$SourceDir = (Join-Path $HOME ".codex-last-prompt-footer\openai-codex"),
    [string]$OutputDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "dist\windows"),
    [string]$PatchFile = "",
    [string]$ReleaseRepository = "bic98/codex-last-prompt-footer",
    [string]$ReleaseTag = "",
    [switch]$SkipPrebuiltDownload,
    [switch]$InstallDeps
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "[codex-last-prompt-footer] $Message"
}

function Ensure-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

function Get-VsWherePath {
    $programFilesX86 = ${env:ProgramFiles(x86)}
    if (-not $programFilesX86) {
        return $null
    }

    $vswhere = Join-Path $programFilesX86 "Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        return $vswhere
    }

    return $null
}

function Get-VisualStudioInstallPath {
    $vswhere = Get-VsWherePath
    if (-not $vswhere) {
        return $null
    }

    $installPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($LASTEXITCODE -ne 0 -or -not $installPath) {
        return $null
    }

    return $installPath
}

function Import-MsvcEnvironment {
    if (Get-Command link.exe -ErrorAction SilentlyContinue) {
        return $true
    }

    $installPath = Get-VisualStudioInstallPath
    if (-not $installPath) {
        return $false
    }

    $vsDevCmd = Join-Path $installPath "Common7\Tools\VsDevCmd.bat"
    if (-not (Test-Path $vsDevCmd)) {
        return $false
    }

    $envDump = & cmd.exe /s /c "`"$vsDevCmd`" -no_logo -arch=x64 -host_arch=x64 >nul && set"
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    foreach ($line in $envDump) {
        if ($line -match '^(.*?)=(.*)$') {
            Set-Item -Path "Env:$($Matches[1])" -Value $Matches[2]
        }
    }

    return [bool](Get-Command link.exe -ErrorAction SilentlyContinue)
}

function Show-MsvcBuildToolsHelp {
    @"
Missing Microsoft C++ Build Tools required for Rust's MSVC toolchain.

Install Visual Studio Build Tools 2022 with the C++ workload, then rerun the installer.

Recommended command:
  winget install --id Microsoft.VisualStudio.2022.BuildTools --source winget --accept-source-agreements --accept-package-agreements --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"

Official download:
  https://visualstudio.microsoft.com/downloads/
"@ | Write-Error
}

function Install-MsvcBuildTools {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget is required for automatic Visual Studio Build Tools installation."
    }

    Write-Step "Installing Visual Studio Build Tools 2022 with C++ workload via winget"
    & winget install `
        --id Microsoft.VisualStudio.2022.BuildTools `
        --source winget `
        --accept-source-agreements `
        --accept-package-agreements `
        --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"

    if ($LASTEXITCODE -ne 0) {
        throw "winget installation failed with exit code $LASTEXITCODE"
    }
}

function Ensure-WindowsBuildTools {
    if (Import-MsvcEnvironment) {
        return
    }

    if ($InstallDeps -or $env:AUTO_INSTALL_DEPS -eq "1") {
        Install-MsvcBuildTools
        if (Import-MsvcEnvironment) {
            return
        }

        throw "Visual Studio Build Tools installation completed, but the MSVC environment is still unavailable. Restart PowerShell and retry."
    }

    Show-MsvcBuildToolsHelp
    exit 1
}

function Get-PatchNameForTag {
    param([string]$Tag)
    $normalized = $Tag -replace '^rust-', ''
    return "codex-$normalized-last-prompt-footer.patch"
}

function Resolve-PatchFile {
    param(
        [string]$RepoRoot,
        [string]$Tag,
        [string]$Override
    )

    if ($Override) {
        if (-not (Test-Path $Override)) {
            throw "Patch file not found: $Override"
        }
        return $Override
    }

    $candidate = Join-Path $RepoRoot ("patches\" + (Get-PatchNameForTag -Tag $Tag))
    if (-not (Test-Path $candidate)) {
        throw "Patch file not found for $Tag. Expected: $candidate`nSet -PatchFile to target a different Codex tag."
    }

    return $candidate
}

function Get-PatchSha256 {
    param([string]$Path)
    return (Get-FileHash -Algorithm SHA256 -Path $Path).Hash.ToLowerInvariant()
}

function Write-BuildInfo {
    param(
        [string]$Path,
        [string]$Tag,
        [string]$PatchSha,
        [string]$Source
    )

    @(
        "CODEX_TAG=$Tag"
        "PATCH_SHA=$PatchSha"
        "SOURCE=$Source"
    ) | Set-Content -Path $Path
}

function Test-MatchingBuild {
    param(
        [string]$BuildInfoPath,
        [string]$BuiltExe,
        [string]$Tag,
        [string]$PatchSha
    )

    if (-not (Test-Path $BuiltExe) -or -not (Test-Path $BuildInfoPath)) {
        return $false
    }

    $lines = Get-Content $BuildInfoPath
    return $lines -contains "CODEX_TAG=$Tag" -and $lines -contains "PATCH_SHA=$PatchSha"
}

function Get-ReleaseTagValue {
    param(
        [string]$Tag,
        [string]$Override
    )

    if ($Override) {
        return $Override
    }

    return "v$($Tag -replace '^rust-v', '')"
}

function Get-ReleaseArch {
    switch ($env:PROCESSOR_ARCHITECTURE.ToLowerInvariant()) {
        "amd64" { return "x86_64" }
        "arm64" { return "aarch64" }
        default { return $null }
    }
}

function Try-DownloadPrebuiltBinary {
    param(
        [string]$StateDir,
        [string]$OutputDir,
        [string]$Tag,
        [string]$Repository,
        [string]$ResolvedReleaseTag
    )

    $arch = Get-ReleaseArch
    if (-not $arch) {
        return $false
    }

    $version = $Tag -replace '^rust-v', ''
    $asset = "codex-last-prompt-footer-$version-windows-$arch.zip"
    $url = "https://github.com/$Repository/releases/download/$ResolvedReleaseTag/$asset"
    $archive = Join-Path $StateDir $asset
    $extractDir = Join-Path $StateDir "prebuilt-windows-$arch"

    Write-Step "Trying prebuilt binary: $url"
    try {
        Invoke-WebRequest $url -OutFile $archive
    } catch {
        return $false
    }

    if (Test-Path $extractDir) {
        Remove-Item $extractDir -Recurse -Force
    }

    Expand-Archive -Path $archive -DestinationPath $extractDir -Force
    $downloadedExe = Join-Path $extractDir "codex.exe"
    if (-not (Test-Path $downloadedExe)) {
        throw "Downloaded prebuilt archive did not contain codex.exe"
    }

    New-Item -ItemType Directory -Force $OutputDir | Out-Null
    Copy-Item $downloadedExe (Join-Path $OutputDir "codex.exe") -Force
    return $true
}

function Ensure-Rust {
    if (Get-Command cargo -ErrorAction SilentlyContinue) {
        return
    }

    Write-Step "Rust not found. Installing rustup (stable, minimal profile)."
    $rustupInit = Join-Path $env:TEMP "rustup-init.exe"
    Invoke-WebRequest "https://win.rustup.rs/x86_64" -OutFile $rustupInit
    & $rustupInit -y --profile minimal --default-toolchain stable
    if ($LASTEXITCODE -ne 0) {
        throw "rustup installation failed with exit code $LASTEXITCODE"
    }
}

function Invoke-CargoBuild {
    $stdoutLog = Join-Path $env:TEMP "codex-last-prompt-footer-cargo-stdout.log"
    $stderrLog = Join-Path $env:TEMP "codex-last-prompt-footer-cargo-stderr.log"

    function Invoke-CargoProcess {
        param([string[]]$Arguments)

        Remove-Item $stdoutLog, $stderrLog -ErrorAction SilentlyContinue

        $process = Start-Process -FilePath "cargo" `
            -ArgumentList $Arguments `
            -NoNewWindow `
            -Wait `
            -PassThru `
            -RedirectStandardOutput $stdoutLog `
            -RedirectStandardError $stderrLog

        if (Test-Path $stdoutLog) {
            Get-Content $stdoutLog
        }
        if (Test-Path $stderrLog) {
            Get-Content $stderrLog
        }

        return $process.ExitCode
    }

    try {
        $exitCode = Invoke-CargoProcess -Arguments @("+stable", "build", "-p", "codex-cli", "--release", "--locked")

        if ($exitCode -eq 0) {
            return
        }

        $outputText = ""
        if (Test-Path $stdoutLog) {
            $outputText += Get-Content $stdoutLog -Raw
        }
        if (Test-Path $stderrLog) {
            $outputText += Get-Content $stderrLog -Raw
        }

        if ($outputText -match 'cannot update the lock file|lock file .*needs to be updated|Cargo\.lock') {
            Write-Step "Cargo.lock needs an update for this platform; retrying without --locked"
            $exitCode = Invoke-CargoProcess -Arguments @("+stable", "build", "-p", "codex-cli", "--release")
            if ($exitCode -ne 0) {
                throw "cargo build failed with exit code $exitCode"
            }
            return
        }

        throw "cargo build failed with exit code $exitCode"
    } finally {
        Remove-Item $stdoutLog, $stderrLog -ErrorAction SilentlyContinue
    }
}

Ensure-Command git
$repoRoot = Split-Path $PSScriptRoot -Parent
$patchFile = Resolve-PatchFile -RepoRoot $repoRoot -Tag $CodexTag -Override $PatchFile
$patchSha = Get-PatchSha256 -Path $patchFile
$buildInfoPath = Join-Path $OutputDir ".build-info"
$builtExe = Join-Path $OutputDir "codex.exe"
$resolvedReleaseTag = Get-ReleaseTagValue -Tag $CodexTag -Override $ReleaseTag

New-Item -ItemType Directory -Force (Split-Path $SourceDir -Parent) | Out-Null
if (Test-MatchingBuild -BuildInfoPath $buildInfoPath -BuiltExe $builtExe -Tag $CodexTag -PatchSha $patchSha) {
    Write-Step "Using cached patched binary at $builtExe"
    exit 0
}

$stateDir = Split-Path $SourceDir -Parent
if (-not $SkipPrebuiltDownload) {
    if (Try-DownloadPrebuiltBinary -StateDir $stateDir -OutputDir $OutputDir -Tag $CodexTag -Repository $ReleaseRepository -ResolvedReleaseTag $resolvedReleaseTag) {
        Write-BuildInfo -Path $buildInfoPath -Tag $CodexTag -PatchSha $patchSha -Source "release"
        Write-Step "Downloaded prebuilt patched binary: $builtExe"
        exit 0
    }

    Write-Step "No compatible prebuilt binary found. Falling back to local Rust build."
}

Ensure-Rust
$env:PATH = "$env:USERPROFILE\.cargo\bin;$env:PATH"
Ensure-WindowsBuildTools

if (-not (Test-Path $SourceDir)) {
    Write-Step "Cloning official openai/codex source (shallow) into $SourceDir"
    git clone --depth 1 --branch $CodexTag https://github.com/openai/codex.git $SourceDir
    if ($LASTEXITCODE -ne 0) {
        throw "git clone failed with exit code $LASTEXITCODE"
    }
} else {
    Write-Step "Using existing source cache at $SourceDir"
    $currentTag = git -C $SourceDir describe --tags --exact-match HEAD 2>$null
    if ($currentTag -ne $CodexTag) {
        Write-Step "Fetching tag $CodexTag"
        git -C $SourceDir fetch --depth 1 origin tag $CodexTag --no-tags
        if ($LASTEXITCODE -ne 0) {
            throw "git fetch failed with exit code $LASTEXITCODE"
        }
    }
    git -C $SourceDir checkout --force $CodexTag
    if ($LASTEXITCODE -ne 0) {
        throw "git checkout failed with exit code $LASTEXITCODE"
    }
    git -C $SourceDir reset --hard $CodexTag
    if ($LASTEXITCODE -ne 0) {
        throw "git reset failed with exit code $LASTEXITCODE"
    }
    git -C $SourceDir clean -fd
    if ($LASTEXITCODE -ne 0) {
        throw "git clean failed with exit code $LASTEXITCODE"
    }
}

Write-Step "Applying last-prompt footer patch"
git -C $SourceDir apply --check $patchFile 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Step "Patch already applied or source has diverged; resetting and retrying"
    git -C $SourceDir checkout --force $CodexTag
    git -C $SourceDir reset --hard $CodexTag
}
git -C $SourceDir apply $patchFile
if ($LASTEXITCODE -ne 0) {
    throw "git apply failed with exit code $LASTEXITCODE"
}

$cargoRoot = Join-Path $SourceDir "codex-rs"
Write-Step "Building patched codex-cli (this may take a few minutes on first run)"
Push-Location $cargoRoot
try {
    Invoke-CargoBuild
} finally {
    Pop-Location
}

$sourceBuiltExe = Join-Path $cargoRoot "target\release\codex.exe"
if (-not (Test-Path $sourceBuiltExe)) {
    throw "Built binary not found: $sourceBuiltExe"
}

New-Item -ItemType Directory -Force $OutputDir | Out-Null
Copy-Item $sourceBuiltExe $builtExe -Force
Write-BuildInfo -Path $buildInfoPath -Tag $CodexTag -PatchSha $patchSha -Source "local"

Write-Step "Patched binary ready: $builtExe"
