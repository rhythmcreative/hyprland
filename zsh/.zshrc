# --- Rhythm Arch Zsh Configuration ---

# Set name of the theme to load
# We use Starship so this is secondary
ZSH_THEME="robbyrussell"

# Source plugins from pacman/AUR (Clean installation without Oh-My-Zsh)
[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Starship Prompt
if command -v starship > /dev/null; then
    eval "$(starship init zsh)"
fi

# Pywal colors in terminal
[ -f "$HOME/.cache/wal/sequences" ] && cat "$HOME/.cache/wal/sequences"

# Aliases
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias pacinst='sudo pacman -S'
alias pacupd='sudo pacman -Syu'
alias yayinst='yay -S'
alias ..='cd ..'
alias ...='cd ../..'

# History configuration
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# Keybindings
bindkey '^[[A' up-line-or-search
bindkey '^[[B' down-line-or-search
