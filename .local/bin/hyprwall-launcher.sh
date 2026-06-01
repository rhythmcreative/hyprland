#!/usr/bin/env bash
export PATH="$HOME/.local/bin:$PATH"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"

# Asegurar que el daemon de swww está corriendo
pgrep swww-daemon > /dev/null || swww-daemon --format xrgb &

# Ejecutar Quickshell con la versión corregida del selector
quickshell -p "/home/rhythmcreative/.config/quickshell/aino_v2"
