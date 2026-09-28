#!/usr/bin/env bash
# Migration 001: ensure user state and media directories exist.
set -euo pipefail
mkdir -p "$HOME/.local/state/rhythm/migrations" \
         "$HOME/Videos/Recordings" \
         "$HOME/Pictures/Screenshots" \
         "$HOME/Documents/notes" \
         "$HOME/.snapshots" 2>/dev/null || true
echo "001: state and media directories ensured."
