#!/bin/bash

# --- Rhythm Arch Hyprland Installer (GUM TUI Version) ---

# ANSI Color Codes
CLR_CYAN='\033[0;36m'
CLR_GREEN='\033[0;32m'
CLR_YELLOW='\033[1;33m'
CLR_RED='\033[0;31m'
CLR_NC='\033[0m'
CLR_BOLD='\033[1m'

# --- SECURITY CHECK ---
if [ "$EUID" -eq 0 ]; then
    echo -e "${CLR_RED}[ERROR] No ejecutes este script como root.${CLR_NC}"
    exit 1
fi

# --- INITIAL SETUP ---
# Pre-install gum for the TUI
if ! command -v gum > /dev/null; then
    echo -e "[INFO] Instalando gum para la interfaz..."
    sudo pacman -S --needed --noconfirm gum git base-devel stow zsh curl > /dev/null 2>&1
fi

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# --- FUNCTIONS ---

print_banner() {
    clear
    echo -e "${CLR_CYAN}"
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
    echo -e "${CLR_NC}"
}

section() {
    echo -e "\n${CLR_BOLD}${CLR_CYAN}>>> $1${CLR_NC}\n"
}

info() {
    echo -e "${CLR_GREEN}[OK]${CLR_NC} $1"
}

warn() {
    echo -e "${CLR_YELLOW}[!]${CLR_NC} $1"
}

error() {
    echo -e "${CLR_RED}[X]${CLR_NC} $1"
}

enable_multilib() {
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        info "Habilitando repositorio multilib..."
        sudo sed -i '/^#\[multilib\]/,+1 s/^#//' /etc/pacman.conf
        sudo pacman -Sy > /dev/null 2>&1
    fi
}

install_yay() {
    if ! command -v yay > /dev/null; then
        info "Instalando AUR helper (yay)..."
        git clone https://aur.archlinux.org/yay.git /tmp/yay > /dev/null 2>&1
        cd /tmp/yay && makepkg -si --noconfirm > /dev/null 2>&1
        cd "$DOTFILES_DIR"
    fi
}

# --- MAIN INSTALLER ---

print_banner
gum spin --spinner dot --title "Iniciando instalador..." sleep 1

section "Preparación del sistema"
install_yay
info "Dependencias iniciales listas."

section "Selección de Software"

# 1. CORE (Mandatorio: Siempre se instala)
CORE_PKGS="hyprland sddm hypridle hyprlock hyprpicker xdg-desktop-portal-hyprland waybar rofi kitty network-manager-applet pipewire pipewire-pulse playerctl swappy grim slurp nwg-look bibata-cursor-theme tela-circle-icon-theme-all otf-font-awesome ttf-jetbrains-mono-nerd"

# 2. SELECCIÓN DE HARDWARE Y APPS (Opcional)
SOFTWARE_CHOICE=$(gum choose --no-limit --header "Selecciona hardware y aplicaciones adicionales (Espacio para marcar, Enter para confirmar)" \
    "Drivers NVIDIA" \
    "Herramientas ASUS (ROG/TUF)" \
    "Aplicaciones (Brave, Vesktop, etc.)" \
    "Gaming (Steam + Multilib)")

# Construir lista basada en la elección
PKGS_TO_INSTALL="$CORE_PKGS"

if [[ $SOFTWARE_CHOICE == *"Drivers NVIDIA"* ]]; then
    PKGS_TO_INSTALL="$PKGS_TO_INSTALL nvidia-open-dkms nvidia-settings nvidia-utils"
fi

if [[ $SOFTWARE_CHOICE == *"Herramientas ASUS"* ]]; then
    PKGS_TO_INSTALL="$PKGS_TO_INSTALL asusctl supergfxctl rog-control-center"
fi

if [[ $SOFTWARE_CHOICE == *"Aplicaciones"* ]]; then
    PKGS_TO_INSTALL="$PKGS_TO_INSTALL brave-origin-nightly-bin vesktop telegram-desktop code thunar dolphin"
fi

if [[ $SOFTWARE_CHOICE == *"Gaming"* ]]; then
    enable_multilib
    PKGS_TO_INSTALL="$PKGS_TO_INSTALL steam"
fi

section "Instalación de paquetes"
info "Instalando núcleo del sistema, estética y selección de software..."
yay -S --needed --noconfirm $PKGS_TO_INSTALL

section "Configuraciones (Dotfiles)"
if gum confirm "¿Quieres aplicar las configuraciones (stow) ahora?"; then
    mkdir -p ~/.config ~/.local/bin
    stow -v -R -t ~ .config
    stow -v -R -t ~ .local
    stow -v -R -t ~ zsh
    stow -v -R -t ~ bash
    stow -v -R -t ~ gtk
    info "Configuraciones aplicadas."
fi

section "Fondos de Pantalla"
if gum confirm "¿Quieres descargar la colección de wallpapers?"; then
    WALL_DIR="$HOME/Pictures/Wallpapers"
    mkdir -p "$WALL_DIR"
    if [ -z "$(ls -A "$WALL_DIR" 2>/dev/null)" ]; then
        info "Descargando wallpapers desde el repositorio..."
        git clone https://github.com/bjarneo/wallpapers.git /tmp/wallpapers-repo > /dev/null 2>&1
        cp -r /tmp/wallpapers-repo/* "$WALL_DIR/"
        rm -rf /tmp/wallpapers-repo
        info "Wallpapers instalados en $WALL_DIR."
    else
        warn "La carpeta de wallpapers ya tiene contenido, saltando descarga."
    fi
fi

section "Entorno de Shell"
if gum confirm "¿Quieres configurar Zsh como shell por defecto?"; then
    [ "$SHELL" != "$(which zsh)" ] && sudo chsh -s "$(which zsh)" "$USER"
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        info "Instalando Oh-My-Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended > /dev/null 2>&1
    fi
    info "Zsh configurado."
fi

section "Servicios del Sistema"
if gum confirm "¿Quieres habilitar el gestor de inicio (SDDM)?"; then
    sudo systemctl enable sddm
    info "SDDM habilitado."
fi

# Habilitar servicios de hardware si se instalaron
if [[ $SOFTWARE_CHOICE == *"Herramientas ASUS"* ]]; then
    info "Habilitando servicios ASUS..."
    sudo systemctl enable --now asusd.service supergfxd.service
fi

print_banner
echo -e "${CLR_GREEN}${CLR_BOLD}Instalación completada con éxito.${CLR_NC}"
echo -e "Reinicia la sesión para aplicar todos los cambios."
