#!/bin/bash

# Script para sincronizar LibreWolf con pywal
# Se ejecuta automáticamente cuando pywal genera nuevos colores

# Directorio del perfil de LibreWolf
PROFILE_DIR="$HOME/.librewolf/gf51229j.default-default"
CHROME_DIR="$PROFILE_DIR/chrome"

# Crear directorio chrome si no existe
mkdir -p "$CHROME_DIR"

# Copiar los templates compilados por pywal
if [ -f "$HOME/.cache/wal/librewolf-userChrome.css" ]; then
    cp "$HOME/.cache/wal/librewolf-userChrome.css" "$CHROME_DIR/userChrome.css"
    echo "✓ LibreWolf userChrome.css actualizado con pywal"
fi

if [ -f "$HOME/.cache/wal/librewolf-userContent.css" ]; then
    cp "$HOME/.cache/wal/librewolf-userContent.css" "$CHROME_DIR/userContent.css"
    echo "✓ LibreWolf userContent.css actualizado con pywal"
fi

# Comprobar si LibreWolf está corriendo y sugerir reinicio
if pgrep -x "librewolf" > /dev/null; then
    echo "⚠️  LibreWolf está ejecutándose. Reinicia el navegador para ver los cambios."
else
    echo "✓ Sincronización completa. Los cambios se aplicarán al abrir LibreWolf."
fi
