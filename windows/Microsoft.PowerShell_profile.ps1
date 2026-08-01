#################################################################################
#   C:\Users\<username>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1   #
#################################################################################

#  PowerShell 7+ equivalent of ~/.bashrc

#  First time setup:
#
#  Enable runnig a downloaded file (admin)
#     Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
#  At this point the file may still be flagged as downloaded, so you need to get rid of that:
#     Get-ExecutionPolicy -List
#     Get-Item -Path $PROFILE -Stream Zone.Identifier
#     Unblock-File -Path $PROFILE
#
#  Disable startup update check that can take up to 10+ seconds:
#     [System.Environment]::SetEnvironmentVariable("POWERSHELL_UPDATECHECK", "Off", [System.EnvironmentVariableTarget]::User)

#  Legend:
#  Command on terminal spawn, Basic functions, Exports, Functions, Bindings, Look and feel, Completions, Aliases

#  Packages used, install for the full functionality:
#    Chocolatey  (package manager, used throughout) https://chocolatey.org/install
#    winget: can be installed with ctt' winutil
#    Choco-Cleaner  (chocolatey residual file cleanup): choco install choco-cleaner
#    PSWindowsUpdate  (Windows Update via terminal)
#      Installed automatically on first `up` run if missing

#  Optional, features silently skip if not installed:
#
#    fastfetch (terminal info on spawn) winget install fastfetch
#    btop      (top/hotp aliases - htop has no native Windows build): winget install btop
#    termdown  (td/tdh aliases): pip install termdown
#    scrcpy    (scrcpy/scrcam aliases): winget install scrcpy
#    fzf       (fuzzy package search alias): winget install fzf

#  Typically preinstalled, verify with `Get-Command <name>`:
#
#    curl.exe, tar.exe   (Windows 10 1803+ / Windows 11)
#    ping.exe            (built-in networking)

#  Windows-specific:
#
#    Session actions use shutdown.exe, rundll32, logoff
#    powercfg sleep-inhibit scope: SYSTEM + DISPLAY only, does not block screen lock

#  Output color conventions:
#
#    Blue    informational, in progress
#    Green   success, task complete
#    Yellow  prompts, warnings needing attention
#    Red     failures, aborts

#  Comment conventions:
#
#    if the comment or the command is very long/multi line, put the command before it, otherwise same line


#################################
#   Command on terminal spawn   #
#################################

if (Get-Command fastfetch -ErrorAction SilentlyContinue) { fastfetch }


#######################
#   Basic functions   #
#######################

# don't show how long it took to spawn the terminal
$PSProfileLoadTimePreference = 'Silent'
# C:\Users\<CurrentUser>\ by default, like on linux
Set-Location $HOME


###############
#   Exports   #
###############

# expand and persist PSReadLine history (bash: HISTFILESIZE/HISTSIZE)
Set-PSReadLineOption -MaximumHistoryCount 10000 -HistorySaveStyle SaveIncrementally

# Windows equivalents of XDG folders - already set natively, listed for reference only
# $env:LOCALAPPDATA   ~ XDG_CACHE_HOME / XDG_DATA_HOME
# $env:APPDATA        ~ XDG_CONFIG_HOME
# $env:TEMP           ~ /tmp


#################
#   Functions   #
#################

#    shared helpers
function Write-Info    { param([string]$msg) Write-Host "  $msg" -ForegroundColor Blue }
function Write-Done    { param([string]$msg) Write-Host "  ✅  $msg" -ForegroundColor Green }
function Write-Warn    { param([string]$msg) Write-Host "  ⚠️  $msg" -ForegroundColor Yellow }
function Write-Fail    { param([string]$msg) Write-Host "  ❌  $msg" -ForegroundColor Red }

