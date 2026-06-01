#!/bin/bash

# Copy the generated simple dunst config
cp ~/.cache/wal/simple-dunstrc ~/.config/dunst/dunstrc

# Kill ALL existing notification daemons
pkill swaync
pkill dunst
pkill fnott
pkill mako
pkill wob

# Wait a moment for processes to die
sleep 0.5

# Start ONLY dunst with simple elegant config
dunst &
