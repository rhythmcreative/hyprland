#!/bin/bash

# Script para alternar entre tema original y variado de Waybar
# Mantiene el weather con color fijo en el tema variado

WAYBAR_DIR="$HOME/.config/waybar"
CACHE_DIR="$HOME/.cache/wal"
CURRENT_THEME_FILE="$WAYBAR_DIR/.current_theme"

# Función para mostrar ayuda
show_help() {
    echo "Uso: $0 [opciones]"
    echo "Opciones:"
    echo "  -h, --help     Mostrar esta ayuda"
    echo "  -s, --status   Mostrar tema actual"
    echo "  -r, --reload   Recargar waybar después de cambiar"
    echo "  -v, --verbose  Modo verbose"
    echo "  original       Forzar tema original"
    echo "  varied         Forzar tema variado"
    echo ""
    echo "Sin argumentos, alterna automáticamente entre temas."
}

# Variables por defecto
RELOAD_WAYBAR=true
VERBOSE=false
FORCE_THEME=""

# Procesar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -s|--status)
            if [[ -f "$CURRENT_THEME_FILE" ]]; then
                current=$(cat "$CURRENT_THEME_FILE")
                echo "Tema actual: $current"
            else
                echo "Tema actual: original (por defecto)"
            fi
            exit 0
            ;;
        -r|--reload)
            RELOAD_WAYBAR=true
            shift
            ;;
        --no-reload)
            RELOAD_WAYBAR=false
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        original)
            FORCE_THEME="original"
            shift
            ;;
        varied)
            FORCE_THEME="varied"
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

# Determinar tema actual
if [[ -f "$CURRENT_THEME_FILE" ]]; then
    current_theme=$(cat "$CURRENT_THEME_FILE")
else
    current_theme="original"
fi

log "Tema actual: $current_theme"

# Determinar próximo tema
if [[ -n "$FORCE_THEME" ]]; then
    next_theme="$FORCE_THEME"
elif [[ "$current_theme" == "varied" ]]; then
    next_theme="original"
else
    next_theme="varied"
fi

log "Cambiando a tema: $next_theme"

# Crear backup antes del cambio
if [[ -f "$WAYBAR_DIR/style.css" ]]; then
    backup_file="$WAYBAR_DIR/style.css.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$WAYBAR_DIR/style.css" "$backup_file"
    log "Backup creado: $backup_file"
fi

# Aplicar tema
case "$next_theme" in
    "original")
        if [[ -f "$CACHE_DIR/waybar-style.css" ]]; then
            cp "$CACHE_DIR/waybar-style.css" "$WAYBAR_DIR/style.css"
            echo "original" > "$CURRENT_THEME_FILE"
            echo "✅ Tema original aplicado"
            log "Usando template original de pywal"
        else
            echo "❌ Error: No se encontró waybar-style.css"
            exit 1
        fi
        ;;
    "varied")
        if [[ -f "$CACHE_DIR/waybar-style-varied.css" ]]; then
            cp "$CACHE_DIR/waybar-style-varied.css" "$WAYBAR_DIR/style.css"
            echo "varied" > "$CURRENT_THEME_FILE"
            echo "✅ Tema variado aplicado (weather mantiene color fijo)"
            log "Usando template variado de pywal"
            
            if [[ "$VERBOSE" == true ]]; then
                echo ""
                echo "🎨 Distribución de colores variados:"
                echo "  🔲 CPU: color1    🧠 Memory: color5"
                echo "  🕐 Clock: color4  🔊 Audio: color3"
                echo "  💡 Brightness: color6  🌡️ Temp: color2/color3"
                echo "  🌤️ Weather: #94e2d5 (fijo)"
                echo ""
            fi
        else
            echo "❌ Error: No se encontró waybar-style-varied.css"
            echo "Ejecuta 'wal -R -t' primero para generar los templates"
            exit 1
        fi
        ;;
esac

# Recargar waybar
if [[ "$RELOAD_WAYBAR" == true ]]; then
    log "Recargando waybar..."
    
    if pgrep -x waybar > /dev/null; then
        pkill waybar
        sleep 0.3
    fi
    
    nohup waybar > /dev/null 2>&1 &
    
    if [[ $? -eq 0 ]]; then
        echo "✅ Waybar recargado correctamente"
    else
        echo "⚠️  Warning: Error al recargar waybar"
    fi
fi

log "Cambio de tema completado"
