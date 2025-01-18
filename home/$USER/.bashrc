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

[[ "$(whoami)" = "root" ]] && return          # was ist dis???

[[ -z "$FUNCNEST" ]] && export FUNCNEST=100   # limits recursive functions, see 'man bash'

# Ignore case on auto-completion, bind used instead of sticking these in .inputrc
if [[ $iatest -gt 0 ]]; then bind "set completion-ignore-case on"; fi

# Show auto-completion list automatically, without double tab
if [[ $iatest -gt 0 ]]; then bind "set show-all-if-ambiguous On"; fi

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

[[ -f ~/.welcome_screen ]] && . ~/.welcome_screen #was dis ???

########
# Bindings
############

# Use the up and down arrow keys for finding a command in history
# You can write some initial letters of the command first.
bind '"\e[A":history-search-backward'
bind '"\e[B":history-search-forward'

bind '"\C-H":unix-word-rubout'   # ctrl + backspace deletes a word
# ctrl + c to freeze a running program, ctrl + q to unfreeze

# Better Tab completion
bind "set show-all-if-ambiguous on"
bind "set completion-ignore-case on"
bind '"\C-i": menu-complete' # This binds the 'menu-complete' to the Tab key (Ctrl + i is equivalent to Tab)
bind '"\e[Z]": menu-complete-backward' # This binds Shift + Tab to cycle backward

#######
# Exports
###########

# Expand the history size
export HISTFILESIZE=10000
export HISTSIZE=500
export HISTTIMEFORMAT="%F %T " # add timestamp to history

# set up XDG folders
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

#############
# Look and feel
#################

PS1='\[\e[94m\]$(whoami)\[\e[0m\] @\[\e[95m\] $(pwd) \[\e[0m\]~ '
#PS1='$(whoami) @ $(pwd) $ ' # below with colors
#_set_liveuser_PS1() {
#PS1='$(whoami) @ $(pwd) $ '
#}
#_set_liveuser_PS1
#unset -f _set_liveuser_PS1

# Terminal title
PROMPT_COMMAND='echo -en "\033]0;$(whoami) @ $(pwd) ~ - Alacritty"'
# When a command is running, hardcoded Alacritty as the name, can always rename
trap 'echo -ne "\033]0;$(whoami) @ ${PWD} (${BASH_COMMAND}) - Alacritty\007"' DEBUG

#######
# Aliases
###########

# Run commands unaliased with a '\'

alias ls='ls -a --color=auto'
alias ll='ls -lav --ignore=..'   # show long listing of all except ".."
alias l='ls -lav --ignore=.?*'   # show long listing but no hidden dotfiles except "."
alias ff='fastfetch'

alias c='clear'
alias x='exit'
alias q='exit'
alias bash='source ~/.bashrc'    # refresh shell
alias kde='systemctl --user restart plasma-plasmashell' # restart kde plasma shell

alias re='reboot'
alias po='poweroff'
alias zz='systemctl suspend'     # sleep

alias up='yay -Syu'
alias top='htop'
alias we='curl wttr.in'          # weather
alias lin='curl -fsSL https://christitus.com/linux | sh'
alias lindev='curl -fsSL https://christitus.com/linuxdev | sh'
