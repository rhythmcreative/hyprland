#!/bin/bash

# --- Rhythm Arch Hyprland Installer ---

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PACKAGES_FILE="$DOTFILES_DIR/packages.txt"

echo "Iniciando instalación de Hyprland..."

# 1. Detección de Hardware
echo "Detectando hardware..."
IS_LAPTOP=false
IS_ASUS=false
IS_NVIDIA=false

if [ -d /sys/class/power_supply/BAT0 ]; then
    IS_LAPTOP=true
    echo "  Laptop detectada."
fi

if cat /sys/class/dmi/id/board_vendor | grep -qi "ASUS"; then
    IS_ASUS=true
    echo "  Hardware asus detectado."
fi

if lspci | grep -qi "NVIDIA"; then
    IS_NVIDIA=true
    echo "  Gpu nvidia detectada."
fi

# 2. Configuración de Repositorios Especiales
if [ "$IS_ASUS" = true ]; then
    if ! grep -q "\[g14\]" /etc/pacman.conf; then
        echo "Configurando repositorio g14 (asus)..."
        sudo pacman-key --recv-keys 8F654886F17D497FEFE3DB448B15A6B0E9A3D5D9
        sudo pacman-key --lsign-key 8F654886F17D497FEFE3DB448B15A6B0E9A3D5D9
        echo -e "\n[g14]\nServer = https://arch.asus-linux.org" | sudo tee -a /etc/pacman.conf
        sudo pacman -Sy
    fi
fi

# 3. Instalación de Yay (AUR helper)
if ! command -v yay > /dev/null; then
    echo "Instalando yay..."
    sudo pacman -S --needed git base-devel
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm
    cd "$DOTFILES_DIR"
fi

# 4. Instalación de Paquetes
if [ -f "$PACKAGES_FILE" ]; then
    echo "Instalando paquetes desde $PACKAGES_FILE..."
    # Filtramos paquetes de hardware si no estamos en el hardware correcto
    PACKAGES=$(cat "$PACKAGES_FILE")
    
    if [ "$IS_ASUS" = false ]; then
        PACKAGES=$(echo "$PACKAGES" | grep -vE "asusctl|supergfxctl|rog-control-center")
    fi
    if [ "$IS_NVIDIA" = false ]; then
        PACKAGES=$(echo "$PACKAGES" | grep -vE "nvidia")
    fi

    echo "$PACKAGES" | yay -S --needed --noconfirm -
else
    echo "Aviso: $PACKAGES_FILE no encontrado."
fi

# 4.1 Instalación de Flatpaks
FLATPAKS_FILE="$DOTFILES_DIR/flatpaks.txt"
if [ -f "$FLATPAKS_FILE" ]; then
    if command -v flatpak > /dev/null; then
        echo "Instalando aplicaciones flatpak..."
        while read -r app; do
            [ -z "$app" ] && continue
            flatpak install --user -y flathub "$app"
        done < "$FLATPAKS_FILE"
    else
        echo "Flatpak no instalado, saltando instalación de apps flatpak."
    fi
fi

# 4.2 Descarga de Wallpapers
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
if [ ! -d "$WALLPAPER_DIR" ] || [ -z "$(ls -A "$WALLPAPER_DIR")" ]; then
    echo "Descargando colección de wallpapers..."
    mkdir -p "$WALLPAPER_DIR"
    git clone https://github.com/bjarneo/wallpapers.git /tmp/wallpapers-repo
    cp -r /tmp/wallpapers-repo/* "$WALLPAPER_DIR/"
    rm -rf /tmp/wallpapers-repo
else
    echo "La carpeta de wallpapers ya existe y tiene contenido, saltando descarga."
fi

# 5. Symlinks con Stow
echo "Creando enlaces simbólicos..."
mkdir -p ~/.config
mkdir -p ~/.local/bin

stow -v -R -t ~ config
stow -v -R -t ~ local
stow -v -R -t ~ zsh
stow -v -R -t ~ bash
stow -v -R -t ~ gtk

# 6. Post-instalación
echo "Configuraciones finales..."

# Zsh como shell por defecto
if [[ $SHELL != *"zsh"* ]]; then
    echo "  Cambiando shell a zsh..."
    chsh -s $(which zsh)
fi

# Oh-My-Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "  Instalando oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Habilitar servicios de hardware
if [ "$IS_ASUS" = true ]; then
    echo "  Habilitando servicios asus..."
    sudo systemctl enable --now asusd.service
    sudo systemctl enable --now supergfxd.service
fi

echo "Instalación completada. Reinicia tu sesión para ver los cambios."
