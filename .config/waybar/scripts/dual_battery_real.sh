#!/bin/bash

# 🔋 Script de Batería Dinámico Inteligente (v3 - Desktop & Multi-battery aware)
# Detecta automáticamente 0, 1, 2 o más baterías.
# Si no hay batería, muestra el icono de corriente/sobremesa sin texto.

# 1. Detectar todas las baterías disponibles (excluyendo periféricos)
ACTUAL_BATS=()
for b in /sys/class/power_supply/*; do
    [ -d "$b" ] || continue
    if [ "$(cat "$b/type" 2>/dev/null)" = "Battery" ]; then
        if [ -f "$b/scope" ] && grep -qi "device" "$b/scope"; then continue; fi
        ACTUAL_BATS+=("$b")
    fi
done

NUM_BATS=${#ACTUAL_BATS[@]}

# Detectar cargador / corriente
AC_ONLINE=0
for a in /sys/class/power_supply/*; do
    [ -d "$a" ] || continue
    atype=$(cat "$a/type" 2>/dev/null || true)
    if [ "$atype" = "Mains" ] || [ "$atype" = "USB" ] || [[ "$a" =~ (AC|ADP|ACAD) ]]; then
        if [ "$(cat "$a/online" 2>/dev/null)" = "1" ]; then
            AC_ONLINE=1
            break
        fi
    fi
done

get_battery_icon() {
    local capacity=$1
    local status=$2
    local ac_on=$3
    if [[ "$status" == "Charging" ]] || [[ "$ac_on" -eq 1 ]]; then
        echo "󰂄"
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
    ICON=$(get_battery_icon "$CAP" "$STAT" "$AC_ONLINE")

    TOTAL_CAP=$((TOTAL_CAP + CAP))
    if [ "$STAT" == "Charging" ] || [ "$AC_ONLINE" -eq 1 ]; then
        IS_CHARGING=true
    fi

    # Formatear texto de la barra (Icono + Porcentaje)
    if [ $i -gt 0 ]; then TEXT="$TEXT | "; fi
    TEXT="$TEXT$ICON $CAP%"

    # Formatear tooltip
    TOOLTIP="$TOOLTIP$BAT_NAME: $CAP% ($STAT)\\n"
done

[ "$AC_ONLINE" -eq 1 ] && TOOLTIP="${TOOLTIP}Alimentación CA: Conectado\\n"

# 4. Calcular promedio total para la clase CSS
AVG_CAP=$((TOTAL_CAP / NUM_BATS))

# 5. Definir clase CSS
if [ "$IS_CHARGING" = true ]; then CLASS="charging";
elif [ "$AVG_CAP" -le 15 ]; then CLASS="critical";
elif [ "$AVG_CAP" -le 30 ]; then CLASS="warning";
else CLASS="normal"; fi

# 6. Salida en formato JSON para Waybar
echo "{\"text\":\"$TEXT\",\"tooltip\":\"$TOOLTIP\",\"class\":\"$CLASS\",\"on-click\":\"true\"}"
