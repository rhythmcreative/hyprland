#!/bin/bash

# Script de instalación para la integración de pywal con el tema SDDM astronaut
# Autor: rhythmcreative

set -e

THEME_DIR="/home/rhythmcreative/sddm-astronaut-theme/sddm-astronaut-theme"
SDDM_THEMES_DIR="/usr/share/sddm/themes"
THEME_NAME="sddm-astronaut-theme"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
    print_status "Verificando requisitos..."
    
    # Verificar si se está ejecutando como root para la instalación
    if [[ "$1" == "install" ]] && [[ $EUID -ne 0 ]]; then
        print_error "Este script debe ejecutarse como root para instalar el tema."
        echo "Usa: sudo $0 install"
        exit 1
    fi
    
    # Verificar pywal
    if ! command -v wal >/dev/null 2>&1; then
        print_warning "pywal no está instalado. Instalándolo..."
        if command -v pacman >/dev/null 2>&1; then
            pacman -S --noconfirm python-pywal
        elif command -v apt >/dev/null 2>&1; then
            apt update && apt install -y python3-pywal
        else
            print_error "No se pudo instalar pywal automáticamente. Instálalo manualmente:"
            echo "  pip install pywal"
            exit 1
        fi
    fi
    
    # Verificar ImageMagick
    if ! command -v convert >/dev/null 2>&1; then
        print_warning "ImageMagick no está instalado. Instalándolo..."
        if command -v pacman >/dev/null 2>&1; then
            pacman -S --noconfirm imagemagick
        elif command -v apt >/dev/null 2>&1; then
            apt update && apt install -y imagemagick
        else
            print_warning "No se pudo instalar ImageMagick automáticamente. Se recomienda instalarlo para mejor calidad de imagen."
        fi
    fi
    
    print_success "Verificación de requisitos completada."
}

install_theme() {
    print_status "Instalando tema SDDM..."
    
    # Crear directorio de temas si no existe
    mkdir -p "$SDDM_THEMES_DIR"
    
    # Copiar tema
    if [[ -d "$SDDM_THEMES_DIR/$THEME_NAME" ]]; then
        print_warning "El tema ya existe. Creando respaldo..."
        mv "$SDDM_THEMES_DIR/$THEME_NAME" "$SDDM_THEMES_DIR/${THEME_NAME}.backup.$(date +%Y%m%d-%H%M%S)"
    fi
    
    cp -r "$THEME_DIR" "$SDDM_THEMES_DIR/$THEME_NAME"
    chmod +x "$SDDM_THEMES_DIR/$THEME_NAME/pywal-sync.sh"
    
    print_success "Tema instalado en $SDDM_THEMES_DIR/$THEME_NAME"
}

configure_sddm() {
    print_status "Configurando SDDM..."
    
    # Buscar archivo de configuración de SDDM
    local sddm_conf=""
    if [[ -f "/etc/sddm.conf" ]]; then
        sddm_conf="/etc/sddm.conf"
    elif [[ -f "/usr/lib/sddm/sddm.conf.d/default.conf" ]]; then
        sddm_conf="/etc/sddm.conf"
        print_status "Creando /etc/sddm.conf..."
    else
        print_status "Creando /etc/sddm.conf..."
        sddm_conf="/etc/sddm.conf"
    fi
    
    # Hacer backup de configuración existente
    if [[ -f "$sddm_conf" ]]; then
        cp "$sddm_conf" "${sddm_conf}.backup.$(date +%Y%m%d-%H%M%S)"
        print_status "Backup creado: ${sddm_conf}.backup.$(date +%Y%m%d-%H%M%S)"
    fi
    
    # Configurar tema
    if grep -q "\\[Theme\\]" "$sddm_conf" 2>/dev/null; then
        # Actualizar configuración existente
        sed -i "s/^Current=.*/Current=$THEME_NAME/" "$sddm_conf"
        if ! grep -q "^Current=" "$sddm_conf"; then
            sed -i "/\\[Theme\\]/a Current=$THEME_NAME" "$sddm_conf"
        fi
    else
        # Agregar sección Theme
        echo "" >> "$sddm_conf"
        echo "[Theme]" >> "$sddm_conf"
        echo "Current=$THEME_NAME" >> "$sddm_conf"
    fi
    
    print_success "SDDM configurado para usar el tema $THEME_NAME"
}

