#!/usr/bin/env bash
# Migration 002: ensure ~/.version tracks the repo version file.
set -euo pipefail
REPO_DIR="${RHYTHM_REPO:-$HOME/hyprland}"
if [ -f "$REPO_DIR/.version" ] && [ ! -f "$HOME/.version" ]; then
    cp -f "$REPO_DIR/.version" "$HOME/.version"
    echo "002: ~/.version restored from repo."
else
    echo "002: version file already present."
fi
