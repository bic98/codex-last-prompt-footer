[CmdletBinding()]
param(
    [string]$CodexTag = "rust-v0.114.0"
)

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

    throw "Could not locate the installed codex launcher directory. Install the official Codex CLI first: npm install -g @openai/codex"
}

function Backup-IfNeeded {
    param([string]$Path)
    if ((Test-Path $Path) -and -not (Test-Path "$Path.openai-backup")) {
        Copy-Item $Path "$Path.openai-backup" -Force
    }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$buildScript = Join-Path $PSScriptRoot "build.ps1"

$shimDir = Get-CodexLauncherDirectory

Write-Step "Preparing patched codex binary"
& $buildScript -CodexTag $CodexTag
if ($LASTEXITCODE -ne 0) {
    throw "build.ps1 failed with exit code $LASTEXITCODE"
}

$builtExe = Join-Path $repoRoot "dist\windows\codex.exe"
if (-not (Test-Path $builtExe)) {
    throw "Built binary not found: $builtExe"
}

$customDir = Join-Path $shimDir "custom-codex"
New-Item -ItemType Directory -Force $customDir | Out-Null
Copy-Item $builtExe (Join-Path $customDir "codex.exe") -Force

$cmdPath = Join-Path $shimDir "codex.cmd"
$ps1Path = Join-Path $shimDir "codex.ps1"

Backup-IfNeeded $cmdPath
Backup-IfNeeded $ps1Path

$cmdContent = @(
    '@ECHO off',
    'SETLOCAL',
    'SET "CUSTOM_CODEX=%~dp0custom-codex\codex.exe"',
    '"%CUSTOM_CODEX%" %*'
)

$ps1Content = @(
    '#!/usr/bin/env pwsh',
    '$basedir = Split-Path $MyInvocation.MyCommand.Definition -Parent',
    '$customCodex = Join-Path $basedir "custom-codex/codex.exe"',
    '',
    'if ($MyInvocation.ExpectingInput) {',
    '  $input | & $customCodex $args',
    '} else {',
    '  & $customCodex $args',
    '}',
    '',
    'exit $LASTEXITCODE'
)

Set-Content -Path $cmdPath -Value $cmdContent
Set-Content -Path $ps1Path -Value $ps1Content

Write-Step "Installed patched Codex launcher into $shimDir"
Write-Step "Original launchers were backed up with the .openai-backup suffix"
Write-Step "Run 'codex --version' or launch 'codex' normally to test"
