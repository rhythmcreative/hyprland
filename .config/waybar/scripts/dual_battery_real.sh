#!/bin/bash

# Dual Battery Script (Dynamic Detection)
# Soporta sistemas con 1 o 2 baterías (Thinkpad, ASUS, etc.)

# Detectar baterías disponibles
BATS=(/sys/class/power_supply/BAT*)
NUM_BATS=${#BATS[@]}

get_battery_icon() {
    local capacity=$1
    local status=$2
    if [[ "$status" == "Charging" ]]; then echo "󰂄";
    elif [[ $capacity -ge 95 ]]; then echo "󰁹";
    elif [[ $capacity -ge 80 ]]; then echo "󰂂";
    elif [[ $capacity -ge 60 ]]; then echo "󰂁";
    elif [[ $capacity -ge 40 ]]; then echo "󰂀";
    elif [[ $capacity -ge 20 ]]; then echo "󰁿";
    else echo "󰁺"; fi
}

if [ "$NUM_BATS" -eq 0 ]; then
    echo "{\"text\":\"No Bat\",\"tooltip\":\"No se detectaron baterías\",\"class\":\"critical\"}"
    exit 0
fi

# Procesar Batería 1
BAT0_NAME=$(basename "${BATS[0]}")
BAT0_CAP=$(cat "${BATS[0]}/capacity" 2>/dev/null || echo "0")
BAT0_STAT=$(cat "${BATS[0]}/status" 2>/dev/null || echo "Unknown")
BAT0_ICON=$(get_battery_icon "$BAT0_CAP" "$BAT0_STAT")

if [ "$NUM_BATS" -ge 2 ]; then
    # Sistema de Doble Batería
    BAT1_NAME=$(basename "${BATS[1]}")
    BAT1_CAP=$(cat "${BATS[1]}/capacity" 2>/dev/null || echo "0")
    BAT1_STAT=$(cat "${BATS[1]}/status" 2>/dev/null || echo "Unknown")
    BAT1_ICON=$(get_battery_icon "$BAT1_CAP" "$BAT1_STAT")
    
    # Calcular promedio o total real
    # Para simplicidad en el icono central usamos el promedio
    TOTAL_CAP=$(( (BAT0_CAP + BAT1_CAP) / 2 ))
    
    TEXT="$BAT0_ICON ${BAT0_CAP}% | $BAT1_ICON ${BAT1_CAP}%"
    TOOLTIP="Estado Dual:\\n$BAT0_NAME: ${BAT0_CAP}% ($BAT0_STAT)\\n$BAT1_NAME: ${BAT1_CAP}% ($BAT1_STAT)"
else
    # Sistema de Batería Única
    TOTAL_CAP=$BAT0_CAP
    TEXT="$BAT0_ICON ${BAT0_CAP}%"
    TOOLTIP="$BAT0_NAME: ${BAT0_CAP}% ($BAT0_STAT)"
fi

# Clase CSS
if [ "$TOTAL_CAP" -le 15 ]; then CLASS="critical";
elif [ "$TOTAL_CAP" -le 30 ]; then CLASS="warning";
else CLASS="normal"; fi

echo "{\"text\":\"$TEXT\",\"tooltip\":\"$TOOLTIP\",\"class\":\"$CLASS\"}"
