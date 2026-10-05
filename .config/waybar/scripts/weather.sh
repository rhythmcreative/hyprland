#!/bin/bash

# Script para mostrar información del clima en waybar
# Ubicación: Paracuellos de Jarama, España
# Actualización: cada 10 minutos (configurado en waybar)
# Muestra: Solo icono del clima con información detallada en tooltip

# Cargar variables de entorno desde .env
if [ -f "$HOME/.env" ]; then
    source "$HOME/.env"
fi

# Coordenadas de Paracuellos de Jarama
LAT="40.5078"
LON="-3.4683"

# API Key de OpenWeather
API_KEY="${OPEN_WEATHER_MAP_SECRET}"

# URL de la API 2.5 de OpenWeather (gratuita)
API_URL="https://api.openweathermap.org/data/2.5/weather?lat=${LAT}&lon=${LON}&appid=${API_KEY}&units=metric&lang=es"

# Archivo temporal para cache
CACHE_FILE="/tmp/weather_cache.json"
CACHE_DURATION=600  # 10 minutos en segundos

# Función para obtener icono del clima (iconos compatibles con waybar)
get_weather_icon() {
    local condition="$1"
    case "$condition" in
        *"clear"*|*"despejado"*) echo "☀" ;;
        *"cloud"*|*"nublado"*|*"nubes"*) echo "☁" ;;
        *"rain"*|*"lluvia"*) echo "🌧" ;;
        *"thunder"*|*"tormenta"*) echo "⛈" ;;
        *"snow"*|*"nieve"*) echo "❄" ;;
        *"mist"*|*"fog"*|*"neblina"*) echo "🌫" ;;
        *"partly cloudy"*|*"partly-cloudy"*|*"broken clouds"*) echo "⛅" ;;
        *) echo "🌤" ;;
    esac
}

# Función para obtener dirección del viento
get_wind_direction() {
    local deg=$1
    # Convertir a entero para evitar problemas con decimales
    deg=$(printf "%.0f" "$deg" 2>/dev/null || echo "0")
    
    if [ $deg -ge 338 ] || [ $deg -lt 23 ]; then
        echo "N"
    elif [ $deg -ge 23 ] && [ $deg -lt 68 ]; then
        echo "NE"
    elif [ $deg -ge 68 ] && [ $deg -lt 113 ]; then
        echo "E"
    elif [ $deg -ge 113 ] && [ $deg -lt 158 ]; then
        echo "SE"
    elif [ $deg -ge 158 ] && [ $deg -lt 203 ]; then
        echo "S"
    elif [ $deg -ge 203 ] && [ $deg -lt 248 ]; then
        echo "SW"
    elif [ $deg -ge 248 ] && [ $deg -lt 293 ]; then
        echo "W"
    elif [ $deg -ge 293 ] && [ $deg -lt 338 ]; then
        echo "NW"
    else
        echo ""
    fi
}

# Verificar si el cache es válido
is_cache_valid() {
    if [ -f "$CACHE_FILE" ]; then
        local file_time=$(stat -c %Y "$CACHE_FILE" 2>/dev/null)
        local current_time=$(date +%s)
        local time_diff=$((current_time - file_time))
        
        if [ $time_diff -lt $CACHE_DURATION ]; then
            return 0
        fi
    fi
    return 1
}

# Función principal para obtener datos del clima
get_weather_data() {
    # Si el cache es válido, usarlo
    if is_cache_valid; then
        cat "$CACHE_FILE"
        return 0
    fi
    
    # Intentar con OpenWeather API si tenemos API key
    if [ -n "$API_KEY" ] && [ "$API_KEY" != "" ]; then
        get_openweather_data
    else
        # Usar servicio alternativo sin API key
        get_wttr_data
    fi
}

