#!/bin/bash

# Script para obtener información detallada de GPU NVIDIA para Waybar

# Redirigir stderr para evitar contaminación de salida JSON
exec 2>/dev/null

# Verificar si nvidia-smi está disponible
if ! command -v nvidia-smi >/dev/null 2>&1; then
    printf '{"text":"GPU N/A","tooltip":"NVIDIA SMI no disponible","class":"warning"}\n'
    exit 0
fi

# Obtener información de la GPU
info=$(nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw,clocks.current.graphics --format=csv,noheader,nounits 2>/dev/null)

# Verificar si nvidia-smi funcionó correctamente
if [ $? -ne 0 ] || [ -z "$info" ]; then
    printf '{"text":"GPU Error","tooltip":"Error al obtener información de GPU","class":"critical"}\n'
    exit 0
fi

# Parsear los valores de manera segura
temp=$(echo "$info" | cut -d',' -f1 | xargs | grep -o '[0-9]*')
util=$(echo "$info" | cut -d',' -f2 | xargs | grep -o '[0-9]*')
mem_used=$(echo "$info" | cut -d',' -f3 | xargs | grep -o '[0-9]*')
mem_total=$(echo "$info" | cut -d',' -f4 | xargs | grep -o '[0-9]*')
power=$(echo "$info" | cut -d',' -f5 | xargs | grep -o '[0-9.]*')
clock=$(echo "$info" | cut -d',' -f6 | xargs | grep -o '[0-9]*')

# Verificar que los valores no estén vacíos
[ -z "$temp" ] && temp="0"
[ -z "$util" ] && util="0"
[ -z "$mem_used" ] && mem_used="0"
[ -z "$mem_total" ] && mem_total="1"
[ -z "$power" ] && power="0.0"
[ -z "$clock" ] && clock="0"

# Calcular porcentaje de memoria de manera segura
if [ "$mem_total" -gt 0 ]; then
    mem_percent=$(awk "BEGIN {printf \"%.0f\", ($mem_used/$mem_total)*100}" 2>/dev/null)
    [ -z "$mem_percent" ] && mem_percent="0"
else
    mem_percent="0"
fi

# Determinar clase CSS basada en temperatura
css_class=""
if [ "$temp" -gt 80 ]; then
    css_class="critical"
elif [ "$temp" -gt 70 ]; then
    css_class="warning"
fi

# Salida JSON para Waybar (usar printf para garantizar formato correcto)
printf '{"text":"󰮲 %s°C","tooltip":"🔥 Temperatura: %s°C\n⚡ Utilización: %s%%\n🧠 Memoria: %sMB / %sMB (%s%%)\n🔌 Consumo: %sW\n⏰ Reloj: %sMHz","class":"%s"}\n' "$temp" "$temp" "$util" "$mem_used" "$mem_total" "$mem_percent" "$power" "$clock" "$css_class"
