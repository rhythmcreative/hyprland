#!/bin/bash
# Script de instalación para los dotfiles de rhythmcreative

echo "Iniciando la instalación de los dotfiles..."

# --- Detección del Sistema Operativo ---
OS=""
if [ -f /etc/arch-release ]; then
    OS="Arch"
elif [ -f /etc/debian_version ]; then
    OS="Debian"
else
    echo "Sistema operativo no soportado. Este script solo funciona en Arch Linux y distribuciones basadas en Debian (como Ubuntu)."
    exit 1
fi

echo "Sistema operativo detectado: $OS"

# --- Funciones de Instalación de Paquetes ---
install_packages_arch() {
    echo "Instalando paquetes para Arch Linux..."
    # Asegúrate de tener un ayudante de AUR como 'yay' o 'paru' instalado.
    yay -S --needed \
        sddm \
        hyprland hyprpm hyprlock hyprpicker xdg-desktop-portal-hyprland \
        waybar rofi python-pywal swww mako nwg-dock-hyprland nwg-displays \
        asusctl \
        kitty ulauncher dolphin thunar network-manager-applet grim slurp swappy \
        jq polkit-kde-agent qt5ct pipewire wireplumber pipewire-audio pipewire-pulse \
        wpctl brightnessctl playerctl noto-fonts noto-fonts-cjk noto-fonts-emoji \
        ttf-font-awesome bibata-cursor-theme adwaita-icon-theme \
        git gcc go rust cargo meson cmake gettext gtk3 gtk4 cairo pango gdk-pixbuf2 glib2

    # Nota: warp-terminal requiere un instalador separado que debes descargar y ejecutar.
    echo "Recuerda instalar warp-terminal por separado."
}

install_packages_debian() {
    echo "Instalando paquetes para Debian/Ubuntu..."
    sudo apt update
    sudo apt install -y \
        sddm \
        waybar rofi python3-pywal kitty ulauncher dolphin thunar network-manager-gnome \
        grim slurp swappy jq polkit-kde-agent-1 qt5ct pipewire wireplumber \
        pipewire-audio-client-libraries libspa-0.2-bluetooth libpipewire-0.3-0 \
        brightnessctl playerctl fonts-noto fonts-noto-cjk fonts-noto-color-emoji \
        fonts-font-awesome adwaita-icon-theme git build-essential golang rustc cargo \
        meson cmake gettext libgtk-3-dev libgtk-4-dev libcairo2-dev libpango1.0-dev \
        libgdk-pixbuf2.0-dev libglib2.0-dev

    # --- AVISO IMPORTANTE ---
    # La mayoría de los componentes de Hyprland y Asus no están en los repositorios de Ubuntu.
    # Deberás compilarlos o instalarlos manualmente. Aquí hay una guía general:
    #
    # 1. Hyprland: Sigue la guía oficial en el wiki de Hyprland.
    #    https://wiki.hypr.land/Getting-Started/Installation/#ubuntu
    #
    # 2. Asusctl: La instalación recomendada es a través de las guías en asus-linux.org.
    #    Puede requerir añadir un PPA o compilar desde el código fuente.
    #    https://asus-linux.org/wiki/arch-guide/
    #
    # 3. swww, hyprlock, hyprpicker, nwg-dock-hyprland, nwg-displays:
    #    Generalmente, el proceso es:
    #    a) Clona el repositorio de GitHub del proyecto.
    #    b) Entra en el directorio del proyecto.
    #    c) Sigue las instrucciones de compilación (usualmente 'meson build', 'ninja -C build', etc.).
    #
    # 4. warp-terminal: Descarga el instalador .deb desde su sitio web oficial.
    echo "¡ACCIÓN REQUERIDA! Varios paquetes clave (Hyprland, asusctl, swww, etc.) deben ser instalados manualmente en Ubuntu."
}

# --- Ejecución de la Instalación ---
if [ "$OS" = "Arch" ]; then
    install_packages_arch
elif [ "$OS" = "Debian" ]; then
    install_packages_debian
fi

echo "Instalación de paquetes base completada."

# --- Creación de Enlaces Simbólicos ---
create_symlinks() {
    echo "Creando enlaces simbólicos..."

    # Directorio donde se encuentra este script
    local SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
    local DOTFILES_DIR="$SCRIPT_DIR"
    local BACKUP_DIR="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"

    # Lista de directorios de configuración para enlazar
    local CONFIG_DIRS=("hypr" "waybar" "rofi" "wal")
    # Lista de directorios locales para enlazar
    local LOCAL_DIRS=("bin")

    # Asegurarse de que el directorio de destino existe
    mkdir -p "$HOME/.config"
    mkdir -p "$HOME/.local"
    mkdir -p "$HOME/Pictures" # Asegurar que el directorio Pictures existe

    # Función para crear un enlace, haciendo backup si es necesario
    link_item() {
        local src=$1
        local dest=$2
        
        if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$src" ]; then
            echo "✔ Enlace ya existe y es correcto: $dest"
            return
        fi

        if [ -e "$dest" ]; then
            echo "Haciendo backup de $dest en $BACKUP_DIR"
            mkdir -p "$(dirname "$BACKUP_DIR/$dest")"
            mv "$dest" "$BACKUP_DIR/$dest"
        fi
        
        echo "🔗 Creando enlace: $dest -> $src"
        ln -s "$src" "$dest"
    }

    # Enlazar directorios de .config
    for dir in "${CONFIG_DIRS[@]}"; do
        local src="$DOTFILES_DIR/config/$dir"
        local dest="$HOME/.config/$dir"
        if [ -d "$src" ]; then
            link_item "$src" "$dest"
        fi
    done

    # Enlazar directorios de .local
    for dir in "${LOCAL_DIRS[@]}"; do
        local src="$DOTFILES_DIR/local/$dir"
        local dest="$HOME/.local/$dir"
        if [ -d "$src" ]; then
            link_item "$src" "$dest"
        fi
    done

    # Enlazar el directorio de Wallpapers
    local WALLPAPERS_SRC="$DOTFILES_DIR/Pictures/Wallpapers"
    local WALLPAPERS_DEST="$HOME/Pictures/Wallpapers"
    if [ -d "$WALLPAPERS_SRC" ]; then
        link_item "$WALLPAPERS_SRC" "$WALLPAPERS_DEST"
    fi
    
    echo "Creación de enlaces simbólicos completada."
}

# --- Ejecución Final ---
create_symlinks

echo "✅ ¡Instalación de dotfiles completada!"
echo "Por favor, reinicia tu sesión de Hyprland para que todos los cambios surtan efecto."

echo ""
echo "--- 🚀 PASO FINAL REQUERIDO: Configurar SDDM ---"
echo "Para configurar el gestor de inicio de sesión (SDDM) con tu tema personalizado, ejecuta el siguiente comando:"
echo ""
echo "    sudo ./setup_sddm.sh"
echo ""
echo "Esto copiará el tema y la configuración a las carpetas del sistema y habilitará SDDM en el arranque."
