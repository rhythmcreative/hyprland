#!/usr/bin/env bash
cd "$(dirname "$0")"

WALLPAPER_ENGINE_BIN="$HOME/linux-wallpaperengine/build/output/linux-wallpaperengine"
WALLPAPER_FPS=60
SCREENSHOT_DIR="$HOME/.cache/wallpaper-screenshots"
WAL_CMD="wal"
VENV_BIN=""
[[ -n "$VENV_BIN" ]] && export PATH="$VENV_BIN:$PATH"

mkdir -p "$SCREENSHOT_DIR"

WALLPAPER_DIR=""
HASH=""
THUMB_FOLDER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --hash)
            HASH="$2"
            shift 2
            ;;
        --thumb-folder)
            THUMB_FOLDER="$2"
            shift 2
            ;;
        *)
            if [[ -z "$WALLPAPER_DIR" ]]; then
                WALLPAPER_DIR="$1"
            fi
            shift
            ;;
    esac
done

if [[ -z "$WALLPAPER_DIR" || ! -d "$WALLPAPER_DIR" ]]; then
    echo "Usage: $0 [--hash HASH --thumb-folder PATH] <wallpaper_folder_path>"
    echo "Error: Folder does not exist: $WALLPAPER_DIR" >&2
    exit 1
fi

echo "$WALLPAPER_DIR" > ~/.cache/quickshell-last-wallpaper


MONITORS=()

# Por que se descubre la firma de Hyprland aqui y no se da por puesta:
#
# La isla lanza este script con un Process desde su unidad de systemd, y systemd
# NO hereda el entorno del compositor. Sin HYPRLAND_INSTANCE_SIGNATURE, hyprctl
# contesta "HYPRLAND_INSTANCE_SIGNATURE not set!" y sale con codigo de error.
# Antes solo se comprobaba `command -v hyprctl`, que si existe, asi que la
# llamada se hacia igual y su fallo se tragaba: jq recibia el mensaje de error en
# vez de JSON, MONITORS quedaba VACIO y la transicion se pedia solo para el
# eDP-1 del fallback. De ahi que la animacion saliera en una pantalla y en la
# otra el fondo se quedase como estuviera.
#
# No se arregla declarando la variable en la unidad: la firma cambia en cada
# sesion de Hyprland y la unidad no se entera. Se descubre, como en
# wallpaper-monitor-watcher.
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    _runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    if [ -d "$_runtime/hypr" ]; then
        _sig=$(ls -t "$_runtime/hypr/" 2>/dev/null | head -n1)
        [ -n "$_sig" ] && export HYPRLAND_INSTANCE_SIGNATURE="$_sig"
    fi
    unset _runtime _sig
fi

# Ahora sí: hyprctl tiene que FUNCIONAR, no solo existir.
if command -v hyprctl >/dev/null 2>&1 && hyprctl monitors -j >/dev/null 2>&1; then
    MONITORS=($(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null))
elif command -v xrandr >/dev/null 2>&1; then
    MONITORS=($(xrandr --query 2>/dev/null | grep " connected" | awk '{print $1}'))
fi

if [ "${#MONITORS[@]}" -gt 0 ]; then
    OUTPUTS=$(IFS=, ; echo "${MONITORS[*]}")
    AWWW_OUTPUTS=(--outputs "$OUTPUTS")
else
    # Sin lista de salidas NO se pasa --outputs, y awww aplica a todas. Antes
    # aquí se inventaba un "eDP-1": en una máquina sin panel interno ese nombre
    # no existe, así que el fondo no se ponía en ninguna pantalla y no había
    # ningún error que lo dijera.
    AWWW_OUTPUTS=()
    echo "wallpaper-apply: no se han podido detectar las salidas; se aplica a todas" >&2
fi


BLACK_PNG="/tmp/wallpaper-black.png"
if [[ ! -f "$BLACK_PNG" ]]; then
    ffmpeg -y -f lavfi -i color=black:size=1920x1080 -frames:v 1 "$BLACK_PNG" >/dev/null 2>&1 || true
fi

if [[ -f "$BLACK_PNG" ]]; then
    awww img "${AWWW_OUTPUTS[@]}" \
        --transition-type fade \
        --transition-duration 0.8 \
        --transition-fps 60 \
        --transition-bezier 0.22,1,0.36,1 \
        -- "$BLACK_PNG" 2>/dev/null || true
fi

pkill -f "$WALLPAPER_ENGINE_BIN" 2>/dev/null || true


WALLPAPER_IMAGE=""

for img in preview.jpg preview.jpeg preview.png thumbnail.jpg; do
    if [[ -f "$WALLPAPER_DIR/$img" ]]; then
        WALLPAPER_IMAGE="$WALLPAPER_DIR/$img"
        break
    fi
done

if [[ -z "$WALLPAPER_IMAGE" && -f "$WALLPAPER_DIR/project.json" ]]; then
    path=$(jq -r '.preview // .thumbnail // empty' "$WALLPAPER_DIR/project.json" 2>/dev/null)
    if [[ -n "$path" && -f "$WALLPAPER_DIR/$path" ]]; then
        WALLPAPER_IMAGE="$WALLPAPER_DIR/$path"
    fi
fi

if [[ -z "$WALLPAPER_IMAGE" ]]; then
    SS_FILE="$SCREENSHOT_DIR/$(basename "$WALLPAPER_DIR").png"
    (linux-wallpaperengine --screenshot "$SS_FILE" --bg "$WALLPAPER_DIR" >/dev/null 2>&1 &)
    sleep 2
    WALLPAPER_IMAGE="$SS_FILE"
fi

WAL_SUCCESS=false
if [[ -n "$WAL_CMD" && -f "$WALLPAPER_IMAGE" ]]; then
    if "$WAL_CMD" -i "$WALLPAPER_IMAGE" -n -q 2>/dev/null; then
        WAL_SUCCESS=true
    fi
fi

if [[ "$WAL_SUCCESS" == false && -n "$HASH" && -n "$THUMB_FOLDER" ]]; then
    cached_thumb="$THUMB_FOLDER/$HASH.jpg"
    if [[ -f "$cached_thumb" ]]; then
        "$WAL_CMD" -i "$cached_thumb" -n -q 2>/dev/null || true
    fi
fi

for i in "${!MONITORS[@]}"; do
    MON="${MONITORS[$i]}"
    CMD=(
        "$WALLPAPER_ENGINE_BIN"
        --no-foreground
        --silent
        --scaling fill
        --"${WALLPAPER_FPS}fps"
        --screen-root "$MON"
        --bg "$WALLPAPER_DIR"
    )

    [[ $i -ne 0 ]] && CMD+=(--silent)

    nohup "${CMD[@]}" >/dev/null 2>&1 &
    disown
done

sleep 1.5
awww clear 2>/dev/null || true