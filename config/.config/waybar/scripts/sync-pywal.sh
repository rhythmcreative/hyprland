#!/bin/bash

# Script para sincronizar automáticamente Waybar con pywal
# Especialmente configurado para mantener el módulo privacy sincronizado

WAYBAR_DIR="$HOME/.config/waybar"
PYWAL_COLORS="$HOME/.cache/wal/colors-waybar.css"

# Función para copiar colores de pywal a waybar
sync_colors() {
    if [ -f "$PYWAL_COLORS" ]; then
        echo "Sincronizando colores de pywal..."
        cp "$PYWAL_COLORS" "$WAYBAR_DIR/colors-pywal.css"
        echo "Colores sincronizados correctamente."
    else
        echo "Error: No se encontró el archivo de colores de pywal en $PYWAL_COLORS"
        return 1
    fi
}

# Función para reiniciar waybar
restart_waybar() {
    echo "Reiniciando Waybar..."
    pkill waybar 2>/dev/null
    sleep 0.5
    waybar &
    disown
    echo "Waybar reiniciado."
}

# Función principal
main() {
    echo "=== Sync Waybar con Pywal ==="
    echo "Sincronizando módulo privacy y otros componentes..."
    
    # Sincronizar colores
    if sync_colors; then
        # Reiniciar waybar para aplicar cambios
        restart_waybar
        echo "✅ Sincronización completada. El módulo privacy de Waybar ahora usa los colores de pywal."
    else
        echo "❌ Error en la sincronización."
        exit 1
    fi
}

# Verificar si se debe ejecutar automáticamente
if [ "$1" = "--auto" ]; then
    # Modo automático (sin salida verbose para hooks)
    sync_colors > /dev/null 2>&1 && restart_waybar > /dev/null 2>&1
else
    # Modo manual con salida detallada
    main
fi
