#!/bin/bash

# Select a random wallpaper from the Wallpapers directory
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
WALLPAPER=$(find "$WALLPAPER_DIR" -type f | shuf -n 1)

swww img "$WALLPAPER" --transition-type grow --transition-pos 0.8,0.9 --transition-step 90 --transition-fps 60
wal -i "$WALLPAPER" -a 85
