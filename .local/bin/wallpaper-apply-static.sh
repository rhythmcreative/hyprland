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
killall linux-wallpaperengine 2>/dev/null || true

# Sincronización completa con animación suave (awww grow / fade) y Pywal (Waybar, Quickshell, Dock)
if [ -x "$HOME/.local/bin/sync-wallpaper-animation" ]; then
    exec "$HOME/.local/bin/sync-wallpaper-animation" "$WALLPAPER_IMAGE"
fi

# Fallback si sync-wallpaper-animation no estuviese presente
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    if [ -d "$XDG_RUNTIME_DIR/hypr" ]; then
        _sig=$(ls -t "$XDG_RUNTIME_DIR/hypr/" 2>/dev/null | head -n1)
        [ -n "$_sig" ] && export HYPRLAND_INSTANCE_SIGNATURE="$_sig"
        unset _sig
    fi
fi

if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    _wl=$(ls -t "$XDG_RUNTIME_DIR"/wayland-[0-9]* 2>/dev/null | grep -v '\.lock$' | grep -v 'awww-daemon' | head -n1)
    [ -n "$_wl" ] && export WAYLAND_DISPLAY="$(basename "$_wl")"
    unset _wl
fi

if [ -x "$HOME/.local/bin/wallpaper-backend" ]; then
    "$HOME/.local/bin/wallpaper-backend" apply "$WALLPAPER_IMAGE"
elif command -v awww >/dev/null 2>&1; then
    awww img --transition-type grow --transition-pos center --transition-duration 1.5 --transition-fps 60 -- "$WALLPAPER_IMAGE"
fi

if command -v wal >/dev/null 2>&1; then
    wal -i "$WALLPAPER_IMAGE" -n -q 2>/dev/null || true
fi
if [ -x "$HOME/.local/bin/modern-pywal-sync" ]; then
    "$HOME/.local/bin/modern-pywal-sync" >/dev/null 2>&1 || true
fi