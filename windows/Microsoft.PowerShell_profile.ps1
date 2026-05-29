# Still WIP, needs testing

# ============================================================
#  Microsoft.PowerShell_profile.ps1
#  PowerShell 7+ equivalent of ~/.bashrc
#  Profile path:    echo $PROFILE
#  Profile path:    C:\Users\<username>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
# ============================================================


# ════════════════════════════════════════════════════════════
#  SECTION 0 — REQUIREMENTS & CONVENTIONS
# ════════════════════════════════════════════════════════════

# Required — install once before using this profile:
#
#   Chocolatey (package manager for Windows apps)
#     https://chocolatey.org/install
#
#   Choco-Cleaner (chocolatey residual file cleanup)
#     choco install choco-cleaner
#
#   PSWindowsUpdate (Windows Update via terminal)
#     Installed via PowerShell Gallery — run in order, restart terminal between steps:
#     1. Install-Module PowerShellGet -Force -AllowClobber
#     2. Install-Module PSWindowsUpdate

# Output color conventions:
#
#   Blue   — informational, what's currently happening
#   Green  — successful action or completion
#   Yellow — requires user attention or follow-up action
#   Red    — abort / failure

Set-Location $HOME


# ════════════════════════════════════════════════════════════
#  SECTION 1 — SHARED HELPERS
# ════════════════════════════════════════════════════════════

function Write-Info { param([string]$msg) Write-Host "  $msg" -ForegroundColor Blue }
function Write-Done { param([string]$msg) Write-Host "  ✅  $msg" -ForegroundColor Green }
function Write-Warn { param([string]$msg) Write-Host "  ⚠️  $msg" -ForegroundColor Yellow }
function Write-Fail { param([string]$msg) Write-Host "  ❌  $msg" -ForegroundColor Red }

