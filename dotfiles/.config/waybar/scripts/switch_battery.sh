#!/bin/bash

WAYBAR_CONFIG="$HOME/.config/waybar/config"
if [ ! -f "$WAYBAR_CONFIG" ]; then
    notify-send "Waybar" "Config file not found!"
    exit 1
fi

# Detect current mode using jq to check modules-right list
CURRENT_MODE=$(jq -r '.["modules-right"] | if any(. == "custom/dual-battery") then "dual" elif any(. == "battery") then "single" else "pcmode" end' "$WAYBAR_CONFIG")

echo "Detected mode: $CURRENT_MODE"

# Cycle to next mode: Single -> Dual -> PC Mode -> Single
if [[ "$CURRENT_MODE" == "single" ]]; then
    NEXT_MODE="dual"
    echo "Switching to Dual Battery Mode..."
    notify-send "Waybar" "Switching to Dual Battery Mode..." || true
    
    # Apply Dual Battery
    # Apply Dual Battery
    jq '.["modules-right"] |= (map(if . == "battery" then ["custom/dual-battery"] else [.] end) | flatten)' "$WAYBAR_CONFIG" > "$WAYBAR_CONFIG.tmp" && mv "$WAYBAR_CONFIG.tmp" "$WAYBAR_CONFIG"
    # Ensure custom/dual-battery is defined (it should be in config already, but just in case we don't need to add dynamic definitions like before)

elif [[ "$CURRENT_MODE" == "dual" ]]; then
    NEXT_MODE="pcmode"
    echo "Switching to PC Mode (No Battery)..."
    notify-send "Waybar" "Switching to PC Mode (No Battery)..." || true

    # Apply PC Mode
    jq '.["modules-right"] |= map(select(. != "battery" and . != "custom/dual-battery"))' "$WAYBAR_CONFIG" > "$WAYBAR_CONFIG.tmp" && mv "$WAYBAR_CONFIG.tmp" "$WAYBAR_CONFIG"
    # jq 'del(."battery#bat1", ."battery#bat2")' "$WAYBAR_CONFIG" > "$WAYBAR_CONFIG.tmp" && mv "$WAYBAR_CONFIG.tmp" "$WAYBAR_CONFIG"

else
    NEXT_MODE="single"
    echo "Switching to Single Battery Mode..."
    notify-send "Waybar" "Switching to Single Battery Mode..." || true

    # Apply Single Battery
    # Add 'battery' back to modules-right if it's missing. 
    # We want to put it after backlight if possible.
    jq 'if (.["modules-right"] | index("backlight")) then .["modules-right"] |= (reduce .[] as $item ([]; if $item == "backlight" then . + [$item, "battery"] else . + [$item] end)) else .["modules-right"] += ["battery"] end' "$WAYBAR_CONFIG" > "$WAYBAR_CONFIG.tmp" && mv "$WAYBAR_CONFIG.tmp" "$WAYBAR_CONFIG"
fi

# Reload Waybar
pkill -SIGUSR2 waybar
