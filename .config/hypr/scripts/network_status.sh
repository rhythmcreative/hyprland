#!/bin/bash

# Script para mostrar estado de red en hyprlock

# Verificar conectividad
if ping -c 1 -W 1 8.8.8.8 &>/dev/null; then
    # Obtener interfaz activa
    interface=$(ip route | grep '^default' | head -n1 | awk '{print $5}')
    
    if [[ -n "$interface" ]]; then
        if [[ "$interface" =~ ^wl ]]; then
            # WiFi
            ssid=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)
            if [[ -n "$ssid" ]]; then
                echo "📶 $ssid"
            else
                echo "📶 WiFi"
            fi
        else
            # Ethernet
            echo "🔌 Ethernet"
        fi
    else
        echo "🌐 Conectado"
    fi
else
    echo "❌ Sin conexión"
fi
