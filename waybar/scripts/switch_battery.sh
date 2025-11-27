#!/bin/bash

SCRIPT_DIR="$HOME/.config/waybar/scripts"
CURRENT_LINK="$SCRIPT_DIR/current_battery.sh"
SINGLE_SCRIPT="$SCRIPT_DIR/single_battery.sh"
DUAL_SCRIPT="$SCRIPT_DIR/dual_battery_real.sh"

# Check what the link currently points to
if [ -L "$CURRENT_LINK" ]; then
    TARGET=$(readlink "$CURRENT_LINK")
    if [[ "$TARGET" == "$SINGLE_SCRIPT" ]]; then
        ln -sf "$DUAL_SCRIPT" "$CURRENT_LINK"
        notify-send "Waybar" "Switched to Dual Battery Mode"
    else
        ln -sf "$SINGLE_SCRIPT" "$CURRENT_LINK"
        notify-send "Waybar" "Switched to Single Battery Mode"
    fi
else
    # Default to single if link doesn't exist
    ln -sf "$SINGLE_SCRIPT" "$CURRENT_LINK"
    notify-send "Waybar" "Initialized Single Battery Mode"
fi

# Reload Waybar to apply changes immediately (optional, usually waybar updates custom modules on interval)
# pkill -SIGUSR2 waybar # Reload config
