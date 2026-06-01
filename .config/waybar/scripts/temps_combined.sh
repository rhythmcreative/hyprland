#!/bin/bash

# Script para mostrar temperaturas combinadas de CPU y GPU

# Obtener temperatura de CPU (usando el mismo hwmon que tu configuración)
cpu_temp=$(cat /sys/class/hwmon/hwmon7/temp1_input 2>/dev/null | awk '{print int($1/1000)}')
# Alternativa con hwmon4 si hwmon7 no funciona
if [ -z "$cpu_temp" ]; then
    cpu_temp=$(cat /sys/class/hwmon/hwmon4/temp1_input 2>/dev/null | awk '{print int($1/1000)}')
fi

# Obtener temperatura de GPU NVIDIA
gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null)

# Formatear salida
if [ ! -z "$cpu_temp" ] && [ ! -z "$gpu_temp" ]; then
    text="🖥️ ${cpu_temp}°C | 🎮 ${gpu_temp}°C"
    tooltip="CPU: ${cpu_temp}°C | NVIDIA GPU: ${gpu_temp}°C"
    class="temps-ok"
elif [ ! -z "$cpu_temp" ]; then
    text="🖥️ ${cpu_temp}°C | 🎮 N/A"
    tooltip="CPU: ${cpu_temp}°C | GPU: Not available"
    class="cpu-only"
else
    text="🖥️ N/A | 🎮 N/A"
    tooltip="Temperatures not available"
    class="temps-error"
fi

echo "{\"text\":\"${text}\", \"tooltip\":\"${tooltip}\", \"class\":\"${class}\"}"
