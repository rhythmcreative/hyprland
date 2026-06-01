#!/bin/bash

# --- Rhythm arch Hyprland installer (Concise & Emoji-free) ---

# Colores (Sin emojis)
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# --- SEGURIDAD ---
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}[ERROR] No ejecutes este script como root.${NC}"
    exit 1
fi

clear
echo -e "${CYAN}"
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
echo -e "${NC}"

# --- Utilidades ---

ask() {
    read -p "[PREGUNTA] $1 (s/n): " resp
    if [[ $resp =~ ^[Ss]$ ]]; then
        return 0
    else
        return 1
    fi
}

# --- Funciones de Configuración ---

enable_multilib() {
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        echo -e "[INFO] Habilitando repositorio multilib..."
        sudo sed -i '/^#\[multilib\]/,+1 s/^#//' /etc/pacman.conf
        sudo pacman -Sy
    fi
}

install_base_deps() {
    echo -e "[INFO] Instalando dependencias base..."
    sudo pacman -S --needed --noconfirm git base-devel stow zsh curl
}

install_yay() {
    if ! command -v yay > /dev/null; then
        echo -e "[INFO] Instalando AUR helper (yay)..."
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        cd /tmp/yay && makepkg -si --noconfirm
        cd "$DOTFILES_DIR"
    fi
}

# --- Selección de Software ---

install_software() {
    echo -e "\n[SOFTWARE] Selección de componentes:"
    
    # 1. CORE (Siempre necesario para Hyprland)
    CORE_PKGS="hyprland hypridle hyprlock hyprpicker xdg-desktop-portal-hyprland waybar rofi kitty network-manager-applet pipewire pipewire-pulse playerctl swappy grim slurp"
    echo -e "[*] Instalando núcleo del sistema (Hyprland, Waybar, etc.)..."
    yay -S --needed --noconfirm $CORE_PKGS

    # 2. DRIVERS
    if lspci | grep -qi "NVIDIA"; then
        if ask "¿Instalar drivers de NVIDIA?"; then
            yay -S --needed --noconfirm nvidia-open-dkms nvidia-settings nvidia-utils
        fi
    fi

    if [ -f /sys/class/dmi/id/board_vendor ] && grep -qi "ASUS" /sys/class/dmi/id/board_vendor; then
        if ask "¿Instalar herramientas para ASUS (asusctl, supergfxctl)?"; then
            yay -S --needed --noconfirm asusctl supergfxctl rog-control-center
        fi
    fi

    # 3. APLICACIONES
    if ask "¿Instalar aplicaciones de usuario (Brave, Discord, Telegram, VSCode)?"; then
        yay -S --needed --noconfirm brave-origin-nightly-bin vesktop telegram-desktop code thunar dolphin
    fi

    # 4. STEAM (Requiere multilib)
    if ask "¿Instalar Steam y configurar soporte multilib?"; then
        enable_multilib
        yay -S --needed --noconfirm steam
    fi

    # 5. PERSONALIZACIÓN
    if ask "¿Instalar temas y fuentes (Tela Circle, JetBrains Mono, Bibata)?"; then
        yay -S --needed --noconfirm bibata-cursor-theme tela-circle-icon-theme-all otf-font-awesome ttf-jetbrains-mono-nerd nwg-look
    fi
}

# --- Ejecución ---

echo -e "[INICIO] Comenzando instalación personalizada..."

install_base_deps
install_yay
install_software

if ask "¿Aplicar configuraciones (dotfiles) ahora?"; then
    mkdir -p ~/.config ~/.local/bin
    stow -v -R -t ~ .config
    stow -v -R -t ~ .local
    stow -v -R -t ~ zsh
    stow -v -R -t ~ bash
    stow -v -R -t ~ gtk
fi

if ask "¿Configurar Zsh como shell por defecto?"; then
    [ "$SHELL" != "$(which zsh)" ] && sudo chsh -s "$(which zsh)" "$USER"
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
fi

echo -e "\n${GREEN}[HECHO] Instalación completada con éxito.${NC}"
echo "[AVISO] Reinicia la sesión para ver los cambios."



