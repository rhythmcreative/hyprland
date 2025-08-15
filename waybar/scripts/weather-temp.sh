#!/bin/bash

# Script de clima temporal para Waybar usando wttr.in
# Funciona inmediatamente mientras se activa tu API key de OpenWeatherMap

LOCATION="Paracuellos+de+Jarama,Madrid"
CACHE_FILE="$HOME/.cache/waybar_weather_temp.json"
CACHE_DURATION=300  # 5 minutos

# Función para obtener iconos meteorológicos
get_weather_icon() {
    local condition="$1"
    case "$condition" in
        *"Sunny"*|*"Clear"*|*"sol"*|*"despejado"*) echo "☀️" ;;
        *"Partly"*|*"Few"*|*"nuboso"*|*"parcial"*) echo "⛅" ;;
        *"Cloudy"*|*"Overcast"*|*"nublado"*|*"cubierto"*) echo "☁️" ;;
        *"Rain"*|*"Drizzle"*|*"lluvia"*|*"llovizna"*) echo "🌧️" ;;
        *"Heavy rain"*|*"Shower"*|*"fuerte"*) echo "🌧️" ;;
        *"Thunder"*|*"Storm"*|*"tormenta"*|*"trueno"*) echo "⛈️" ;;
        *"Snow"*|*"nieve"*) echo "❄️" ;;
        *"Fog"*|*"Mist"*|*"niebla"*) echo "🌫️" ;;
        *"Wind"*|*"viento"*) echo "💨" ;;
        *) echo "🌤️" ;;
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

# Obtener datos del clima usando wttr.in con formato detallado
weather_data=$(curl -s "wttr.in/$LOCATION?format=%t|%C|%h|%f|%w" --connect-timeout 5 --max-time 10)

# Verificar si curl fue exitoso
if [ $? -ne 0 ] || [ -z "$weather_data" ]; then
    # Intentar usar cache viejo si existe
    if [ -f "$CACHE_FILE" ] && [ -s "$CACHE_FILE" ]; then
        cached_data=$(cat "$CACHE_FILE")
        if echo "$cached_data" | jq -e . >/dev/null 2>&1; then
            echo "$cached_data" | jq '.text = "🌐" | .tooltip = "Sin conexión - usando datos guardados"'
            exit 0
        fi
    fi
    
    echo '{"text":"🌐","tooltip":"Error de conexión","class":"weather-error"}'
    exit 1
fi

# Parsear los datos (formato: temp|condition|humidity|feels_like|wind)
IFS='|' read -r temp condition humidity feels_like wind <<< "$weather_data"

# Limpiar los datos
temp=$(echo "$temp" | tr -d '°C+' | tr -d ' ')
condition=$(echo "$condition" | xargs)
humidity=$(echo "$humidity" | xargs)
feels_like=$(echo "$feels_like" | tr -d '°C+' | tr -d ' ')
wind=$(echo "$wind" | xargs)

# Obtener icono
icon=$(get_weather_icon "$condition")

# Crear tooltip más detallado
if [ -n "$feels_like" ] && [ "$feels_like" != "$temp" ]; then
    tooltip="$condition\\n${temp}°C (sensación ${feels_like}°C)\\nHumedad: $humidity\\nViento: $wind\\nParacuellos de Jarama, Madrid\\n\\n⏳ Usando datos temporales - OpenWeatherMap se activará pronto"
else
    tooltip="$condition\\n${temp}°C\\nHumedad: $humidity\\nViento: $wind\\nParacuellos de Jarama, Madrid\\n\\n⏳ Usando datos temporales - OpenWeatherMap se activará pronto"
fi

# Crear JSON de salida
output="{\"text\":\"$icon ${temp}°C\",\"tooltip\":\"$tooltip\",\"class\":\"weather-temp\"}"

# Guardar en cache
echo "$output" > "$CACHE_FILE"

# Mostrar resultado
echo "$output"
