#!/bin/bash

# Script to optimize Hyprland performance
# Works on both modern Hyprland Lua (0.55+) and legacy Hyprland (<0.55)

hypr_eval_ok() {
    local lua="$1"
    local out
    out=$(hyprctl eval "$lua" 2>&1) || return 1
    case "$out" in
        *error*|*unknown*|*"legacy parsers"*|"") return 1 ;;
    esac
    return 0
}

optimize() {
    if ! hypr_eval_ok 'hl.config({ decoration = { blur = { enabled = false }, shadow = { enabled = false } }, misc = { vrr = 1 }, debug = { vfr = true }, render = { direct_scanout = 1 } })'; then
        hyprctl --batch "\
            keyword decoration:blur:enabled 0;\
            keyword decoration:shadow:enabled 0;\
            keyword misc:vrr 1;\
            keyword debug:vfr 1;\
            keyword render:direct_scanout 1" >/dev/null 2>&1 || true
    fi
    notify-send "Performance Optimization" "Maximum responsiveness enabled" 2>/dev/null || true
}

restore() {
    hyprctl reload >/dev/null 2>&1 || true
    if command -v notch-hypr-helper >/dev/null 2>&1; then
        notch-hypr-helper apply-tweaks >/dev/null 2>&1 || true
    elif [ -x "$HOME/.local/bin/notch-hypr-helper" ]; then
        "$HOME/.local/bin/notch-hypr-helper" apply-tweaks >/dev/null 2>&1 || true
    fi
    notify-send "Performance Optimization" "Default settings restored" 2>/dev/null || true
}

if [[ "${1:-}" == "restore" ]]; then
    restore
else
    optimize
fi
