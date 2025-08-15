#!/bin/bash

# Script de clima para Waybar usando wttr.in
# Para Paracuellos de Jarama, Madrid
# No requiere API key - Servicio gratuito

# Configuración
CITY="Paracuellos+de+Jarama,Madrid,Spain"
CACHE_FILE="$HOME/.cache/waybar_weather_paracuellos.json"
CACHE_DURATION=600  # 10 minutos (wttr.in actualiza menos frecuentemente)

# Función para obtener iconos según descripción del clima
get_weather_icon() {
    local condition="$1"
    case "$condition" in
        *"Sunny"*|*"Clear"*|*"despejado"*|*"soleado"*) echo "☀️" ;;
        *"Partly cloudy"*|*"parcialmente nublado"*|*"algo nublado"*) echo "⛅" ;;
        *"Cloudy"*|*"Overcast"*|*"nublado"*|*"cubierto"*) echo "☁️" ;;
        *"Mist"*|*"Fog"*|*"neblina"*|*"niebla"*) echo "🌫️" ;;
        *"Light rain"*|*"lluvia ligera"*|*"llovizna"*) echo "🌦️" ;;
        *"Rain"*|*"Heavy rain"*|*"lluvia"*|*"lluvia fuerte"*) echo "🌧️" ;;
        *"Snow"*|*"nieve"*) echo "❄️" ;;
        *"Thunder"*|*"tormenta"*|*"truenos"*) echo "⛈️" ;;
        *) echo "🌤️" ;;  # default
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
if is_cache_valid && [ -s "$CACHE_FILE" ]; then
    cached_data=$(cat "$CACHE_FILE")
    if echo "$cached_data" | jq -e . >/dev/null 2>&1; then
        echo "$cached_data"
        exit 0
    fi
fi

# Obtener datos del clima de wttr.in (formato JSON)
weather_data=$(curl -s "https://wttr.in/$CITY?format=j1" \
    --connect-timeout 10 \
    --max-time 20)

# Verificar si curl fue exitoso
if [ $? -ne 0 ] || [ -z "$weather_data" ]; then
    # Intentar usar cache viejo si existe
    if [ -f "$CACHE_FILE" ] && [ -s "$CACHE_FILE" ]; then
        cached_data=$(cat "$CACHE_FILE")
        if echo "$cached_data" | jq -e . >/dev/null 2>&1; then
            echo "$cached_data" | jq '.text = "🌐" + (.text | split(" ")[1:] | join(" ")) | .tooltip = "Sin conexión - usando datos guardados\n" + .tooltip'
            exit 0
        fi
    fi
    
    echo '{"text":"🌐","tooltip":"Error de conexión con wttr.in","class":"weather-error"}'
    exit 1
fi

# Verificar si la respuesta es válida JSON
if ! echo "$weather_data" | jq -e . >/dev/null 2>&1; then
    echo '{"text":"📡","tooltip":"Respuesta inválida del servidor de clima","class":"weather-error"}'
    exit 1
fi

# Extraer datos del JSON de wttr.in
temp=$(echo "$weather_data" | jq -r '.current_condition[0].temp_C // "N/A"')
feels_like=$(echo "$weather_data" | jq -r '.current_condition[0].FeelsLikeC // "N/A"')
humidity=$(echo "$weather_data" | jq -r '.current_condition[0].humidity // "N/A"')
desc_en=$(echo "$weather_data" | jq -r '.current_condition[0].weatherDesc[0].value // "N/A"')
wind_speed=$(echo "$weather_data" | jq -r '.current_condition[0].windspeedKmph // "N/A"')
wind_dir=$(echo "$weather_data" | jq -r '.current_condition[0].winddirDegree // "N/A"')
pressure=$(echo "$weather_data" | jq -r '.current_condition[0].pressure // "N/A"')
visibility=$(echo "$weather_data" | jq -r '.current_condition[0].visibility // "N/A"')

# Traducir descripción del clima al español
case "$desc_en" in
    *"Sunny"|*"Clear"*) desc="Despejado" ;;
    *"Partly cloudy"*) desc="Parcialmente nublado" ;;
    *"Cloudy"|*"Overcast"*) desc="Nublado" ;;
    *"Mist"|*"Fog"*) desc="Neblina" ;;
    *"Light rain"|*"Patchy rain"*) desc="Lluvia ligera" ;;
    *"Moderate rain"|*"Rain"*) desc="Lluvia" ;;
    *"Heavy rain"*) desc="Lluvia fuerte" ;;
    *"Light snow"*) desc="Nieve ligera" ;;
    *"Snow"|*"Heavy snow"*) desc="Nieve" ;;
    *"Thunder"*) desc="Tormenta" ;;
    *) desc="$desc_en" ;;
esac

# Obtener icono basado en la descripción
icon=$(get_weather_icon "$desc_en")

# Crear tooltip simple sin saltos de línea problemáticos
tooltip="$desc - ${temp}°C | Sensación ${feels_like}°C | Humedad ${humidity}%"

if [ "$wind_speed" != "N/A" ] && [ "$wind_speed" != "0" ]; then
    tooltip="$tooltip | Viento ${wind_speed} km/h"
fi

tooltip="$tooltip | Paracuellos de Jarama"

# Crear JSON de forma simple y compatible con Waybar
# Asegurar que el script use UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# Escapar comillas en el tooltip
tooltip_escaped=$(echo "$tooltip" | sed 's/"/\\"/g')

# Crear JSON compacto en una sola línea - solo icono
output="{\"text\":\"$icon\",\"tooltip\":\"$tooltip_escaped\",\"class\":\"weather-ok\"}"

# Verificar y compactar el JSON usando jq
if echo "$output" | jq -e . > /dev/null 2>&1; then
    # Si el JSON es válido, compactarlo
    output=$(echo "$output" | jq -c .)
else
    # Fallback con icono simple si hay problemas de encoding
    output="{\"text\":\"🌤️\",\"tooltip\":\"$tooltip_escaped\",\"class\":\"weather-ok\"}"
    output=$(echo "$output" | jq -c .)
fi

# Guardar en cache
echo "$output" > "$CACHE_FILE"

# Mostrar resultado
echo "$output"
