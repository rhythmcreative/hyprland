#!/bin/bash
# Temperatura de la CPU para Waybar, con el sensor resuelto en ejecucion.
#
# POR QUE NO PUEDE SER UN hwmon-path FIJO
# --------------------------------------
# Waybar permite fijar "hwmon-path": "/sys/class/hwmon/hwmon5/temp1_input", y
# eso es lo que hacia la config. El problema es que hwmonN no es un sensor: es
# un indice, y el orden depende del orden de carga de los drivers. Medido en
# esta maquina:
#
#     hwmon5  = acpitz     (zona termica ACPI)
#     hwmon7  = thinkpad   (sensor del portatil)
#     hwmon10 = coretemp   (la CPU de verdad)
#
# Asi que el hwmon5 fijo no daba la CPU: daba la zona ACPI, que en un portatil
# marca practicamente lo mismo que la CPU pero por casualidad, no por diseno. Y
# en otra maquina hwmon5 puede ser la NVMe, o no existir, y el modulo se
# quedaba vacio sin avisar. Este mismo problema lo tenia la version anterior de
# este script, que probaba hwmon7 y luego hwmon4.
#
# Que se busca, por orden, y el primero que exista gana:
#
#   1. coretemp / k10temp / zenpower  -> el driver de la CPU
#   2. cpu_thermal / soc_thermal      -> ARM y algunos Qualcomm
#   3. thinkpad / thinkpad_cpu        -> el sensor de ThinkPad, que va al nucleo
#   4. acpitz                          -> ultimo recurso, zona termica ACPI
#
# La lectura va por label, no por indice temp1: un mismo chip puede exponer
# Package id 0 e id 1, y temp1 no siempre es el paquete.

# El nombre del sensor esta en el fichero "name" de cada hwmon. Se recorren
# todos y se elige el primero cuyo nombre coincida con la lista de prioridad.
resolve_sensor() {
    local dir nombre
    for dir in /sys/class/hwmon/hwmon*; do
        [ -r "$dir/name" ] || continue
        nombre=$(cat "$dir/name" 2>/dev/null || true)
        [ -n "$nombre" ] || continue
        case "$nombre" in
            coretemp|k10temp|zenpower|cpu_thermal|soc_thermal|thinkpad|thinkpad_cpu|acpitz)
                # Por temperatura y no por temp1: ver arriba.
                local lbl
                for lbl in "$dir"/temp*_label; do
                    if [ -r "$lbl" ]; then
                        local texto
                        texto=$(cat "$lbl" 2>/dev/null || true)
                        case "$texto" in
                            *Package*|*Core*|*Tdie*|*CPU*|"" )
                                echo "${lbl%_label}_input"
                                return 0
                                ;;
                        esac
                    fi
                done
                # Sin labels: temp1 es la mejor apuesta dentro de este sensor.
                if [ -r "$dir/temp1_input" ]; then
                    echo "$dir/temp1_input"
                    return 0
                fi
                ;;
        esac
    done
    return 1
}

SENSOR=$(resolve_sensor)

if [ -z "$SENSOR" ] || [ ! -r "$SENSOR" ]; then
    echo '{"text":"󰔏 N/A","tooltip":"No CPU temperature sensor found","class":"cpu-error"}'
    exit 0
fi

cpu_temp_raw=$(cat "$SENSOR" 2>/dev/null || true)
if [ -z "$cpu_temp_raw" ]; then
    echo '{"text":"󰔏 N/A","tooltip":"Could not read '"$SENSOR"'","class":"cpu-error"}'
    exit 0
fi

cpu_temp=$(echo "$cpu_temp_raw" | awk '{print int($1/1000)}')

if [ "$cpu_temp" -ge 85 ]; then
    icon="󰸁"; class="cpu-critical"; tooltip="CPU: ${cpu_temp}°C (high)"
elif [ "$cpu_temp" -ge 70 ]; then
    icon="󰔏"; class="cpu-hot"; tooltip="CPU: ${cpu_temp}°C (warm)"
else
    icon="󰔏"; class="cpu-normal"; tooltip="CPU: ${cpu_temp}°C"
fi

echo "{\"text\":\"${icon} ${cpu_temp}°C\",\"tooltip\":\"${tooltip}\",\"class\":\"${class}\"}"