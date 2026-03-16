[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "[codex-last-prompt-footer] $Message"
}

function Remove-UserPathEntry {
    param([string]$PathEntry)

    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not $currentPath) {
        return
    }

    $parts = $currentPath.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries) |
        Where-Object { $_ -ne $PathEntry }

    [Environment]::SetEnvironmentVariable("Path", ($parts -join ';'), "User")
}

$stateDir = Join-Path $HOME ".codex-last-prompt-footer"
$shimDir = Join-Path $stateDir "shims\windows"

Remove-Item (Join-Path $shimDir "codex.cmd") -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $shimDir "codex.ps1") -Force -ErrorAction SilentlyContinue
Remove-UserPathEntry -PathEntry $shimDir

Write-Step "Removed persistent Codex shim from $shimDir"
Write-Step "Open a new PowerShell window to pick up the restored user PATH."
