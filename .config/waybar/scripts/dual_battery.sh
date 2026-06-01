#!/bin/bash

# Obtener capacidad de ambas baterías
BAT0_CAPACITY=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "0")
BAT1_CAPACITY=$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo "0")

# Obtener estado de carga
BAT0_STATUS=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "Unknown")
BAT1_STATUS=$(cat /sys/class/power_supply/BAT1/status 2>/dev/null || echo "Unknown")

# Obtener energía actual y potencia para calcular tiempo restante
BAT0_ENERGY_NOW=$(cat /sys/class/power_supply/BAT0/energy_now 2>/dev/null || echo "0")
BAT0_ENERGY_FULL=$(cat /sys/class/power_supply/BAT0/energy_full 2>/dev/null || echo "0")
BAT0_POWER_NOW=$(cat /sys/class/power_supply/BAT0/power_now 2>/dev/null || echo "1")

BAT1_ENERGY_NOW=$(cat /sys/class/power_supply/BAT1/energy_now 2>/dev/null || echo "0")
BAT1_ENERGY_FULL=$(cat /sys/class/power_supply/BAT1/energy_full 2>/dev/null || echo "0")
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

# Calcular tiempo restante total
TOTAL_ENERGY_NOW=$((BAT0_ENERGY_NOW + BAT1_ENERGY_NOW))
TOTAL_POWER_NOW=$((BAT0_POWER_NOW + BAT1_POWER_NOW))

if [[ $TOTAL_POWER_NOW -gt 0 ]] && [[ "$BAT0_STATUS" != "Charging" ]] && [[ "$BAT1_STATUS" != "Charging" ]]; then
    TOTAL_TIME_REMAINING=$((TOTAL_ENERGY_NOW * 3600 / TOTAL_POWER_NOW))
else
    TOTAL_TIME_REMAINING=0
fi

# Función para obtener icono según capacidad (versión vertical)
get_battery_icon() {
    local capacity=$1
    local status=$2
    
    if [[ "$status" == "Charging" ]]; then
        echo "󰂄"
    elif [[ $capacity -ge 80 ]]; then
        echo "󰂂"
    elif [[ $capacity -ge 60 ]]; then
        echo "󰂁"
    elif [[ $capacity -ge 40 ]]; then
        echo "󰂀"  
    elif [[ $capacity -ge 20 ]]; then
        echo "󰁿"
    else
        echo "󰁺"
    fi
}

# Calcular capacidad combinada real
TOTAL_ENERGY_FULL=$((BAT0_ENERGY_FULL + BAT1_ENERGY_FULL))
if [[ $TOTAL_ENERGY_FULL -gt 0 ]]; then
    TOTAL_CAPACITY=$(( TOTAL_ENERGY_NOW * 100 / TOTAL_ENERGY_FULL ))
else
    TOTAL_CAPACITY=$(( (BAT0_CAPACITY + BAT1_CAPACITY) / 2 ))
fi

# Determinar estado combinado
if [[ "$BAT0_STATUS" == "Charging" ]] || [[ "$BAT1_STATUS" == "Charging" ]]; then
    TOTAL_STATUS="Cargando"
    COMBINED_ICON="󰂄"
elif [[ "$BAT0_STATUS" == "Full" ]] && [[ "$BAT1_STATUS" == "Full" ]]; then
    TOTAL_STATUS="Llena"
    COMBINED_ICON="󰁹"
else
    TOTAL_STATUS="Descargando"
    COMBINED_ICON=$(get_battery_icon $TOTAL_CAPACITY "Discharging")
fi

# Determinar clase CSS
if [[ $TOTAL_CAPACITY -le 15 ]]; then
    CLASS="critical"
elif [[ $TOTAL_CAPACITY -le 30 ]]; then
    CLASS="warning"
else
    CLASS="normal"
fi

# Salida JSON para Waybar
TIME_FORMATTED=$(format_time $TOTAL_TIME_REMAINING)
TOOLTIP="Total: ${TOTAL_CAPACITY}% ($TOTAL_STATUS)\\n"
TOOLTIP+="BAT0: ${BAT0_CAPACITY}% (${BAT0_STATUS})\\n"
TOOLTIP+="BAT1: ${BAT1_CAPACITY}% (${BAT1_STATUS})\\n"
TOOLTIP+="Tiempo restante: $TIME_FORMATTED"

echo "{\"text\":\"$COMBINED_ICON ${TOTAL_CAPACITY}%\",\"tooltip\":\"$TOOLTIP\",\"class\":\"$CLASS\"}"

