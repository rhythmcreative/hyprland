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
# Incluye base, ui, audio, red, bluetooth, polkit y estética
CORE_PKGS="hyprland sddm hypridle hyprlock hyprpicker xdg-desktop-portal-hyprland waybar rofi kitty networkmanager network-manager-applet bluez bluez-utils pipewire pipewire-pulse wireplumber pavucontrol playerctl pamixer brightnessctl gvfs polkit-kde-agent swappy grim slurp nwg-look bibata-cursor-theme tela-circle-icon-theme-all otf-font-awesome ttf-jetbrains-mono-nerd flatpak python-pywal swww stow"

# 2. SELECCIÓN DE HARDWARE Y APPS (Opcional)
SOFTWARE_CHOICE=$(gum choose --no-limit --header "Selecciona hardware y aplicaciones adicionales (Espacio para marcar, Enter para confirmar)" \
    "Drivers NVIDIA" \
    "Herramientas ASUS (ROG/TUF)" \
    "Aplicaciones (Brave, Obsidian, OBS...)" \
    "Gaming (Steam, Minecraft...)" \
    "Productividad (LibreOffice)" \
    "Virtualización (VirtualBox)")

# Construir lista basada en la elección
PKGS_TO_INSTALL="$CORE_PKGS"

if [[ $SOFTWARE_CHOICE == *"Drivers NVIDIA"* ]]; then
    PKGS_TO_INSTALL="$PKGS_TO_INSTALL nvidia-open-dkms nvidia-settings nvidia-utils"
fi

if [[ $SOFTWARE_CHOICE == *"Herramientas ASUS"* ]]; then
    PKGS_TO_INSTALL="$PKGS_TO_INSTALL asusctl supergfxctl rog-control-center"
fi

if [[ $SOFTWARE_CHOICE == *"Aplicaciones"* ]]; then
    APPS_CHOICE=$(gum choose --no-limit --header "Selecciona qué aplicaciones instalar (Espacio para marcar)" \
        "Brave (Browser)" \
        "Vesktop (Discord)" \
        "Telegram" \
        "VS Code" \
        "Obsidian" \
        "OBS Studio" \
        "Thunar (File Manager)" \
        "Dolphin (File Manager)")
    
    [[ $APPS_CHOICE == *"Brave"* ]] && PKGS_TO_INSTALL="$PKGS_TO_INSTALL brave-origin-nightly-bin"
    [[ $APPS_CHOICE == *"Vesktop"* ]] && PKGS_TO_INSTALL="$PKGS_TO_INSTALL vesktop"
    [[ $APPS_CHOICE == *"Telegram"* ]] && PKGS_TO_INSTALL="$PKGS_TO_INSTALL telegram-desktop"
    [[ $APPS_CHOICE == *"VS Code"* ]] && PKGS_TO_INSTALL="$PKGS_TO_INSTALL code"
    [[ $APPS_CHOICE == *"Obsidian"* ]] && PKGS_TO_INSTALL="$PKGS_TO_INSTALL obsidian"
    [[ $APPS_CHOICE == *"OBS Studio"* ]] && PKGS_TO_INSTALL="$PKGS_TO_INSTALL obs-studio"
    [[ $APPS_CHOICE == *"Thunar"* ]] && PKGS_TO_INSTALL="$PKGS_TO_INSTALL thunar"
    [[ $APPS_CHOICE == *"Dolphin"* ]] && PKGS_TO_INSTALL="$PKGS_TO_INSTALL dolphin"
fi

if [[ $SOFTWARE_CHOICE == *"Gaming"* ]]; then
    enable_multilib
    PKGS_TO_INSTALL="$PKGS_TO_INSTALL steam minecraft-launcher"
fi

if [[ $SOFTWARE_CHOICE == *"Productividad"* ]]; then
    PKGS_TO_INSTALL="$PKGS_TO_INSTALL libreoffice-fresh"
fi

if [[ $SOFTWARE_CHOICE == *"Virtualización"* ]]; then
    PKGS_TO_INSTALL="$PKGS_TO_INSTALL virtualbox virtualbox-host-dkms"
fi

section "Instalación de paquetes"
info "Instalando núcleo del sistema, estética y selección de software..."
yay -S --needed --noconfirm $PKGS_TO_INSTALL

# 3. INSTALACIÓN DE FLATPAKS
if [ -f "$DOTFILES_DIR/flatpaks.txt" ]; then
    if gum confirm "¿Quieres instalar las aplicaciones Flatpak de la lista?"; then
        info "Instalando Flatpaks..."
        while read -r app; do
            [ -z "$app" ] || [[ "$app" =~ ^# ]] && continue
            flatpak install --user -y flathub "$app"
        done < "$DOTFILES_DIR/flatpaks.txt"
    fi
fi

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
    
    # Sincronización inicial de colores para el terminal
    if command -v wal > /dev/null; then
        info "Generando paleta de colores inicial (Pywal)..."
        RANDOM_WALL=$(find "$WALL_DIR" -type f | shuf -n 1)
        if [ ! -z "$RANDOM_WALL" ]; then
            wal -i "$RANDOM_WALL" --skip-sequences > /dev/null 2>&1
            info "Terminal sincronizado con el wallpaper: $(basename "$RANDOM_WALL")"
        fi
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
if gum confirm "¿Quieres habilitar los servicios esenciales (Red, Bluetooth, SDDM)?"; then
    sudo systemctl enable NetworkManager
    sudo systemctl enable bluetooth
    sudo systemctl enable sddm
    
    # Instalar tema SDDM local
    if [ -d "$DOTFILES_DIR/sddm/sddm-astronaut-theme" ]; then
        info "Instalando tema SDDM local..."
        sudo mkdir -p /usr/share/sddm/themes
        sudo cp -r "$DOTFILES_DIR/sddm/sddm-astronaut-theme" /usr/share/sddm/themes/
    fi

    # Configurar el tema astronaut
    if [ ! -d "/etc/sddm.conf.d" ]; then
        sudo mkdir -p /etc/sddm.conf.d
    fi
    echo -e "[Theme]\nCurrent=sddm-astronaut-theme" | sudo tee /etc/sddm.conf.d/theme.conf
    info "Servicios de sistema habilitados y SDDM configurado."
fi

# Añadir usuario a grupos necesarios
info "Configurando permisos de usuario..."
sudo usermod -aG video,input,render $USER

# Habilitar servicios de hardware si se instalaron
if [[ $SOFTWARE_CHOICE == *"Herramientas ASUS"* ]]; then
    info "Habilitando servicios ASUS..."
    sudo systemctl enable --now asusd.service supergfxd.service
fi

# Sincronización final de tema
if [ -f "$HOME/.local/bin/modern-pywal-sync" ]; then
    info "Aplicando sincronización de tema definitiva..."
    bash "$HOME/.local/bin/modern-pywal-sync" > /dev/null 2>&1
fi

print_banner
echo -e "${CLR_GREEN}${CLR_BOLD}Instalación completada con éxito.${CLR_NC}"
echo -e "Reinicia la sesión para aplicar todos los cambios."
