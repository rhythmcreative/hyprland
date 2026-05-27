#!/bin/bash

# Script para obtener la temperatura de CPU con información detallada

# Obtener temperatura del CPU Package (el mismo sensor que tenías configurado)
cpu_temp_raw=$(cat /sys/class/hwmon/hwmon7/temp1_input 2>/dev/null)
if [ -z "$cpu_temp_raw" ]; then
    # Alternativa con hwmon4 si hwmon7 no funciona
    cpu_temp_raw=$(cat /sys/class/hwmon/hwmon4/temp1_input 2>/dev/null)
fi

if [ ! -z "$cpu_temp_raw" ]; then
    cpu_temp=$(echo "$cpu_temp_raw" | awk '{print int($1/1000)}')
    
    # Determinar el ícono y clase según la temperatura
    if [ $cpu_temp -ge 85 ]; then
        icon="󰸁"
        class="cpu-critical"
        tooltip="🚨 CPU Temperature CRITICAL: ${cpu_temp}°C"
    elif [ $cpu_temp -ge 70 ]; then
        icon="󰔏"
        class="cpu-hot"
        tooltip="⚠️  CPU Temperature HIGH: ${cpu_temp}°C"
    else
        icon="󰔏"
        class="cpu-normal"
        tooltip="CPU Temperature: ${cpu_temp}°C"
    fi
    
    echo "{\"text\":\"${icon} ${cpu_temp}°C\", \"tooltip\":\"${tooltip}\", \"class\":\"${class}\"}"
else
    echo "{\"text\":\"󰔏 N/A\", \"tooltip\":\"CPU Temperature not available\", \"class\":\"cpu-error\"}"
fi
