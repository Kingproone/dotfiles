#   ~/.bashrc   #
#################

#  Packages used, install once before using this config:
#
#    pacman-contrib  (checkupdates, paccache)
#      sudo pacman -S pacman-contrib
#
#    yay  (AUR helper, used throughout)  (pre-installed on EOS)
#      https://github.com/Jguer/yay#installation
#
#    rate-mirrors  (mirror ranking)
#      sudo pacman -S rate-mirrors
#
#    fzf  (fuzzy package search aliases)
#      sudo pacman -S fzf
#
#    fastfetch  (terminal info on spawn)
#      sudo pacman -S fastfetch

#  Optional, features silently skip if not installed:
#
#    bash-completion  tab completion  (pre-installed on EOS)
#      sudo pacman -S bash-completion
#
#    flatpak          flatpak update/cleanup blocks
#      sudo pacman -S flatpak
#
#    topgrade, instead of yay and flatpak separately
#
#    appmanager (appimage updates)

#  Plasma-specific — non-functional on other DEs:
#
#    qt6-tools / qdbus6  [pre-installed with Plasma]
#      po, re, out, pod, red, outd aliases
#      DE logout in archupdate, replace the command for other DEs

#  Output color conventions:
#
#    Blue    \033[1;34m  informational, in progress
#    Green   \033[1;32m  success, task complete
#    Yellow  \033[1;33m  prompts, warnings needing attention
#    Red     \033[1;31m  failures, aborts
#    White   \033[1m     neutral, user choice acknowledgement

#  Comment conventions
#
#   if the comment or the command is very long/ multi line, put the command before it, otherwise same line


#   Command to autorun on terminal spawn   #
############################################

fastfetch


#   Basic functions   #
#######################

# to prevent running random stuff as root
[[ "$(whoami)" = "root" ]] && return

# limits recursive functions, see 'man bash'
[[ -z "$FUNCNEST" ]] && export FUNCNEST=100

# if not running interactively, don't do anything
[[ $- != *i* ]] && return

# append to history instead of overwriting
shopt -s histappend

# check window size after each command, update LINES and COLUMNS
shopt -s checkwinsize

# Tell VA-API to use the Mesa driver
export LIBVA_DRIVER_NAME=radeonsi
# For VDPAU
export VDPAU_DRIVER=radeonsi


#   Exports   #
###############

#      expand the history size
export HISTFILESIZE=10000
export HISTSIZE=500

#      add timestamp to history
export HISTTIMEFORMAT="%F %T "

#      crash symbols
export DEBUGINFOD_URLS="https://debuginfod.archlinux.org"

#      set up XDG folders
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"


#   Functions   #
#################

