# ============================================================
#  Microsoft.PowerShell_profile.ps1
#  PowerShell 7+ equivalent of ~/.bashrc
#  Profile path:    C:\Users\<username>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
#
#  First time setup — run once in an admin PowerShell session:
#    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
# ============================================================

#  Packages used, install for the full functionality:
#
#    fastfetch  (terminal info on spawn)
#      winget install fastfetch
#
#    Chocolatey  (package manager, used throughout)
#      https://chocolatey.org/install
#
#    Choco-Cleaner  (chocolatey residual file cleanup)
#      choco install choco-cleaner
#
#    PSWindowsUpdate  (Windows Update via terminal)
#      Install-Module PowerShellGet -Force -AllowClobber
#      Install-Module PSWindowsUpdate

#  Optional, features silently skip if not installed:
#
#    btop      (top/hotp aliases — htop has no native Windows build)
#      winget install btop
#
#    termdown  (td/tdh aliases)
#      pip install termdown
#
#    scrcpy    (scrcpy/scrcam aliases)
#      winget install scrcpy
#
#    fzf       (fuzzy package search alias)
#      winget install fzf
#
#    npm, pip  (cache cleanup steps)

#  Typically preinstalled, verify with `Get-Command <name>`:
#
#    curl.exe, tar.exe   (Windows 10 1803+ / Windows 11)
#    ping.exe            (built-in networking)

#  Windows-specific:
#
#    No Plasma/qdbus6 equivalent — session actions use shutdown.exe, rundll32, logoff
#    powercfg sleep-inhibit scope: SYSTEM + DISPLAY only, does not block screen lock
#      (same scope as bash's systemd-inhibit --what=sleep)

#  Output color conventions:
#
#    Blue    informational, in progress
#    Green   success, task complete
#    Yellow  prompts, warnings needing attention
#    Red     failures, aborts
#    White   neutral, user choice acknowledgement

#  Comment conventions:
#
#    if the comment or the command is very long/multi line, put the command before it, otherwise same line


############################################
#   Command to autorun on terminal spawn   #
############################################

if (Get-Command fastfetch -ErrorAction SilentlyContinue) { fastfetch }


#######################
#   Basic functions   #
#######################

Set-Location $HOME


###############
#   Exports   #
###############

# expand and persist PSReadLine history (bash: HISTFILESIZE/HISTSIZE)
Set-PSReadLineOption -MaximumHistoryCount 10000 -HistorySaveStyle SaveIncrementally

# Windows equivalents of XDG folders — already set natively, listed here for reference only
#   $env:LOCALAPPDATA   ~ XDG_CACHE_HOME / XDG_DATA_HOME
#   $env:APPDATA         ~ XDG_CONFIG_HOME
#   $env:TEMP            ~ /tmp


#################
#   Functions   #
#################

#    shared helpers

function Write-Info    { param([string]$msg) Write-Host "  $msg" -ForegroundColor Blue }
function Write-Done    { param([string]$msg) Write-Host "  ✅  $msg" -ForegroundColor Green }
function Write-Warn    { param([string]$msg) Write-Host "  ⚠️  $msg" -ForegroundColor Yellow }
function Write-Fail    { param([string]$msg) Write-Host "  ❌  $msg" -ForegroundColor Red }
function Write-Neutral { param([string]$msg) Write-Host "  $msg" -ForegroundColor White }

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

# Free space on the system drive, in GiB — shared by Invoke-Cleanup and Invoke-Update
function Get-FreeSpaceGiB {
    [math]::Round((Get-PSDrive $env:SystemDrive.TrimEnd(':')).Free / 1GB, 2)
}

#    no Windows equivalent for mirrorranking or availableupdates (no unified mirror/update
#    list mechanism the way pacman has — winget/choco upgrade lists are folded into Invoke-Update)

