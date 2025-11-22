#!/bin/bash

# Este script requiere privilegios de sudo para copiar archivos a /etc y /usr/share,
# y para habilitar el servicio de SDDM.

# --- Colors for output ---
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

# --- Log functions ---
info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $1"
}

success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $1"
}

error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $1"
}

# --- Sudo Check ---
if [ "$EUID" -ne 0 ]; then
  error "Por favor, ejecuta este script con sudo."
  exit 1
fi

info "Iniciando la configuración de SDDM..."

# --- Check if SDDM is installed ---
if ! pacman -Q sddm &> /dev/null; then
    error "SDDM no está instalado."
    info "Por favor, ejecuta primero el script principal 'install.sh' para instalar SDDM y otras dependencias."
    exit 1
fi
info "SDDM está instalado. Procediendo..."

# --- Directorio del script ---
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
THEME_SRC_DIR="$SCRIPT_DIR/sddm/themes/sddm-astronaut-theme"
CONFIG_SRC_FILE="$SCRIPT_DIR/sddm/sddm.conf.d/astronaut.conf"

# --- Verificar que los archivos fuente existen ---
if [ ! -d "$THEME_SRC_DIR" ]; then
    error "El directorio del tema no se encuentra en '$THEME_SRC_DIR'"
    exit 1
fi
if [ ! -f "$CONFIG_SRC_FILE" ]; then
    error "El archivo de configuración no se encuentra en '$CONFIG_SRC_FILE'"
    exit 1
fi

# 1. Crear directorios de destino y copiar el tema
THEME_DEST_DIR="/usr/share/sddm/themes"
info "Asegurando que el directorio de temas '$THEME_DEST_DIR' existe..."
mkdir -p "$THEME_DEST_DIR"

info "Instalando el tema sddm-astronaut-theme..."
cp -r "$THEME_SRC_DIR" "$THEME_DEST_DIR/"

# 2. Crear directorio de configuración y copiar la configuración
CONFIG_DEST_DIR="/etc/sddm.conf.d"
info "Asegurando que el directorio de configuración '$CONFIG_DEST_DIR' existe..."
mkdir -p "$CONFIG_DEST_DIR"

info "Aplicando la configuración del tema..."
cp "$CONFIG_SRC_FILE" "$CONFIG_DEST_DIR/"

# 3. Habilitar el servicio de SDDM
info "Habilitando el servicio de SDDM para que se inicie en el arranque..."
systemctl enable sddm.service

success "✅ Configuración de SDDM completada."
info "SDDM se iniciará en el próximo arranque del sistema."