# based on: https://github.com/ChrisTitusTech/linutil/blob/main/core/tabs/system-setup/system-cleanup.sh
archcleanup() {
    # cache sudo credentials upfront to avoid mid-run prompts, no equivalent for doas
    sudo -v || { printf "\033[1;31mFailed to obtain sudo credentials. Aborting.\033[0m\n"; return 1; }

    printf "\033[1;32mPerforming system cleanup...\033[0m\n"

    # snapshot available space before cleanup for freed space calc
    local before
    before=$(df --output=avail / | tail -n1)

    printf "\033[1;32mRemoving leftover download directories from the package cache...\033[0m\n"
    if [ -d /var/cache/pacman/pkg ]; then
        sudo find /var/cache/pacman/pkg -type d -name "download-*" -exec rm -rf {} + 2>/dev/null || true
    fi

    printf "\033[1;32mCleaning package cache (keeping last 2 versions)...\033[0m\n"
    sudo paccache -rk2

    printf "\033[1;32mRemoving uninstalled package cache...\033[0m\n"
    sudo paccache -ruk0

    printf "\033[1;32mChecking for orphaned packages...\033[0m\n"
    local orphans
    orphans=$(pacman -Qtdq 2>/dev/null)
    [ -n "$orphans" ] && echo "$orphans" | sudo pacman -Rns - --noconfirm

    # corrupted or missing .git causes yay -Sc to bail
    printf "\033[1;32mRemoving broken yay AUR cache directories...\033[0m\n"
    find "$HOME/.cache/yay" -mindepth 1 -maxdepth 1 -type d ! -exec git -C {} rev-parse --git-dir \; -exec rm -rf {} + 2>/dev/null || true

    printf "\033[1;32mCleaning yay cache...\033[0m\n"
    yay -Sc --noconfirm </dev/null

    # managed by rate-mirrors separately
    printf "\033[1;32mRemoving mirrorlist pacnew files...\033[0m\n"
    sudo rm -f /etc/pacman.d/*.pacnew

    if command -v flatpak &>/dev/null; then
        printf "\033[1;32mCleaning unused Flatpak runtimes and repairing stale refs...\033[0m\n"
        flatpak uninstall --unused -y 2>/dev/null || true
        flatpak repair --user 2>/dev/null || true
    fi

    if [ -d /var/lib/systemd/coredump ]; then
        printf "\033[1;32mRemoving coredumps older than 3 days...\033[0m\n"
        sudo find /var/lib/systemd/coredump -type f -mtime +3 -delete 2>/dev/null || true
    fi

    # /tmp is tmpfs, clears on reboot
    printf "\033[1;32mCleaning /var/tmp files older than 5 days...\033[0m\n"
    [ -d /var/tmp ] && sudo find /var/tmp -type f -atime +5 -delete

    printf "\033[1;32mVacuuming systemd journal older than 3 days (system + user)...\033[0m\n"
    sudo journalctl --vacuum-time=3d
    journalctl --user --vacuum-time=3d # must run as user, not root

    local cleanup_answer
    printf "\033[1;33mEmpty the trash and clean cache files (over 5 days old and thumbnails excluded)? [y/N] \033[0m"
    read -r cleanup_answer
    if [[ "$cleanup_answer" == [yY] ]]; then
        [ -d "$HOME/.local/share/Trash" ] && find "$HOME/.local/share/Trash" -mindepth 1 -delete
        [ -d "$HOME/.cache" ] && find "$HOME/.cache/" -type f -atime +5 ! -path "$HOME/.cache/thumbnails/*" -delete
    fi

    local dev_answer
    if command -v npm &>/dev/null || command -v pip &>/dev/null || [ -d "$HOME/.cargo/registry" ]; then
        printf "\033[1;33mClean developer caches (cargo, npm, pip)? [y/N] \033[0m"
        read -r dev_answer
        if [[ "$dev_answer" == [yY] ]]; then
            [ -d "$HOME/.cargo/registry" ] && rm -rf "$HOME/.cargo/registry/cache"
            command -v npm &>/dev/null && npm cache clean --force 2>/dev/null || true
            command -v pip &>/dev/null && pip cache purge 2>/dev/null || true
        fi
    fi

    # fstrim is autorun by default on arch on a weekly basis
    # to confirm: systemctl status fstrim.timer

    local after freed
    after=$(df --output=avail / | tail -n1)
    freed=$(awk "BEGIN {printf \"%.2f\", ($after - $before) / 1048576}")
    printf "\033[1;32m✅ Cleanup complete. Freed %s GiB. Current disk usage:\033[0m\n" "$freed"
    df -h / | tail -n1
}

# rank pacman mirrors using rate-mirrors, to restore a backup run the below line
# sudo cp /etc/pacman.d/mirrorlist.bak /etc/pacman.d/mirrorlist
# rate-mirrors supports other distros as well, available in the extra repos
mirrorranking() {
    local rateinstall_answer
    if ! command -v rate-mirrors &>/dev/null; then
        printf "\033[1;31mrate-mirrors not found. Install it? [Y/n] \033[0m"
        read -r rateinstall_answer
        [[ -z "$rateinstall_answer" || "$rateinstall_answer" == [yY] ]] && yay -S rate-mirrors || return 1
        command -v rate-mirrors &>/dev/null || return 1
    fi

    if [[ -f "/etc/pacman.d/mirrorlist" ]]; then
        printf "\033[1;34mRanking Arch mirrors...\033[0m\n"
        sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
        rate-mirrors --save=/tmp/mirrorlist arch && sudo mv /tmp/mirrorlist /etc/pacman.d/mirrorlist
    fi

    if [[ -f "/etc/pacman.d/endeavouros-mirrorlist" ]]; then
        printf "\033[1;34mRanking EndeavourOS mirrors...\033[0m\n"
        sudo cp /etc/pacman.d/endeavouros-mirrorlist /etc/pacman.d/endeavouros-mirrorlist.bak
        rate-mirrors --save=/tmp/endeavouros-mirrorlist endeavouros && sudo mv /tmp/endeavouros-mirrorlist /etc/pacman.d/endeavouros-mirrorlist
    fi

    if [[ -f "/etc/pacman.d/chaotic-mirrorlist" ]]; then
        printf "\033[1;34mRanking Chaotic-AUR mirrors...\033[0m\n"
        sudo cp /etc/pacman.d/chaotic-mirrorlist /etc/pacman.d/chaotic-mirrorlist.bak
        rate-mirrors --save=/tmp/chaotic-mirrorlist chaotic-aur && sudo mv /tmp/chaotic-mirrorlist /etc/pacman.d/chaotic-mirrorlist
    fi

    printf "\033[1;32m✅ Mirror ranking complete.\033[0m\n"
}

# list available updates if the source is used
availableupdates() {
    local official_count=0 chaotic_count=0 aur_count=0 flat_count=0 appimage_count=0  # counters

    # gather all data upfront before any output
    local updates official_pkgs chaotic_pkgs aur_pkgs
    updates=$(checkupdates 2>/dev/null)
    official_pkgs=$(pacman -Sl core extra multilib endeavouros 2>/dev/null | awk '{print $2}')
    chaotic_pkgs=$(pacman -Sl chaotic-aur 2>/dev/null | awk '{print $2}')
    aur_pkgs=$(yay -Quq --aur 2>/dev/null)

    printf "\033[1;34m→ Official updates:\033[0m\n"
    official_count=$(grep -Fwf <(printf '%s\n' "$official_pkgs") <<< "$updates" | grep -Fwvf <(printf '%s\n' "$chaotic_pkgs") | tee /dev/tty | wc -l)
    printf "\033[1;34m→ %d package(s)\033[0m\n" "$official_count"

    # if a package is available through both an official channel and chaotic, it will be listed here, cantfix, count is correct tho
    if [[ -n "$chaotic_pkgs" ]]; then
        printf "\n\033[1;34m→ Chaotic-AUR updates:\033[0m\n"
        chaotic_count=$(grep -Fwf <(printf '%s\n' "$chaotic_pkgs") <<< "$updates" | tee /dev/tty | wc -l)
        printf "\033[1;34m→ %d package(s)\033[0m\n" "$chaotic_count"
    fi

    if [[ -n "$aur_pkgs" ]]; then
        printf "\n\033[1;34m→ AUR updates:\033[0m\n"
        aur_count=$(printf "%s\n" "$aur_pkgs" | tee /dev/tty | wc -l)
        printf "\033[1;34m→ %d package(s)\033[0m\n" "$aur_count"
    fi

    if command -v flatpak &>/dev/null && flatpak list --app 2>/dev/null | grep -q .; then
        printf "\n\033[1;34m→ Flatpak updates:\033[0m\n"
        flat_count=$(flatpak remote-ls --updates 2>/dev/null | tee /dev/tty | wc -l)
        printf "\033[1;34m→ %d package(s)\033[0m\n" "$flat_count"
    fi

    local appimage_output
    if command -v app-manager &>/dev/null; then
        appimage_output=$(app-manager --update-check 2>/dev/null)
        if [[ "$appimage_output" != *"No installed apps"* ]]; then
            printf "\n\033[1;34m→ AppImage updates:\033[0m\n"
            appimage_count=$(printf "%s\n" "$appimage_output" | grep -v "All apps up to date" | tee /dev/tty | wc -l)
            printf "\033[1;34m→ %d package(s)\033[0m\n" "$appimage_count"
        fi
    fi

    local total installed percent update_color
    total=$(( official_count + chaotic_count + aur_count + flat_count + appimage_count ))
    installed=$(( $(pacman -Qq 2>/dev/null | wc -l) + $(flatpak list --app 2>/dev/null | wc -l) ))
    percent=$(awk "BEGIN {printf \"%.2f\", $total / $installed * 100}")
    if   (( $(awk "BEGIN {print ($percent >= 35)}") )); then
        update_color="\033[1;31m"       # red
    elif (( $(awk "BEGIN {print ($percent >= 15)}") )); then
        update_color="\033[38;5;208m"   # orange
    else
        update_color="\033[1;33m"       # yellow
    fi

    printf "\n${update_color}→ Total updates available: %d (~%s%%)\033[0m\n" "$total" "$percent"
}

# for a graphical approach check out: https://github.com/dhruv8sh/arch-update-checker
# based on: https://www.reddit.com/r/archlinux/comments/1lkxcio/arch_news_before_update/
archupdate() {
    # require at least 3 GiB free space before upgrading
    local root_avail clean_answer
    root_avail=$(df -k --output=avail / | tail -n1)
    if [[ $root_avail -lt 3145728 ]]; then
        printf "\033[1;31m⚠️  Less than 3 GiB free on root partition.\033[0m\n" >&2
        printf "\033[1;33mRun system cleanup now? [Y/n] \033[0m"
        read -r clean_answer
        if [[ -z "$clean_answer" || "$clean_answer" == [yY] ]]; then
            archcleanup
            root_avail=$(df -k --output=avail / | tail -n1)
            if [[ $root_avail -lt 3145728 ]]; then
                printf "\033[1;31m⛔ Still less than 3 GiB free. Free up space manually before upgrading.\033[0m\n" >&2
                return 1
            fi
        else
            return 1
        fi
    fi

    # show the 2 latest Arch Linux news urls using rss, so you won't be surprised when your system gets borked
    # CTRL + click or right click + open to view the entries (or set up direct first click to open)
    local item_blocks item link pubdate date_short
    printf "\033[1;34m📰 Latest Arch Linux news:\033[0m\n"
    # description text is entity-escaped (&lt;p&gt;) so no stray </item> tags appear inside
    # a block — safe to collapse newlines first, then extract each <item>...</item> intact
    item_blocks=$(curl -s --compressed --fail --connect-timeout 3 --max-time 8 --retry 2 --retry-delay 1 \
        https://archlinux.org/feeds/news/ 2>/dev/null \
        | tr -d '\r\n' | grep -oP '<item>.*?</item>' | head -n 2)
    if [[ -n "$item_blocks" ]]; then
        while read -r item; do
            link=$(grep -oP '(?<=<link>)https://archlinux\.org/news/[^<]+' <<< "$item")
            pubdate=$(grep -oP '(?<=<pubDate>)[^<]+' <<< "$item")
            # guard: date -d "" returns today rather than failing on empty input
            date_short=""
            [[ -n "$pubdate" ]] && date_short=$(date -d "$pubdate" +%y.%m.%d 2>/dev/null)
            printf " • %s: %s\n" "$date_short" "$link"
        done <<< "$item_blocks"
    else
        printf "\033[1;31mError fetching news; check manually: https://archlinux.org/news/\033[0m\n"
    fi

    # check mirrorlist age and prompt for ranking if older than 2 weeks
    local mirror_age mirror_answer
    local mirror_check="/etc/pacman.d/mirrorlist"
    if [[ -f "$mirror_check" ]]; then
        mirror_age=$(( ($(date +%s) - $(stat -c %Y "$mirror_check")) / 86400 ))
        if [[ $mirror_age -gt 14 ]]; then
            printf "\033[1;33m⚠️  Mirrorlist is %d days old. Rank all mirrors now? [Y/n] \033[0m" "$mirror_age"
            read -r mirror_answer
            [[ -z "$mirror_answer" || "$mirror_answer" == [yY] ]] && mirrorranking
        fi
    fi

    # prompt to continue with the upgrade
    local answer
    printf "\033[1;33mContinue with the system upgrade? [Y/n] \033[0m"
    read -r answer
    if [[ -n "$answer" && "$answer" != [yY] ]]; then
        printf "\033[1m🚫 Upgrade cancelled.\033[0m\n"
        return 0
    fi

    # inhibit sleep for the duration of the upgrade, test with: systemd-inhibit --list
    local inhibit_pid
    { systemd-inhibit --what=sleep:idle --who="archupdate" --why="System upgrade in progress" --mode=block sleep infinity & inhibit_pid=$!; } 2>/dev/null
    trap "
        kill $inhibit_pid 2>/dev/null
        wait $inhibit_pid 2>/dev/null
        printf '\n\033[1m🚫 Upgrade cancelled.\033[0m\n'
        trap - INT RETURN
        exit 0
    " INT
    trap "kill $inhibit_pid 2>/dev/null; wait $inhibit_pid 2>/dev/null" RETURN

    # capture kernel info before upgrade while modules dir is still present
    local running_ver kernel_pkg
    running_ver=$(uname -r)
    kernel_pkg=$(cat "/usr/lib/modules/$running_ver/pkgbase" 2>/dev/null)

    # lock file check: abort if actively locked, remove if stale and no process holds it
    local lock_pid
    local lock=/var/lib/pacman/db.lck
    if [[ -e "$lock" ]]; then
        lock_pid=$(sudo fuser "$lock" 2>/dev/null)
        if [[ -n "$lock_pid" ]]; then
            printf "\033[1;31m🔒 Pacman is actively running (lock held by PID %s). Wait for it to finish.\033[0m\n" "$lock_pid" >&2
            return 1
        else
            printf "\033[1;34mStale pacman lock found (no active process). Removing and continuing.\033[0m\n"
            sudo rm -f "$lock"
        fi
    fi

    # upgrade using topgrade, alternative to the following update blocks (may not support appmanager)
#    printf "\033[1;34mRunning system upgrade...\033[0m\n"
#    if ! topgrade --no-self-update -y; then
#        printf "\033[1;31m❌ Upgrade failed. Check the log for details: /var/log/pacman.log\033[0m\n" >&2
#        return 1
#    fi
#    printf "\033[1;32mSystem upgrade complete.\033[0m\n"

    # run the upgrade
    printf "\033[1;34mRunning system upgrade...\033[0m\n"
    if ! yay -Syu; then
        printf "\033[1;31m❌ Upgrade failed. Check the log for details: /var/log/pacman.log\033[0m\n" >&2
        return 1
    fi
    printf "\033[1;32mSystem upgrade complete.\033[0m\n"

    # update flatpaks if found
    if command -v flatpak &>/dev/null; then
        printf "\033[1;34mUpdating Flatpak packages...\033[0m\n"
        flatpak update -y </dev/null | cat
        printf "\033[1;32mFlatpak update complete.\033[0m\n"
    fi

    # update appimages if appmanager is found
    if command -v app-manager &>/dev/null; then
        printf "\033[1;34mUpdating AppImage packages...\033[0m\n"
        app-manager --update-all </dev/null | cat
        printf "\033[1;32mAppImage update complete.\033[0m\n"
    fi

    # check for .pacnew files and save list for manual review
    # /etc/pacman.d excluded, updated by rate-mirrors and cleaned up by archcleanup
    local pacnew_found pacnew_list
    pacnew_found=$(find /etc -name "*.pacnew" -not -path "/etc/pacman.d/*" 2>/dev/null)
    if [[ -n "$pacnew_found" ]]; then
        pacnew_list="$HOME/pacnew-$(date +%Y-%m-%d_%H-%M-%S).txt"
        printf "%s\n" "$pacnew_found" > "$pacnew_list"
        printf "\033[1;33m⚠️  .pacnew files found. Review and merge manually, list saved to:\n    %s\033[0m\n" "$pacnew_list"
    fi

    # check if root partition is full (0 bytes free) before any reboot
    root_avail=$(df -k --output=avail / | tail -n1)
    if [[ $root_avail -eq 0 ]]; then
        printf "\033[1;31m⛔ Root partition full, the system may not boot!\033[0m\n" >&2
        printf "\033[1;33mRun system cleanup now? [Y/n] \033[0m"
        read -r clean_answer
        if [[ -z "$clean_answer" || "$clean_answer" == [yY] ]]; then
            archcleanup
            root_avail=$(df -k --output=avail / | tail -n1)
            if [[ $root_avail -eq 0 ]]; then
                printf "\033[1;31m⛔ Root partition still full. Fix manually before rebooting!\033[0m\n" >&2
                return 1
            fi
        else
            return 1
        fi
    fi

    # check if a new kernel has been installed for the currently running kernel family
    local new_ver reboot_answer
    new_ver=$(for d in /usr/lib/modules/*/; do
        [[ -d "$d" ]] || continue
        ver=${d%/}; ver=${ver##*/}
        [[ "$ver" == "$running_ver" ]] && continue
        [[ -z "$kernel_pkg" || "$(cat "${d}pkgbase" 2>/dev/null)" == "$kernel_pkg" ]] || continue
        echo "$ver"
    done | sort -V | tail -n1)
    if [[ -n "$new_ver" ]]; then
        printf "\033[1;33mKernel updated (%s -> %s). Reboot? [Y/n] \033[0m" "$running_ver" "$new_ver"
        read -r reboot_answer
        [[ -z "$reboot_answer" || "$reboot_answer" == [yY] ]] && plasmareboot # change this to your DE specific reboot code
    fi

    # processes using stale shared libraries require a soft-reboot to reload system services
    local soft_reboot_answer
    if find /proc -maxdepth 2 -name maps 2>/dev/null | sudo xargs --no-run-if-empty grep -l '\.so.*deleted' 2>/dev/null | grep -q .; then
        printf "\033[1;33mProcesses are using outdated shared libraries. Soft-reboot? [Y/n] \033[0m"
        read -r soft_reboot_answer
        [[ -z "$soft_reboot_answer" || "$soft_reboot_answer" == [yY] ]] && systemctl soft-reboot
    fi

    # DE packages updated today, a logout/login is sufficient to reload the session
    local today de_packages logout_answer
    today=$(date +'%Y-%m-%d')
    de_packages='budgie-desktop|cinnamon|cosmic-session|deepin-session|enlightenment|gnome-shell|hyprland|i3-wm|labwc|lxqt-session|lxsession|mate-session-manager|niri|pantheon-session|plasma-desktop|plasma-workspace|river|sway|ukui-session-manager|wayfire|xfce4-session|xfwm4'
    if grep -qE "^\[$today.*\[ALPM\] upgraded.*($de_packages)" /var/log/pacman.log; then
        printf "\033[1;33mDesktop environment packages updated. Log out and back in? [Y/n] \033[0m"
        read -r logout_answer
        [[ -z "$logout_answer" || "$logout_answer" == [yY] ]] && plasmalogout # change this to your DE specific logout code
    fi

    # check for failed systemd units after upgrade and attempt to restart them
    local failed_units
    failed_units=$(systemctl --failed --no-legend --no-pager 2>/dev/null)
    if [[ -n "$failed_units" ]]; then
        printf "\033[1;31m❌ Some systemd units failed:\033[0m\n" >&2
        printf "%s\n" "$failed_units"
        printf "\033[1;34mAttempting to restart failed units...\033[0m\n"
        printf "%s\n" "$failed_units" | awk '{print $1}' | while read -r unit; do
            printf "\033[1;34mRestarting %s...\033[0m\n" "$unit"
            if ! sudo systemctl restart "$unit" 2>/dev/null; then
                unit_log="$HOME/failed-unit-${unit}-$(date +%Y-%m-%d_%H-%M-%S).txt"
                journalctl -xu "$unit" > "$unit_log" 2>/dev/null
                printf "\033[1;31m%s still failed. Log saved to:\n    %s\033[0m\n" "$unit" "$unit_log" >&2
            fi
        done
    fi

    printf "\033[1;32m✅ Update complete.\033[0m\n"
}

