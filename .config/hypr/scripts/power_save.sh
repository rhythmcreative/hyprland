#!/usr/bin/env bash
# Script to toggle power saving mode in Hyprland and powerprofilesctl
export PATH="$HOME/.local/bin:$PATH"

if [ -x "$HOME/.local/bin/toggle-powersave" ]; then
    exec "$HOME/.local/bin/toggle-powersave" "${1:-toggle}"
fi

STATUS_FILE="/tmp/hyprland_power_save"

enable_power_save() {
    hyprctl --batch "\
        keyword animations:enabled 0;\
        keyword decoration:shadow:enabled 0;\
        keyword decoration:drop_shadow 0;\
        keyword decoration:blur:enabled 0;\
        keyword general:gaps_in 0;\
        keyword general:gaps_out 0;\
        keyword general:border_size 1"
    local title body
    title=$(hypr-i18n powersave.enabled_title 2>/dev/null)
    [ -z "$title" ] && title="Power Saving"
    body=$(hypr-i18n powersave.enabled_body 2>/dev/null)
    [ -z "$body" ] && body="Animations and blur disabled"
    notify-send "$title" "$body" -i battery-low
    touch "$STATUS_FILE"
}

disable_power_save() {
    hyprctl reload
    local title body
    title=$(hypr-i18n powersave.disabled_title 2>/dev/null)
    [ -z "$title" ] && title="Power Saving"
    body=$(hypr-i18n powersave.disabled_body 2>/dev/null)
    [ -z "$body" ] && body="Normal mode restored"
    notify-send "$title" "$body" -i battery-full
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
