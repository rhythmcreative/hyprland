#!/bin/bash

# Obtener capacidad de ambas baterías
BAT0_CAPACITY=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "0")
BAT1_CAPACITY=$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo "0")

# Obtener estado de carga
BAT0_STATUS=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "Unknown")
BAT1_STATUS=$(cat /sys/class/power_supply/BAT1/status 2>/dev/null || echo "Unknown")

# Obtener energía actual y potencia para calcular tiempo restante
BAT0_ENERGY_NOW=$(cat /sys/class/power_supply/BAT0/energy_now 2>/dev/null || echo "0")
BAT0_POWER_NOW=$(cat /sys/class/power_supply/BAT0/power_now 2>/dev/null || echo "1")
BAT1_ENERGY_NOW=$(cat /sys/class/power_supply/BAT1/energy_now 2>/dev/null || echo "0")
BAT1_POWER_NOW=$(cat /sys/class/power_supply/BAT1/power_now 2>/dev/null || echo "1")

# Función para convertir tiempo en segundos a formato legible
format_time() {
    local seconds=$1
    if [[ $seconds -le 0 ]]; then
        echo "N/A"
        return
    fi
    
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    
    if [[ $hours -gt 0 ]]; then
        printf "%dh %02dm" $hours $minutes
    else
        printf "%dm" $minutes
    fi
}

# Calcular tiempo restante para cada batería (en segundos)
if [[ $BAT0_POWER_NOW -gt 0 ]] && [[ "$BAT0_STATUS" != "Charging" ]]; then
    BAT0_TIME_REMAINING=$((BAT0_ENERGY_NOW * 3600 / BAT0_POWER_NOW))
else
    BAT0_TIME_REMAINING=0
fi

if [[ $BAT1_POWER_NOW -gt 0 ]] && [[ "$BAT1_STATUS" != "Charging" ]]; then
    BAT1_TIME_REMAINING=$((BAT1_ENERGY_NOW * 3600 / BAT1_POWER_NOW))
else
    BAT1_TIME_REMAINING=0
fi

# Calcular tiempo promedio (si ambas baterías están descargándose)
if [[ $BAT0_TIME_REMAINING -gt 0 ]] && [[ $BAT1_TIME_REMAINING -gt 0 ]]; then
    TOTAL_TIME_REMAINING=$(((BAT0_TIME_REMAINING + BAT1_TIME_REMAINING) / 2))
elif [[ $BAT0_TIME_REMAINING -gt 0 ]]; then
    TOTAL_TIME_REMAINING=$BAT0_TIME_REMAINING
elif [[ $BAT1_TIME_REMAINING -gt 0 ]]; then
    TOTAL_TIME_REMAINING=$BAT1_TIME_REMAINING
else
    TOTAL_TIME_REMAINING=0
fi

# Función para obtener icono según capacidad
get_battery_icon() {
    local capacity=$1
    local status=$2
    
    if [[ "$status" == "Charging" ]]; then
        echo "󰂄"  # Nerd Font charging icon
    elif [[ $capacity -ge 80 ]]; then
        echo "󰁹"  # Nerd Font full battery
    elif [[ $capacity -ge 60 ]]; then
        echo "󰂀"  # Nerd Font 3/4 battery
    elif [[ $capacity -ge 40 ]]; then
        echo "󰁾"  # Nerd Font 1/2 battery
    elif [[ $capacity -ge 20 ]]; then
        echo "󰁼"  # Nerd Font 1/4 battery
    else
        echo "󰁺"  # Nerd Font empty battery
    fi
}

# Obtener iconos para ambas baterías
BAT0_ICON=$(get_battery_icon $BAT0_CAPACITY "$BAT0_STATUS")
BAT1_ICON=$(get_battery_icon $BAT1_CAPACITY "$BAT1_STATUS")

# Calcular capacidad total promedio
TOTAL_CAPACITY=$(( (BAT0_CAPACITY + BAT1_CAPACITY) / 2 ))

# Determinar clase CSS basada en el promedio
if [[ $TOTAL_CAPACITY -le 15 ]]; then
    CLASS="critical"
elif [[ $TOTAL_CAPACITY -le 30 ]]; then
    CLASS="warning"
else
    CLASS="normal"
fi

# Salida JSON para Waybar
TIME_FORMATTED=$(format_time $TOTAL_TIME_REMAINING)
echo "{\"text\":\"$BAT0_ICON ${BAT0_CAPACITY}% | $BAT1_ICON ${BAT1_CAPACITY}%\",\"tooltip\":\"Promedio de Batería: ${TOTAL_CAPACITY}%\\nTiempo restante: $TIME_FORMATTED\\nBatería Principal: ${BAT0_CAPACITY}% (${BAT0_STATUS})\\nBatería Secundaria: ${BAT1_CAPACITY}% (${BAT1_STATUS})\",\"class\":\"$CLASS\"}"