# Remove a package, its orphaned dependencies, and anything that depends on it
purge() {
    local purge_answer
    printf "\n\033[1;31m  ⚠  PURGE: %s ?\033[0m\n" "$*"
    printf "\033[1;31m  This will also remove any package that depends on it, and orphaned dependencies left behind.\033[0m\n"
    printf "\033[1m  Proceed? [y/N] \033[0m"
    read -r purge_answer
    [[ "$purge_answer" == [yY] ]] && yay -Rnsc "$@" || printf "\n  Purge cancelled.\n\n"
}

# Plasma, no dialog; defined as functions so they can be called from scripts,
# in the kernel and DE blocks of archupdate, aliased shorhand commands
plasmashutdown() { qdbus6 org.kde.Shutdown /Shutdown org.kde.Shutdown.logoutAndShutdown; }
plasmalogout()   { qdbus6 org.kde.Shutdown /Shutdown org.kde.Shutdown.logout; }
plasmareboot()   { qdbus6 org.kde.Shutdown /Shutdown org.kde.Shutdown.logoutAndReboot; }

#   Bindings   #
################

# Ctrl + C to freeze a running terminal program, Ctrl + Q to unfreeze

#    text manipulation/ getting around - get a better description, handling? navigation?
bind '"\C-H":unix-word-rubout'       # Ctrl + Backspace/H deletes the previous word
bind '"\e[3;5~": kill-word'          # Ctrl + Delete deletes the next word
bind '"\e[1;5D": backward-word'      # Ctrl + Left moves one word left
bind '"\e[1;5C": forward-word'       # Ctrl + Right moves one word right
# write some initial letters of a command first then up/down arrows to find it in history
bind '"\e[A":history-search-backward'
bind '"\e[B":history-search-forward'

