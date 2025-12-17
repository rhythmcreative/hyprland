#!/bin/bash

WAYBAR_CONFIG="$HOME/.config/waybar/config"
if [ ! -f "$WAYBAR_CONFIG" ]; then
    notify-send "Waybar" "Config file not found!"
    exit 1
fi

# Detect current mode using jq to check modules-right list
CURRENT_MODE=$(jq -r '.["modules-right"] | if any(. == "battery#bat1") and any(. == "battery#bat2") then "dual" elif any(. == "battery") then "single" else "pcmode" end' "$WAYBAR_CONFIG")

echo "Detected mode: $CURRENT_MODE"

# Cycle to next mode: Single -> Dual -> PC Mode -> Single
if [[ "$CURRENT_MODE" == "single" ]]; then
    NEXT_MODE="dual"
    echo "Switching to Dual Battery Mode..."
    notify-send "Waybar" "Switching to Dual Battery Mode..." || true
    
    # Apply Dual Battery
    jq '.["modules-right"] |= (map(if . == "battery" then ["battery#bat1", "battery#bat2"] else [.] end) | flatten)' "$WAYBAR_CONFIG" > "$WAYBAR_CONFIG.tmp" && mv "$WAYBAR_CONFIG.tmp" "$WAYBAR_CONFIG"
    jq '."battery#bat1" = (."battery" + {"bat": "BAT0"})' "$WAYBAR_CONFIG" > "$WAYBAR_CONFIG.tmp" && mv "$WAYBAR_CONFIG.tmp" "$WAYBAR_CONFIG"
    jq '."battery#bat2" = (."battery" + {"bat": "BAT1"})' "$WAYBAR_CONFIG" > "$WAYBAR_CONFIG.tmp" && mv "$WAYBAR_CONFIG.tmp" "$WAYBAR_CONFIG"

elif [[ "$CURRENT_MODE" == "dual" ]]; then
    NEXT_MODE="pcmode"
    echo "Switching to PC Mode (No Battery)..."
    notify-send "Waybar" "Switching to PC Mode (No Battery)..." || true

    # Apply PC Mode
    jq '.["modules-right"] |= map(select(. != "battery" and . != "battery#bat1" and . != "battery#bat2"))' "$WAYBAR_CONFIG" > "$WAYBAR_CONFIG.tmp" && mv "$WAYBAR_CONFIG.tmp" "$WAYBAR_CONFIG"
    jq 'del(."battery#bat1", ."battery#bat2")' "$WAYBAR_CONFIG" > "$WAYBAR_CONFIG.tmp" && mv "$WAYBAR_CONFIG.tmp" "$WAYBAR_CONFIG"

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
