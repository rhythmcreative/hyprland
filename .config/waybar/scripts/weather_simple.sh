#!/bin/bash

# Script de clima simplificado para Waybar
# Con iconos de clima visibles

# Configurar UTF-8 para soporte de emojis
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

CITY="Paracuellos+de+Jarama,Madrid,Spain"
CACHE_FILE="$HOME/.cache/waybar_weather.json"
CACHE_DURATION=600

# Función para verificar cache
is_cache_valid() {
    if [ ! -f "$CACHE_FILE" ]; then
        return 1
    fi
    
    local cache_time=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    local current_time=$(date +%s)
    local age=$((current_time - cache_time))
    
    [ $age -lt $CACHE_DURATION ]
}

# Usar cache si es válido
if is_cache_valid && [ -s "$CACHE_FILE" ]; then
    cached_data=$(cat "$CACHE_FILE")
    if echo "$cached_data" | jq -e . >/dev/null 2>&1; then
        echo "$cached_data"
        exit 0
    fi
fi

# Obtener datos del clima
weather_data=$(curl -s "https://wttr.in/$CITY?format=j1" \
    --connect-timeout 10 \
    --max-time 20 \
    --user-agent "waybar-weather/1.0")

# Verificar si curl funcionó
if [ $? -ne 0 ] || [ -z "$weather_data" ]; then
    echo '{"text":"Error clima","tooltip":"No se pudo conectar al servicio de clima","class":"weather-error"}'
    exit 1
fi

# Verificar JSON válido
if ! echo "$weather_data" | jq -e . >/dev/null 2>&1; then
    echo '{"text":"JSON Error","tooltip":"Respuesta inválida del servidor","class":"weather-error"}'
    exit 1
fi


# Extraer datos
temp=$(echo "$weather_data" | jq -r '.current_condition[0].temp_C // "N/A"')
desc=$(echo "$weather_data" | jq -r '.current_condition[0].weatherDesc[0].value // "N/A"')
feels_like=$(echo "$weather_data" | jq -r '.current_condition[0].FeelsLikeC // "N/A"')
humidity=$(echo "$weather_data" | jq -r '.current_condition[0].humidity // "N/A"')

# Crear texto solo con temperatura
text="${temp}°C"
tooltip="Clima: $desc | Temperatura: ${temp}°C | Sensacion: ${feels_like}°C | Humedad: ${humidity}% | Paracuellos de Jarama"

# Crear JSON usando printf para evitar problemas de encoding
output=$(printf '{"text":"%s","tooltip":"%s","class":"weather-ok"}' "$text" "$tooltip")

# Verificar que es JSON válido
if ! echo "$output" | jq -e . >/dev/null 2>&1; then
    echo '{"text":"JSON Error","tooltip":"Error generando JSON","class":"weather-error"}'
    exit 1
fi

# Guardar en cache
echo "$output" > "$CACHE_FILE"

# Mostrar resultado
echo "$output"
