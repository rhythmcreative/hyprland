#!/usr/bin/env bash
# Migration 003: enable persistent user services if their units are deployed.
set -euo pipefail
units=(waybar-island.service privacy-shield.service rhythm-power-profile.service rhythm-ota-check.timer wallpaper-monitor-watcher.service rust-dock-monitor-watcher.service)
if ! command -v systemctl >/dev/null 2>&1; then
    echo "003: systemctl unavailable, skipping."
    exit 0
fi
systemctl --user daemon-reload 2>/dev/null || true
for u in "${units[@]}"; do
    if [ -f "$HOME/.config/systemd/user/$u" ]; then
        systemctl --user enable "$u" 2>/dev/null || true
        echo "003: enabled $u."
    fi
done
