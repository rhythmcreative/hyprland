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

# La isla lanza este script desde systemd, que no hereda el entorno del
# compositor: sin HYPRLAND_INSTANCE_SIGNATURE hyprctl falla, jq no parsea su
# mensaje de error y MONITORS queda vacio. Con la lista vacia la imagen se pedia
# solo para el "eDP-1" del fallback, que en otra maquina no existe. Se descubre
# la firma aqui; el detalle esta en wallpaper-apply.sh.
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    _runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    if [ -d "$_runtime/hypr" ]; then
        _sig=$(ls -t "$_runtime/hypr/" 2>/dev/null | head -n1)
        [ -n "$_sig" ] && export HYPRLAND_INSTANCE_SIGNATURE="$_sig"
    fi
    unset _runtime _sig
fi

MONITORS=()
if command -v hyprctl >/dev/null 2>&1 && hyprctl monitors -j >/dev/null 2>&1; then
    MONITORS=($(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null))
elif command -v xrandr >/dev/null 2>&1; then
    MONITORS=($(xrandr --query 2>/dev/null | grep " connected" | awk '{print $1}'))
fi

if [ "${#MONITORS[@]}" -gt 0 ]; then
    AWWW_OUTPUTS=(--outputs "$(IFS=, ; echo "${MONITORS[*]}")")
else
    # Sin --outputs awww las aplica a todas, que es mejor que un nombre de
    # monitor inventado.
    AWWW_OUTPUTS=()
    echo "wallpaper-apply-static: no se han podido detectar las salidas; se aplica a todas" >&2
fi

killall linux-wallpaperengine 2>/dev/null || true

awww img "${AWWW_OUTPUTS[@]}" -- "$WALLPAPER_IMAGE"