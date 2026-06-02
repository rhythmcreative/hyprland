#!/bin/bash

# Script para actualizar manualmente el clima de Waybar
# Elimina el cache y ejecuta el script de clima

echo "🔄 Actualizando datos del clima..."

# Eliminar cache
rm -f "$HOME/.cache/waybar_weather_openweather.json" 2>/dev/null

# Ejecutar script de clima
"$HOME"/.config/waybar/scripts/weather.sh

echo "✅ Clima actualizado"
