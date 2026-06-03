#!/bin/bash

# auto-battery-setup.sh - Detección y configuración automática de energía para Waybar
# Este script configura Waybar según si el equipo es un PC de sobremesa, 
# una laptop estándar o un ThinkPad con doble batería.

CONFIG="$HOME/.config/waybar/config"
BATS=(/sys/class/power_supply/BAT*)
NUM_BATS=${#BATS[@]}

# Asegurar que el archivo de configuración existe
if [ ! -f "$CONFIG" ]; then
    exit 1
fi

# 1. Limpiar módulos de energía existentes en modules-right
# Eliminamos battery, battery#bat0, battery#bat1 y custom/desktop-power
CLEAN_CONFIG=$(jq '.["modules-right"] |= map(select(. != "battery" and . != "battery#bat0" and . != "battery#bat1" and . != "custom/desktop-power"))' "$CONFIG")

if [ "$NUM_BATS" -ge 2 ]; then
    # MODO DUAL (ThinkPad) - Módulos pegados
    FINAL_CONFIG=$(echo "$CLEAN_CONFIG" | jq '.["modules-right"] += ["battery#bat0", "battery#bat1"]')
elif [ "$NUM_BATS" -eq 1 ]; then
    # MODO SIMPLE (Laptop normal)
    FINAL_CONFIG=$(echo "$CLEAN_CONFIG" | jq '.["modules-right"] += ["battery"]')
else
    # MODO ESCRITORIO (PC)
    FINAL_CONFIG=$(echo "$CLEAN_CONFIG" | jq '.["modules-right"] += ["custom/desktop-power"]')
fi

# Guardar y recargar
echo "$FINAL_CONFIG" > "$CONFIG"
pkill -SIGUSR2 waybar || true
