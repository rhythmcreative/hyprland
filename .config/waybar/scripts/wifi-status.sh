#!/bin/bash

# Obtener el estado de la conexión WiFi
wifi_status=$(nmcli -t -f WIFI general)
connection_status=$(nmcli -t -f STATE general)

# Verificar si WiFi está habilitado
if [ "$wifi_status" = "enabled" ]; then
    # Obtener información de la conexión activa
    active_connection=$(nmcli -t -f NAME,TYPE connection show --active | grep wireless | cut -d: -f1)
    signal_strength=$(nmcli -t -f IN-USE,SIGNAL dev wifi | grep '\*' | cut -d: -f2)
    
    if [ -n "$active_connection" ] && [ "$connection_status" = "connected (global)" ]; then
        # Conectado a WiFi - mostrar ícono según la intensidad de señal
        if [ -n "$signal_strength" ]; then
            if [ "$signal_strength" -ge 80 ]; then
                icon="󰤨"  # Señal excelente
            elif [ "$signal_strength" -ge 60 ]; then
                icon="󰤥"  # Señal buena
            elif [ "$signal_strength" -ge 40 ]; then
                icon="󰤢"  # Señal regular
            elif [ "$signal_strength" -ge 20 ]; then
                icon="󰤟"  # Señal débil
            else
                icon="󰤯"  # Señal muy débil
            fi
            tooltip="Connected to: $active_connection\nSignal: $signal_strength%"
        else
            icon="󰤢"  # Conectado pero sin información de señal
            tooltip="Connected to: $active_connection"
        fi
        class="connected"
    else
        # WiFi habilitado pero no conectado
        icon="󰤭"
        tooltip="WiFi enabled - Not connected"
        class="disconnected"
    fi
else
    # WiFi deshabilitado
    icon="󰤮"
    tooltip="WiFi disabled"
    class="disabled"
fi

# Salida en formato JSON para waybar
echo "{\"text\":\"$icon\", \"tooltip\":\"$tooltip\", \"class\":\"$class\"}"
