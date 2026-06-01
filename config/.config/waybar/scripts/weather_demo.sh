#!/bin/bash

# Demo del weather script que funciona sin API key
# Simula diferentes condiciones climáticas

# Función para obtener iconos (versión texto simple)
get_weather_icon_by_code() {
    local icon_code="$1"
    case "$icon_code" in
        "01d")  echo "󰖙" ;;      # clear sky day (nerd font sun)
        "01n")  echo "󰖔" ;;      # clear sky night (nerd font moon)
        "02d")  echo "󰖕" ;;      # few clouds day
        "02n")  echo "󰖔" ;;      # few clouds night
        "03d"|"03n") echo "󰖐" ;; # scattered clouds
        "04d"|"04n") echo "󰖐" ;; # broken clouds
        "09d"|"09n") echo "󰖗" ;; # shower rain
        "10d"|"10n") echo "󰖖" ;; # rain
        "11d"|"11n") echo "󰖓" ;; # thunderstorm
        "13d"|"13n") echo "󰖘" ;; # snow
        "50d"|"50n") echo "󰖑" ;; # mist/fog
        *) echo "󰖕" ;;          # default
    esac
}

# Simular datos del clima para Paracuellos de Jarama (Madrid)
hora=$(date +%H)
minuto=$(date +%M)

# Horarios: Día 6:00-22:00, Noche 22:00-6:00
if [ $hora -ge 6 ] && [ $hora -lt 22 ]; then
    # Día - Condiciones típicas de Paracuellos de Jarama en agosto
    case $((hora % 5)) in
        0) icon_code="01d"; desc="Despejado"; temp=$((28 + (hora - 12)/3)) ;;
        1) icon_code="02d"; desc="Pocas nubes"; temp=$((26 + (hora - 10)/3)) ;;
        2) icon_code="01d"; desc="Soleado"; temp=$((30 + (hora - 14)/2)) ;;
        3) icon_code="02d"; desc="Algo nublado"; temp=$((25 + (hora - 8)/3)) ;;
        4) icon_code="01d"; desc="Cielo claro"; temp=$((29 + (hora - 13)/2)) ;;
    esac
else
    # Noche (22:00-6:00) - Temperaturas nocturnas de verano en Madrid
    case $((hora % 3)) in
        0) icon_code="01n"; desc="Despejado"; temp=$((18 + hora/4)) ;;
        1) icon_code="02n"; desc="Pocas nubes"; temp=$((16 + hora/3)) ;;
        2) icon_code="01n"; desc="Cielo estrellado"; temp=$((17 + hora/4)) ;;
    esac
fi

# Obtener icono
icon=$(get_weather_icon_by_code "$icon_code")

# Crear salida JSON para Waybar
output="{\"text\":\"$icon\",\"tooltip\":\"$desc - ${temp}°C - Paracuellos de Jarama (DEMO)\",\"class\":\"weather-ok\"}"

echo "$output"