function Remove-Folder {
    param([string]$path)
    if (Test-Path $path) {
        Remove-Item "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Queues a locked file for deletion on next reboot via MoveFileEx DELAY_UNTIL_REBOOT.
# The OS removes it before the locking process starts on next boot.
function Remove-OnReboot {
    param([string]$path)
    Add-Type -TypeDefinition @"
        using System;
        using System.Runtime.InteropServices;
        public class PendingDelete {
            [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
            public static extern bool MoveFileEx(string existing, string newName, int flags);
        }
"@ -ErrorAction SilentlyContinue
    foreach ($file in (Get-Item $path -ErrorAction SilentlyContinue)) {
        [PendingDelete]::MoveFileEx($file.FullName, $null, 0x4) | Out-Null
    }
}

function Test-Admin {
    ([Security.Principal.WindowsPrincipal]
     [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Checks for elevation and exits with a tailored message if not admin.
# On Windows 11 24H2+ where sudo is present, shows the sudo invocation instead.
function Assert-Admin {
    param([string]$cmdName)
    if (Test-Admin) { return $true }

    Write-Fail "$cmdName requires elevation."
    if (Get-Command sudo -ErrorAction SilentlyContinue) {
        Write-Warn "sudo is available — run: sudo pwsh -Command $cmdName"
    } else {
        Write-Warn "Right-click Windows Terminal → Run as administrator"
    }
    return $false
}


# ════════════════════════════════════════════════════════════
#  SECTION 2 — CLEANUP
#  Requires Administrator for full effect.
# ════════════════════════════════════════════════════════════

function Invoke-Cleanup {

    if (-not (Assert-Admin "cleanup")) { return }

    $ErrorActionPreference = "SilentlyContinue"
    $driveLetter = $env:SystemDrive.TrimEnd(':')
    $beforeBytes = (Get-PSDrive $driveLetter).Free

    # Only thumbcache_*.db files — other shell state in this folder is left untouched
    Write-Info "Clearing thumbnail cache..."
    Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction SilentlyContinue

    # iconcache*.db is locked by the running Explorer process — queued via
    # MoveFileEx DELAY_UNTIL_REBOOT so Explorer never needs to be killed
    Write-Info "Queueing icon cache for deletion on next reboot..."
    Remove-OnReboot "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*.db"

    Write-Info "Clearing Windows Temp..."
    Remove-Folder "$env:SystemRoot\Temp"

    Write-Info "Clearing User Temp..."
    Remove-Folder $env:TEMP

    # WU service stopped to release file locks, restarted after
    Write-Info "Clearing Windows Update download cache..."
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Remove-Folder "$env:SystemRoot\SoftwareDistribution\Download"
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue

    # Uses built-in cmdlet where available, falls back to folder deletion on older builds
    Write-Info "Clearing Delivery Optimisation cache..."
    try {
        Delete-DeliveryOptimizationCache -Force
    } catch {
        Remove-Folder "$env:SystemRoot\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache"
    }

    # Firefox: only cache2 inside each profile folder is removed — bookmarks,
    # history, extensions, passwords are untouched
    Write-Info "Clearing browser caches (Edge, Chrome, Firefox, Brave)..."
    $browserCaches = @(
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\Cache_Data"
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache"
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\Cache_Data"
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache"
        "$env:APPDATA\Mozilla\Firefox\Profiles"
        "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache\Cache_Data"
    )
    foreach ($p in $browserCaches) {
        if ($p -like "*Firefox*") {
            Get-ChildItem $p -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                Remove-Folder "$($_.FullName)\cache2"
            }
        } else {
            Remove-Folder $p
        }
    }

    Write-Info "Flushing DNS cache..."
    ipconfig /flushdns | Out-Null

    Write-Info "Emptying Recycle Bin..."
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue

    Write-Info "Clearing npm cache..."
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        npm cache clean --force 2>&1 | Out-Null
    }

    Write-Info "Clearing pip cache..."
    if (Get-Command pip -ErrorAction SilentlyContinue) {
        pip cache purge 2>&1 | Out-Null
    }

    # removes .ignore, .old, cache files, .nupkg embedded archives and other residual files
    Write-Info "Clearing Chocolatey residual files..."
    if (Get-Command choco-cleaner -ErrorAction SilentlyContinue) {
        choco-cleaner 2>&1 | Out-Null
    }

    $afterBytes    = (Get-PSDrive $driveLetter).Free
    $totalFreedGiB = [math]::Round(($afterBytes - $beforeBytes) / 1GB, 2)

    Write-Done "Cleanup complete — $totalFreedGiB GiB freed. Icon cache takes effect on next reboot."
}


# ════════════════════════════════════════════════════════════
#  SECTION 3 — UPDATE
#  Windows Update requires:  Install-Module PSWindowsUpdate
# ════════════════════════════════════════════════════════════

function Invoke-Update {

    if (-not (Assert-Admin "update")) { return }

    $driveLetter = $env:SystemDrive.TrimEnd(':')
    $freeGiB = [math]::Round((Get-PSDrive $driveLetter).Free / 1GB, 2)
    if ($freeGiB -lt 3) {
        Write-Warn "Less than 3 GiB free on $($env:SystemDrive) ($freeGiB GiB)."
        $answer = Read-Host "  Run cleanup now? [Y/n]"
        if ($answer -eq '' -or $answer -match '^[yY]$') {
            Invoke-Cleanup
            $freeGiB = [math]::Round((Get-PSDrive $driveLetter).Free / 1GB, 2)
            if ($freeGiB -lt 3) {
                Write-Fail "Still less than 3 GiB free. Free up space manually before updating."
                return
            }
        } else { return }
    }

    Write-Info "Upgrading via winget..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
    } else { Write-Warn "winget not found — skipped" }

    # choco can upgrade both powershell-core and choco-cleaner from within a running pwsh
    # session but doing so mid-upgrade can break the flow — both handled at the end
    Write-Info "Upgrading via Chocolatey (powershell-core and choco-cleaner excluded until end)..."
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        choco upgrade all -y --except "powershell-core,choco-cleaner" 2>&1
    } else { Write-Warn "Chocolatey not found — skipped" }

    # PSWindowsUpdate installed automatically if missing, then used immediately
    Write-Info "Checking Windows Update..."
    if (-not (Get-Command Install-WindowsUpdate -ErrorAction SilentlyContinue)) {
        Write-Info "PSWindowsUpdate not found — installing..."
        Install-Module PSWindowsUpdate -Force -AcceptLicense
    }
    Install-WindowsUpdate -AcceptAll -AutoReboot:$false

    # choco-cleaner upgraded before pwsh in case pwsh kills the session
    Write-Info "Upgrading Choco-Cleaner..."
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        choco upgrade choco-cleaner -y
    }

    # if the session is still alive after Windows Update, pwsh wasn't updated there
    # safe to upgrade now — if it kills the session, everything else is already done
    Write-Info "Upgrading PowerShell Core..."
    Invoke-UpdatePwsh

    Write-Done "All updates complete — reboot when ready."
}

# Upgrades powershell-core via Chocolatey. Called as the last step of Invoke-Update
# but also aliased standalone for running outside of a pwsh session.
function Invoke-UpdatePwsh {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        choco upgrade powershell-core -y
    } else { Write-Warn "Chocolatey not found — skipped" }
}


# ════════════════════════════════════════════════════════════
#  SECTION 4 — RESETBASE
#  Collapses WinSxS to a new baseline, permanently removing
#  superseded update components. Typically frees 5-15 GB.
#  IRREVERSIBLE — run after confirming updates are stable.
#  Requires Administrator.
#  https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/clean-up-the-winsxs-folder?view=windows-11
# ════════════════════════════════════════════════════════════

function Invoke-ResetBase {

    if (-not (Assert-Admin "resetbase")) { return }

    Write-Info "Running WinSxS ResetBase — this will take several minutes..."
    Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase
    Write-Done "ResetBase complete — reboot recommended."
}


# ════════════════════════════════════════════════════════════
#  SECTION 5 — ALIASES
# ════════════════════════════════════════════════════════════

# Scripts
Set-Alias -Name cl        -Value Invoke-Cleanup
Set-Alias -Name up        -Value Invoke-Update
Set-Alias -Name up-pwsh   -Value Invoke-UpdatePwsh
Set-Alias -Name resetbase -Value Invoke-ResetBase

# Shell
function reload { . $PROFILE; Write-Done "Profile reloaded." }
function q      { exit }

# Power management
# zz uses SetSuspendState — follows Windows power plan (hibernates if enabled, sleeps if not)
function zz  {
    Add-Type -Assembly System.Windows.Forms
    [System.Windows.Forms.Application]::SetSuspendState('Suspend', $false, $false)
}
function po  { shutdown /s /t 0 }
function re  { shutdown /r /t 0 }
function lok { rundll32.exe user32.dll,LockWorkStation }
function out { logoff }

# restart Explorer
function reex {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer
}

# network
function ping { ping -n 6 google.com }  # should take ~5 seconds