#    Tab completion
bind "set completion-ignore-case on"           # case-insensitive completion
bind "set completion-prefix-display-length 2"  # show common prefix differently (Bash 5+)
bind "set menu-complete-display-prefix on"     # Tab shows common prefix first, then cycles (Bash 4.4+)
bind "set colored-stats on"                    # colorized completion matches (requires bash-completion)
bind "set visible-stats on"                    # show file type indicators (e.g., / for dirs)
bind "set mark-directories on"                 # mark directories with / in completion
bind "set mark-symlinked-directories on"
bind '"\C-i": menu-complete'                   # Tab cycles forward through matches
bind '"\e[Z": menu-complete-backward'          # Shift + Tab to cycle backwards


#   Look and feel   #
#####################

# default line before you can start typing
PS1='\[\e[95m\]@ \[\e[0m\]\[\e[94m\]$(pwd)\[\e[0m\]\[\e[95m\] ~ \[\e[0m\]'
#PS1='\[\e[95m\]$(pwd)\[\e[0m\]\[\e[94m\] ~ \[\e[0m\]'        # without @
#PS1='@ $(pwd) ~ '                                            # without colors

# set terminal title to current directory on prompt
PROMPT_COMMAND='printf "\033]0;@ %s\007" "$(pwd)"'

# only update title for user-entered commands, not internal shell functions
trap '
  case "$BASH_COMMAND" in
    __bp_interactive_mode|__bp_precmd_invoke_cmd|__bp_preexec_invoke_exec)
      # do nothing for internal functions
      ;;
    *)
      printf "\033]0;@ %s ~ %s\007" "${PWD}" "${BASH_COMMAND}"
      ;;
  esac
