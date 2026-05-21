#!/bin/bash

# =============================================================================
# Arch Linux System Dotfiles Installer
# Configuración Completa: Hyprland + Waybar + SDDM + Pywal
# =============================================================================

set -e

# Colores para la interfaz
export GREEN='\033[0;32m'
export BLUE='\033[0;34m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export NC='\033[0m'

echo -e "${BLUE}======================================================${NC}"
echo -e "${GREEN}      Instalador de Configuración de Sistema Arch${NC}"
echo -e "${BLUE}======================================================${NC}"

# 1. Verificación de Entorno
if [ ! -f /etc/arch-release ]; then
    echo -e "${RED}Error: Este script está diseñado específicamente para Arch Linux.${NC}"
    exit 1
fi

# 2. Definición de Dependencias
DEPENDENCIES=(
    hyprland waybar rofi-wayland swww network-manager-applet
    dolphin python-pywal kitty bibata-cursor-theme adwaita-icon-theme
    qt5ct mako grim slurp wl-clipboard xdg-desktop-portal-hyprland
    hypridle hyprlock imagemagick swappy fastfetch gvfs nfs-utils
    ttf-jetbrains-mono-nerd ttf-font-awesome otf-font-awesome inter-font
    xorg-xrandr brightnessctl playerctl pamixer jq
)

AUR_DEPENDENCIES=(
    nwg-dock-hyprland
    nwg-displays
    warp-terminal-bin
    tela-circle-icon-theme-git
    awww-git
    sddm-astronaut-theme-git
)

# 3. Función de Instalación de Paquetes
install_packages() {
    echo -e "${YELLOW}Actualizando sistema e instalando dependencias base...${NC}"
    sudo pacman -S --needed --noconfirm "${DEPENDENCIES[@]}"
    
    # Manejo de AUR Helper
    AUR_HELPER=""
    if command -v yay > /dev/null; then AUR_HELPER="yay";
    elif command -v paru > /dev/null; then AUR_HELPER="paru";
    else
        echo -e "${YELLOW}Instalando 'yay' como ayudante de AUR...${NC}"
        sudo pacman -S --needed --noconfirm git base-devel
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        cd /tmp/yay && makepkg -si --noconfirm && cd -
        rm -rf /tmp/yay
        AUR_HELPER="yay"
    fi

    echo -e "${YELLOW}Instalando paquetes del AUR...${NC}"
    $AUR_HELPER -S --needed --noconfirm "${AUR_DEPENDENCIES[@]}"

    # Instalación de aplicaciones adicionales si existen las listas
    if [[ -f "pkglist.txt" ]]; then
        echo -e "${BLUE}¿Deseas instalar también todas las aplicaciones adicionales de tu sistema anterior?${NC}"
        read -p "(y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Instalando aplicaciones adicionales...${NC}"
            # Intentar instalar con pacman lo que se pueda y el resto con el AUR helper
            sudo pacman -S --needed --noconfirm - < pkglist.txt 2>/dev/null || true
            $AUR_HELPER -S --needed --noconfirm - < aur_pkglist.txt 2>/dev/null || true
        fi
    fi
}

# 4. Implementación de Archivos
deploy_configs() {
    echo -e "${YELLOW}Creando respaldos y desplegando configuraciones...${NC}"
    BACKUP_DIR="$HOME/dots_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"

    # Lista de directorios a procesar
    CONFIG_DIRS=("hypr" "waybar" "kitty" "rofi" "mako" "wal" "SDDM" "gtk-3.0")
    
    for dir in "${CONFIG_DIRS[@]}"; do
        if [ -d "$HOME/.config/$dir" ]; then
            mv "$HOME/.config/$dir" "$BACKUP_DIR/" 2>/dev/null || true
        fi
    done

    # Archivos de Home
    HOME_FILES=(".bashrc" ".zshrc" ".gtkrc-2.0")
    for file in "${HOME_FILES[@]}"; do
        if [ -f "$HOME/$file" ]; then
            mv "$HOME/$file" "$BACKUP_DIR/" 2>/dev/null || true
        fi
    done

    # Copia de archivos
    mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/Pictures/Wallpapers" "$HOME/.themes"
    
    cp -r dotfiles/.config/* "$HOME/.config/"
    cp -r dotfiles/.local/bin/* "$HOME/.local/bin/"
    cp -r dotfiles/Pictures/Wallpapers/* "$HOME/Pictures/Wallpapers/"
    cp -r dotfiles/.themes/* "$HOME/.themes/"
    cp dotfiles/.bashrc "$HOME/"
    cp dotfiles/.zshrc "$HOME/"
    cp dotfiles/.gtkrc-2.0 "$HOME/"

    # Permisos
    chmod +x "$HOME/.local/bin/"*
    echo -e "${GREEN}Configuraciones de usuario desplegadas correctamente.${NC}"
}

# 5. Configuración de SDDM (Privilegios de Root)
setup_sddm_integration() {
    echo -e "${YELLOW}Configurando integración de SDDM (requiere sudo)...${NC}"
    
    # Instalar el root-helper
    if [ -f "dotfiles/.local/bin/sddm-root-helper" ]; then
        sudo cp "dotfiles/.local/bin/sddm-root-helper" "/usr/local/bin/"
        sudo chmod +x "/usr/local/bin/sddm-root-helper"
    fi

    # Configurar el tema en SDDM
    sudo mkdir -p /etc/sddm.conf.d
    echo -e "[Theme]\nCurrent=sddm-astronaut-theme" | sudo tee /etc/sddm.conf.d/theme.conf > /dev/null

    echo -e "${BLUE}¿Deseas habilitar SDDM sin contraseña para los scripts de sincronización?${NC}"
    echo -e "${YELLOW}(Esto añade una regla a sudoers para /usr/local/bin/sddm-root-helper)${NC}"
    read -p "(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "$(whoami) ALL=(ALL) NOPASSWD: /usr/local/bin/sddm-root-helper" | sudo tee /etc/sudoers.d/sddm-sync > /dev/null
        echo -e "${GREEN}Regla de sudoers añadida.${NC}"
    fi
}

# Ejecución Principal
read -p "¿Comenzar la instalación completa? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Instalación cancelada.${NC}"
    exit 0
fi

install_packages
deploy_configs
setup_sddm_integration

echo -e "${BLUE}======================================================${NC}"
echo -e "${GREEN}      ¡Instalación Finalizada con Éxito!${NC}"
echo -e "${BLUE}======================================================${NC}"
echo -e "${YELLOW}Respaldo creado en: $BACKUP_DIR${NC}"
echo -e "${YELLOW}Recomendación: Reinicia el sistema para aplicar todos los cambios.${NC}"
