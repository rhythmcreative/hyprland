#!/bin/bash

# Obtener el dispositivo de salida actual
current_sink=$(pactl get-default-sink)
sink_info=$(pactl list sinks | grep -A 20 "Name: $current_sink")

# Obtener descripción del dispositivo
description=$(echo "$sink_info" | grep "Description:" | cut -d':' -f2- | xargs)

# Detectar tipo de dispositivo y mostrar icono apropiado
if echo "$description" | grep -qi "headphone\|headset\|auricular"; then
    echo '{"text": "🎧", "tooltip": "Auriculares: '"$description"'", "class": "headphones"}'
elif echo "$description" | grep -qi "bluetooth"; then
    # Verificar si es un dispositivo bluetooth tipo auriculares
    if echo "$description" | grep -qi "wh-\|wf-\|airpods\|buds\|beats"; then
        echo '{"text": "🎧", "tooltip": "Auriculares Bluetooth: '"$description"'", "class": "headphones-bt"}'
    else
        echo '{"text": "🔊", "tooltip": "Altavoz Bluetooth: '"$description"'", "class": "speaker-bt"}'
    fi
elif echo "$description" | grep -qi "speaker\|altavoz"; then
    echo '{"text": "🔊", "tooltip": "Altavoz: '"$description"'", "class": "speaker"}'
else
    echo '{"text": "🔊", "tooltip": "Audio: '"$description"'", "class": "default"}'
fi
