#!/bin/bash
WALLPAPER_ENGINE_BIN="/home/rhythmcreative/linux-wallpaperengine/build/output/linux-wallpaperengine"

pkill -f $WALLPAPER_ENGINE_BIN
sleep 0.1


read -r LAST_WALLPAPER < "$HOME/.cache/quickshell-last-wallpaper"

if command -v hyprctl >/dev/null 2>&1; then
  MONITORS=($(hyprctl monitors -j | jq -r '.[].name'))
elif command -v xrandr >/dev/null 2>&1; then
  MONITORS=($(xrandr --query | grep " connected" | awk '{print $1}'))
else
  MONITORS=("eDP-1")
fi

for i in "${!MONITORS[@]}"; do
  MON="${MONITORS[$i]}"
  CMD=($WALLPAPER_ENGINE_BIN --no-foreground --scaling fill --60fps --screen-root "$MON" --bg "$LAST_WALLPAPER")
  [[ "$i" -ne 0 ]] && CMD+=(--silent)
  nohup "${CMD[@]}" >/dev/null 2>&1 &
  disown
done
