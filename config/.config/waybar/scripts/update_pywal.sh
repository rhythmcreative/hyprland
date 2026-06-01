#!/bin/bash

# Script to update Waybar when pywal colors change
# This should be called after wal -i command

# Wait a moment for pywal to finish generating colors
sleep 1

# Restart waybar to apply new colors
killall waybar 2>/dev/null
waybar &

echo "Waybar colors updated with pywal!"
