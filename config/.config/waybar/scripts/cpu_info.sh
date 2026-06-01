#!/bin/bash

# Script para obtener información detallada de CPU para Waybar

# Redirigir stderr para evitar contaminación de salida JSON
exec 2>/dev/null

# Obtener temperatura de CPU (k10temp para AMD)
temp_path="/sys/class/hwmon/hwmon5/temp1_input"
if [ -f "$temp_path" ]; then
    temp_raw=$(cat "$temp_path" 2>/dev/null)
    if [ -n "$temp_raw" ]; then
        temp=$((temp_raw / 1000))
    else
        temp="N/A"
    fi
else
    temp="N/A"
fi

# Obtener utilización de CPU con método más confiable
cpu_usage=$(awk '{u=$2+$4; t=$2+$4+$5; if (NR==1){u1=u; t1=t;} else print (100*(u-u1))/(t-t1)}' <(grep 'cpu ' /proc/stat; sleep 0.1; grep 'cpu ' /proc/stat) 2>/dev/null)
if [ -z "$cpu_usage" ]; then
    cpu_usage=0
fi
cpu_usage=$(printf "%.0f" "$cpu_usage")

# Obtener frecuencia actual del CPU
cpu_freq=$(cat /proc/cpuinfo 2>/dev/null | grep "cpu MHz" | head -1 | awk '{print $4}' | cut -d'.' -f1)
if [ -z "$cpu_freq" ]; then
    cpu_freq="N/A"
fi

# Obtener información del CPU
cpu_model=$(lscpu 2>/dev/null | grep "Model name" | sed 's/Model name: *//' | awk '{print $1, $2, $3}')
if [ -z "$cpu_model" ]; then
    cpu_model="Unknown"
fi

# Obtener número de núcleos
cores=$(nproc 2>/dev/null)
if [ -z "$cores" ]; then
    cores="N/A"
fi

# Determinar clase CSS basada en temperatura
css_class=""
if [ "$temp" != "N/A" ]; then
    if [ "$temp" -gt 85 ]; then
        css_class="critical"
    elif [ "$temp" -gt 75 ]; then
        css_class="warning"
    fi
fi

# Salida JSON para Waybar (usar printf para garantizar formato correcto)
printf '{"text":"󰍛 %s°C","tooltip":"🔥 Temperatura: %s°C\n⚡ Utilización: %s%%\n⏰ Frecuencia: %sMHz\n🔧 Procesador: %s\n🧵 Núcleos: %s","class":"%s"}\n' "$temp" "$temp" "$cpu_usage" "$cpu_freq" "$cpu_model" "$cores" "$css_class"