# Función para obtener datos de OpenWeather
get_openweather_data() {
    # Obtener datos de OpenWeather API
    local weather_data=$(curl -s "$API_URL" 2>/dev/null)
    
    # Verificar si la respuesta es válida
    if [ $? -ne 0 ] || [ -z "$weather_data" ] || echo "$weather_data" | grep -q '"cod".*401'; then
        echo '{"text": "🌡️ API Key Inválida", "tooltip": "API Key de OpenWeather no es válida. Usando servicio alternativo..."}'
        get_wttr_data
        return
    fi
    
    # Verificar si hay error en la respuesta
    if echo "$weather_data" | grep -q '"cod".*4'; then
        echo '{"text": "🌡️ Error API", "tooltip": "Error en la API de OpenWeather. Usando servicio alternativo..."}'
        get_wttr_data
        return
    fi
    
    # Parsear datos usando jq si está disponible, sino usar métodos básicos
    if command -v jq >/dev/null 2>&1; then
        parse_with_jq "$weather_data"
    else
        parse_basic "$weather_data"
    fi
    
    # Guardar en cache
    if [ -n "$result" ]; then
        echo "$result" > "$CACHE_FILE"
        echo "$result"
    fi
}

# Función para obtener datos de wttr.in (sin API key)
get_wttr_data() {
    # Usar servicio wttr.in para Paracuellos de Jarama
    local city="Paracuellos+de+Jarama,Spain"
    local weather_data=$(curl -s "https://wttr.in/$city?format=%C+%t+%h+%w+%p" --connect-timeout 5 --max-time 10 2>/dev/null)
    
    # Verificar si curl fue exitoso
    if [ $? -ne 0 ] || [ -z "$weather_data" ]; then
        # Usar cache viejo si existe
        if [ -f "$CACHE_FILE" ]; then
            cat "$CACHE_FILE" 2>/dev/null && return
        fi
        # Fallback
        result='{"text":"❌","tooltip":"Sin conexión","class":"weather-error"}'
        echo "$result" > "$CACHE_FILE"
        echo "$result"
        return
    fi
    
    parse_wttr_data "$weather_data"
    
    # Guardar en cache
    if [ -n "$result" ]; then
        echo "$result" > "$CACHE_FILE"
        echo "$result"
    fi
}