create_autostart_script() {
    print_status "Creando script de autostart para sincronización automática..."
    
    local autostart_dir="/home/$SUDO_USER/.config/autostart"
    local autostart_file="$autostart_dir/sddm-pywal-sync.desktop"
    local script_path="/home/$SUDO_USER/.local/bin/sddm-pywal-sync"
    
    # Crear directorio si no existe
    sudo -u "$SUDO_USER" mkdir -p "$autostart_dir"
    sudo -u "$SUDO_USER" mkdir -p "/home/$SUDO_USER/.local/bin"
    
    # Crear script wrapper
    cat > "$script_path" << 'EOF'
#!/bin/bash
# Wrapper para sincronización automática de pywal con SDDM

THEME_SCRIPT="/usr/share/sddm/themes/sddm-astronaut-theme/pywal-sync.sh"

if [[ -f "$THEME_SCRIPT" ]]; then
    # Esperar un poco para asegurar que pywal ha terminado
    sleep 2
    sudo "$THEME_SCRIPT"
else
    echo "Error: Script de sincronización no encontrado en $THEME_SCRIPT"
fi
EOF
    
    chmod +x "$script_path"
    chown "$SUDO_USER:$SUDO_USER" "$script_path"
    
    # Crear archivo .desktop para autostart
    cat > "$autostart_file" << EOF
[Desktop Entry]
Type=Application
Name=SDDM Pywal Sync
Comment=Synchronize SDDM theme with pywal colors
Exec=$script_path
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF
    
    chown "$SUDO_USER:$SUDO_USER" "$autostart_file"
    
    print_success "Script de autostart creado en $autostart_file"
}

create_wallpaper_hook() {
    print_status "Creando hook para cambio de wallpaper..."
    
    local hook_dir="/home/$SUDO_USER/.config/wal/hooks"
    local hook_script="$hook_dir/sddm-sync.sh"
    
    # Crear directorio si no existe
    sudo -u "$SUDO_USER" mkdir -p "$hook_dir"
    
    # Crear hook script
    cat > "$hook_script" << 'EOF'
#!/bin/bash
# Hook de pywal para sincronizar con SDDM
# Este script se ejecuta automáticamente cuando pywal genera nuevos colores

THEME_SCRIPT="/usr/share/sddm/themes/sddm-astronaut-theme/pywal-sync.sh"

if [[ -f "$THEME_SCRIPT" ]]; then
    echo "Sincronizando tema SDDM con colores de pywal..."
    sudo "$THEME_SCRIPT" 2>/dev/null || {
        echo "Error: No se pudo actualizar el tema SDDM. Puede ser necesario ejecutar con sudo."
    }
else
    echo "Error: Script de sincronización no encontrado."
fi
EOF
    
    chmod +x "$hook_script"
    chown "$SUDO_USER:$SUDO_USER" "$hook_script"
    
    print_success "Hook de pywal creado en $hook_script"
}

setup_sudo_permissions() {
    print_status "Configurando permisos sudo para sincronización automática..."
    
    local sudoers_file="/etc/sudoers.d/sddm-pywal-sync"
    
    cat > "$sudoers_file" << EOF
# Permitir al usuario ejecutar el script de sincronización de SDDM sin contraseña
$SUDO_USER ALL=(root) NOPASSWD: /usr/share/sddm/themes/sddm-astronaut-theme/pywal-sync.sh
EOF
    
    chmod 440 "$sudoers_file"
    
    print_success "Permisos sudo configurados en $sudoers_file"
}

