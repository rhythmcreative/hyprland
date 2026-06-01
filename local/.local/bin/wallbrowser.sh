#!/bin/bash

# Explorador Interactivo de Wallpapers
# Abre Thunar en la carpeta de wallpapers con vista de iconos

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

# Abrir Thunar en el directorio de wallpapers
thunar "$WALLPAPER_DIR" &
