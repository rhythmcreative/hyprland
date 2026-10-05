#!/bin/bash

echo "🌤️  Obteniendo tu API key de OpenWeatherMap (SÚPER FÁCIL)"
echo "========================================================"
echo
echo "Te voy a abrir la página de registro automáticamente."
echo "Solo tienes que:"
echo
echo "1️⃣  Hacer clic en 'Sign Up'"
echo "2️⃣  Llenar el formulario (2 minutos)"
echo "3️⃣  Confirmar tu email"
echo "4️⃣  Copiar tu API key"
echo
echo "💡 Es GRATIS y tardas menos de 5 minutos."
echo
read -p "🚀 ¿Abrir la página ahora? (Y/n): " open_page

if [[ "$open_page" != "n" && "$open_page" != "N" ]]; then
    # Intentar abrir con diferentes navegadores
    if command -v firefox >/dev/null 2>&1; then
        firefox "https://openweathermap.org/api" 2>/dev/null &
        echo "🌐 Abriendo Firefox..."
    elif command -v chromium >/dev/null 2>&1; then
        chromium "https://openweathermap.org/api" 2>/dev/null &
        echo "🌐 Abriendo Chromium..."
    elif command -v google-chrome >/dev/null 2>&1; then
        google-chrome "https://openweathermap.org/api" 2>/dev/null &
        echo "🌐 Abriendo Chrome..."
    elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open "https://openweathermap.org/api" 2>/dev/null &
        echo "🌐 Abriendo navegador..."
    else
        echo "❌ No pude abrir el navegador automáticamente."
        echo "📋 Copia esta URL en tu navegador:"
        echo "   https://openweathermap.org/api"
    fi
    
    echo
    echo "⏳ Esperando que obtengas tu API key..."
    echo
fi

echo "📋 Cuando tengas tu API key, pégala aquí:"
read -p "🔑 API Key: " api_key

if [ -z "$api_key" ]; then
    echo "❌ No ingresaste la API key."
    echo "💡 Ejecuta este script otra vez cuando la tengas."
    exit 1
fi

# Configurar la API key
API_KEY_FILE="$HOME/.config/waybar/openweather_api_key"

cat > "$API_KEY_FILE" << EOF
# Configuración de OpenWeatherMap API
# Configurado automáticamente el $(date)
API_KEY=$api_key
EOF

chmod 600 "$API_KEY_FILE"

echo "✅ API key guardada correctamente."
echo
echo "🧪 Probando la conexión..."

# Probar la API
test_result=$(curl -s "https://api.openweathermap.org/data/2.5/weather?id=3114397&appid=${api_key}&units=metric" --connect-timeout 10 --max-time 15)

if echo "$test_result" | grep -q '"cod":200'; then
    echo "🎉 ¡PERFECTO! Tu API key funciona."
    echo
    echo "🌡️  Datos actuales del clima:"
    temp=$(echo "$test_result" | jq -r '.main.temp' | cut -d. -f1)
    desc=$(echo "$test_result" | jq -r '.weather[0].description')
    humidity=$(echo "$test_result" | jq -r '.main.humidity')
    feels_like=$(echo "$test_result" | jq -r '.main.feels_like' | cut -d. -f1)
    
    echo "   🌡️  Temperatura: ${temp}°C"
    echo "   🌡️  Sensación: ${feels_like}°C"  
    echo "   💧 Humedad: ${humidity}%"
    echo "   ☁️  Condición: $desc"
    echo
    echo "🔄 Reiniciando Waybar..."
    pkill waybar 2>/dev/null
    sleep 1
    "$HOME/.config/waybar/launch.sh" --force > /dev/null 2>&1 &
    echo "✅ ¡Todo listo! Tu clima ya está funcionando en Waybar."
else
    echo "⚠️  Hay un problema con la API key."
    echo "Esto puede pasar si:"
    echo "- La API key es incorrecta"
    echo "- Aún no está activada (puede tardar 2 horas)"
    echo "- Hay problemas de conexión"
    echo
    echo "💡 Intenta ejecutar este script otra vez en unos minutos."
fi
