#!/bin/bash

# Script para probar todos los iconos de clima
# Muestra cómo se ven los diferentes iconos de Nerd Fonts

echo "=== Prueba de iconos de clima para waybar ==="
echo ""

# Función para iconos de clima (copiada del script principal)
get_weather_icon() {
    local condition=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    case "$condition" in
        *"sunny"*|*"clear"*) echo "" ;;  # nf-weather-day-sunny
        *"partly cloudy"*|*"partly"*) echo "" ;;  # nf-weather-day-cloudy
        *"cloudy"*|*"overcast"*) echo "" ;;  # nf-weather-cloudy
        *"mist"*|*"fog"*) echo "" ;;  # nf-weather-fog
        *"light rain"*|*"patchy rain"*|*"drizzle"*) echo "" ;;  # nf-weather-rain
        *"rain"*|*"shower"*) echo "" ;;  # nf-weather-rain
        *"snow"*) echo "" ;;  # nf-weather-snow
        *"thunder"*|*"storm"*) echo "" ;;  # nf-weather-thunderstorm
        *) echo "" ;;  # nf-weather-day-cloudy (default)
    esac
}

# Lista de condiciones de prueba
conditions=(
    "Sunny"
    "Clear"
    "Partly cloudy"
    "Cloudy" 
    "Overcast"
    "Mist"
    "Fog"
    "Light rain"
    "Patchy rain"
    "Drizzle"
    "Rain"
    "Shower"
    "Snow"
    "Thunder"
    "Storm"
    "Unknown condition"
)

echo "Condición               | Icono | Descripción"
echo "------------------------|-------|-------------"

for condition in "${conditions[@]}"; do
    icon=$(get_weather_icon "$condition")
    printf "%-22s | %-5s | %s\n" "$condition" "$icon" "$condition"
done

echo ""
echo "=== Prueba de iconos sin conexión ==="
echo "Sin conexión            |   | Error de red"
echo ""
echo "Si no ves los iconos correctamente, verifica que tengas instalados:"
echo "  - noto-fonts-emoji"
echo "  - ttf-nerd-fonts-symbols-mono"
echo "  - JetBrainsMono Nerd Font configurado en waybar"

#!/bin/bash

echo "=== PRUEBA DE ICONOS DE CLIMA ==="
echo

echo "1. Emojis Unicode:"
echo "☀️ Sol día"
echo "🌙 Luna noche"
echo "⛅ Parcialmente nublado"
echo "☁️ Nublado"
echo "🌧️ Lluvia"
echo "❄️ Nieve"
echo "⛈️ Tormenta"
echo

echo "2. Nerd Fonts Weather:"
echo " Sol"
echo " Luna"
echo " Parcialmente nublado"
echo " Nublado"
echo " Lluvia"
echo " Nieve"
echo " Tormenta"
echo

echo "3. Caracteres Unicode básicos:"
echo "○ Sol día"
echo "◐ Luna noche"
echo "◔ Parcialmente nublado"
echo "● Nublado"
echo "▓ Lluvia"
echo "* Nieve"
echo "⚡ Tormenta"
echo

echo "4. Texto simple:"
echo "SOL Sol día"
echo "LUNA Luna noche"
echo "NUBES Parcialmente nublado"
echo "NUBLADO Nublado"
echo "LLUVIA Lluvia"
echo "NIEVE Nieve"
echo "TORMENTA Tormenta"
echo

echo "¿Cuáles se ven mejor en tu terminal?"
