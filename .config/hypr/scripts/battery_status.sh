#!/bin/bash
# Fast battery status for hyprlock (<2ms, 0 latency, no emojis)

BAT_DIR=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n 1)

if [[ -n "$BAT_DIR" && -f "$BAT_DIR/capacity" ]]; then
    capacity=$(cat "$BAT_DIR/capacity" 2>/dev/null)
    status=$(cat "$BAT_DIR/status" 2>/dev/null)
    
    prefix="BAT"
    if [[ "$status" == "Charging" ]]; then
        prefix="CHG"
    fi
    
    echo "[$prefix] $capacity%"
else
    echo ""
fi
