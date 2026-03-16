[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("enable", "disable", "status")]
    [string]$Command = "status"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "[codex-last-prompt-footer] $Message"
}

$stateDir = Join-Path $HOME ".codex-last-prompt-footer"
$configDir = Join-Path $stateDir "config"
$footerStateFile = Join-Path $configDir "footer-enabled"

New-Item -ItemType Directory -Force $configDir | Out-Null

if (-not (Test-Path $footerStateFile)) {
    Set-Content -Path $footerStateFile -Value "1"
}

switch ($Command) {
    "enable" {
        Set-Content -Path $footerStateFile -Value "1"
        Write-Step "Footer preview enabled"
    }
    "disable" {
        Set-Content -Path $footerStateFile -Value "0"
        Write-Step "Footer preview disabled"
    }
    "status" {
        $current = (Get-Content -Path $footerStateFile -Raw).Trim()
        if ($current -eq "0") {
            Write-Step "Footer preview is disabled"
        } else {
            Write-Step "Footer preview is enabled"
        }
    }
}