function Invoke-Cleanup {

    if (-not (Assert-Admin "cleanup")) { return }

    $ErrorActionPreference = "SilentlyContinue"

    $beforeGiB = Get-FreeSpaceGiB

    Write-Info "Clearing thumbnail cache..."
    Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction SilentlyContinue

    Write-Info "Queueing icon cache for deletion on next reboot..."
    Remove-OnReboot "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*.db"

    Write-Info "Clearing Windows Temp..."
    Remove-Folder "$env:SystemRoot\Temp"

    Write-Info "Clearing User Temp..."
    Remove-Folder $env:TEMP

    Write-Info "Clearing Windows Update download cache..."
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Remove-Folder "$env:SystemRoot\SoftwareDistribution\Download"
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue

    Write-Info "Clearing Delivery Optimisation cache..."
    try {
        Delete-DeliveryOptimizationCache -Force
    } catch {
        Remove-Folder "$env:SystemRoot\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache"
    }

#     i don't trust this
#     Write-Info "Clearing browser caches (Edge, Chrome, Firefox, Brave)..."
#     $browserCaches = @(
#         "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\Cache_Data"
#         "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache"
#         "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\Cache_Data"
#         "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache"
#         "$env:APPDATA\Mozilla\Firefox\Profiles"
#         "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache\Cache_Data"
#     )
#     foreach ($p in $browserCaches) {
#         if ($p -like "*Firefox*") {
#             Get-ChildItem $p -Directory -ErrorAction SilentlyContinue | ForEach-Object {
#                 Remove-Folder "$($_.FullName)\cache2"
#             }
#         } else {
#             Remove-Folder $p
#         }
#     }

    Write-Info "Flushing DNS cache..."
    ipconfig /flushdns | Out-Null

    Write-Info "Emptying Recycle Bin..."
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue

    Write-Info "Clearing npm cache..."
    if (Get-Command npm -ErrorAction SilentlyContinue) { npm cache clean --force 2>&1 | Out-Null }

    Write-Info "Clearing pip cache..."
    if (Get-Command pip -ErrorAction SilentlyContinue) { pip cache purge 2>&1 | Out-Null }

    Write-Info "Clearing Chocolatey residual files..."
    if (Get-Command choco-cleaner -ErrorAction SilentlyContinue) { choco-cleaner 2>&1 | Out-Null }

    $afterGiB      = Get-FreeSpaceGiB
    $totalFreedGiB = [math]::Round($afterGiB - $beforeGiB, 2)

    Write-Done "Cleanup complete — $totalFreedGiB GiB freed. Icon cache takes effect on next reboot."
}