function Remove-Folder {
    param([string]$path)
    if (Test-Path $path) {
        Remove-Item "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# tracks profile versions via GitHub commit history so local edits ahead of upstream
# never trigger a false "update available" prompt - mirrors bash's bashup design.
# Always backs up before replacing, never overwrites blindly.
function powershellup {
    $repoOwner = "Kingproone"
    $repoName = "dotfiles"
    $repoBranch = "main"
    $repoPath = "windows/Microsoft.PowerShell_profile.ps1"
    $repoRawUrl = "https://raw.githubusercontent.com/$repoOwner/$repoName/$repoBranch/$repoPath"
    $commitsApiUrl = "https://api.github.com/repos/$repoOwner/$repoName/commits?path=$repoPath&sha=$repoBranch&per_page=30"
    $shaCacheDir = "$env:LOCALAPPDATA\powershellup"
    $shaCache = "$shaCacheDir\sha"
    $bodyIndent = "            "

    function Save-Sha {
        param($sha)
        if (-not $sha) { return }
        if (-not (Test-Path $shaCacheDir)) { New-Item -ItemType Directory -Path $shaCacheDir -Force | Out-Null }
        Set-Content -Path $shaCache -Value $sha -NoNewline
    }

    Write-Info "Checking for a newer profile on GitHub..."

    $remoteShas = @()
    $remoteDates = @()
    $remoteMsgs = @()
    $remoteBodies = @()

    try {
        $commits = Invoke-RestMethod -Uri $commitsApiUrl -TimeoutSec 10 -ErrorAction Stop
        foreach ($c in $commits) {
            $remoteShas += $c.sha
            try { $remoteDates += [datetime]::Parse($c.commit.author.date).ToString('yy.MM.dd') } catch { $remoteDates += "" }
            $lines = $c.commit.message -split '\r?\n'
            $remoteMsgs += $lines[0]
            if ($lines.Count -gt 1) {
                $remoteBodies += ,@($lines[1..($lines.Count - 1)] | Where-Object { $_ -ne '' })
            } else {
                $remoteBodies += ,@()
            }
        }
    } catch {
        # remoteShas stays empty, falls through to the API-failed message path below
    }

    $storedSha = ""
    if (Test-Path $shaCache) { $storedSha = (Get-Content $shaCache -Raw).Trim() }

    # first run ever: nothing to compare against yet, record current HEAD as the
    # baseline and stop. local content is irrelevant here: bootstrapping only means
    # "start tracking from now," not "local matches remote"
    if ($remoteShas.Count -gt 0 -and -not $storedSha) {
        Save-Sha $remoteShas[0]
        Write-Done "Now tracking profile versions from this point on."
        return
    }

    if ($remoteShas.Count -gt 0) {
        if ($remoteShas[0] -eq $storedSha) {
            Write-Done "Already up to date."
            return
        }
        $found = -1
        for ($i = 0; $i -lt $remoteShas.Count; $i++) {
            if ($remoteShas[$i] -eq $storedSha) { $found = $i; break }
        }
        if ($found -ge 0) {
            Write-Warn "New commits since your last pull:"
            for ($j = 0; $j -lt $found; $j++) {
                Write-Host " • $($remoteDates[$j]): $($remoteMsgs[$j])" -ForegroundColor Yellow
                foreach ($bline in $remoteBodies[$j]) {
                    Write-Host "$bodyIndent$bline" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Warn "Could not place your version in recent history (older than fetched range, or history changed), falling back to content comparison."
        }
    } else {
        Write-Warn "Could not reach the GitHub API for version info, falling back to content comparison."
    }

    try {
        $rawContent = Invoke-RestMethod -Uri $repoRawUrl -TimeoutSec 10 -ErrorAction Stop
    } catch {
        Write-Fail "Failed to fetch, check connection or repo URL."
        return
    }
    if (-not $rawContent) {
        Write-Fail "Empty response, GitHub may be down or the path changed."
        return
    }

    $localContent = Get-Content -Path $PROFILE -Raw
    $remoteLines = $rawContent -split '\r?\n'
    $localLines = $localContent -split '\r?\n'

    if (-not (Compare-Object -ReferenceObject $localLines -DifferenceObject $remoteLines)) {
        Write-Done "Already up to date."
        Save-Sha $remoteShas[0]
        return
    }

    # PowerShell has no built-in unified-diff tool, Compare-Object gives a +/- style
    # listing (no hunk headers/context lines like diff -u), kept dependency-free on purpose
    Write-Warn "Differences found:"
    Compare-Object -ReferenceObject $localLines -DifferenceObject $remoteLines | ForEach-Object {
        if ($_.SideIndicator -eq '=>') {
            Write-Host "  + $($_.InputObject)" -ForegroundColor Green
        } else {
            Write-Host "  - $($_.InputObject)" -ForegroundColor Red
        }
    }

    $upgradeAnswer = Read-Host "  Upgrade profile? [Y/n]"
    if ($upgradeAnswer -ne '' -and $upgradeAnswer -notmatch '^[yY]$') {
        Write-Info "Upgrade cancelled."
        return
    }

    Copy-Item -Path $PROFILE -Destination "$PROFILE.bak" -Force
    Set-Content -Path $PROFILE -Value $rawContent -NoNewline
    Save-Sha $remoteShas[0]
    Write-Done "Profile updated. Backup saved to $PROFILE.bak"

    $reloadAnswer = Read-Host "  Reload now? [Y/n]"
    if ($reloadAnswer -ne '' -and $reloadAnswer -notmatch '^[yY]$') {
        Write-Info "Not reloading, run '. reload' when ready."
        return
    }
    Write-Info "Run '. reload' to apply the changes to this session."
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
        Write-Warn "sudo is available - run: sudo pwsh -Command $cmdName"
    } else {
        Write-Warn "Right-click Windows Terminal → Run as administrator"
    }
    return $false
}

# Free space on the system drive, in GiB - shared by Invoke-Cleanup and Invoke-Update
function Get-FreeSpaceGiB {
    [math]::Round((Get-PSDrive $env:SystemDrive.TrimEnd(':')).Free / 1GB, 2)
}

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

    Write-Done "✅ Cleanup complete. Freed $totalFreedGiB GiB. Icon cache takes effect on next reboot."
}

# prevents system sleep via the real Win32 sleep-prevention API. powercfg /requestsoverride
# (the previous approach) only overrides a request a process is ALREADY making, it can't
# create a sleep-prevention effect for a process (like plain pwsh.exe) that makes no power
# request of its own, so it silently did nothing. SetThreadExecutionState is the correct,
# standard mechanism for a script to actually request this.
function Set-SleepPrevention {
    param([switch]$Disable)
    Add-Type -TypeDefinition @"
        using System;
        using System.Runtime.InteropServices;
        public class PowerState {
            [DllImport("kernel32.dll", SetLastError = true)]
            public static extern uint SetThreadExecutionState(uint esFlags);
        }
"@ -ErrorAction SilentlyContinue

    $ES_CONTINUOUS = 0x80000000u
    $ES_SYSTEM_REQUIRED = 0x00000001u

    if ($Disable) {
        # ES_CONTINUOUS alone clears any previously set requirement
        [PowerState]::SetThreadExecutionState($ES_CONTINUOUS) | Out-Null
    } else {
        [PowerState]::SetThreadExecutionState($ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED) | Out-Null
    }
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
        $response = Invoke-WebRequest -Uri $feedUrl -TimeoutSec 8 -ErrorAction Stop
        $feed = [xml]$response.Content
        $feed.feed.entry | Select-Object -First 2 | ForEach-Object {
            $dateStr = ""
            try { $dateStr = [datetime]::Parse($_.updated).ToString('yy.MM.dd') } catch {}
            $prefix = if ($dateStr) { "${dateStr}: " } else { "" }
            $kbPart = if ([string]$_.title -match '-(.+)') { $Matches[1].Trim() } else { [string]$_.title }
            Write-Info "$prefix$kbPart - $($_.link.href)"
        }
    } catch {
        Write-Warn "Could not fetch update history, check manually: https://learn.microsoft.com/en-us/windows/release-health/"
    }

    $answer = Read-Host "`n  Continue with system update? [Y/n]"
    if ($answer -ne '' -and $answer -notmatch '^[yY]$') {
        Write-Info "🚫 Update cancelled."
        return
    }

    Set-SleepPrevention
    try {

        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Info "Upgrading via winget..."
            winget pin add --id Microsoft.PowerShell --silent 2>$null | Out-Null
            winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
        }

        if (Get-Command choco -ErrorAction SilentlyContinue) {
            Write-Info "Upgrading via Chocolatey (powershell-core excluded until end)..."
#             choco upgrade all -y --except "powershell-core" 2>&1 | Out-Host
# if it gets stuck mid upgrade, use the commented one instead
            choco upgrade all -y --except "powershell-core"

            if (-not (Get-Command choco-cleaner -ErrorAction SilentlyContinue)) {
                Write-Info "Choco-Cleaner not found, installing..."
                choco install choco-cleaner -y 2>&1 | Out-Host
            }
        }

        # Known limitation: PSWindowsUpdate wraps the older Windows Update Agent
        # COM API, which doesn't always see everything the modern Settings-app pipeline does
        # particularly larger cumulative/build updates. Treat it as best-effort; if a KB
        # doesn't show up here, check Settings > Windows Update manually.
        Write-Info "Checking Windows Update..."
        if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Write-Info "PSWindowsUpdate not found, installing..."
            try {
                Install-Module PSWindowsUpdate -Scope CurrentUser -Force -AcceptLicense -ErrorAction Stop
            } catch {
                Write-Fail "Failed to install PSWindowsUpdate: $($_.Exception.Message)"
            }
        }
        Import-Module PSWindowsUpdate -Force -ErrorAction SilentlyContinue
        if (Get-Command Install-WindowsUpdate -ErrorAction SilentlyContinue) {
            Install-WindowsUpdate -AcceptAll -AutoReboot:$false
        } else {
            Write-Warn "PSWindowsUpdate still unavailable, skipping Windows Update"
        }

        Write-Info "Upgrading PowerShell Core..."
        Invoke-UpdatePwsh

        Write-Done "All updates complete."

    } finally {
        Set-SleepPrevention -Disable
    }
}

