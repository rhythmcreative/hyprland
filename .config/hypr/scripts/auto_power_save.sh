#!/bin/bash

# Monitors battery status and enables power saving if low
# Run this in the background

LOW_BATTERY_THRESHOLD=20
STATE_FILE="/tmp/auto_power_save_state"

while true; do
    # Get combined capacity
    BAT0_CAP=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 0)
    BAT1_CAP=$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo 0)
    
    # Simple average for the trigger
    AVG_CAP=$(( (BAT0_CAP + BAT1_CAP) / 2 ))
    
    # Check if any battery is charging
    IS_CHARGING=0
    if grep -q "Charging" /sys/class/power_supply/BAT*/status 2>/dev/null; then
        IS_CHARGING=1
    fi

    if [[ $IS_CHARGING -eq 0 && $AVG_CAP -le $LOW_BATTERY_THRESHOLD ]]; then
        if [[ ! -f "$STATE_FILE" ]]; then
            /home/rhythmcreative/.config/hypr/scripts/power_save.sh on
            touch "$STATE_FILE"
        fi
    elif [[ $IS_CHARGING -eq 1 || $AVG_CAP -gt $LOW_BATTERY_THRESHOLD ]]; then
        if [[ -f "$STATE_FILE" ]]; then
            /home/rhythmcreative/.config/hypr/scripts/power_save.sh off
            rm -f "$STATE_FILE"
        fi
    fi
    sleep 60
done
