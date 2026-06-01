#!/bin/bash

# Script para obtener la temperatura de la GPU NVIDIA con información detallada

# Obtener información de la GPU
gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null)
gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null)
gpu_usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null)

if [ $? -eq 0 ] && [ ! -z "$gpu_temp" ]; then
    # Determinar el ícono y clase según la temperatura
    if [ $gpu_temp -ge 90 ]; then
        icon="󰸁"
        class="gpu-critical"
        tooltip="🚨 GPU Temperature CRITICAL: ${gpu_temp}°C\n${gpu_name}\nUsage: ${gpu_usage}%"
    elif [ $gpu_temp -ge 75 ]; then
        icon="󰔏"
        class="gpu-hot"
        tooltip="⚠️  GPU Temperature HIGH: ${gpu_temp}°C\n${gpu_name}\nUsage: ${gpu_usage}%"
    else
        icon="󰔏"
        class="gpu-normal"
        tooltip="GPU Temperature: ${gpu_temp}°C\n${gpu_name}\nUsage: ${gpu_usage}%"
    fi
    
    echo "{\"text\":\"${icon} ${gpu_temp}°C\", \"tooltip\":\"${tooltip}\", \"class\":\"${class}\"}"
else
    echo "{\"text\":\"󰔏 N/A\", \"tooltip\":\"NVIDIA GPU not available\", \"class\":\"gpu-error\"}"
fi
