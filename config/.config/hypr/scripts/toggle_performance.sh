#!/bin/bash
STATUS_FILE="/tmp/hypr_performance_mode"

if [[ -f "$STATUS_FILE" ]]; then
    ~/.config/hypr/scripts/optimize_performance.sh restore
    rm "$STATUS_FILE"
else
    ~/.config/hypr/scripts/optimize_performance.sh
    touch "$STATUS_FILE"
fi
