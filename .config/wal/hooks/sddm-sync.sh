#!/bin/bash
# Hook de pywal para sincronizar con SDDM
# Este script se ejecuta automáticamente cuando pywal genera nuevos colores

SYNC_SCRIPT="$HOME/.local/bin/sync-sddm-wallpaper"

if [[ -f "$SYNC_SCRIPT" ]]; then
    echo "Sincronizando tema SDDM con colores de pywal..."
    # Intentar ejecutar con sudo sin contraseña
    sudo "$SYNC_SCRIPT" 2>/dev/null || {
        echo "Error: No se pudo actualizar el tema SDDM. Asegúrate de configurar los permisos sudo NOPASSWD."
    }
else
    echo "Error: Script de sincronización no encontrado en $SYNC_SCRIPT"
fi
