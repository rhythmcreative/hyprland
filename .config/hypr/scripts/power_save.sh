#!/usr/bin/env bash
# Script to toggle power saving mode in Hyprland and powerprofilesctl
export PATH="$HOME/.local/bin:$PATH"

if [ -x "$HOME/.local/bin/toggle-powersave" ]; then
    exec "$HOME/.local/bin/toggle-powersave" "${1:-toggle}"
fi

STATUS_FILE="/tmp/hyprland_power_save"

hypr_eval_ok() {
    local lua="$1"
    local out
    out=$(hyprctl eval "$lua" 2>&1) || return 1
    case "$out" in
        *error*|*unknown*|*"legacy parsers"*|"") return 1 ;;
    esac
    return 0
}

enable_power_save() {
    if ! hypr_eval_ok 'hl.config({ animations = { enabled = false }, decoration = { shadow = { enabled = false }, blur = { enabled = false } }, general = { gaps_in = 0, gaps_out = 0, border_size = 1 } })'; then
        hyprctl --batch "\
            keyword animations:enabled 0;\
            keyword decoration:shadow:enabled 0;\
            keyword decoration:blur:enabled 0;\
            keyword general:gaps_in 0;\
            keyword general:gaps_out 0;\
            keyword general:border_size 1" >/dev/null 2>&1 || true
    fi
    notify-send "Power Saving" "Animations and blur disabled" -i battery-low 2>/dev/null || true
    touch "$STATUS_FILE"
}

disable_power_save() {
    hyprctl reload >/dev/null 2>&1 || true
    notify-send "Power Saving" "Normal mode restored" -i battery-full 2>/dev/null || true
    rm -f "$STATUS_FILE"
}

if [[ "${1:-}" == "on" ]]; then
    enable_power_save
elif [[ "${1:-}" == "off" ]]; then
    disable_power_save
else
    if [[ -f "$STATUS_FILE" ]]; then
        disable_power_save
    else
        enable_power_save
    fi
fi
