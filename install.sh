#!/bin/bash

# --- Rhythm Arch Hyprland Installer v2 (Enhanced TUI) ---

# Colors & Styles (using gum for some, ANSI for others)
CLR_PRIMARY="#BD93F9" # Dracula Purple
CLR_SECONDARY="#8BE9FD" # Dracula Cyan
CLR_SUCCESS="#50FA7B" # Dracula Green
CLR_ERROR="#FF5555" # Dracula Red
CLR_WARN="#FFB86C" # Dracula Orange

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# --- INITIAL SETUP ---
if [ "$EUID" -eq 0 ]; then
    gum style --foreground "$CLR_ERROR" --bold " [ERROR] No ejecutes este script como root."
    exit 1
fi

# Ensure gum is installed
if ! command -v gum > /dev/null; then
    sudo pacman -S --needed --noconfirm gum git base-devel stow zsh curl > /dev/null 2>&1
fi

# --- UI FUNCTIONS ---

print_banner() {
    clear
    echo -e "${CLR_PRIMARY}"
    echo "██████╗ ██╗  ██╗██╗   ██╗████████╗██╗  ██╗███╗   ███╗ ██████╗██████╗ ███████╗ █████╗ ████████╗██╗██╗   ██╗███████╗"
    echo "██╔══██╗██║  ██║╚██╗ ██╔╝╚══██╔══╝██║  ██║████╗ ████║██╔════╝██╔══██╗██╔════╝██╔══██╗╚══██╔══╝██║██║   ██║██╔════╝"
    echo "██████╔╝███████║ ╚████╔╝    ██║   ███████║██╔████╔██║██║     ██████╔╝█████╗  ███████║   ██║   ██║██║   ██║█████╗  "
    echo "██╔══██╗██╔══██║  ╚██╔╝     ██║   ██╔══██║██║╚██╔╝██║██║     ██╔══██╗██╔══╝  ██╔══██║   ██║   ██║╚██╗ ██╔╝██╔══╝  "
    echo "██║  ██║██║  ██║   ██║      ██║   ██║  ██║██║ ╚═╝ ██║╚██████╗██║  ██║███████╗██║  ██║   ██║   ██║ ╚████╔╝ ███████╗"
    echo "╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝      ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═══╝  ╚══════╝"
    echo ""
    echo "██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗"
    echo "██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝"
    echo "██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗"
    echo "██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║"
    echo "██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║"
    echo "╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝"
    echo -e "\n      Rhythm Arch Hyprland Installer v2"
}

header() {
    echo ""
    gum style --foreground "$CLR_SECONDARY" --bold "─── $1 ───"
}

info() {
    gum style --foreground "$CLR_SUCCESS" "  ✔ $1"
}

warn() {
    gum style --foreground "$CLR_WARN" "  ! $1"
}

error() {
    gum style --foreground "$CLR_ERROR" "  ✘ $1"
}

# --- SYSTEM HELPERS ---

install_yay() {
    if ! command -v yay > /dev/null; then
        header "Instalando AUR Helper (yay)"
        git clone https://aur.archlinux.org/yay.git /tmp/yay > /dev/null 2>&1
        cd /tmp/yay && makepkg -si --noconfirm > /dev/null 2>&1
        cd "$DOTFILES_DIR"
    fi
}

enable_multilib() {
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        header "Habilitando Repositorio Multilib"
        sudo sed -i '/^#\[multilib\]/,+1 s/^#//' /etc/pacman.conf
        sudo pacman -Sy > /dev/null 2>&1
        info "Multilib habilitado."
    fi
}

# --- INSTALLATION STEPS ---

