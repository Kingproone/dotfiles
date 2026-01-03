# ~/.bashrc
#############

# Command to autorun on terminal spawn
########################################

fastfetch


# Basic functions
#############

# to prevent running random stuff as root
[[ "$(whoami)" = "root" ]] && return

# limits recursive functions, see 'man bash'
[[ -z "$FUNCNEST" ]] && export FUNCNEST=100

# case insensitive auto-completion, bind used instead of sticking these in .inputrc
if [[ $iatest -gt 0 ]]; then bind "set completion-ignore-case on"; fi

# show auto-completion list automatically, without double Tab
if [[ $iatest -gt 0 ]]; then bind "set show-all-if-ambiguous On"; fi

# if not running interactively, don't do anything
[[ $- != *i* ]] && return


# Exports
###########

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


# idea from reddit, significantly changed and expanded and possibly unneccessearly bloated in some ways
# https://www.reddit.com/r/archlinux/comments/1lkxcio/arch_news_before_update/
archupdate() {

    # show the 2 latest Arch Linux news urls (from rss) so you won't be surprised when system gets borked
    printf "🔔 Latest Arch Linux news:\n"
    if ! curl -sS --compressed --fail --connect-timeout 3 --max-time 8 --retry 2 --retry-delay 1 \
        https://archlinux.org/feeds/news/ \
        | grep -oP '(?<=<link>https://archlinux\.org/news/)[^<]+' \
        | head -n 2 \
        | sed 's|^| • https://archlinux.org/news/|'; then
        printf "\033[1m(Error fetching news; continuing anyway)\033[0m\n"
    fi
    printf "\n"

    # prompt to continue with the upgrade
    printf "\033[1mContinue with the system upgrade? [Y/n] \033[0m"
    read -r answer
    if [[ -z "$answer" || "$answer" == [yY] ]]; then
        # run the upgrade and capture exit status. If it fails (including auth failure), abort
        if ! yay -Syu; then
            printf "\033[1m❌ Upgrade failed (exit code %d). Aborting further steps.\033[0m\n" "$?" >&2
            return "$?"
        fi
    else
        printf "\033[1m🚫 Upgrade cancelled.\033[0m\n"
        return 0
    fi

    # after a successful upgrade, check if the kernel was updated and prompt for a reboot
    if pacman -Q linux &>/dev/null; then
        local installed_version=$(pacman -Q linux | awk '{print $2}')
        local running_version=$(uname -r)
        if [[ "${installed_version//./-}" != "${running_version//./-}" ]]; then
            printf "\033[1mThe kernel has been updated (%s -> %s). Reboot? [Y/n] \033[0m" "$running_version" "$installed_version"
            read -r reboot_answer
            if [[ -z "$reboot_answer" || "$reboot_answer" == [yY] ]]; then
                reboot
            fi
        fi
    fi

    # check for Desktop Environment core package updates today (this workaround is the only one i could think to only check the last update, should work since you don't update more than once a day, right? riiiiight?)
    local today=$(date +'%Y-%m-%d')
    local de_packages='plasma-desktop|plasma-workspace|gnome-shell|xfce4-session|xfwm4|cinnamon|mate-session|lxqt-session|hyprland|niri'
    if grep -qE "^\[$today.*\[ALPM\] upgraded.*($de_packages)" /var/log/pacman.log; then
        printf "\033[1mDesktop environment packages have been updated.  Restart the session? [Y/n] \033[0m "
        read -r soft_reboot_answer
        if [[ -z "$soft_reboot_answer" || "$soft_reboot_answer" == [yY] ]]; then
            systemctl soft-reboot
        fi
    fi

    printf "\033[1m✅ Update complete.\033[0m\n"
}


# Bindings
############

# CTRL + C to freeze a running terminal program, CTRL + Q to unfreeze

# write some initial letters of the command first
# up/down arrow keys for finding a command in history
bind '"\e[A":history-search-backward'
bind '"\e[B":history-search-forward'

bind '"\C-H":unix-word-rubout'   # CTRL + backspace deletes the previous word
bind '"\C\d": kill-word'         # CTRL + Delete: delete next word
# left/right arrow to move by a word (if your terminal supports it)
bind '"\e[1;5C": forward-word'   # Ctrl + Right
bind '"\e[1;5D": backward-word'  # Ctrl + Left

# better Tab completion
bind "set show-all-if-ambiguous on"            # Show all matches immediately if ambiguous
bind "set completion-ignore-case on"           # Case-insensitive completion
bind "set completion-prefix-display-length 2"  # Show common prefix differently (Bash 5+)
bind "set menu-complete-display-prefix on"     # On first Tab, show common prefix only; cycle on subsequent Tabs (Bash 4.4+)
bind "set colored-stats on"                    # Colorized completion matches (requires bash-completion)
bind "set visible-stats on"                    # Show file type indicators (e.g., / for dirs)
bind "set mark-directories on"                 # Mark directories with / in completion
bind "set mark-symlinked-directories on"

# Tab cycles through matches
bind '"\C-i": menu-complete'            # 'menu-complete' to the Tab key
bind '"\e[Z": menu-complete-backward'   # Shift + Tab to cycle backward


# Look and feel
#################

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


# Bash copmletion setup
#########################

# load bash-completion if available and readable
[[ -r "/usr/share/bash-completion/bash_completion" ]] && . "/usr/share/bash-completion/bash_completion"

# doas completion (requiring bash-completion)
complete -F _root_command doas   # or _command for basic behavior
#complete -cf doas # fallback for no bash-copmletion


# Aliases
###########

# run commands unaliased with a backslash '\'

#     system actions
alias po='poweroff'
alias re='reboot'
alias sre='systemctl soft-reboot'
alias lock='loginctl lock-session'
alias zz='systemctl suspend'   # sleep

#     session actions
alias c='clear'
alias x='exit'
alias q='exit'
alias bash='source ~/.bashrc'   # reload the terminal shell
alias kde='systemctl --user restart plasma-plasmashell'   # restart the plasma shell
alias plasma='systemctl --user restart plasma-plasmashell'
alias ping='ping -c 6 google.com'     # takes ~5 seconds
alias up="archupdate"
alias purge='yay -Rnsc' # no Tab completion
alias hm='yay -Sy &> /dev/null && yay -Qu' # check for updates without installing

# yoinked from: https://github.com/ChrisTitusTech/mybash/blob/main/.bashrc  (aliased as yayf)
# search the repos for packages in the terminal, can pan the bottom with scroll or click and drag, enter installs, TAB for multi selection, add --reverse to fzf for inverted layout
alias f="yay -Slq | fzf --multi --preview 'yay -Sii {1}' --preview-window=down:75% | xargs -ro yay -S"
# search installd packages for uninstall, works like the above one
alias r="yay -Qq | fzf --multi --preview 'yay -Qi {1}' --preview-window=down:75% | xargs -ro yay -Rns"

#     programs
alias ff='fastfetch'
alias td='termdown'
alias l='ls -lav --ignore=.?*'   # show long listing but no hidden dotfiles except "."
alias ll='ls -lav --ignore=..'   # show long listing of all except ".."
alias ls='ls -a --color=auto'
alias top='htop'
alias hotp='htop'
alias we='curl wttr.in'   # weather
alias lin='curl -fsSL https://christitus.com/linux | sh'
alias lindev='curl -fsSL https://christitus.com/linuxdev | sh'
alias scrcpy='scrcpy --video-codec=h265 --turn-screen-off'
alias scrcam='scrcpy --video-source=camera --camera-size=1920x1080 --camera-facing=front --v4l2-sink=/dev/video2 --no-playback'