# Parsear datos de wttr.in
parse_wttr_data() {
    local data="$1"
    
    # Extraer temperatura (buscar el patrón +XX°C o -XX°C)
    local temp=$(echo "$data" | grep -oE '[+-]?[0-9]+°C' | head -1)
    # Extraer humedad (buscar el patrón XX%)
    local humidity=$(echo "$data" | grep -oE '[0-9]+%' | head -1)
    # Extraer viento (buscar dirección + velocidad)
    local wind=$(echo "$data" | grep -oE '[↑↓←→↖↗↘↙][0-9]+km/h' | head -1)
    # Extraer presión
    local pressure=$(echo "$data" | grep -oE '[0-9]+hPa' | head -1)
    # Extraer condición (todo antes de la temperatura)
    local condition=$(echo "$data" | sed "s/ $temp.*//" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    
    # Valores por defecto
    temp=${temp:-"--°C"}
    humidity=${humidity:-"-%"}
    condition=${condition:-"Sin datos"}
    
    # Obtener icono
    local icon=$(get_weather_icon "$condition")
    
    # Crear tooltip
    local tooltip="🌍 Paracuellos de Jarama\\n🌡️ Temperatura: $temp\\n📖 Condición: $condition\\n💧 Humedad: $humidity"
    
    if [ -n "$wind" ] && [ "$wind" != " " ]; then
        tooltip="$tooltip\\n💨 Viento: $wind"
    fi
    
    if [ -n "$pressure" ] && [ "$pressure" != " " ]; then
        tooltip="$tooltip\\n🔘 Presión: $pressure"
    fi
    
    # Crear resultado JSON - solo icono
    if command -v jq >/dev/null 2>&1; then
        # -c es lo que faltaba: jq imprime el JSON en varias lineas y el
        # parser de waybar solo admite una, asi que abortaba con
        # "Error parsing JSON: Line 1, Column 2 Missing '}'" y el modulo se
        # quedaba vacio aunque jq validara la salida.
        result=$(jq -nc \
            --arg text "$icon" \
            --arg tooltip "Paracuellos de Jarama | Temp: $temp | $condition | Humedad: $humidity" \
            '{text: $text, tooltip: $tooltip, class: "weather-ok"}')
    else
        # JSON manual sin jq - solo icono
        local simple_tooltip="Paracuellos de Jarama | Temp: $temp | $condition | Humedad: $humidity"
        result="{\"text\":\"$icon\",\"tooltip\":\"$simple_tooltip\",\"class\":\"weather-ok\"}"
    fi
}

# Parsear con jq (método preferido) - API 2.5
parse_with_jq() {
    local data="$1"
    
    # Extraer información actual de la API 2.5
    local temp=$(echo "$data" | jq -r '.main.temp // 0')
    local feels_like=$(echo "$data" | jq -r '.main.feels_like // 0')
    local humidity=$(echo "$data" | jq -r '.main.humidity // 0')
    local pressure=$(echo "$data" | jq -r '.main.pressure // 0')
    local wind_speed=$(echo "$data" | jq -r '.wind.speed // 0')
    local wind_deg=$(echo "$data" | jq -r '.wind.deg // 0')
    local visibility=$(echo "$data" | jq -r '.visibility // 10000')
    local description=$(echo "$data" | jq -r '.weather[0].description // "Sin datos"')
    local main=$(echo "$data" | jq -r '.weather[0].main // "Clear"')
    # Forzar nombre de ciudad a Paracuellos de Jarama
    local city="Paracuellos de Jarama"
    
    # Convertir temperatura a entero
    temp=$(printf "%.0f" "$temp")
    feels_like=$(printf "%.0f" "$feels_like")
    
    # Obtener icono
    local icon=$(get_weather_icon "$main")
    
    # Dirección del viento
    local wind_dir=$(get_wind_direction "$wind_deg")
    
    # Formatear velocidad del viento (m/s a km/h)
    local wind_kmh=$(echo "$wind_speed * 3.6" | bc 2>/dev/null || echo "0")
    wind_kmh=$(printf "%.1f" "$wind_kmh")
    
    # Formatear visibilidad (m a km)
    local visibility_km=$(echo "scale=1; $visibility / 1000" | bc 2>/dev/null || echo "10")
    
    # Para waybar, construir un tooltip sin barras invertidas dobles en las nuevas líneas
    local tooltip="🌍 ${city} | 🌡 Temperatura: ${temp}°C (sensación ${feels_like}°C) | 📖 ${description} | 💧 Humedad: ${humidity}% | 🔘 Presión: ${pressure} hPa | 💨 Viento: ${wind_kmh} km/h ${wind_dir} | 👁 Visibilidad: ${visibility_km} km"
    
# Añadir timestamp para debug (opcional)
    local timestamp=$(date '+%H:%M')
    
    # Resultado final - solo icono con clase CSS
    result="{\"text\": \"${icon}\", \"tooltip\": \"${tooltip} (${timestamp})\", \"class\": \"weather-updated\"}"
    
    # Debug: mostrar en stderr cuándo se actualiza
    echo "[$(date)] Weather updated: ${icon} ${temp}°C" >&2
}

# Parsear básico sin jq
parse_basic() {
    local data="$1"
    
    # Extraer temperatura usando grep y sed (método básico)
    local temp=$(echo "$data" | grep -o '"temp":[0-9.-]*' | cut -d: -f2 | head -1)
    local description=$(echo "$data" | grep -o '"description":"[^"]*"' | cut -d'"' -f4 | head -1)
    
    # Valores por defecto si no se pueden extraer
    temp=${temp:-"--"}
    description=${description:-"Sin datos"}
    
    # Convertir a entero si es posible
    if [[ "$temp" =~ ^[0-9.-]+$ ]]; then
        temp=$(printf "%.0f" "$temp")
    fi
    
    local icon=$(get_weather_icon "$description")
    
    # Resultado básico - solo icono
    result='{"text": "'${icon}'", "tooltip": "Paracuellos de Jarama | Temp: '${temp}'°C | '${description}'"}'
}

# Verificar dependencias
check_dependencies() {
    if ! command -v curl >/dev/null 2>&1; then
        echo '{"text": "❌ No curl", "tooltip": "curl no está instalado"}'
        exit 1
    fi
    
    if ! command -v bc >/dev/null 2>&1; then
        # bc no es crítico, pero sí recomendado
        :
    fi
}

# Función principal
main() {
    check_dependencies
    get_weather_data
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