step_software() {
    header "Selección de Software"
    
    # Core packages are always installed
    CORE_PKGS="hyprland sddm hypridle hyprlock hyprpicker xdg-desktop-portal-hyprland waybar rofi kitty networkmanager network-manager-applet bluez bluez-utils pipewire pipewire-pulse wireplumber pavucontrol playerctl pamixer brightnessctl gvfs polkit-kde-agent swappy grim slurp nwg-look bibata-cursor-theme tela-circle-icon-theme-all otf-font-awesome ttf-jetbrains-mono-nerd flatpak python-pywal swww stow qt5-graphicaleffects qt5-quickcontrols2 qt5-svg qt5-declarative"
    
    info "Instalando núcleo del sistema (Hyprland + Estética)..."
    yay -S --needed --noconfirm $CORE_PKGS

    SELECTED_SW=$(gum choose --no-limit --header "Selecciona aplicaciones extra (Espacio para marcar, Enter para confirmar)" \
        "Drivers NVIDIA" \
        "Herramientas ASUS (ROG/TUF)" \
        "Navegador Brave" \
        "Vesktop (Discord)" \
        "Telegram Desktop" \
        "Visual Studio Code" \
        "Obsidian" \
        "OBS Studio" \
        "Steam" \
        "Thunar" \
        "Dolphin" \
        "Flatpaks")

    EXTRA_PKGS=""
    [[ $SELECTED_SW == *"Drivers NVIDIA"* ]] && EXTRA_PKGS="$EXTRA_PKGS nvidia-open-dkms nvidia-settings nvidia-utils"
    [[ $SELECTED_SW == *"Herramientas ASUS"* ]] && EXTRA_PKGS="$EXTRA_PKGS asusctl supergfxctl rog-control-center"
    [[ $SELECTED_SW == *"Brave"* ]] && EXTRA_PKGS="$EXTRA_PKGS brave-origin-nightly-bin"
    [[ $SELECTED_SW == *"Vesktop"* ]] && EXTRA_PKGS="$EXTRA_PKGS vesktop"
    [[ $SELECTED_SW == *"Telegram"* ]] && EXTRA_PKGS="$EXTRA_PKGS telegram-desktop"
    [[ $SELECTED_SW == *"Visual Studio Code"* ]] && EXTRA_PKGS="$EXTRA_PKGS code"
    [[ $SELECTED_SW == *"Obsidian"* ]] && EXTRA_PKGS="$EXTRA_PKGS obsidian"
    [[ $SELECTED_SW == *"OBS Studio"* ]] && EXTRA_PKGS="$EXTRA_PKGS obs-studio"
    [[ $SELECTED_SW == *"Thunar"* ]] && EXTRA_PKGS="$EXTRA_PKGS thunar"
    [[ $SELECTED_SW == *"Dolphin"* ]] && EXTRA_PKGS="$EXTRA_PKGS dolphin"

    if [[ $SELECTED_SW == *"Steam"* ]]; then
        enable_multilib
        EXTRA_PKGS="$EXTRA_PKGS steam"
    fi

    if [ ! -z "$EXTRA_PKGS" ]; then
        header "Instalando Aplicaciones Seleccionadas"
        yay -S --needed --noconfirm $EXTRA_PKGS
    fi

    if [[ $SELECTED_SW == *"Flatpaks"* ]]; then
        if [ -f "$DOTFILES_DIR/flatpaks.txt" ]; then
            header "Instalando Flatpaks"
            flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
            while read -r app; do
                [ -z "$app" ] || [[ "$app" =~ ^# ]] && continue
                info "Instalando: $app"
                flatpak install --user -y flathub "$app" > /dev/null 2>&1
            done < "$DOTFILES_DIR/flatpaks.txt"
        fi
    fi
}

step_dotfiles() {
    header "Configuraciones (Dotfiles)"
    if gum confirm "¿Quieres aplicar las configuraciones (stow) ahora?"; then
        mkdir -p ~/.config ~/.local/bin
        stow -v -R -t ~ .config
        stow -v -R -t ~ .local
        stow -v -R -t ~ zsh
        stow -v -R -t ~ bash
        stow -v -R -t ~ gtk
        info "Archivos de configuración enlazados."
    fi
}

step_wallpapers() {
    header "Fondos de Pantalla"
    if gum confirm "¿Quieres instalar la colección de wallpapers?"; then
        WALL_DIR="$HOME/Pictures/Wallpapers"
        mkdir -p "$WALL_DIR"
        
        if [ -d "$DOTFILES_DIR/wallpapers" ] && [ -f "$DOTFILES_DIR/wallpapers/extract.sh" ]; then
            CHOICE=$(gum choose "Instalar todos los packs" "Instalar un pack específico" "Cancelar")
            
            if [ "$CHOICE" == "Instalar todos los packs" ]; then
                info "Extrayendo colección completa..."
                cd "$DOTFILES_DIR/wallpapers" && bash extract.sh
                cd "$DOTFILES_DIR"
            elif [ "$CHOICE" == "Instalar un pack específico" ]; then
                PACK_NUM=$(gum input --placeholder "Número de pack (1-49)" --value "1")
                if [ ! -z "$PACK_NUM" ]; then
                    info "Extrayendo pack $PACK_NUM..."
                    cd "$DOTFILES_DIR/wallpapers" && bash extract.sh "$PACK_NUM"
                    cd "$DOTFILES_DIR"
                fi
            fi
        else
            info "Descargando desde repositorio externo..."
            git clone https://github.com/bjarneo/wallpapers.git /tmp/wallpapers-repo > /dev/null 2>&1
            cp -r /tmp/wallpapers-repo/* "$WALL_DIR/"
            rm -rf /tmp/wallpapers-repo
            info "Wallpapers descargados en $WALL_DIR."
        fi
    fi
}

step_system() {
    header "Servicios y Shell"
    
    if gum confirm "¿Quieres configurar Zsh como shell por defecto?"; then
        [ "$SHELL" != "$(which zsh)" ] && sudo chsh -s "$(which zsh)" "$USER"
        if [ ! -d "$HOME/.oh-my-zsh" ]; then
            info "Instalando Oh-My-Zsh..."
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended > /dev/null 2>&1
        fi
    fi

    if gum confirm "¿Habilitar servicios básicos (Red, BT, SDDM)?"; then
        sudo systemctl enable NetworkManager bluetooth sddm
        
        # SDDM Theme
        if [ -d "$DOTFILES_DIR/sddm/sddm-astronaut-theme" ]; then
            sudo mkdir -p /usr/share/sddm/themes
            sudo cp -r "$DOTFILES_DIR/sddm/sddm-astronaut-theme" /usr/share/sddm/themes/
            sudo mkdir -p /etc/sddm.conf.d
            echo -e "[Theme]\nCurrent=sddm-astronaut-theme" | sudo tee /etc/sddm.conf.d/theme.conf > /dev/null
        fi
        info "Servicios listos."
    fi

    # User groups
    sudo usermod -aG video,input,render,wheel $USER
}

# --- MAIN LOOP ---

print_banner
gum spin --spinner dot --title "Preparando el terreno..." sleep 1

install_yay
step_software
step_dotfiles
step_wallpapers
step_system

# Final Sync
if [ -f "$HOME/.local/bin/modern-pywal-sync" ]; then
    bash "$HOME/.local/bin/modern-pywal-sync" > /dev/null 2>&1
fi

header "Instalación Finalizada"
gum style --foreground "$CLR_SUCCESS" --bold "Todo listo. ¡Disfruta de tu nuevo entorno!"

if gum confirm "¿Quieres iniciar SDDM ahora?"; then
    sudo systemctl start sddm
else
    echo "Reinicia para aplicar todos los cambios."
fi
