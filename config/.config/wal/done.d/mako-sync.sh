#!/bin/bash

# Auto-sync Mako with pywal colors
# This script runs automatically after pywal generates colors

# Wait a moment for colors to be fully written
sleep 0.5

# Run the sync script
~/.local/bin/sync-mako-pywal

# Optional: Send a notification about the sync
if command -v notify-send &> /dev/null; then
    notify-send -u low "Mako synchronized" "Notification colors updated with pywal theme" &
fi
