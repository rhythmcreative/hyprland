#!/bin/bash

# Dual Battery Script (BAT0 + BAT1)

# Get capacity
BAT0_CAPACITY=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "0")
BAT1_CAPACITY=$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo "0")

# Get status
BAT0_STATUS=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "Unknown")
BAT1_STATUS=$(cat /sys/class/power_supply/BAT1/status 2>/dev/null || echo "Unknown")

get_battery_icon() {
    local capacity=$1
    local status=$2
    if [[ "$status" == "Charging" ]]; then echo "󰂄";
    elif [[ $capacity -ge 80 ]]; then echo "󰂂";
    elif [[ $capacity -ge 60 ]]; then echo "󰂁";
    elif [[ $capacity -ge 40 ]]; then echo "󰂀";
    elif [[ $capacity -ge 20 ]]; then echo "󰁿";
    else echo "󰁺"; fi
}

BAT0_ICON=$(get_battery_icon $BAT0_CAPACITY "$BAT0_STATUS")
BAT1_ICON=$(get_battery_icon $BAT1_CAPACITY "$BAT1_STATUS")

# Determine class based on average or lowest
AVG_CAPACITY=$(( (BAT0_CAPACITY + BAT1_CAPACITY) / 2 ))

if [[ $AVG_CAPACITY -le 15 ]]; then CLASS="critical";
elif [[ $AVG_CAPACITY -le 30 ]]; then CLASS="warning";
else CLASS="normal"; fi

# Output JSON
# Format: [BAT0] [BAT1]
TEXT="$BAT0_ICON ${BAT0_CAPACITY}% | $BAT1_ICON ${BAT1_CAPACITY}%"
TOOLTIP="BAT0: ${BAT0_CAPACITY}% (${BAT0_STATUS})\\nBAT1: ${BAT1_CAPACITY}% (${BAT1_STATUS})"

echo "{\"text\":\"$TEXT\",\"tooltip\":\"$TOOLTIP\",\"class\":\"$CLASS\"}"
