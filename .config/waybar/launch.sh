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

# Check if we are in a Wayland session
if [ -z "$WAYLAND_DISPLAY" ]; then
    echo "WARNING: WAYLAND_DISPLAY is not set. Waybar might fail." >> "$LOG_FILE"
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
