#!/bin/bash

# --- Rhythm arch Hyprland installer (Interactive Version) ---

# Colores para la interfaz
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PACKAGES_FILE="$DOTFILES_DIR/packages.txt"

# --- SEGURIDAD: No correr como root ---
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}❌ ERROR: No ejecutes este script como root.${NC}"
    echo "Arch Linux no permite compilar paquetes (makepkg) como root."
    echo "Por favor, usa un usuario normal con privilegios sudo."
    exit 1
fi

# Limpiar pantalla para la presentación
clear
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║           RHYTHM HYPRLAND INSTALLER - v2.0               ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# --- Funciones de Instalación ---

install_base_deps() {
    echo -e "\n${YELLOW}📦 Instalando dependencias base...${NC}"
    sudo pacman -S --needed --noconfirm git base-devel stow zsh curl
}

detect_hardware() {
    echo -e "\n${YELLOW}🔍 Detectando hardware...${NC}"
    IS_LAPTOP=false; IS_ASUS=false; IS_NVIDIA=false
    [ -d /sys/class/power_supply/BAT0 ] || [ -d /sys/class/power_supply/BAT1 ] && IS_LAPTOP=true && echo "  • Laptop detectada"
    [ -f /sys/class/dmi/id/board_vendor ] && grep -qi "ASUS" /sys/class/dmi/id/board_vendor && IS_ASUS=true && echo "  • Hardware ASUS detectado"
    lspci | grep -qi "NVIDIA" && IS_NVIDIA=true && echo "  • GPU NVIDIA detectada"
}

setup_asus() {
    if [ "$IS_ASUS" = true ] && ! grep -q "\[g14\]" /etc/pacman.conf; then
        echo -e "\n${YELLOW}🏗️ Configurando repositorio ASUS (g14)...${NC}"
        sudo pacman-key --recv-keys 8F654886F17D497FEFE3DB448B15A6B0E9A3D5D9
        sudo pacman-key --lsign-key 8F654886F17D497FEFE3DB448B15A6B0E9A3D5D9
        echo -e "\n[g14]\nServer = https://arch.asus-linux.org" | sudo tee -a /etc/pacman.conf
        sudo pacman -Sy
    fi
}

install_yay() {
    if ! command -v yay > /dev/null; then
        echo -e "\n${YELLOW}🌟 Instalando AUR helper (yay)...${NC}"
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        cd /tmp/yay && makepkg -si --noconfirm
        cd "$DOTFILES_DIR"
    fi
}

install_packages() {
    echo -e "\n${YELLOW}💾 Instalando paquetes del sistema...${NC}"
    if [ -f "$PACKAGES_FILE" ]; then
        PACKAGES=$(cat "$PACKAGES_FILE")
        [ "$IS_ASUS" = false ] && PACKAGES=$(echo "$PACKAGES" | grep -vE "asusctl|supergfxctl|rog-control-center")
        [ "$IS_NVIDIA" = false ] && PACKAGES=$(echo "$PACKAGES" | grep -vE "nvidia")
        echo "$PACKAGES" | yay -S --needed --noconfirm -
    else
        echo -e "${RED}⚠️ No se encontró packages.txt${NC}"
    fi
}

apply_stow() {
    echo -e "\n${YELLOW}🔗 Aplicando enlaces simbólicos (stow)...${NC}"
    mkdir -p ~/.config ~/.local/bin
    stow -v -R -t ~ .config
    stow -v -R -t ~ .local
    stow -v -R -t ~ zsh
    stow -v -R -t ~ bash
    stow -v -R -t ~ gtk
}

download_wallpapers() {
    echo -e "\n${YELLOW}🖼️ Descargando wallpapers...${NC}"
    WALL_DIR="$HOME/Pictures/Wallpapers"
    mkdir -p "$WALL_DIR"
    if [ -z "$(ls -A "$WALL_DIR" 2>/dev/null)" ]; then
        git clone https://github.com/bjarneo/wallpapers.git /tmp/wallpapers-repo
        cp -r /tmp/wallpapers-repo/* "$WALL_DIR/"
        rm -rf /tmp/wallpapers-repo
    else
        echo "Carpeta de wallpapers ya tiene contenido, saltando."
    fi
}

setup_shell() {
    echo -e "\n${YELLOW}🐚 Configurando Zsh y Oh-My-Zsh...${NC}"
    [ "$SHELL" != "$(which zsh)" ] && sudo chsh -s "$(which zsh)" "$USER"
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
}

# --- MENU PRINCIPAL ---

show_menu() {
    echo -e "${BOLD}¿Qué deseas instalar?${NC}"
    echo -e "1) ${GREEN}Instalación Completa${NC} (Recomendado)"
    echo -e "2) ${CYAN}Solo Configuraciones${NC} (dotfiles + stow)"
    echo -e "3) ${CYAN}Solo Scripts${NC} (.local/bin)"
    echo -e "4) ${CYAN}Solo Wallpapers${NC}"
    echo -e "5) ${RED}Salir${NC}"
    echo ""
    read -p "Selecciona una opción [1-5]: " CHOICE
}

# --- Ejecución ---

show_menu

case $CHOICE in
    1)
        install_base_deps
        detect_hardware
        setup_asus
        install_yay
        install_packages
        apply_stow
        download_wallpapers
        setup_shell
        ;;
    2)
        install_base_deps
        apply_stow
        ;;
    3)
        mkdir -p ~/.local/bin
        stow -v -R -t ~ .local
        ;;
    4)
        download_wallpapers
        ;;
    5)
        echo "Saliendo..."
        exit 0
        ;;
    *)
        echo -e "${RED}Opción no válida.${NC}"
        exit 1
        ;;
esac

echo -e "\n${GREEN}${BOLD}✅ Proceso finalizado con éxito.${NC}"
echo "Reinicia tu sesión para aplicar todos los cambios."


