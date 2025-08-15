#!/bin/bash

# Script para aplicar tema variado de Waybar con pywal
# Mantiene el módulo weather con su color original

# Función para mostrar ayuda
show_help() {
    echo "Uso: $0 [opciones]"
    echo "Opciones:"
    echo "  -h, --help     Mostrar esta ayuda"
    echo "  -r, --reload   Recargar waybar después de aplicar el tema"
    echo "  -v, --verbose  Modo verbose"
    echo ""
    echo "Este script aplica un tema variado de colores pywal a waybar"
    echo "manteniendo el módulo weather con su color original."
}

# Variables por defecto
RELOAD_WAYBAR=false
VERBOSE=false

# Procesar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -r|--reload)
            RELOAD_WAYBAR=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Opción desconocida: $1"
            show_help
            exit 1
            ;;
    esac
done

# Función de log
log() {
    if [[ "$VERBOSE" == true ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    fi
}

# Directorios
WAL_DIR="$HOME/.cache/wal"
WAYBAR_DIR="$HOME/.config/waybar"
TEMPLATES_DIR="$HOME/.config/wal/templates"

log "Iniciando aplicación de tema variado de waybar..."

# Verificar que existe el archivo de colores de pywal
if [[ ! -f "$WAL_DIR/colors" ]]; then
    echo "Error: No se encontraron colores de pywal en $WAL_DIR/colors"
    echo "Ejecuta 'wal' primero para generar los colores."
    exit 1
fi

# Verificar que existe el template variado
if [[ ! -f "$TEMPLATES_DIR/waybar-style-varied.css" ]]; then
    echo "Error: No se encontró el template waybar-style-varied.css"
    echo "Archivo esperado: $TEMPLATES_DIR/waybar-style-varied.css"
    exit 1
fi

log "Archivos necesarios encontrados"

# Crear backup del estilo actual si existe
if [[ -f "$WAYBAR_DIR/style.css" ]]; then
    backup_file="$WAYBAR_DIR/style.css.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$WAYBAR_DIR/style.css" "$backup_file"
    log "Backup creado: $backup_file"
fi

# Aplicar el nuevo template usando wal
log "Generando nuevo CSS variado usando pywal..."

# Usar wal para generar el CSS desde el template
wal -R -t

# Verificar si se generó el archivo CSS variado
if [[ -f "$WAL_DIR/waybar-style-varied.css" ]]; then
    log "CSS variado generado correctamente"
    
    # Copiar el CSS generado a la configuración de waybar
    cp "$WAL_DIR/waybar-style-varied.css" "$WAYBAR_DIR/style.css"
    log "CSS aplicado a waybar"
    
    echo "✅ Tema variado aplicado correctamente"
    
    # Mostrar distribución de colores
    if [[ "$VERBOSE" == true ]]; then
        echo ""
        echo "=== Distribución de colores ==="
        echo "🔲 CPU: color1 ($(sed -n '2p' "$WAL_DIR/colors"))"
        echo "🧠 Memory: color5 ($(sed -n '6p' "$WAL_DIR/colors"))"
        echo "🕐 Clock: color4 ($(sed -n '5p' "$WAL_DIR/colors"))"
        echo "🔊 Audio: color3 ($(sed -n '4p' "$WAL_DIR/colors"))"
        echo "💡 Backlight: color6 ($(sed -n '7p' "$WAL_DIR/colors"))"
        echo "🌡️ Temp CPU: color3 ($(sed -n '4p' "$WAL_DIR/colors"))"
        echo "🌡️ Temp Package: color2 ($(sed -n '3p' "$WAL_DIR/colors"))"
        echo "📶 Bluetooth: color8/color2/color6"
        echo "🌤️ Weather: #94e2d5 (color fijo)"
        echo ""
    fi
    
else
    echo "❌ Error: No se pudo generar el CSS variado"
    exit 1
fi

# Recargar waybar si se solicitó
if [[ "$RELOAD_WAYBAR" == true ]]; then
    log "Recargando waybar..."
    
    if pgrep -x waybar > /dev/null; then
        pkill waybar
        sleep 1
    fi
    
    # Intentar ejecutar waybar en segundo plano
    nohup waybar > /dev/null 2>&1 &
    
    if [[ $? -eq 0 ]]; then
        echo "✅ Waybar recargado correctamente"
    else
        echo "⚠️  Warning: Error al recargar waybar"
    fi
fi

log "Script completado"
