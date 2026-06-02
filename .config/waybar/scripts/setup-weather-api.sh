#!/bin/bash

# Script para configurar la API key de OpenWeatherMap
API_KEY_FILE="$HOME/.config/waybar/openweather_api_key"

echo "🌤️  Configuración de OpenWeatherMap API"
echo "======================================"
echo
echo "Para usar el widget de clima necesitas una API key gratuita de OpenWeatherMap."
echo
echo "📝 Pasos para obtener tu API key:"
echo "1. Ve a: https://openweathermap.org/api"
echo "2. Haz clic en 'Sign Up' (registrarse)"
echo "3. Crea una cuenta gratuita"
echo "4. Ve a 'My API keys' en tu perfil"
echo "5. Copia tu API key"
echo
echo "⚠️  NOTA: Puede tardar hasta 2 horas en activarse tu API key después del registro."
echo

# Verificar si ya hay una API key configurada
if [ -f "$API_KEY_FILE" ]; then
    if grep -q "^API_KEY=" "$API_KEY_FILE" 2>/dev/null; then
        current_key=$(grep "^API_KEY=" "$API_KEY_FILE" | cut -d= -f2)
        if [ -n "$current_key" ] && [ "$current_key" != "tu_api_key_aqui" ]; then
            echo "✅ Ya tienes una API key configurada: ${current_key:0:8}..."
            echo
            read -p "¿Quieres cambiarla? (y/N): " change_key
            if [[ "$change_key" != "y" && "$change_key" != "Y" ]]; then
                echo "👍 Manteniendo la API key actual."
                exit 0
            fi
        fi
    fi
fi

echo
read -p "🔑 Pega tu API key aquí: " api_key

if [ -z "$api_key" ]; then
    echo "❌ No ingresaste ninguna API key."
    exit 1
fi

# Validar que la API key tenga el formato correcto (32 caracteres hexadecimales)
if [[ ! "$api_key" =~ ^[a-f0-9]{32}$ ]]; then
    echo "⚠️  Advertencia: La API key no tiene el formato esperado (32 caracteres hexadecimales)."
    read -p "¿Continuar de todos modos? (y/N): " continue_anyway
    if [[ "$continue_anyway" != "y" && "$continue_anyway" != "Y" ]]; then
        exit 1
    fi
fi

# Crear el archivo con la API key
cat > "$API_KEY_FILE" << EOF
# Configuración de OpenWeatherMap API
# Archivo generado automáticamente el $(date)

API_KEY=$api_key
EOF

chmod 600 "$API_KEY_FILE"  # Solo el usuario puede leer/escribir

echo "✅ API key configurada correctamente."
echo
echo "🧪 Probando la conexión con OpenWeatherMap..."

# Probar la API key
test_result=$(curl -s "https://api.openweathermap.org/data/2.5/weather?id=3114397&appid=${api_key}&units=metric" --connect-timeout 10 --max-time 15)

if echo "$test_result" | grep -q '"cod":200'; then
    echo "🎉 ¡Perfecto! La API key funciona correctamente."
    echo
    echo "Probando el widget de clima..."
    "$HOME"/.config/waybar/scripts/weather.sh
else
    error_msg=$(echo "$test_result" | jq -r '.message // "Error desconocido"' 2>/dev/null || echo "Error desconocido")
    echo "❌ Error al probar la API key: $error_msg"
    echo
    echo "Posibles causas:"
    echo "- API key incorrecta"
    echo "- API key aún no activada (puede tardar hasta 2 horas)"
    echo "- Problema de conexión a internet"
fi

echo
echo "📍 El widget está configurado para Paracuellos de Jarama, Madrid."
echo "📱 Reinicia Waybar para ver los cambios: pkill waybar && waybar &"
