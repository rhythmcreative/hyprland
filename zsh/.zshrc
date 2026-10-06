# --- Rhythm Arch Zsh Configuration ---

# Ensure ~/.local/bin is in PATH
[[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && export PATH="$HOME/.local/bin:$PATH"

# Set name of the theme to load
# We use Starship so this is secondary
ZSH_THEME="robbyrussell"

# Source plugins (Arch, Fedora, NixOS)
# Arch: /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
# Fedora: /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
# NixOS: Provided via environment variables ZSH_AUTOSUGGESTIONS_SRC / ZSH_SYNTAX_HIGHLIGHTING_SRC
if [ -z "$ZSH_AUTOSUGGESTIONS_SRC" ] || [ ! -f "$ZSH_AUTOSUGGESTIONS_SRC" ]; then
    if [ -f "/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
        ZSH_AUTOSUGGESTIONS_SRC="/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
    elif [ -f "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
        ZSH_AUTOSUGGESTIONS_SRC="/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    fi
fi

if [ -z "$ZSH_SYNTAX_HIGHLIGHTING_SRC" ] || [ ! -f "$ZSH_SYNTAX_HIGHLIGHTING_SRC" ]; then
    if [ -f "/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
        ZSH_SYNTAX_HIGHLIGHTING_SRC="/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    elif [ -f "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
        ZSH_SYNTAX_HIGHLIGHTING_SRC="/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    fi
fi

[ -n "$ZSH_AUTOSUGGESTIONS_SRC" ] && [ -f "$ZSH_AUTOSUGGESTIONS_SRC" ] && source "$ZSH_AUTOSUGGESTIONS_SRC"
[ -n "$ZSH_SYNTAX_HIGHLIGHTING_SRC" ] && [ -f "$ZSH_SYNTAX_HIGHLIGHTING_SRC" ] && source "$ZSH_SYNTAX_HIGHLIGHTING_SRC"

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
if command -v pacman >/dev/null 2>&1; then
    alias pacinst='sudo pacman -S'
    alias pacupd='sudo pacman -Syu'
    alias yayinst='yay -S'
fi
if command -v dnf >/dev/null 2>&1; then
    alias dnfinst='sudo dnf install'
    alias dnfupd='sudo dnf upgrade'
fi
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
