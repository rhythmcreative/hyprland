#!/usr/bin/env bash
cd "$(dirname "$0")"

WAL_CMD="wal"
VENV_BIN=""
[[ -n "$VENV_BIN" ]] && export PATH="$VENV_BIN:$PATH"

WALLPAPER_IMAGE="$1"
if [[ -z "$WALLPAPER_IMAGE" || ! -f "$WALLPAPER_IMAGE" ]]; then
    echo "Usage: $0 <wallpaper_image>"
    echo "Error: File does not exist: $WALLPAPER_IMAGE" >&2
    exit 1
fi

echo "$WALLPAPER_IMAGE" > ~/.cache/quickshell-last-wallpaper

[[ -n "$WAL_CMD" ]] && "$WAL_CMD" -i "$WALLPAPER_IMAGE" -n -q 2>/dev/null || true

MONITORS=()
if command -v hyprctl >/dev/null 2>&1; then
    MONITORS=($(hyprctl monitors -j | jq -r '.[].name'))
elif command -v xrandr >/dev/null 2>&1; then
    MONITORS=($(xrandr --query | grep " connected" | awk '{print $1}'))
else
    MONITORS=("eDP-1")
fi
[[ ${#MONITORS[@]} -eq 0 ]] && MONITORS=("eDP-1")

OUTPUTS=$(IFS=, ; echo "${MONITORS[*]}")

killall linux-wallpaperengine

swww img --outputs "$OUTPUTS" -- "$WALLPAPER_IMAGE"