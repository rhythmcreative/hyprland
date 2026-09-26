#!/bin/bash

# Script para establecer wallpaper desde Thunar/Dolphin
# Sincronizado con Pywal y el sistema

WALLPAPER_PATH="$1"

if [ -z "$WALLPAPER_PATH" ] || [ ! -f "$WALLPAPER_PATH" ]; then
    exit 1
fi

SELECTED=$(basename "$WALLPAPER_PATH")

# Aplicar wallpaper con animacion sincronizada de waybar, quickshell y rust-dock
if [ -x "$HOME/.local/bin/sync-wallpaper-animation" ]; then
    "$HOME/.local/bin/sync-wallpaper-animation" "$WALLPAPER_PATH"
else
    if command -v awww &> /dev/null; then
        awww img "$WALLPAPER_PATH" --transition-type grow --transition-pos center --transition-duration 1.5 --transition-fps 60
    fi
    if command -v wal &> /dev/null; then
        wal -i "$WALLPAPER_PATH" -n -q
        "$HOME/.local/bin/modern-pywal-sync"
    fi
    echo "$WALLPAPER_PATH" > "$HOME/.cache/current-wallpaper"
fi
