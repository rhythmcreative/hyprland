#!/bin/bash
# auto-battery-setup.sh - Automatic power and battery detection for Waybar
# Detects whether the system is a desktop PC (0 batteries), standard laptop (1 battery),
# or dual-battery laptop (e.g. ThinkPad T480 with BAT0 and BAT1).

WAYBAR_DIR="$HOME/.config/waybar"
CONFIG="$WAYBAR_DIR/config"

# Detect real system batteries (exclude peripheral devices like wireless mice)
BATS=()
for b in /sys/class/power_supply/*; do
    [ -d "$b" ] || continue
    if [ -f "$b/type" ] && grep -qi "battery" "$b/type"; then
        if [ -f "$b/scope" ] && grep -qi "device" "$b/scope"; then
            continue
        fi
        BATS+=("$(basename "$b")")
    fi
done

NUM_BATS=${#BATS[@]}

# Update all waybar configs (base config and any per-monitor config-* files)
for cfg in "$CONFIG" "$WAYBAR_DIR"/config-*; do
    [ -f "$cfg" ] || continue
    
    # Clean existing power/battery modules from modules-right
    CLEAN_CONFIG=$(jq '.["modules-right"] |= map(select(. != "battery" and . != "battery#bat0" and . != "battery#bat1" and . != "custom/desktop-power" and . != "custom/dual-battery"))' "$cfg" 2>/dev/null)
    
    if [ -n "$CLEAN_CONFIG" ] && echo "$CLEAN_CONFIG" | jq . >/dev/null 2>&1; then
        if [ "$NUM_BATS" -ge 2 ]; then
            # Dual battery mode (ThinkPad / Asus)
            FINAL_CONFIG=$(echo "$CLEAN_CONFIG" | jq '.["modules-right"] += ["battery#bat0", "battery#bat1"]')
        elif [ "$NUM_BATS" -eq 1 ]; then
            # Single battery mode (standard laptop)
            FINAL_CONFIG=$(echo "$CLEAN_CONFIG" | jq '.["modules-right"] += ["battery"]')
        else
            # Desktop PC mode (no battery)
            FINAL_CONFIG=$(echo "$CLEAN_CONFIG" | jq '.["modules-right"] += ["custom/desktop-power"]')
        fi
        
        if [ -n "$FINAL_CONFIG" ] && echo "$FINAL_CONFIG" | jq . >/dev/null 2>&1; then
            echo "$FINAL_CONFIG" > "$cfg"
        fi
    fi
done
