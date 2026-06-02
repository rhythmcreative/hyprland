#!/bin/bash

# Script de demostración para la integración de pywal con SDDM astronaut theme
# Autor: rhythmcreative

# Detectar dinámicamente el directorio del tema
THEME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Demo de integración Pywal + SDDM Astronaut Theme ==="
echo ""

# Función para mostrar paso a paso
show_step() {
    echo -e "\n🚀 $1"
    echo "----------------------------------------"
}

# Función para confirmar antes de continuar
confirm() {
    read -p "Presiona Enter para continuar..."
}

show_step "Paso 1: Verificando estado del sistema"

echo "Directorio actual del tema: $THEME_DIR"
echo "Scripts disponibles:"
ls -la *.sh

echo ""
echo "Estado de pywal:"
if command -v wal >/dev/null 2>&1; then
    echo "✅ pywal está instalado"
    wal_version=$(wal --version 2>/dev/null | head -1)
    echo "   Versión: $wal_version"
    
    if [[ -f ~/.cache/wal/colors ]]; then
        echo "✅ Colores de pywal disponibles"
        echo "   Archivo: ~/.cache/wal/colors"
        echo "   Wallpaper actual: $(cat ~/.cache/wal/wal 2>/dev/null || echo 'No detectado')"
    else
        echo "⚠️  No hay colores de pywal generados"
    fi
else
    echo "❌ pywal no está instalado"
    echo "   Para instalar en Arch: sudo pacman -S python-pywal"
fi

echo ""
echo "Estado de ImageMagick:"
if command -v convert >/dev/null 2>&1; then
    echo "✅ ImageMagick está instalado"
else
    echo "⚠️  ImageMagick no está instalado (opcional)"
    echo "   Para instalar en Arch: sudo pacman -S imagemagick"
fi

confirm

show_step "Paso 2: Probando detección de wallpaper"

echo "Intentando detectar wallpaper actual..."
echo ""

# Simular la función de detección
detect_wallpaper() {
    local wallpaper=""
    
    echo "Métodos de detección probados:"
    
    # Nitrogen
    if command -v nitrogen >/dev/null 2>&1; then
        wallpaper=$(grep "file=" ~/.config/nitrogen/bg-saved.cfg 2>/dev/null | head -n1 | cut -d'=' -f2-)
        if [[ -n "$wallpaper" ]]; then
            echo "✅ nitrogen: $wallpaper"
            echo "$wallpaper"
            return
        else
            echo "❌ nitrogen: no configurado"
        fi
    else
        echo "❌ nitrogen: no instalado"
    fi
    
    # feh
    if command -v feh >/dev/null 2>&1; then
        wallpaper=$(cat ~/.fehbg 2>/dev/null | grep -o "'[^']*'" | head -n1 | tr -d "'")
        if [[ -n "$wallpaper" ]]; then
            echo "✅ feh: $wallpaper"
            echo "$wallpaper"
            return
        else
            echo "❌ feh: no configurado"
        fi
    else
        echo "❌ feh: no instalado"
    fi
    
    # gsettings (GNOME)
    if command -v gsettings >/dev/null 2>&1; then
        wallpaper=$(gsettings get org.gnome.desktop.background picture-uri 2>/dev/null | tr -d "'" | sed 's|file://||')
        if [[ -n "$wallpaper" ]] && [[ "$wallpaper" != "none" ]]; then
            echo "✅ gsettings (GNOME): $wallpaper"
            echo "$wallpaper"
            return
        else
            echo "❌ gsettings: no configurado o no es GNOME"
        fi
    else
        echo "❌ gsettings: no instalado"
    fi
    
    # pywal cache
    if [[ -f ~/.cache/wal/wal ]]; then
        wallpaper=$(cat ~/.cache/wal/wal)
        echo "✅ pywal cache: $wallpaper"
        echo "$wallpaper"
        return
    else
        echo "❌ pywal cache: no existe"
    fi
    
    echo ""
    echo "❌ No se pudo detectar wallpaper automáticamente"
}

current_wallpaper=$(detect_wallpaper)

