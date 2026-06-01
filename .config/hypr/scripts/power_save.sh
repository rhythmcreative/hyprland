#!/bin/bash

# Script to toggle power saving mode in Hyprland
# usage: power_save.sh [on|off]

STATUS_FILE="/tmp/hyprland_power_save"

enable_power_save() {
    hyprctl --batch "\
        keyword animations:enabled 0;\
        keyword decoration:drop_shadow 0;\
        keyword decoration:blur:enabled 0;\
        keyword general:gaps_in 0;\
        keyword general:gaps_out 0;\
        keyword general:border_size 1"
    notify-send "Power Saving" "Animations and blur disabled" -i battery-low
    touch "$STATUS_FILE"
}

disable_power_save() {
    hyprctl reload
    notify-send "Power Saving" "Normal mode restored" -i battery-full
    rm -f "$STATUS_FILE"
}

if [[ "$1" == "on" ]]; then
    enable_power_save
elif [[ "$1" == "off" ]]; then
    disable_power_save
else
    if [[ -f "$STATUS_FILE" ]]; then
        disable_power_save
    else
        enable_power_save
    fi
fi