function Invoke-Update {

    if (-not (Assert-Admin "update")) { return }

    $freeGiB = Get-FreeSpaceGiB
    if ($freeGiB -lt 3) {
        Write-Warn "Less than 3 GiB free on $($env:SystemDrive) ($freeGiB GiB)."
        $answer = Read-Host "  Run cleanup now? [Y/n]"
        if ($answer -eq '' -or $answer -match '^[yY]$') {
            Invoke-Cleanup
            $freeGiB = Get-FreeSpaceGiB
            if ($freeGiB -lt 3) {
                Write-Fail "Still less than 3 GiB free. Free up space manually before updating."
                return
            }
        } else { return }
    }

    $os = (Get-CimInstance Win32_OperatingSystem).Caption
    $feedUrl = switch -Wildcard ($os) {
        "*Windows 11*" { "https://support.microsoft.com/en-us/feed/atom/4ec863cc-2ecd-e187-6cb3-b50c6545db92" }
        "*Windows 10*" { "https://support.microsoft.com/en-us/feed/atom/6ae59d69-36fc-8e4d-23dd-631d98bf74a9" }
        default        { "https://support.microsoft.com/en-us/feed/atom/4ec863cc-2ecd-e187-6cb3-b50c6545db92" }
    }
    Write-Info "📰 Latest Windows updates:"
    try {
        $feed = Invoke-RestMethod -Uri $feedUrl -TimeoutSec 8 -ErrorAction Stop
        $feed.feed.entry | Select-Object -First 2 | ForEach-Object {
            $dateStr = ""
            try { $dateStr = [datetime]::Parse($_.updated).ToString('yy.MM.dd') } catch {}
            $prefix = if ($dateStr) { "$dateStr: " } else { "" }
            $kbPart = if ([string]$_.title -match '—(.+)') { $Matches[1].Trim() } else { [string]$_.title }
            Write-Info "$prefix$kbPart - $($_.link.href)"
        }
    } catch {
        Write-Warn "Could not fetch update history — check manually: https://learn.microsoft.com/en-us/windows/release-health/"
    }

    $answer = Read-Host "`n  Continue with system update? [Y/n]"
    if ($answer -ne '' -and $answer -notmatch '^[yY]$') {
        Write-Neutral "🚫 Update cancelled."
        return
    }

    $processName = (Get-Process -Id $PID).Name + ".exe"
    powercfg /requestsoverride PROCESS $processName SYSTEM DISPLAY AWAYMODE 2>$null
    try {

        Write-Info "Upgrading via winget..."
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
        } else { Write-Warn "winget not found — skipped" }

        Write-Info "Upgrading via Chocolatey (powershell-core and choco-cleaner excluded until end)..."
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            choco upgrade all -y --except "powershell-core,choco-cleaner" 2>&1 | Out-Host
        } else { Write-Warn "Chocolatey not found — skipped" }

        Write-Info "Checking Windows Update..."
        if (-not (Get-Command Install-WindowsUpdate -ErrorAction SilentlyContinue)) {
            Write-Info "PSWindowsUpdate not found — installing..."
            Install-Module PSWindowsUpdate -Force -AcceptLicense
        }
        Install-WindowsUpdate -AcceptAll -AutoReboot:$false

        Write-Info "Upgrading Choco-Cleaner..."
        if (Get-Command choco -ErrorAction SilentlyContinue) { choco upgrade choco-cleaner -y }

        Write-Info "Upgrading PowerShell Core..."
        Invoke-UpdatePwsh

        Write-Done "All updates complete — reboot when ready."

    } finally {
        powercfg /requestsoverride PROCESS $processName 2>$null
    }
}

function Invoke-UpdatePwsh {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        choco upgrade powershell-core -y
    } else { Write-Warn "Chocolatey not found — skipped" }
}

# Check current overrides with: powercfg /requestsoverride
function Clear-SleepOverride {
    param([string]$ProcessName = ((Get-Process -Id $PID).Name + ".exe"))
    powercfg /requestsoverride PROCESS $ProcessName 2>$null
    Write-Done "Cleared sleep override for $ProcessName (if any existed)."
}

# Collapses WinSxS to a new baseline, permanently removing superseded update components.
# Typically frees 5-15 GB. IRREVERSIBLE — run after confirming updates are stable.
function Invoke-ResetBase {
    if (-not (Assert-Admin "resetbase")) { return }
    Write-Info "Running WinSxS ResetBase — this will take several minutes..."
    Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase
    Write-Done "ResetBase complete — reboot recommended."
}

# Remove a package, attempting both winget and Chocolatey since Windows has no
# single source of truth for which manager installed it
function Remove-Package {
    param(
        [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments = $true)]
        [string[]]$Name
    )

    Write-Host "`n  ⚠️ PURGE: $($Name -join ' ') ?" -ForegroundColor Red
    Write-Host "  This will attempt removal via both winget and Chocolatey." -ForegroundColor Red
    Write-Host "  Proceed? [y/N] " -NoNewline -ForegroundColor White
    $purgeAnswer = Read-Host
    if ($purgeAnswer -notmatch '^[yY]$') { Write-Host "`n  Purge cancelled.`n"; return }

    Write-Host "  Are you doubly sure? This cannot be undone! [y/N] " -NoNewline -ForegroundColor Red
    $confirmAnswer = Read-Host
    if ($confirmAnswer -notmatch '^[yY]$') { Write-Host "`n  Purge cancelled.`n"; return }

    foreach ($pkg in $Name) {
        if (Get-Command winget -ErrorAction SilentlyContinue) { winget uninstall --name $pkg --silent 2>$null }
        if (Get-Command choco -ErrorAction SilentlyContinue) { choco uninstall $pkg -y 2>$null }
    }
}


