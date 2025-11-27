#!/bin/bash

# Single Battery Script (BAT0)

# Get capacity and status
BAT0_CAPACITY=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "0")
BAT0_STATUS=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "Unknown")

# Get energy/power for time calculation
BAT0_ENERGY_NOW=$(cat /sys/class/power_supply/BAT0/energy_now 2>/dev/null || echo "0")
BAT0_POWER_NOW=$(cat /sys/class/power_supply/BAT0/power_now 2>/dev/null || echo "1")

format_time() {
    local seconds=$1
    if [[ $seconds -le 0 ]]; then echo "N/A"; return; fi
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    if [[ $hours -gt 0 ]]; then printf "%dh %02dm" $hours $minutes; else printf "%dm" $minutes; fi
}

if [[ $BAT0_POWER_NOW -gt 0 ]] && [[ "$BAT0_STATUS" != "Charging" ]]; then
    BAT0_TIME_REMAINING=$((BAT0_ENERGY_NOW * 3600 / BAT0_POWER_NOW))
else
    BAT0_TIME_REMAINING=0
fi

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

if [[ $BAT0_CAPACITY -le 15 ]]; then CLASS="critical";
elif [[ $BAT0_CAPACITY -le 30 ]]; then CLASS="warning";
else CLASS="normal"; fi

TIME_FORMATTED=$(format_time $BAT0_TIME_REMAINING)

# Output JSON
echo "{\"text\":\"$BAT0_ICON ${BAT0_CAPACITY}%\",\"tooltip\":\"Battery: ${BAT0_CAPACITY}%\\nTime: $TIME_FORMATTED\\nStatus: ${BAT0_STATUS}\",\"class\":\"$CLASS\"}"