function Invoke-UpdatePwsh {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        choco upgrade powershell-core -y
    } else { Write-Warn "Chocolatey not found - skipped" }
}

# Upgrades powershell-core via package manager
# Called as the last step of Invoke-Update
function Invoke-UpdatePwsh {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget upgrade --id Microsoft.PowerShell --silent --accept-package-agreements --accept-source-agreements
    } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
        choco upgrade powershell-core -y
    } else {
        Write-Warn "Neither winget nor Chocolatey found, skipped"
    }
}

# Manually clear a stale powercfg override left behind by an older version of this
# profile. No longer set by Invoke-Update (replaced by Set-SleepPrevention), kept here
# purely as a one-time cleanup tool for anyone upgrading from that version.
# Check current overrides with: powercfg /requestsoverride
function Clear-SleepOverride {
    param([string]$ProcessName = ((Get-Process -Id $PID).Name + ".exe"))
    powercfg /requestsoverride PROCESS $ProcessName 2>$null
    Write-Done "Cleared sleep override for $ProcessName (if any existed)."
}

# Collapses WinSxS to a new baseline, permanently removing superseded update components.
# Typically frees 5-15 GB. IRREVERSIBLE - run after confirming updates are stable.
function Invoke-ResetBase {
    if (-not (Assert-Admin "resetbase")) { return }
    Write-Info "Running WinSxS ResetBase - this will take several minutes..."
    Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase
    Write-Done "ResetBase complete - reboot recommended."
}

