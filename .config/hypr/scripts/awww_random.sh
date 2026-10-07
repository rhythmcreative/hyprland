#!/bin/bash

if [ -x "$HOME/.local/bin/wallpaper-random" ]; then
    exec "$HOME/.local/bin/wallpaper-random"
fi

# Select a random wallpaper from the Wallpapers directory
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
[ -d "$WALLPAPER_DIR" ] || WALLPAPER_DIR="$HOME/.config/hypr/wallpapers"
[ -d "$WALLPAPER_DIR" ] || exit 0

WALLPAPER=$(find "$WALLPAPER_DIR" -type f -regex ".*\.\(jpg\|jpeg\|png\|gif\|webp\)" 2>/dev/null | shuf -n 1)
[ -n "$WALLPAPER" ] && [ -f "$WALLPAPER" ] || exit 0

if command -v awww >/dev/null 2>&1; then
    awww img "$WALLPAPER" --transition-type grow --transition-pos 0.8,0.9 --transition-duration 1.5
elif command -v swww >/dev/null 2>&1; then
    swww img "$WALLPAPER" --transition-type grow --transition-pos 0.8,0.9 --transition-step 90 --transition-fps 60
fi

if command -v wal >/dev/null 2>&1; then
    wal -i "$WALLPAPER" -n -q
fi
