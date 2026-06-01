#!/bin/bash

# Script to force GTK to load our custom CSS for nm-applet
# This runs in the background to ensure the styles are applied

# Load environment variables if they exist
[ -f "$HOME/.cache/wal/colors.sh" ] && source "$HOME/.cache/wal/colors.sh"

# Apply the GTK CSS settings
gsettings set org.gnome.desktop.interface gtk-theme "PywalGTK-Auto" 2>/dev/null || true

# Set environment variables for GTK
export GTK_THEME=PywalGTK-Auto
export GTK_CSD=0
export GTK_OVERLAY_SCROLLING=0

# If running in Wayland, set GDK backend
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    export GDK_BACKEND=wayland,x11
fi

# Send D-Bus signal to reload GTK settings
dbus-send --type=signal /org/gtk/Settings org.gtk.Settings.SettingChanged \
    string:"gtk-theme-name" string:"PywalGTK-Auto" 2>/dev/null || true

# Send CSS reload message
dbus-send --type=signal /org/gtk/Settings org.gtk.Settings.StyleUpdated 2>/dev/null || true

# Success
echo "GTK CSS settings applied successfully"
exit 0
