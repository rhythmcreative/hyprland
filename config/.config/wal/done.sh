#!/bin/bash

# This script runs after wal finishes

# Update Mako configuration
~/.config/mako/pywal-update.sh

# Update Waybar (if needed)
pkill -SIGUSR1 waybar

# Update Qt5CT configuration
~/.config/wal/scripts/qt5ct-wal.sh

# Any other post-wal commands can go here
