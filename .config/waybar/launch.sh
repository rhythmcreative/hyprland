#!/bin/bash

WAYBAR_DIR="$HOME/.config/waybar"
STATE_FILE="$WAYBAR_DIR/vertical_state"

# Kill existing waybar instance just in case
killall -q waybar
# Wait for waybar to terminate
while pgrep -x waybar >/dev/null; do sleep 0.1; done

# Launch waybar based on state
if [ -f "$STATE_FILE" ]; then
    waybar -c "$WAYBAR_DIR/config-vertical" -s "$WAYBAR_DIR/style-vertical.css" &
else
    waybar &
fi
