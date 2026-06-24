<#
.SYNOPSIS
    Installs or uninstalls the Load-LazyWorker shortcut into the user's
    PowerShell profile so it can be called from anywhere, on demand.
.DESCRIPTION
    Registers a lightweight function named 'Load-LazyWorker' in $PROFILE.
    The module is NOT auto-loaded — it only loads when you explicitly call
    Load-LazyWorker from any directory in any pwsh session.

    Works on both Windows and Linux/macOS.
    Run with -Uninstall to remove the registration.
.PARAMETER Uninstall
    Remove the LazyWorker function from $PROFILE.
.EXAMPLE
    # Install
    ./Install-LazyWorker.ps1

    # Then in any new terminal, just type:
    Load-LazyWorker

    # Uninstall
    ./Install-LazyWorker.ps1 -Uninstall
#>
[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Uninstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Resolve paths ────────────────────────────────────────────────────────────
$loaderScript = Join-Path $PSScriptRoot 'Load-LazyWorker.ps1'

if (-not (Test-Path -Path $loaderScript)) {
    Write-Error "Load-LazyWorker.ps1 not found at '$loaderScript'. Run this script from the Lazy-Worker project root."
    return
}

# Markers to identify our block in the profile
$markerStart = '# [LazyWorker:BEGIN] — managed by Install-LazyWorker.ps1'
$markerEnd   = '# [LazyWorker:END]'

# The function block we inject into the profile
$functionBlock = @"

$markerStart
function Load-LazyWorker {
    <# Dot-source the loader so env vars and module load into the current session #>
    . '$loaderScript'
}
$markerEnd
"@

# ── Determine profile path ──────────────────────────────────────────────────
$profilePath = $PROFILE.CurrentUserCurrentHost

Write-Host ''
Write-Host '╔══════════════════════════════════════════════════════╗' -ForegroundColor Cyan
Write-Host '║          LazyWorker Installer / Uninstaller         ║' -ForegroundColor Cyan
Write-Host '╚══════════════════════════════════════════════════════╝' -ForegroundColor Cyan
Write-Host ''
Write-Host "  Profile  : $profilePath" -ForegroundColor Gray
Write-Host "  Loader   : $loaderScript" -ForegroundColor Gray
Write-Host "  Platform : $($PSVersionTable.Platform ?? 'Win32NT')" -ForegroundColor Gray
Write-Host "  Action   : $(if ($Uninstall) { 'UNINSTALL' } else { 'INSTALL' })" -ForegroundColor Yellow
Write-Host ''

# ── UNINSTALL ────────────────────────────────────────────────────────────────
if ($Uninstall) {
    if (-not (Test-Path -Path $profilePath)) {
        Write-Host '  ⓘ  No profile file found — nothing to uninstall.' -ForegroundColor DarkGray
        return
    }

    $profileContent = Get-Content -Path $profilePath -Raw
    if ($profileContent -notmatch [regex]::Escape($markerStart)) {
        Write-Host '  ⓘ  LazyWorker is not registered in your profile — nothing to do.' -ForegroundColor DarkGray
        return
    }

    # Remove everything between BEGIN and END markers (inclusive)
    $escapedStart = [regex]::Escape($markerStart)
    $escapedEnd   = [regex]::Escape($markerEnd)
    $cleanedContent = [regex]::Replace($profileContent, "(?s)\r?\n?$escapedStart.*?$escapedEnd\r?\n?", '')
    [System.IO.File]::WriteAllText($profilePath, $cleanedContent, [System.Text.Encoding]::UTF8)

    Write-Host '  ✓  LazyWorker function removed from PowerShell profile.' -ForegroundColor Green
    Write-Host '     Restart your terminal for changes to take effect.' -ForegroundColor Gray
    Write-Host ''
    return
}

# ── INSTALL ──────────────────────────────────────────────────────────────────

# 1. Ensure profile file and its parent directory exist
$profileDir = Split-Path -Path $profilePath -Parent
if (-not (Test-Path -Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    Write-Host "  ✓  Created profile directory: $profileDir" -ForegroundColor Green
}

if (-not (Test-Path -Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
    Write-Host "  ✓  Created profile file: $profilePath" -ForegroundColor Green
}

# 2. Check if already installed
$profileContent = Get-Content -Path $profilePath -Raw
if ($null -ne $profileContent -and $profileContent.Contains($markerStart)) {
    Write-Host '  ⓘ  LazyWorker is already registered in your profile.' -ForegroundColor Yellow

    # Replace existing block in case path changed (project moved)
    $escapedStart = [regex]::Escape($markerStart)
    $escapedEnd   = [regex]::Escape($markerEnd)
    $updatedContent = [regex]::Replace($profileContent, "(?s)\r?\n?$escapedStart.*?$escapedEnd", $functionBlock)

    if ($updatedContent -ne $profileContent) {
        [System.IO.File]::WriteAllText($profilePath, $updatedContent, [System.Text.Encoding]::UTF8)
        Write-Host '  ✓  Updated loader path to current location.' -ForegroundColor Green
    }
    else {
        Write-Host '     Path is already correct — no changes needed.' -ForegroundColor DarkGray
    }
    Write-Host ''
    return
}

# 3. Append function block to profile
Add-Content -Path $profilePath -Value $functionBlock -Encoding utf8
Write-Host '  ✓  LazyWorker function registered in PowerShell profile!' -ForegroundColor Green
Write-Host ''
Write-Host '  ┌──────────────────────────────────────────────────────┐' -ForegroundColor DarkCyan
Write-Host '  │  Restart your terminal (or run: . $PROFILE), then:  │' -ForegroundColor DarkCyan
Write-Host '  │                                                      │' -ForegroundColor DarkCyan
Write-Host '  │    Load-LazyWorker                                   │' -ForegroundColor White
Write-Host '  │                                                      │' -ForegroundColor DarkCyan
Write-Host '  │  to load the module on demand from any directory.    │' -ForegroundColor DarkCyan
Write-Host '  └──────────────────────────────────────────────────────┘' -ForegroundColor DarkCyan
Write-Host ''
