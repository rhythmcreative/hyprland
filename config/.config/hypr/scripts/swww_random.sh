#!/bin/bash

# Select a random wallpaper from the Wallpapers directory
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
WALLPAPER=$(find "$WALLPAPER_DIR" -type f -regex ".*\.\(jpg\|jpeg\|png\|gif\|webp\)" | shuf -n 1)

if command -v awww >/dev/null 2>&1; then
    awww img "$WALLPAPER" --transition-type grow --transition-pos 0.8,0.9 --transition-duration 1.5
else
    swww img "$WALLPAPER" --transition-type grow --transition-pos 0.8,0.9 --transition-step 90 --transition-fps 60
fi

if command -v wal >/dev/null 2>&1; then
    wal -i "$WALLPAPER" -n -q
fi
