#!/bin/bash

# Script de clima real para Paracuellos de Jarama usando OpenWeatherMap API
# ID de ciudad de Paracuellos de Jarama: 3114397

# Configuración
CITY_ID="3114397"  # Paracuellos de Jarama, España
API_KEY_FILE="$HOME/.config/waybar/openweather_api_key"
CACHE_FILE="$HOME/.cache/waybar_weather_cache.json"
CACHE_DURATION=600  # 10 minutos en segundos

# Función para obtener iconos basados en el código de OpenWeatherMap
get_weather_icon() {
    local icon_code="$1"
    case "$icon_code" in
        "01d") echo "☀️" ;;        # clear sky day
        "01n") echo "🌙" ;;        # clear sky night
        "02d") echo "⛅" ;;        # few clouds day
        "02n") echo "☁️" ;;        # few clouds night
        "03d"|"03n") echo "☁️" ;;  # scattered clouds
        "04d"|"04n") echo "☁️" ;;  # broken clouds
        "09d"|"09n") echo "🌧️" ;;  # shower rain
        "10d"|"10n") echo "🌦️" ;;  # rain
        "11d"|"11n") echo "⛈️" ;;  # thunderstorm
        "13d"|"13n") echo "❄️" ;;  # snow
        "50d"|"50n") echo "🌫️" ;;  # mist
        *) echo "🌤️" ;;           # default
    esac
}

# Función para obtener descripción en español
get_spanish_description() {
    local desc="$1"
    case "$desc" in
        "clear sky") echo "Despejado" ;;
        "few clouds") echo "Pocas nubes" ;;
        "scattered clouds") echo "Nubes dispersas" ;;
        "broken clouds") echo "Nublado" ;;
        "shower rain") echo "Chubascos" ;;
        "rain") echo "Lluvia" ;;
        "thunderstorm") echo "Tormenta" ;;
        "snow") echo "Nieve" ;;
        "mist") echo "Niebla" ;;
        "overcast clouds") echo "Muy nublado" ;;
        *) echo "$desc" ;;
    esac
}

# Verificar si existe el archivo de API key
if [ ! -f "$API_KEY_FILE" ]; then
    # Crear archivo de ejemplo si no existe
    cat > "$API_KEY_FILE" << EOF
# Coloca tu API key de OpenWeatherMap aquí
# Obtén una gratis en: https://openweathermap.org/api
# Descomenta la siguiente línea y pon tu API key:
# API_KEY=tu_api_key_aqui
EOF
    echo '{"text":"🔧","tooltip":"Configura tu API key en ~/.config/waybar/openweather_api_key","class":"weather-error"}'
    exit 0
fi

# Leer API key
source "$API_KEY_FILE"

if [ -z "$API_KEY" ]; then
    echo '{"text":"🔑","tooltip":"API key no configurada. Edita ~/.config/waybar/openweather_api_key","class":"weather-error"}'
    exit 0
fi

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

# Obtener datos del clima
weather_data=$(curl -s "https://api.openweathermap.org/data/2.5/weather?id=${CITY_ID}&appid=${API_KEY}&units=metric&lang=es")

# Verificar si la API respondió correctamente
if [ $? -ne 0 ] || [ -z "$weather_data" ]; then
    echo '{"text":"🌐","tooltip":"Error de conexión con OpenWeatherMap","class":"weather-error"}'
    exit 1
fi

# Verificar si la respuesta es válida JSON
if ! echo "$weather_data" | jq -e . >/dev/null 2>&1; then
    echo '{"text":"📡","tooltip":"Respuesta inválida de la API","class":"weather-error"}'
    exit 1
fi

# Verificar si hay error en la respuesta
if echo "$weather_data" | jq -e '.cod != 200' >/dev/null 2>&1; then
    error_msg=$(echo "$weather_data" | jq -r '.message // "Error desconocido"')
    echo "{\"text\":\"❌\",\"tooltip\":\"Error API: $error_msg\",\"class\":\"weather-error\"}"
    exit 1
fi

# Extraer datos del JSON
temp=$(echo "$weather_data" | jq -r '.main.temp // "N/A"' | cut -d. -f1)
desc=$(echo "$weather_data" | jq -r '.weather[0].description // "N/A"')
icon_code=$(echo "$weather_data" | jq -r '.weather[0].icon // "01d"')
city_name=$(echo "$weather_data" | jq -r '.name // "Paracuellos de Jarama"')
humidity=$(echo "$weather_data" | jq -r '.main.humidity // "N/A"')
feels_like=$(echo "$weather_data" | jq -r '.main.feels_like // "N/A"' | cut -d. -f1)

# Obtener icono y descripción
icon=$(get_weather_icon "$icon_code")
spanish_desc=$(get_spanish_description "$desc")

# Crear tooltip detallado
tooltip="$spanish_desc - ${temp}°C (sensación ${feels_like}°C)\\nHumedad: ${humidity}%\\n$city_name, Madrid"

# Crear JSON de salida
output="{\"text\":\"$icon\",\"tooltip\":\"$tooltip\",\"class\":\"weather-ok\"}"

# Guardar en cache
echo "$output" > "$CACHE_FILE"

# Mostrar resultado
echo "$output"
