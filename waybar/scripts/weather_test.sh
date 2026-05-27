#!/bin/bash

# Test script para probar los iconos del clima

echo "Probando iconos del clima:"
echo "------------------------"

# Función para mostrar iconos por código
show_weather_icon() {
    local icon_code="$1"
    local description="$2"
    
    case "$icon_code" in
        "01d")  # clear sky day
            echo "☀️ $icon_code - $description"
            ;;
        "01n")  # clear sky night
            echo "🌙 $icon_code - $description"
            ;;
        "02d")  # few clouds day
            echo "⛅ $icon_code - $description"
            ;;
        "02n")  # few clouds night
            echo "🌙 $icon_code - $description"
            ;;
        "03d"|"03n")  # scattered clouds
            echo "☁️ $icon_code - $description"
            ;;
        "04d"|"04n")  # broken clouds
            echo "☁️ $icon_code - $description"
            ;;
        "09d"|"09n")  # shower rain
            echo "🌦️ $icon_code - $description"
            ;;
        "10d"|"10n")  # rain
            echo "🌧️ $icon_code - $description"
            ;;
        "11d"|"11n")  # thunderstorm
            echo "⛈️ $icon_code - $description"
            ;;
        "13d"|"13n")  # snow
            echo "🌨️ $icon_code - $description"
            ;;
        "50d"|"50n")  # mist/fog
            echo "🌫️ $icon_code - $description"
            ;;
        *)
            echo "🌤️ $icon_code - $description"
            ;;
    esac
}

# Mostrar todos los iconos disponibles
show_weather_icon "01d" "Cielo despejado (día)"
show_weather_icon "01n" "Cielo despejado (noche)"
show_weather_icon "02d" "Pocas nubes (día)"
show_weather_icon "02n" "Pocas nubes (noche)"
show_weather_icon "03d" "Nubes dispersas"
show_weather_icon "04d" "Nubes rotas"
show_weather_icon "09d" "Lluvia ligera"
show_weather_icon "10d" "Lluvia"
show_weather_icon "11d" "Tormenta"
show_weather_icon "13d" "Nieve"
show_weather_icon "50d" "Niebla"

echo ""
echo "Simulación de salida JSON para Waybar:"
echo '{"text":"☀️","tooltip":"Cielo despejado - 22°C","class":"weather-ok"}'
