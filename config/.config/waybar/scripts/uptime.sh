#!/bin/bash

# Get uptime in a readable format
uptime_seconds=$(cat /proc/uptime | cut -d' ' -f1 | cut -d'.' -f1)
uptime_days=$((uptime_seconds / 86400))
uptime_hours=$(((uptime_seconds % 86400) / 3600))
uptime_minutes=$(((uptime_seconds % 3600) / 60))

if [ $uptime_days -gt 0 ]; then
    echo "󰅐 ${uptime_days}d ${uptime_hours}h"
elif [ $uptime_hours -gt 0 ]; then
    echo "󰅐 ${uptime_hours}h ${uptime_minutes}m"
else
    echo "󰅐 ${uptime_minutes}m"
fi
