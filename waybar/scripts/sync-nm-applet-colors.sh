#!/bin/bash

# Script para sincronizar manualmente los colores de nm-applet con waybar
# Uso: ./sync-nm-applet-colors.sh

echo "🎨 Sincronizando colores de waybar con nm-applet..."

# Leer colores actuales de waybar
COLORS_FILE="$HOME/.config/waybar/colors-pywal.css"

if [[ ! -f "$COLORS_FILE" ]]; then
    echo "❌ Error: No se encontró el archivo de colores de waybar: $COLORS_FILE"
    exit 1
fi

# Extraer colores usando el script Python
echo "📝 Ejecutando sincronizador..."
python3 "$HOME/.config/waybar/scripts/waybar-colors-sync.py" &
sync_pid=$!

# Esperar un momento para que se complete la sincronización
sleep 2

# Terminar el daemon (solo queríamos la sincronización inicial)
kill $sync_pid 2>/dev/null

# Limpiar cache GTK
echo "🧹 Limpiando cache GTK..."
rm -rf ~/.cache/gtk-3.0 ~/.cache/gtk-4.0

# Reiniciar nm-applet
echo "🔄 Reiniciando nm-applet..."
pkill -f nm-applet
sleep 0.5
nm-applet & disown

echo "✅ Sincronización completada!"
echo "💡 Ahora nm-applet debería usar los colores de waybar al hacer clic"

# Mostrar colores actuales para verificación
echo
echo "🌈 Colores actuales detectados:"
grep -E '@define-color (background|foreground|color4)' "$COLORS_FILE" | sed 's/@define-color /  /' | sed 's/;$//'
