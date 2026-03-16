[CmdletBinding()]
param(
    [string]$CodexTag = "rust-v0.114.0",
    [switch]$InstallDeps
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "[codex-last-prompt-footer] $Message"
}

function Add-UserPathEntry {
    param([string]$PathEntry)

    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $parts = @()
    if ($currentPath) {
        $parts = $currentPath.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)
    }

    if ($parts -contains $PathEntry) {
        return
    }

    $newParts = @($PathEntry) + $parts
    [Environment]::SetEnvironmentVariable("Path", ($newParts -join ';'), "User")
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$buildScript = Join-Path $PSScriptRoot "build.ps1"
$stateDir = Join-Path $HOME ".codex-last-prompt-footer"
$outputDir = Join-Path $stateDir "dist\windows"
$builtExe = Join-Path $outputDir "codex.exe"
$shimDir = Join-Path $stateDir "shims\windows"
$configDir = Join-Path $stateDir "config"
$footerStateFile = Join-Path $configDir "footer-enabled"

Write-Step "Preparing patched codex binary"
& $buildScript -CodexTag $CodexTag -OutputDir $outputDir -InstallDeps:$InstallDeps
if ($LASTEXITCODE -ne 0) {
    throw "build.ps1 failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path $builtExe)) {
    throw "Built binary not found: $builtExe"
}

New-Item -ItemType Directory -Force $shimDir | Out-Null
New-Item -ItemType Directory -Force $configDir | Out-Null

if (-not (Test-Path $footerStateFile)) {
    Set-Content -Path $footerStateFile -Value "1"
}

$cmdPath = Join-Path $shimDir "codex.cmd"
$ps1Path = Join-Path $shimDir "codex.ps1"

$cmdContent = @(
    '@ECHO off',
    'SETLOCAL',
    "SET ""FOOTER_STATE_FILE=$footerStateFile""",
    'SET "CODEX_LAST_PROMPT_FOOTER=1"',
    'IF EXIST "%FOOTER_STATE_FILE%" SET /P CODEX_LAST_PROMPT_FOOTER=<"%FOOTER_STATE_FILE%"',
    "SET ""PATCHED_CODEX=$builtExe""",
    '"%PATCHED_CODEX%" %*'
)

$ps1Content = @(
    '#!/usr/bin/env pwsh',
    '$patchedCodex = "' + $builtExe.Replace('\', '\\') + '"',
    '$footerStateFile = "' + $footerStateFile.Replace('\', '\\') + '"',
    '$env:CODEX_LAST_PROMPT_FOOTER = "1"',
    'if (Test-Path $footerStateFile) {',
    '  $env:CODEX_LAST_PROMPT_FOOTER = (Get-Content -Path $footerStateFile -Raw).Trim()',
    '}',
    '',
    'if ($MyInvocation.ExpectingInput) {',
    '  $input | & $patchedCodex $args',
    '} else {',
    '  & $patchedCodex $args',
    '}',
    '',
    'exit $LASTEXITCODE'
)

Set-Content -Path $cmdPath -Value $cmdContent
Set-Content -Path $ps1Path -Value $ps1Content

Add-UserPathEntry -PathEntry $shimDir

Write-Step "Installed persistent Codex shim at $shimDir"
Write-Step "The official npm launcher is no longer modified."
Write-Step "Open a new PowerShell window to pick up the updated user PATH."
