#!/bin/bash

# --- Robust Waybar Launcher ---
WAYBAR_DIR="$HOME/.config/waybar"
STATE_FILE="$WAYBAR_DIR/vertical_state"
LOG_FILE="$HOME/.cache/waybar-launch.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

echo "--- Launching Waybar at $(date) ---" >> "$LOG_FILE"

# 1. Kill existing waybar instances aggressively
echo "Stopping existing waybar processes..." >> "$LOG_FILE"
pkill -9 waybar || true
pkill -f "waybar/scripts" || true

# Wait for process to fully release resources
sleep 0.5

# 2. Handle configuration based on state
CONFIG="$WAYBAR_DIR/config"
STYLE="$WAYBAR_DIR/style.css"

if [ -f "$STATE_FILE" ]; then
    echo "Using vertical state configuration..." >> "$LOG_FILE"
    [ -f "$WAYBAR_DIR/config-vertical" ] && CONFIG="$WAYBAR_DIR/config-vertical"
    [ -f "$WAYBAR_DIR/style-vertical.css" ] && STYLE="$WAYBAR_DIR/style-vertical.css"
fi

# 3. Launch with logging
echo "Starting Waybar with config: $CONFIG and style: $STYLE" >> "$LOG_FILE"

# Small delay to ensure display and IPC are ready
sleep 0.2

# Check and auto-detect Wayland and Hyprland environment if missing
if [ -z "$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi
if [ -z "$WAYLAND_DISPLAY" ]; then
    export WAYLAND_DISPLAY=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name "wayland-[0-9]*" ! -name "*.lock" -printf "%f\n" 2>/dev/null | head -n 1)
    [ -z "$WAYLAND_DISPLAY" ] && export WAYLAND_DISPLAY="wayland-1"
fi
if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -n 1)
fi

waybar -c "$CONFIG" -s "$STYLE" >> "$LOG_FILE" 2>&1 &

NEW_PID=$!
echo "Waybar launched with PID: $NEW_PID" >> "$LOG_FILE"

# Verification
sleep 1
if pgrep -x waybar > /dev/null; then
    echo "Waybar is running successfully." >> "$LOG_FILE"
else
    echo "ERROR: Waybar failed to start. Check the logs above." >> "$LOG_FILE"
fi
