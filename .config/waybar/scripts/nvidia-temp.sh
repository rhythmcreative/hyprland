#!/bin/bash

# Obtener temperatura de GPU NVIDIA
temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null)

# Verificar si el comando fue exitoso
if [ $? -eq 0 ] && [ ! -z "$temp" ]; then
    # Determinar clase CSS basada en la temperatura
    if [ "$temp" -ge 90 ]; then
        class="critical"
    elif [ "$temp" -ge 80 ]; then
        class="warning"
    else
        class="normal"
    fi
    
    # Formato JSON para Waybar
    echo "{\"text\":\"󰔏 ${temp}°C\", \"class\":\"$class\", \"tooltip\":\"GPU Temperature: ${temp}°C\"}"
else
    # Si no se puede obtener la temperatura, mostrar error
    echo "{\"text\":\"󰔏 N/A\", \"class\":\"error\", \"tooltip\":\"GPU temperature not available\"}"
fi
