#!/bin/bash
# Fast battery status for hyprlock (<2ms, 0 latency, no emojis)

BATTERY_PATH="/sys/class/power_supply/BAT0"

if [[ -f "$BATTERY_PATH/capacity" ]]; then
    capacity=$(cat "$BATTERY_PATH/capacity")
    status=$(cat "$BATTERY_PATH/status")
    
    prefix="BAT"
    if [[ "$status" == "Charging" ]]; then
        prefix="CHG"
    fi
    
    echo "[$prefix] $capacity%"
else
    echo ""
fi
