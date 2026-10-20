#!/bin/bash

# Script to optimize Hyprland performance
# This script applies settings for maximum responsiveness

optimize() {
    hyprctl --batch "\
        keyword general:no_border_on_floating 1;\
        keyword decoration:blur:enabled 0;\
        keyword decoration:shadow:enabled 0;\
        keyword decoration:drop_shadow 0;\
        keyword misc:vfr 1;\
        keyword misc:vrr 1;\
        keyword misc:no_direct_scanout 0"
    local title body
    title=$(hypr-i18n perf.opt_title 2>/dev/null)
    [ -z "$title" ] && title="Performance Optimization"
    body=$(hypr-i18n perf.opt_max 2>/dev/null)
    [ -z "$body" ] && body="Maximum responsiveness enabled"
    notify-send "$title" "$body"
}

restore() {
    hyprctl reload
    if command -v notch-hypr-helper >/dev/null 2>&1; then
        notch-hypr-helper apply-tweaks >/dev/null 2>&1 || true
    fi
    local title body
    title=$(hypr-i18n perf.opt_title 2>/dev/null)
    [ -z "$title" ] && title="Performance Optimization"
    body=$(hypr-i18n perf.opt_restored 2>/dev/null)
    [ -z "$body" ] && body="Default settings restored"
    notify-send "$title" "$body"
}

if [[ "$1" == "restore" ]]; then
    restore
else
    optimize
fi