if [[ -z "$current_wallpaper" ]]; then
    echo ""
    echo "Para continuar el demo, por favor especifica un wallpaper:"
    read -p "Ruta completa al wallpaper (o Enter para usar imagen de ejemplo): " user_wallpaper
    
    if [[ -n "$user_wallpaper" ]] && [[ -f "$user_wallpaper" ]]; then
        current_wallpaper="$user_wallpaper"
    elif [[ -f "$THEME_DIR/Backgrounds/bg.png" ]]; then
        current_wallpaper="$THEME_DIR/Backgrounds/bg.png"
        echo "Usando imagen de ejemplo del tema"
    else
        echo "❌ No se puede continuar sin una imagen válida"
        exit 1
    fi
fi

echo ""
echo "Wallpaper seleccionado: $current_wallpaper"

confirm

show_step "Paso 3: Generando colores con pywal (si está instalado)"

if command -v wal >/dev/null 2>&1; then
    echo "Generando paleta de colores..."
    wal -i "$current_wallpaper" -n
    
    if [[ -f ~/.cache/wal/colors ]]; then
        echo "✅ Colores generados exitosamente:"
        echo ""
        cat -n ~/.cache/wal/colors | head -8
        echo "..."
        echo ""
        
        # Mostrar algunos colores de ejemplo
        colors=($(cat ~/.cache/wal/colors))
        echo "Colores para el tema:"
        echo "  Background: ${colors[0]}"
        echo "  Highlight:  ${colors[1]}"
        echo "  Text:       ${colors[15]}"
    fi
else
    echo "⚠️  pywal no está disponible, usando colores por defecto"
fi

confirm

show_step "Paso 4: Ejecutando sincronización de prueba"

echo "Ejecutando script de sincronización..."
echo ""

if [[ -f "$THEME_DIR/pywal-sync.sh" ]]; then
    bash "$THEME_DIR/pywal-sync.sh" "$current_wallpaper"
    sync_result=$?
    
    if [[ $sync_result -eq 0 ]]; then
        echo ""
        echo "✅ Sincronización completada exitosamente"
        
        echo ""
        echo "Archivos generados:"
        echo "  📄 theme.conf: $(ls -la theme.conf 2>/dev/null | awk '{print $5" bytes"}' || echo 'No encontrado')"
        echo "  🖼️  Background procesado: $(ls -la Backgrounds/processed/current_bg_80_50.png 2>/dev/null | awk '{print $5" bytes"}' || echo 'No encontrado')"
        
        if [[ -f "theme.conf" ]]; then
            echo ""
            echo "Vista previa de la configuración generada:"
            echo "----------------------------------------"
            grep -E "(Background|HighlightColor|TextColor|BackgroundColor)" theme.conf | head -5
            echo "----------------------------------------"
        fi
    else
        echo "❌ Error en la sincronización"
    fi
else
    echo "❌ Script de sincronización no encontrado"
fi

confirm

show_step "Paso 5: Instrucciones de instalación"

echo "Para instalar completamente el tema con integración pywal:"
echo ""
echo "1. Instalación automática (recomendada):"
echo "   sudo ./install-pywal-integration.sh install"
echo ""
echo "2. O instalación manual:"
echo "   sudo cp -r . /usr/share/sddm/themes/sddm-astronaut-theme"
echo "   sudo systemctl restart sddm"
echo ""
echo "3. Para probar solo la sincronización:"
echo "   ./install-pywal-integration.sh sync"
echo ""
echo "4. Para usar con un wallpaper específico:"
echo "   ./pywal-sync.sh /ruta/al/wallpaper.jpg"
echo ""

show_step "Demo completado"

echo "✅ El demo ha terminado exitosamente"
echo ""
echo "Tu tema está listo para usar con pywal!"
echo "Los archivos generados están en:"
echo "  - theme.conf (configuración del tema)"
echo "  - Backgrounds/processed/ (backgrounds procesados)"
echo ""
echo "¿Quieres instalar el tema ahora?"
read -p "(y/N): " install_now

if [[ "$install_now" =~ ^[Yy]$ ]]; then
    echo ""
    echo "Ejecutando instalación..."
    sudo ./install-pywal-integration.sh install
else
    echo ""
    echo "Puedes instalarlo más tarde con:"
    echo "sudo ./install-pywal-integration.sh install"
fi

echo ""
echo "¡Gracias por probar la integración pywal + SDDM! 🚀"
