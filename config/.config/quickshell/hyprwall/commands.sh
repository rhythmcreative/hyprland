#!/bin/bash
# hyprwall/commands.sh - Sincronización completa con Pywal y Hardware

WALLPAPER_PATH="$1"

if [ -z "$WALLPAPER_PATH" ] || [ ! -f "$WALLPAPER_PATH" ]; then
    exit 1
fi

SELECTED=$(basename "$WALLPAPER_PATH")

# 1. Notificar inicio
notify-send "🎨 Aplicando Wallpaper" "$SELECTED" -t 2000

# 2. Aplicar Wallpaper (swww/awww)
if command -v awww &> /dev/null; then
    awww img "$WALLPAPER_PATH" --transition-type grow --transition-pos "0.9,0.1" --transition-duration 1.5
elif command -v swww &> /dev/null; then
    swww img "$WALLPAPER_PATH" --transition-type grow --transition-pos "0.9,0.1" --transition-duration 1.5
fi

# 3. Sincronizar colores con Pywal
if command -v wal &> /dev/null; then
    wal -i "$WALLPAPER_PATH" -n -q
    
    # 4. Sincronización de componentes de Software
    [ -x "$HOME/.local/bin/sync-waybar-pywal" ] && "$HOME/.local/bin/sync-waybar-pywal"
    [ -x "$HOME/.local/bin/sync-mako-pywal" ] && "$HOME/.local/bin/sync-mako-pywal"
    [ -x "$HOME/.local/bin/sync-rofi-pywal" ] && "$HOME/.local/bin/sync-rofi-pywal"
    
    # 5. Sincronización de Hardware (Teclado ASUS)
    if [[ -x "$HOME/.local/bin/pywal-asusctl-sync" ]]; then
        "$HOME/.local/bin/pywal-asusctl-sync" &
    fi

    # 6. Recarga de Entorno
    hyprctl reload >/dev/null 2>&1 &
    
    # 7. Reiniciar Waybar para aplicar CSS de pywal
    pkill -KILL waybar 2>/dev/null
    nohup waybar > /dev/null 2>&1 &
fi

# 8. Guardar cache del wallpaper actual
echo "$WALLPAPER_PATH" > "$HOME/.cache/current-wallpaper"

notify-send "✅ Sistema Sincronizado" "Tema aplicado correctamente" -t 2000
