#!/bin/bash

# Monitors battery status and enables power saving if low
# Run this in the background

LOW_BATTERY_THRESHOLD=20
STATE_FILE="/tmp/auto_power_save_state"

while true; do
    total=0
    count=0
    for f in /sys/class/power_supply/BAT*/capacity; do
        if [ -f "$f" ]; then
            cap=$(cat "$f" 2>/dev/null || echo 0)
            total=$((total + cap))
            count=$((count + 1))
        fi
    done
    if [ "$count" -eq 0 ]; then
        # No batteries present (e.g. desktop), skip
        sleep 300
        continue
    fi
    AVG_CAP=$((total / count))
    
    # Check if any battery is charging
    IS_CHARGING=0
    if grep -q "Charging" /sys/class/power_supply/BAT*/status 2>/dev/null; then
        IS_CHARGING=1
    fi

    if [[ $IS_CHARGING -eq 0 && $AVG_CAP -le $LOW_BATTERY_THRESHOLD ]]; then
        if [[ ! -f "$STATE_FILE" ]]; then
            "$HOME/.config/hypr/scripts/power_save.sh" on
            touch "$STATE_FILE"
        fi
    elif [[ $IS_CHARGING -eq 1 || $AVG_CAP -gt $LOW_BATTERY_THRESHOLD ]]; then
        if [[ -f "$STATE_FILE" ]]; then
            "$HOME/.config/hypr/scripts/power_save.sh" off
            rm -f "$STATE_FILE"
        fi
    fi
    sleep 60
done
