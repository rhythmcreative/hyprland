#!/usr/bin/env bash
export PATH="$HOME/.local/bin:$PATH"

if [ -x "$HOME/.local/bin/notch-hypr-helper" ]; then
    exec "$HOME/.local/bin/notch-hypr-helper" toggle-perf
else
    STATUS_FILE="/tmp/hypr_performance_mode"
    if [[ -f "$STATUS_FILE" ]]; then
        ~/.config/hypr/scripts/optimize_performance.sh restore
        rm -f "$STATUS_FILE"
    else
        ~/.config/hypr/scripts/optimize_performance.sh
        touch "$STATUS_FILE"
    fi
fi
