#!/bin/bash

WAYBAR_DIR="$HOME/.config/waybar"
STATE_FILE="$WAYBAR_DIR/vertical_state"

# Function to launch waybar
launch_waybar() {
    if [ -f "$STATE_FILE" ]; then
        # Launch vertical
        waybar -c "$WAYBAR_DIR/config-vertical" -s "$WAYBAR_DIR/style-vertical.css" &
    else
        # Launch horizontal
        waybar &
    fi
}

# Kill existing waybar instance
killall -q waybar
# Wait for waybar to terminate
while pgrep -x waybar >/dev/null; do sleep 0.1; done

# Toggle state
if [ -f "$STATE_FILE" ]; then
    rm "$STATE_FILE"
else
    touch "$STATE_FILE"
fi

# Launch new waybar instance
launch_waybar