show_usage() {
    echo "Uso: $0 [install|sync|uninstall]"
    echo ""
    echo "Comandos:"
    echo "  install   - Instala el tema y configura la integración con pywal"
    echo "  sync      - Sincroniza el tema con el wallpaper actual"
    echo "  uninstall - Desinstala el tema y limpia la configuración"
    echo ""
    echo "Ejemplos:"
    echo "  sudo $0 install                    # Instalación completa"
    echo "  $0 sync                           # Solo sincronizar"
    echo "  $0 sync /path/to/wallpaper.jpg    # Sincronizar con wallpaper específico"
    echo "  sudo $0 uninstall                 # Desinstalar"
}

uninstall_theme() {
    print_status "Desinstalando tema..."
    
    # Remover tema
    if [[ -d "$SDDM_THEMES_DIR/$THEME_NAME" ]]; then
        rm -rf "$SDDM_THEMES_DIR/$THEME_NAME"
        print_success "Tema removido de $SDDM_THEMES_DIR/$THEME_NAME"
    fi
    
    # Remover configuración sudoers
    if [[ -f "/etc/sudoers.d/sddm-pywal-sync" ]]; then
        rm "/etc/sudoers.d/sddm-pywal-sync"
        print_success "Permisos sudo removidos"
    fi
    
    # Remover autostart (como usuario)
    if [[ -n "$SUDO_USER" ]]; then
        local autostart_file="/home/$SUDO_USER/.config/autostart/sddm-pywal-sync.desktop"
        local script_path="/home/$SUDO_USER/.local/bin/sddm-pywal-sync"
        
        [[ -f "$autostart_file" ]] && rm "$autostart_file"
        [[ -f "$script_path" ]] && rm "$script_path"
        
        # Remover hook
        local hook_script="/home/$SUDO_USER/.config/wal/hooks/sddm-sync.sh"
        [[ -f "$hook_script" ]] && rm "$hook_script"
        
        print_success "Scripts de usuario removidos"
    fi
    
    print_warning "Recuerda cambiar la configuración de SDDM manualmente si es necesario."
}

main() {
    echo "=== Instalador de integración pywal para tema SDDM astronaut ==="
    echo ""
    
    case "${1:-help}" in
        "install")
            check_requirements install
            install_theme
            configure_sddm
            setup_sudo_permissions
            create_autostart_script
            create_wallpaper_hook
            
            print_success "¡Instalación completada!"
            echo ""
            echo "Para usar:"
            echo "1. Reinicia SDDM: sudo systemctl restart sddm"
            echo "2. Cambia tu wallpaper con: wal -i /path/to/wallpaper.jpg"
            echo "3. O ejecuta manualmente: sudo /usr/share/sddm/themes/$THEME_NAME/pywal-sync.sh"
            ;;
        "sync")
            check_requirements
            if [[ -f "/usr/share/sddm/themes/$THEME_NAME/pywal-sync.sh" ]]; then
                # Si el tema está en /usr/share, puede requerir permisos de root para escribir archivos
                if [[ -w "/usr/share/sddm/themes/$THEME_NAME" ]] && [[ -w "/usr/share/sddm/themes/$THEME_NAME/Backgrounds" ]]; then
                    "/usr/share/sddm/themes/$THEME_NAME/pywal-sync.sh" "${2:-}"
                else
                    sudo "/usr/share/sddm/themes/$THEME_NAME/pywal-sync.sh" "${2:-}"
                fi
            elif [[ -f "$THEME_DIR/pywal-sync.sh" ]]; then
                "$THEME_DIR/pywal-sync.sh" "${2:-}"
            else
                print_error "Script de sincronización no encontrado."
                exit 1
            fi
            ;;
        "uninstall")
            uninstall_theme
            ;;
        *)
            show_usage
            ;;
    esac
}

main "$@"
