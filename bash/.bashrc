#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# Ensure ~/.local/bin is in PATH
[[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && export PATH="$HOME/.local/bin:$PATH"

# Pywal colors in terminal
[ -f "$HOME/.cache/wal/sequences" ] && cat "$HOME/.cache/wal/sequences"


