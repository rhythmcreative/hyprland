#!/bin/bash

# Script to optimize Hyprland performance
# This script applies settings for maximum responsiveness

optimize() {
    hyprctl --batch "\
        keyword general:no_border_on_floating 1;\
        keyword decoration:blur:enabled 0;\
        keyword decoration:drop_shadow 0;\
        keyword misc:vfr 1;\
        keyword misc:vrr 1;\
        keyword misc:no_direct_scanout 0"
    notify-send "Performance Optimization" "Maximum responsiveness enabled"
}

restore() {
    hyprctl reload
    notify-send "Performance Optimization" "Default settings restored"
}

if [[ "$1" == "restore" ]]; then
    restore
else
    optimize
fi