' DEBUG
# add other internal commands to the case statement if you see them in your title, use regex/wildcards to match more patterns if needed


#   Bash copmletions   #
########################

# load bash-completion if available and readable
[[ -r "/usr/share/bash-completion/bash_completion" ]] && . "/usr/share/bash-completion/bash_completion"

# doas completion (requiring bash-completion)
complete -F _root_command doas   # or _command for basic behavior
#complete -cf doas # fallback for no bash-copmletion
complete -c purge
complete -c yay


#   Aliases   #
###############

# run commands unaliased with a backslash '\'

#     session actions
alias sre='systemctl soft-reboot'
alias lok='loginctl lock-session'
alias zz='systemctl suspend'        # sleep
# Plasma, no dialog
alias po='plasmashutdown'
alias out='plasmalogout'
alias re='plasmareboot'
# Plasma, with confirmation *d*ialog
alias pod='qdbus6 org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt.promptShutDown'
alias red='qdbus6 org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt.promptReboot'
alias outd='qdbus6 org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt.promptLogout'
# Plasmashell restart, both work slightly differently
alias plasma='systemctl --user restart plasma-plasmashell'
alias kde='kquitapp6 plasmashell && kstart plasmashell'

#     package management
alias up='archupdate'
alias cl='archcleanup'
alias hm='availableupdates'
alias rank='mirrorranking'
# from https://github.com/ChrisTitusTech/mybash/blob/main/.bashrc  (yayf)
# search the repos, can pan the bottom with scroll or click and drag, enter installs, TAB for multi selection
alias f="yay -Slq | fzf --multi --preview 'yay -Sii {1}' --preview-window=down:75% | xargs -ro yay -S"
# search installed packages to uninstall, works like the above one
alias r="yay -Qq | fzf --multi --preview 'yay -Qii {1}' --preview-window=down:75% | xargs -ro yay -Rns"

#     terminal
alias c='clear'
alias x='exit'
alias q='exit'
alias reload='source ~/.bashrc'     # reload the shell
alias ping='ping -c 6 google.com'   # takes ~5 seconds

#     files and navigation, nnn as terminal file manager
alias l='ls -lav --ignore=.?*'   # long listing but no hidden dotfiles except "."
alias ll='ls -lav --ignore=..'   # long listing of all except ".."
alias ls='ls -a --color=auto'

#     programs
alias top='htop'
alias hotp='htop'
alias ff='fastfetch'
alias td='termdown'
alias tdh='termdown --help'
alias scrcpy='scrcpy --video-codec=h265 --max-fps=60 --turn-screen-off --stay-awake'
alias scrcam='scrcpy --video-source=camera --camera-size=1920x1080 --camera-facing=front --v4l2-sink=/dev/video2 --no-playback'

#     remote scripts
alias we='curl wttr.in'   # weather, stormy could be a local alternative
alias lin='curl -fsSL https://christitus.com/linux | sh'
alias lindev='curl -fsSL https://christitus.com/linuxdev | sh'
