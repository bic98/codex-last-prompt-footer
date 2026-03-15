[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "[codex-last-prompt-footer] $Message"
}

function Get-CodexLauncherDirectory {
    $codexCommand = Get-Command codex -ErrorAction SilentlyContinue
    if ($codexCommand) {
        if ($codexCommand.CommandType -eq "Function") {
            if ($codexCommand.Definition -match "'([^']*codex\.cmd)'") {
                return Split-Path $Matches[1] -Parent
            }
        }

        if ($codexCommand.Source) {
            return Split-Path $codexCommand.Source -Parent
        }
    }

    if (Get-Command npm -ErrorAction SilentlyContinue) {
        $prefix = (& npm prefix -g).Trim()
        if ($LASTEXITCODE -eq 0 -and $prefix) {
            return $prefix
        }
    }

    throw "Could not locate the installed codex launcher directory."
}

$shimDir = Get-CodexLauncherDirectory
$cmdPath = Join-Path $shimDir "codex.cmd"
$ps1Path = Join-Path $shimDir "codex.ps1"
$shPath = Join-Path $shimDir "codex"
$customDir = Join-Path $shimDir "custom-codex"

$restored = $false
foreach ($path in @($cmdPath, $ps1Path, $shPath)) {
    $backup = "$path.openai-backup"
    if (Test-Path $backup) {
        Copy-Item $backup $path -Force
        $restored = $true
    }
}

if (Test-Path $customDir) {
    Remove-Item $customDir -Recurse -Force
}

if ($restored) {
    Write-Step "Original Codex launchers restored."
} else {
    Write-Step "No backup launchers were found. Nothing was restored."
}
