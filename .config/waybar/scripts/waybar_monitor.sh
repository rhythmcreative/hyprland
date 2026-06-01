#!/bin/bash

# Script para monitorear el uso de memoria de waybar y reiniciarlo si es necesario
MAX_MEMORY_MB=200  # Límite de memoria en MB
LOG_FILE="$HOME/.cache/waybar_monitor.log"
PID_FILE="$HOME/.cache/waybar.pid"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

get_waybar_memory() {
    local waybar_pid=$(pgrep -x waybar)
    if [[ -n "$waybar_pid" ]]; then
        # Obtener memoria en KB y convertir a MB
        local mem_kb=$(ps -o rss= -p "$waybar_pid" 2>/dev/null | tr -d ' ')
        if [[ -n "$mem_kb" && "$mem_kb" =~ ^[0-9]+$ ]]; then
            echo $((mem_kb / 1024))
        else
            echo 0
        fi
    else
        echo 0
    fi
}

restart_waybar() {
    log_message "Reiniciando waybar debido a alto uso de memoria"
    
    # Matar waybar suavemente primero
    pkill -TERM waybar
    sleep 2
    
    # Si aún existe, forzar la terminación
    pkill -KILL waybar
    sleep 1
    
    # Limpiar procesos zombie
    pkill -f "waybar.*scripts"
    
    # Esperar un momento antes de reiniciar
    sleep 2
    
    # Reiniciar waybar
    waybar &
    echo $! > "$PID_FILE"
    
    log_message "Waybar reiniciado exitosamente"
}

main() {
    local current_memory=$(get_waybar_memory)
    
    if [[ $current_memory -gt $MAX_MEMORY_MB ]]; then
        log_message "Waybar usando ${current_memory}MB (límite: ${MAX_MEMORY_MB}MB)"
        restart_waybar
    fi
    
    # Limpiar logs antiguos (más de 7 días)
    find "$(dirname "$LOG_FILE")" -name "waybar_monitor.log*" -mtime +7 -delete 2>/dev/null
}

# Crear directorio cache si no existe
mkdir -p "$(dirname "$LOG_FILE")"

main "$@"