################
#   Bindings   #
################

# Windows Terminal binds Ctrl+V to paste directly — no readline literal-insert
# conflict the way Linux terminals have, so no Ctrl+Shift+V workaround is needed

Set-PSReadLineKeyHandler -Key Ctrl+Backspace -Function BackwardKillWord
Set-PSReadLineKeyHandler -Key Ctrl+Delete -Function KillWord
Set-PSReadLineKeyHandler -Key Ctrl+LeftArrow -Function BackwardWord
Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key Shift+Tab -Function MenuComplete


#####################
#   Look and feel   #
#####################

# mirrors bash PS1's magenta/blue/magenta pattern, also sets the window title
function prompt {
    $path = $PWD.Path
    Write-Host "@ " -NoNewline -ForegroundColor Magenta
    Write-Host "$path" -NoNewline -ForegroundColor Blue
    Write-Host " ~ " -NoNewline -ForegroundColor Magenta
    $Host.UI.RawUI.WindowTitle = "@ $path"
    return " "
}


###################
#   Completions   #
###################

# PowerShell's tab completion is built-in for cmdlets, functions, and parameters —
# no equivalent of sourcing bash-completion is needed


###############
#   Aliases   #
###############

#     session actions
function zz  { Add-Type -Assembly System.Windows.Forms; [System.Windows.Forms.Application]::SetSuspendState('Suspend', $false, $false) }  # sleep
function po  { shutdown /s /t 0 }
function re  { shutdown /r /t 0 }
function lok { rundll32.exe user32.dll,LockWorkStation }
function out { logoff }

#     package management
Set-Alias -Name cl        -Value Invoke-Cleanup
Set-Alias -Name up        -Value Invoke-Update
Set-Alias -Name up-pwsh   -Value Invoke-UpdatePwsh
Set-Alias -Name resetbase -Value Invoke-ResetBase
Set-Alias -Name purge     -Value Remove-Package
# search winget packages with fzf — column parsing is best-effort, winget's table
# widths can shift, unlike yay's clean newline list
function f {
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) { Write-Warn "fzf not found — skipped"; return }
    $pkg = winget search "" --accept-source-agreements 2>$null | Select-Object -Skip 2 | fzf | ForEach-Object { ($_ -split '\s{2,}')[1] }
    if ($pkg) { winget install --id $pkg }
}

#     terminal
function reload { . $PROFILE; Write-Done "Profile reloaded." }
function c       { Clear-Host }
function q       { exit }
function x       { exit }
# ping.exe called explicitly — a function named "ping" calling "ping" would recurse into itself
function ping    { ping.exe -n 6 google.com }

#     files and navigation
function l  { Get-ChildItem -Force }
function ll { Get-ChildItem -Force | Format-List }

#     programs
function ff     { if (Get-Command fastfetch -ErrorAction SilentlyContinue) { fastfetch } else { Write-Warn "fastfetch not found" } }
function top    { if (Get-Command btop -ErrorAction SilentlyContinue) { btop } else { Write-Warn "btop not found — htop has no native Windows build" } }
function hotp   { top }
function td     { if (Get-Command termdown -ErrorAction SilentlyContinue) { termdown } else { Write-Warn "termdown not found" } }
function tdh    { termdown --help }
function scrcpy { scrcpy.exe --video-codec=h265 --max-fps=60 --turn-screen-off --stay-awake }
# --v4l2-sink dropped — that's a Linux-only virtual camera device, no Windows equivalent
function scrcam { scrcpy.exe --video-source=camera --camera-size=1920x1080 --camera-facing=front --no-playback }
# restart Explorer — useful after shell/theme changes or freezes, no bash equivalent
function re-explorer {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer
}

#     remote scripts
# win/windev mirror bash's lin/lindev — same Chris Titus Tech project, Windows branch
function win    { irm https://christitus.com/win | iex }
function windev { irm https://christitus.com/windev | iex }
function we     { curl wttr.in }   # weather
