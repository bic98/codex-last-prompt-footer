[CmdletBinding()]
param(
    [string]$CodexTag = "rust-v0.114.0",
    [string]$SourceDir = (Join-Path $HOME ".codex-last-prompt-footer\openai-codex"),
    [string]$OutputDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "dist\windows")
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

Ensure-Command git
Ensure-Rust

$env:PATH = "$env:USERPROFILE\.cargo\bin;$env:PATH"
$repoRoot = Split-Path $PSScriptRoot -Parent
$patchFile = Join-Path $repoRoot "patches\codex-v0.114.0-last-prompt-footer.patch"

if (-not (Test-Path $patchFile)) {
    throw "Patch file not found: $patchFile"
}

if (-not (Test-Path $SourceDir)) {
    Write-Step "Cloning official openai/codex source into $SourceDir"
    git clone https://github.com/openai/codex.git $SourceDir
    if ($LASTEXITCODE -ne 0) {
        throw "git clone failed with exit code $LASTEXITCODE"
    }
} else {
    Write-Step "Using existing source cache at $SourceDir"
}

Write-Step "Fetching tags"
git -C $SourceDir fetch --tags origin
if ($LASTEXITCODE -ne 0) {
    throw "git fetch failed with exit code $LASTEXITCODE"
}

Write-Step "Checking out $CodexTag"
git -C $SourceDir checkout --force $CodexTag
if ($LASTEXITCODE -ne 0) {
    throw "git checkout failed with exit code $LASTEXITCODE"
}

Write-Step "Resetting managed source cache"
git -C $SourceDir reset --hard $CodexTag
if ($LASTEXITCODE -ne 0) {
    throw "git reset failed with exit code $LASTEXITCODE"
}

git -C $SourceDir clean -fd
if ($LASTEXITCODE -ne 0) {
    throw "git clean failed with exit code $LASTEXITCODE"
}

Write-Step "Applying last-prompt footer patch"
git -C $SourceDir apply $patchFile
if ($LASTEXITCODE -ne 0) {
    throw "git apply failed with exit code $LASTEXITCODE"
}

$cargoRoot = Join-Path $SourceDir "codex-rs"
Write-Step "Building patched codex-cli"
Push-Location $cargoRoot
try {
    cargo +stable build -p codex-cli --release
    if ($LASTEXITCODE -ne 0) {
        throw "cargo build failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

$builtExe = Join-Path $cargoRoot "target\release\codex.exe"
if (-not (Test-Path $builtExe)) {
    throw "Built binary not found: $builtExe"
}

New-Item -ItemType Directory -Force $OutputDir | Out-Null
$outputExe = Join-Path $OutputDir "codex.exe"
Copy-Item $builtExe $outputExe -Force

Write-Step "Patched binary ready: $outputExe"
