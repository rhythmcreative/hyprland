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
