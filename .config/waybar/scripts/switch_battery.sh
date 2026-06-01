#!/bin/bash

WAYBAR_CONFIG="$HOME/.config/waybar/config"
if [ ! -f "$WAYBAR_CONFIG" ]; then
    notify-send "Waybar" "Config file not found!"
    exit 1
fi

# Detect current mode
# We check which modules are present in modules-right
CURRENT_RIGHT=$(jq -r '.["modules-right"]' "$WAYBAR_CONFIG")

HAS_SINGLE=$(echo "$CURRENT_RIGHT" | grep -q "\"battery\"" && echo "true" || echo "false")
HAS_DUAL=$(echo "$CURRENT_RIGHT" | grep -q "\"custom/dual-battery\"" && echo "true" || echo "false")

echo "Status: Single=$HAS_SINGLE, Dual=$HAS_DUAL"

# Transitions:
# 1. If has Dual -> Switch to PC Mode (Remove both)
# 2. If has neither -> Switch to Single (Add battery)
# 3. If has Single -> Switch to Dual (Replace battery with dual)

if [ "$HAS_DUAL" == "true" ]; then
    echo "Mode: Dual -> PC Mode"
    notify-send "Energía" "Modo PC (Sin batería en barra)" -i battery
    jq '.["modules-right"] |= map(select(. != "battery" and . != "custom/dual-battery"))' "$WAYBAR_CONFIG" > "$WAYBAR_CONFIG.tmp"
elif [ "$HAS_SINGLE" == "false" ]; then
    echo "Mode: PC -> Single"
    notify-send "Energía" "Modo Batería Simple" -i battery
    # Add 'battery' after 'custom/battery-mode'
    jq '.["modules-right"] |= (reduce .[] as $item ([]; if $item == "custom/battery-mode" then . + [$item, "battery"] else . + [$item] end))' "$WAYBAR_CONFIG" > "$WAYBAR_CONFIG.tmp"
else
    echo "Mode: Single -> Dual"
    notify-send "Energía" "Modo Batería Dual (Thinkpad/ASUS)" -i battery
    # Replace 'battery' with 'custom/dual-battery'
    jq '.["modules-right"] |= map(if . == "battery" then "custom/dual-battery" else . end)' "$WAYBAR_CONFIG" > "$WAYBAR_CONFIG.tmp"
fi

mv "$WAYBAR_CONFIG.tmp" "$WAYBAR_CONFIG"

# Reload Waybar
pkill -SIGUSR2 waybar || hyprctl dispatch exec "$HOME/.config/waybar/launch.sh"
