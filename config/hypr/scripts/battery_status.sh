#!/bin/bash

# Script para mostrar estado de batería en hyprlock

BATTERY_PATH="/sys/class/power_supply/BAT0"

# Verificar si existe la batería
if [[ -f "$BATTERY_PATH/capacity" ]]; then
    capacity=$(cat "$BATTERY_PATH/capacity")
    status=$(cat "$BATTERY_PATH/status")
    
    # Seleccionar ícono según nivel de batería
    if [[ $capacity -ge 90 ]]; then
        icon="🔋"
    elif [[ $capacity -ge 75 ]]; then
        icon="🔋"
    elif [[ $capacity -ge 50 ]]; then
        icon="🔋"
    elif [[ $capacity -ge 25 ]]; then
        icon="🪫"
    else
        icon="🪫"
    fi
    
    # Añadir indicador de carga
    if [[ "$status" == "Charging" ]]; then
        icon="⚡"
    fi
    
    echo "$icon $capacity%"
else
    # No hay batería (PC de escritorio)
    echo ""
fi
