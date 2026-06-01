#!/bin/bash

# --- Rhythm arch Hyprland installer ---

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PACKAGES_FILE="$PACKAGES_FILE" # This was defined earlier but let's be explicit
PACKAGES_FILE="$DOTFILES_DIR/packages.txt"

# --- SEGURIDAD: No correr como root ---
if [ "$EUID" -eq 0 ]; then
    echo "❌ ERROR: No ejecutes este script como root (usuario root)."
    echo "Arch Linux no permite compilar paquetes (makepkg) como root por seguridad."
    echo "Por favor, crea un usuario normal, dale privilegios sudo y ejecuta el script con ese usuario."
    echo ""
    echo "Ejemplo para crear usuario:"
    echo "  useradd -m -G wheel usuario"
    echo "  passwd usuario"
    echo "  EDITOR=nano visudo  # Descomenta la línea %wheel ALL=(ALL:ALL) ALL"
    echo "  su - usuario"
    exit 1
fi

echo "Iniciando instalación de Hyprland..."

# 0. Instalación de dependencias críticas iniciales
echo "Instalando dependencias base (stow, git, zsh, base-devel)..."
sudo pacman -S --needed --noconfirm git base-devel stow zsh

# 1. Detección de hardware
echo "Detectando hardware..."
IS_LAPTOP=false
IS_ASUS=false
IS_NVIDIA=false

if [ -d /sys/class/power_supply/BAT0 ] || [ -d /sys/class/power_supply/BAT1 ]; then
    IS_LAPTOP=true
    echo "  Laptop detectada."
fi

if [ -f /sys/class/dmi/id/board_vendor ] && grep -qi "ASUS" /sys/class/dmi/id/board_vendor; then
    IS_ASUS=true
    echo "  Hardware asus detectado."
fi

if lspci | grep -qi "NVIDIA"; then
    IS_NVIDIA=true
    echo "  Gpu nvidia detectada."
fi

# 2. Configuración de repositorios especiales (ASUS)
if [ "$IS_ASUS" = true ]; then
    if ! grep -q "\[g14\]" /etc/pacman.conf; then
        echo "Configurando repositorio g14 (asus)..."
        sudo pacman-key --recv-keys 8F654886F17D497FEFE3DB448B15A6B0E9A3D5D9
        sudo pacman-key --lsign-key 8F654886F17D497FEFE3DB448B15A6B0E9A3D5D9
        echo -e "\n[g14]\nServer = https://arch.asus-linux.org" | sudo tee -a /etc/pacman.conf
        sudo pacman -Sy
    fi
fi

# 3. Instalación de yay (AUR helper)
if ! command -v yay > /dev/null; then
    echo "Instalando yay..."
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm
    cd "$DOTFILES_DIR"
fi

# 4. Instalación de paquetes
if [ -f "$PACKAGES_FILE" ]; then
    echo "Instalando paquetes desde $PACKAGES_FILE..."
    PACKAGES=$(cat "$PACKAGES_FILE")
    
    if [ "$IS_ASUS" = false ]; then
        PACKAGES=$(echo "$PACKAGES" | grep -vE "asusctl|supergfxctl|rog-control-center")
    fi
    if [ "$IS_NVIDIA" = false ]; then
        PACKAGES=$(echo "$PACKAGES" | grep -vE "nvidia")
    fi

    # Usar pacman para los paquetes oficiales primero (más rápido) y yay para el resto
    echo "$PACKAGES" | yay -S --needed --noconfirm -
else
    echo "Aviso: $PACKAGES_FILE no encontrado."
fi

# 4.1 Instalación de flatpaks
FLATPAKS_FILE="$DOTFILES_DIR/flatpaks.txt"
if [ -f "$FLATPAKS_FILE" ]; then
    if command -v flatpak > /dev/null; then
        echo "Instalando aplicaciones flatpak..."
        while read -r app; do
            [ -z "$app" ] || [[ "$app" =~ ^# ]] && continue
            flatpak install --user -y flathub "$app"
        done < "$FLATPAKS_FILE"
    else
        echo "Flatpak no instalado, saltando instalación de apps flatpak."
    fi
fi

# 4.2 Descarga de wallpapers
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
if [ ! -d "$WALLPAPER_DIR" ] || [ -z "$(ls -A "$WALLPAPER_DIR" 2>/dev/null)" ]; then
    echo "Descargando colección de wallpapers..."
    mkdir -p "$WALLPAPER_DIR"
    git clone https://github.com/bjarneo/wallpapers.git /tmp/wallpapers-repo
    cp -r /tmp/wallpapers-repo/* "$WALLPAPER_DIR/"
    rm -rf /tmp/wallpapers-repo
else
    echo "La carpeta de wallpapers ya existe y tiene contenido, saltando descarga."
fi

# 5. Enlaces simbólicos con stow
echo "Creando enlaces simbólicos..."
mkdir -p ~/.config
mkdir -p ~/.local/bin

# Asegurar que stow esté instalado antes de usarlo
if command -v stow > /dev/null; then
    stow -v -R -t ~ .config
    stow -v -R -t ~ .local
    stow -v -R -t ~ zsh
    stow -v -R -t ~ bash
    stow -v -R -t ~ gtk
else
    echo "❌ ERROR: stow no se instaló correctamente."
fi

# 6. Post-instalación
echo "Configuraciones finales..."

# Zsh como shell por defecto
if command -v zsh > /dev/null; then
    if [[ $SHELL != *"zsh"* ]]; then
        echo "  Cambiando shell a zsh..."
        sudo chsh -s $(which zsh) $USER
    fi
    
    # Oh-my-zsh
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        echo "  Instalando oh-my-zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
else
    echo "  ⚠️ Zsh no encontrado, saltando configuración de shell."
fi

# Habilitar servicios de hardware
if [ "$IS_ASUS" = true ]; then
    echo "  Habilitando servicios asus..."
    sudo systemctl enable --now asusd.service
    sudo systemctl enable --now supergfxd.service
fi

echo "Instalación completada. Reinicia tu sesión para ver los cambios."

