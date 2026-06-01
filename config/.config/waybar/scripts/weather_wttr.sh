#!/bin/bash

# Script de clima real para Paracuellos de Jarama usando wttr.in (sin API key)
# Servicio público gratuito

CACHE_FILE="$HOME/.cache/waybar_weather_wttr.json"
CACHE_DURATION=600  # 10 minutos en segundos

# Función para obtener iconos según condición
get_weather_icon() {
    local condition="$1"
    case "$condition" in
        *"Sunny"*|*"Clear"*) echo "☀️" ;;
        *"Partly cloudy"*|*"Partly Cloudy"*) echo "⛅" ;;
        *"Cloudy"*|*"Overcast"*) echo "☁️" ;;
        *"Rain"*|*"Drizzle"*|*"Shower"*) echo "🌧️" ;;
        *"Thunderstorm"*|*"Thunder"*) echo "⛈️" ;;
        *"Snow"*|*"Blizzard"*) echo "❄️" ;;
        *"Fog"*|*"Mist"*) echo "🌫️" ;;
        *) echo "🌤️" ;;
    esac
}

# Función para traducir condiciones al español
translate_condition() {
    local condition="$1"
    case "$condition" in
        *"Sunny"*|*"Clear"*) echo "Despejado" ;;
        *"Partly cloudy"*|*"Partly Cloudy"*) echo "Parcialmente nublado" ;;
        *"Cloudy"*|*"Overcast"*) echo "Nublado" ;;
        *"Light rain"*) echo "Lluvia ligera" ;;
        *"Rain"*|*"Heavy rain"*) echo "Lluvia" ;;
        *"Drizzle"*) echo "Llovizna" ;;
        *"Thunderstorm"*|*"Thunder"*) echo "Tormenta" ;;
        *"Snow"*) echo "Nieve" ;;
        *"Fog"*|*"Mist"*) echo "Niebla" ;;
        *) echo "$condition" ;;
    esac
}

# Función para verificar si el cache es válido
is_cache_valid() {
    if [ ! -f "$CACHE_FILE" ]; then
        return 1
    fi
    
    local cache_time=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    local current_time=$(date +%s)
    local age=$((current_time - cache_time))
    
    [ $age -lt $CACHE_DURATION ]
}

# Si el cache es válido, usarlo
if is_cache_valid; then
    if [ -s "$CACHE_FILE" ]; then
        cached_data=$(cat "$CACHE_FILE")
        if echo "$cached_data" | jq -e . >/dev/null 2>&1; then
            # Modificar el JSON para indicar que es cache
            echo "$cached_data" | jq '.class = "weather-cached"'
            exit 0
        fi
    fi
fi

# Obtener datos del clima desde wttr.in
# Formato: JSON simplificado para Paracuellos de Jarama
weather_data=$(curl -s -m 10 "https://wttr.in/Paracuellos+de+Jarama?format=j1" 2>/dev/null)

# Verificar si la API respondió correctamente
if [ $? -ne 0 ] || [ -z "$weather_data" ]; then
    echo '{"text":"🌐","tooltip":"Error de conexión","class":"weather-error"}'
    exit 1
fi

# Verificar si la respuesta es válida JSON
if ! echo "$weather_data" | jq -e . >/dev/null 2>&1; then
    echo '{"text":"📡","tooltip":"Respuesta inválida","class":"weather-error"}'
    exit 1
fi

# Extraer datos del JSON
temp=$(echo "$weather_data" | jq -r '.current_condition[0].temp_C // "N/A"')
condition=$(echo "$weather_data" | jq -r '.current_condition[0].weatherDesc[0].value // "N/A"')
feels_like=$(echo "$weather_data" | jq -r '.current_condition[0].FeelsLikeC // "N/A"')
humidity=$(echo "$weather_data" | jq -r '.current_condition[0].humidity // "N/A"')
wind_speed=$(echo "$weather_data" | jq -r '.current_condition[0].windspeedKmph // "N/A"')
wind_dir=$(echo "$weather_data" | jq -r '.current_condition[0].winddir16Point // "N/A"')

# Validar que los datos sean válidos
if [ "$temp" = "N/A" ] || [ "$condition" = "N/A" ]; then
    echo '{"text":"❌","tooltip":"Datos no disponibles","class":"weather-error"}'
    exit 1
fi

# Obtener icono y traducir condición
icon=$(get_weather_icon "$condition")
spanish_condition=$(translate_condition "$condition")

# Crear tooltip detallado
tooltip="$spanish_condition - ${temp}°C (sensación ${feels_like}°C)\\nHumedad: ${humidity}%\\nViento: ${wind_speed} km/h ${wind_dir}\\nParacuellos de Jarama, Madrid"

# Crear JSON de salida
output="{\"text\":\"$icon\",\"tooltip\":\"$tooltip\",\"class\":\"weather-ok\"}"

# Guardar en cache
echo "$output" > "$CACHE_FILE"

# Mostrar resultado
echo "$output"
