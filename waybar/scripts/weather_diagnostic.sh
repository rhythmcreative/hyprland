#!/bin/bash

# Script de diagnóstico para el módulo de clima de waybar
echo "=== DIAGNÓSTICO DEL MÓDULO DE CLIMA DE WAYBAR ==="
echo "Fecha/Hora: $(date)"
echo ""

# Verificar que waybar está funcionando
echo "1. Verificando waybar:"
if pgrep waybar > /dev/null; then
    echo "   ✅ Waybar está ejecutándose (PID: $(pgrep waybar))"
else
    echo "   ❌ Waybar NO está ejecutándose"
fi
echo ""

# Verificar conectividad a wttr.in
echo "2. Verificando conectividad con wttr.in:"
if curl -s --connect-timeout 5 "https://wttr.in" > /dev/null; then
    echo "   ✅ Conectividad con wttr.in OK"
    echo "   📍 Clima actual simple: $(curl -s --connect-timeout 5 'https://wttr.in/Paracuellos+de+Jarama,Madrid,Spain?format=%C+%t')"
else
    echo "   ❌ Sin conectividad con wttr.in"
fi
echo ""

# Verificar script de clima
echo "3. Probando script de clima:"
WEATHER_SCRIPT="/home/rhythmcreative/.config/waybar/scripts/weather.sh"

if [ -f "$WEATHER_SCRIPT" ]; then
    echo "   ✅ Script encontrado: $WEATHER_SCRIPT"
    
    if [ -x "$WEATHER_SCRIPT" ]; then
        echo "   ✅ Script es ejecutable"
        
        echo "   🔄 Ejecutando script..."
        RESULT=$(bash "$WEATHER_SCRIPT" 2>&1)
        EXIT_CODE=$?
        
        if [ $EXIT_CODE -eq 0 ]; then
            echo "   ✅ Script ejecutado exitosamente"
            echo "   📄 Salida JSON:"
            echo "$RESULT" | jq . 2>/dev/null || echo "$RESULT"
        else
            echo "   ❌ Script falló con código de salida: $EXIT_CODE"
            echo "   📄 Error:"
            echo "$RESULT"
        fi
    else
        echo "   ❌ Script no es ejecutable"
        echo "   🔧 Ejecutando: chmod +x $WEATHER_SCRIPT"
        chmod +x "$WEATHER_SCRIPT"
    fi
else
    echo "   ❌ Script NO encontrado en: $WEATHER_SCRIPT"
fi
echo ""

# Verificar cache del clima
echo "4. Verificando cache del clima:"
CACHE_FILE="$HOME/.cache/waybar_weather_paracuellos.json"

if [ -f "$CACHE_FILE" ]; then
    echo "   ✅ Cache encontrado: $CACHE_FILE"
    echo "   📅 Última modificación: $(stat -c %y "$CACHE_FILE")"
    
    if [ -s "$CACHE_FILE" ]; then
        echo "   📄 Contenido del cache:"
        cat "$CACHE_FILE" | jq . 2>/dev/null || cat "$CACHE_FILE"
    else
        echo "   ⚠️  Cache está vacío"
    fi
else
    echo "   ⚠️  Cache no encontrado (se creará en la primera ejecución)"
fi
echo ""

# Verificar configuración de waybar
echo "5. Verificando configuración de waybar:"
WAYBAR_CONFIG="/home/rhythmcreative/.config/waybar/config"

if [ -f "$WAYBAR_CONFIG" ]; then
    echo "   ✅ Configuración encontrada: $WAYBAR_CONFIG"
    
    if grep -q "custom/weather" "$WAYBAR_CONFIG"; then
        echo "   ✅ Módulo 'custom/weather' configurado en waybar"
        
        # Mostrar configuración del módulo de clima
        echo "   📄 Configuración del módulo de clima:"
        grep -A 6 '"custom/weather"' "$WAYBAR_CONFIG" | sed 's/^/     /'
    else
        echo "   ❌ Módulo 'custom/weather' NO encontrado en la configuración"
    fi
else
    echo "   ❌ Configuración de waybar no encontrada"
fi
echo ""

# Verificar dependencias
echo "6. Verificando dependencias:"
DEPS=("curl" "jq")

for dep in "${DEPS[@]}"; do
    if command -v "$dep" > /dev/null; then
        echo "   ✅ $dep: $(command -v $dep)"
    else
        echo "   ❌ $dep: NO INSTALADO"
    fi
done
echo ""

echo "=== FIN DEL DIAGNÓSTICO ==="

# Si hay algún problema, ofrecer solución
if ! pgrep waybar > /dev/null; then
    echo ""
    echo "🔧 SOLUCIÓN SUGERIDA:"
    echo "   Waybar no está funcionando. Reinicia waybar con:"
    echo "   pkill waybar && waybar &"
fi
