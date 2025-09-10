#########
# ~/.bashrc
#############

###############
# Autorun command
###################

fastfetch

#########
# Functions
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

# show latest Arch Linux news before upgrading, based on:
# https://www.reddit.com/r/archlinux/comments/1lkxcio/arch_news_before_update/
arch-update() {
    printf "🔔 Latest Arch Linux news:\n"
    curl -s https://archlinux.org/news/ \
      | grep -E -o 'href="/news/[^"]+"' \
      | cut -d'"' -f2 \
      | head -n 2 \
      | sed 's|^|https://archlinux.org|'

    printf "\n"
    printf "Do you want to continue with the system upgrade? [Y/n] "
    read answer
    if [ -z "$answer" ] || [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        yay -Syu
    else
        printf "⏹️ Upgrade cancelled.\n"
    fi
}

########
# Bindings
############

# ctrl + c to freeze a running program, ctrl + q to unfreeze

# use the up and down arrow keys for finding a command in history
# you can write some initial letters of the command first.
bind '"\e[A":history-search-backward'
bind '"\e[B":history-search-forward'

# ctrl + backspace deletes a word
bind '"\C-H":unix-word-rubout'

# better Tab completion
bind "set show-all-if-ambiguous on"
bind "set completion-ignore-case on"
# 'menu-complete' to the Tab key (Ctrl + i is equivalent to Tab)
bind '"\C-i": menu-complete'
# Shift + Tab to cycle backward
bind '"\e[Z]": menu-complete-backward'

# completion for doas, NEEDS 'bash-completion' to be installed
complete -F _command doas

#######
# Exports
###########

# expand the history size
export HISTFILESIZE=10000
export HISTSIZE=500
# add timestamp to history
export HISTTIMEFORMAT="%F %T "

# set up XDG folders
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

#############
# Look and feel
#################

# default line before you can start typing
PS1='\[\e[95m\]@ \[\e[0m\]\[\e[94m\]$(pwd)\[\e[0m\]\[\e[95m\] ~ \[\e[0m\]'

# Set terminal title to current directory on prompt
PROMPT_COMMAND='printf "\033]0;@ %s\007" "$(pwd)"'

# Only update title for user-entered commands, not internal shell functions
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

#Add other internal commands to the case statement if you see them in your title.
#You can use regex/wildcards to match more patterns if needed.

#######
# Aliases
###########

# run commands unaliased with a '\'

alias ls='ls -a --color=auto'
alias ll='ls -lav --ignore=..'   # show long listing of all except ".."
alias l='ls -lav --ignore=.?*'   # show long listing but no hidden dotfiles except "."
alias ff='fastfetch'
alias td='termdown'

alias c='clear'
alias x='exit'
alias q='exit'
alias bsh='source ~/.bashrc'   # refresh shell
alias kde='systemctl --user restart plasma-plasmashell'   # restart kde plasma shell
alias plasma='systemctl --user restart plasma-plasmashell'

alias re='reboot'
alias sre='systemctl soft-reboot'
alias po='poweroff'
alias zz='systemctl suspend'   # sleep

alias ping='ping -c 6 google.com'     # takes ~5 seconds
alias up="arch-update"
# search the repos for packages in the terminal, can pan the bottom with scroll or click and drag, enter installs
alias yayf="yay -Slq | fzf --multi --preview 'yay -Sii {1}' --preview-window=down:75% | xargs -ro yay -S"
alias purge='yay -Rnsc'
alias top='htop'
alias hotp='htop'
alias we='curl wttr.in'   # weather
alias lin='curl -fsSL https://christitus.com/linux | sh'
alias lindev='curl -fsSL https://christitus.com/linuxdev | sh'
