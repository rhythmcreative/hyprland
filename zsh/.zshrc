# --- Rhythm Arch Zsh Configuration ---

# Ensure ~/.local/bin is in PATH
[[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && export PATH="$HOME/.local/bin:$PATH"

# Set name of the theme to load
# We use Starship so this is secondary
ZSH_THEME="robbyrussell"

# Source plugins from pacman/AUR (Clean installation without Oh-My-Zsh)
#
# En Arch pacman los deja en /usr/share/zsh/plugins. En NixOS no existe
# /usr/share: los plugins viven en el store, y el modulo del escritorio
# exporta la ruta exacta de cada fichero en estas dos variables. El valor por
# defecto es la ruta de Arch, asi que el mismo .zshrc funciona en las dos
# plataformas sin cambiar el comportamiento de ninguna.
: "${ZSH_AUTOSUGGESTIONS_SRC:=/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh}"
: "${ZSH_SYNTAX_HIGHLIGHTING_SRC:=/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh}"

[ -f "$ZSH_AUTOSUGGESTIONS_SRC" ] && source "$ZSH_AUTOSUGGESTIONS_SRC"
[ -f "$ZSH_SYNTAX_HIGHLIGHTING_SRC" ] && source "$ZSH_SYNTAX_HIGHLIGHTING_SRC"

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