# Fuzzy-searchable uninstaller across both winget and choco's installed package lists,
# mirroring bash's `r` alias. Each entry is tagged with its source so removal routes to
# the correct manager. winget's table output is the same fragile column-width format
# already noted in the `f` alias below, verify against real output before trusting it.
function uninstall {
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) { Write-Warn "fzf not found, skipped"; return }

    $wingetList = if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget list --accept-source-agreements 2>$null | Select-Object -Skip 2 | ForEach-Object {
            $id = ($_ -split '\s{2,}')[1]
            if ($id) { "[winget] $id" }
        }
    }
    $chocoList = if (Get-Command choco -ErrorAction SilentlyContinue) {
        choco list 2>$null | Where-Object { $_ -match '^\S+ \S+$' } | ForEach-Object {
            "[choco] $(($_ -split ' ')[0])"
        }
    }

    $selected = @($wingetList) + @($chocoList) | Where-Object { $_ } | fzf --multi
    foreach ($item in $selected) {
        if ($item -match '^\[winget\] (.+)$') { winget uninstall --id $Matches[1] --silent }
        elseif ($item -match '^\[choco\] (.+)$') { choco uninstall $Matches[1] -y }
    }
}


################
#   Bindings   #
################

# Windows Terminal binds Ctrl+V to paste directly - no readline literal-insert
# conflict the way Linux terminals have, so no Ctrl+Shift+V workaround is needed

