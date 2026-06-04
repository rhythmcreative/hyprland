#!/bin/bash

# 🔋 Script de Batería Dinámico Inteligente (v3 - Desktop aware)
# Detecta automáticamente 0, 1, 2 o más baterías.
# Si no hay batería, muestra el icono de corriente/sobremesa sin texto.

# 1. Detectar todas las baterías disponibles
BATS=(/sys/class/power_supply/BAT*)
ACTUAL_BATS=()

for bat in "${BATS[@]}"; do
    if [ -d "$bat" ]; then
        ACTUAL_BATS+=("$bat")
    fi
done

NUM_BATS=${#ACTUAL_BATS[@]}

get_battery_icon() {
    local capacity=$1
    local status=$2
    if [[ "$status" == "Charging" ]]; then echo "󰂄";
    elif [[ $capacity -ge 95 ]]; then echo "󰁹";
    elif [[ $capacity -ge 80 ]]; then echo "󰂂";
    elif [[ $capacity -ge 60 ]]; then echo "󰂁";
    elif [[ $capacity -ge 40 ]]; then echo "󰂀";
    elif [[ $capacity -ge 20 ]]; then echo "󰁿";
    else echo "󰁺"; fi
}

# 2. Caso: No hay baterías (PC de Escritorio)
if [ "$NUM_BATS" -eq 0 ]; then
    # Mostrar solo el icono de CA (sin porcentaje)
    echo "{\"text\":\"󰚥\",\"tooltip\":\"Conectado a CA (Modo Sobremesa)\",\"class\":\"normal\",\"on-click\":\"true\"}"
    exit 0
fi

TOTAL_CAP=0
TEXT=""
TOOLTIP="Estado de Batería:\\n"
IS_CHARGING=false

# 3. Procesar cada batería encontrada
for i in "${!ACTUAL_BATS[@]}"; do
    BAT_PATH="${ACTUAL_BATS[$i]}"
    BAT_NAME=$(basename "$BAT_PATH")
    CAP=$(cat "$BAT_PATH/capacity" 2>/dev/null || echo "0")
    STAT=$(cat "$BAT_PATH/status" 2>/dev/null || echo "Unknown")
    ICON=$(get_battery_icon "$CAP" "$STAT")
    
    TOTAL_CAP=$((TOTAL_CAP + CAP))
    [ "$STAT" == "Charging" ] && IS_CHARGING=true
    
    # Formatear texto de la barra (Icono + Porcentaje)
    if [ $i -gt 0 ]; then TEXT="$TEXT | "; fi
    TEXT="$TEXT$ICON $CAP%"
    
    # Formatear tooltip
    TOOLTIP="$TOOLTIP$BAT_NAME: $CAP% ($STAT)\\n"
done

# 4. Calcular promedio total para la clase CSS
AVG_CAP=$((TOTAL_CAP / NUM_BATS))

# 5. Definir clase CSS
if [ "$IS_CHARGING" = true ]; then CLASS="charging";
elif [ "$AVG_CAP" -le 15 ]; then CLASS="critical";
elif [ "$AVG_CAP" -le 30 ]; then CLASS="warning";
else CLASS="normal"; fi

# 6. Salida en formato JSON para Waybar
echo "{\"text\":\"$TEXT\",\"tooltip\":\"$TOOLTIP\",\"class\":\"$CLASS\",\"on-click\":\"true\"}"
