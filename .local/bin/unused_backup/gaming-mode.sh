#!/bin/bash

# Gaming Mode - Optimización de rendimiento para juegos

# Función para mostrar notificaciones
notify() {
    notify-send -t 3000 -i "applications-games" "Gaming Mode" "$1"
}

# Verificar si el modo gaming ya está activo
GAMING_PID_FILE="/tmp/gaming-mode.pid"

if [ -f "$GAMING_PID_FILE" ]; then
    # Desactivar modo gaming
    kill $(cat "$GAMING_PID_FILE") 2>/dev/null
    rm -f "$GAMING_PID_FILE"
    
    # Restaurar configuraciones normales
    notify "Desactivando modo gaming..."
    
    # Restaurar CPU governor
    echo "powersave" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1
    
    # Restaurar prioridades de procesos
    sudo sysctl kernel.sched_rt_period_us=1000000 >/dev/null 2>&1
    sudo sysctl kernel.sched_rt_runtime_us=950000 >/dev/null 2>&1
    
    # Reactivar servicios no esenciales
    systemctl --user start evolution-data-server.service 2>/dev/null
    
    notify "Modo gaming desactivado - Configuración normal restaurada"
else
    # Activar modo gaming
    notify "Activando modo gaming..."
    
    # Configurar CPU para máximo rendimiento
    echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1
    
    # Optimizar scheduler para gaming
    sudo sysctl kernel.sched_rt_period_us=1000000 >/dev/null 2>&1
    sudo sysctl kernel.sched_rt_runtime_us=990000 >/dev/null 2>&1
    
    # Deshabilitar servicios no esenciales temporalmente
    systemctl --user stop evolution-data-server.service 2>/dev/null
    
    # Crear archivo PID para tracking
    echo $$ > "$GAMING_PID_FILE"
    
    notify "Modo gaming activado - Máximo rendimiento configurado"
    
    # Mantener el script corriendo para poder desactivar el modo
    while [ -f "$GAMING_PID_FILE" ]; do
        sleep 10
    done
fi