Set-PSReadLineKeyHandler -Key Ctrl+Backspace -Function BackwardKillWord
Set-PSReadLineKeyHandler -Key Ctrl+Delete -Function KillWord
Set-PSReadLineKeyHandler -Key Ctrl+LeftArrow -Function BackwardWord
Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord
# type initial letters of a command, then up/down arrows to search history
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
# default puts the cursor where it was when you pressed up/down, move it to the
# end of the recalled line instead, matching how most people expect history to behave
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete         # Tab cycles forward through matches
Set-PSReadLineKeyHandler -Key Shift+Tab -Function MenuComplete   # Shift + Tab cycles backwards


#####################
#   Look and feel   #
#####################

# mirrors bash PS1's magenta/blue/magenta pattern, also sets the window title
function prompt {
    $path = $PWD.Path
    Write-Host "@ " -NoNewline -ForegroundColor Magenta
    Write-Host "$path" -NoNewline -ForegroundColor Blue
    Write-Host " ~" -NoNewline -ForegroundColor Magenta
    $Host.UI.RawUI.WindowTitle = "@ $path"
    return " "
}


###################
#   Completions   #
###################

# PowerShell's tab completion is built-in for cmdlets, functions, and parameters -
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
Set-Alias -Name upsh      -Value Invoke-UpdatePwsh
Set-Alias -Name resetbase -Value Invoke-ResetBase
Set-Alias -Name r         -Value uninstall
# search winget packages with fzf - column parsing is best-effort, winget's table
# widths can shift, unlike yay's clean newline list
function f {
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) { Write-Warn "fzf not found - skipped"; return }
    $pkg = winget search "" --accept-source-agreements 2>$null | Select-Object -Skip 2 | fzf | ForEach-Object { ($_ -split '\s{2,}')[1] }
    if ($pkg) { winget install --id $pkg }
}

#     terminal
# reload doesn't really seem to work the same as on linux, even with using '. reload'
function reload  { . $PROFILE; Write-Done "Profile reloaded." }
function c       { Clear-Host }
function q       { exit }
function x       { exit }
# ping.exe called explicitly - a function named "ping" calling "ping" would recurse into itself
function ping    { ping.exe -n 6 google.com }

#     files and navigation
function l  { Get-ChildItem -Force }
function ll { Get-ChildItem -Force | Format-List }

#     programs
function ff     { if (Get-Command fastfetch -ErrorAction SilentlyContinue) { fastfetch } else { Write-Warn "fastfetch not found" } }
function top    { if (Get-Command btop -ErrorAction SilentlyContinue) { btop } else { Write-Warn "btop not found - htop has no native Windows build" } }
function hotp   { top }
function td     { if (Get-Command termdown -ErrorAction SilentlyContinue) { termdown } else { Write-Warn "termdown not found" } }
function tdh    { termdown --help }
function scrcpy { scrcpy.exe --video-codec=h265 --max-fps=60 --turn-screen-off --stay-awake }
# --v4l2-sink dropped - that's a Linux-only virtual camera device, no Windows equivalent
function scrcam { scrcpy.exe --video-source=camera --camera-size=1920x1080 --camera-facing=front --no-playback }
# restart Explorer - useful after shell/theme changes or freezes, no bash equivalent
function rex {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer
}

#     remote scripts
function win    { irm https://christitus.com/win | iex }
function windev { irm https://christitus.com/windev | iex }
function we     { curl wttr.in }   # weather
Set-Alias -Name shup -Value powershellup
