#!/bin/bash

# Script para establecer wallpaper desde Thunar/Dolphin
# Sincronizado con Pywal y el sistema

WALLPAPER_PATH="$1"

if [ -z "$WALLPAPER_PATH" ] || [ ! -f "$WALLPAPER_PATH" ]; then
    exit 1
fi

SELECTED=$(basename "$WALLPAPER_PATH")

notify-send "Aplicando Wallpaper" "$SELECTED"

# Aplicar con awww
if command -v awww &> /dev/null; then
    awww img "$WALLPAPER_PATH" --transition-type grow --transition-pos center --transition-duration 1.5 --transition-fps 60
fi

# Sincronizar colores
if command -v wal &> /dev/null; then
    wal -i "$WALLPAPER_PATH" -n -q
    
    [ -x "$HOME/.local/bin/sync-waybar-pywal" ] && "$HOME/.local/bin/sync-waybar-pywal"
    [ -x "$HOME/.local/bin/sync-mako-pywal" ] && "$HOME/.local/bin/sync-mako-pywal"
    [ -x "$HOME/.local/bin/sync-rofi-pywal" ] && "$HOME/.local/bin/sync-rofi-pywal"
    [ -x "$HOME/.local/bin/full-system-color-sync" ] && "$HOME/.local/bin/full-system-color-sync"
    
    hyprctl reload
    pkill waybar && nohup waybar > /dev/null 2>&1 &
fi

echo "$WALLPAPER_PATH" > "$HOME/.cache/current-wallpaper"
notify-send "Wallpaper actualizado" "$SELECTED"
