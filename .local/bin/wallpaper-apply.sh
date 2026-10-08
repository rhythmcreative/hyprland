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
#
# Wayland se descubre por el mismo motivo y porque sin el NO BASTA con la firma:
# el cliente de awww saca la ruta de su socket de $WAYLAND_DISPLAY y, si no esta,
# cae en wayland-0. Aqui el compositor toma wayland-1, asi que sin esto el
# `awww img` de mas abajo no llegaba al daemon y no pintaba ninguna pantalla,
# aunque la lista de MONITORS fuera correcta y no hubiera ni un error visible.
buscar_hypr_firma() {
    local d s dir
    for dir in "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" "/tmp/hypr"; do
        [ -d "$dir" ] || continue
        for d in $(ls -t "$dir" 2>/dev/null); do
            [ -d "$dir/$d" ] || continue
            s="$d"
            [ -n "$s" ] || continue
            if [ -S "$dir/$d/.socket2.sock" ] ||
               [ -S "$dir/$d.socket2.sock" ] ||
               [ -S "$dir/$d/.socket.sock" ]; then
                printf '%s\n' "$s"
                return 0
            fi
        done
    done
    return 1
}

if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    if _sig="$(buscar_hypr_firma)"; then
        export HYPRLAND_INSTANCE_SIGNATURE="$_sig"
    fi
fi

_runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    _wl=$(ls -t "$_runtime"/wayland-[0-9]* 2>/dev/null | grep -v '\.lock$' | grep -v 'awww-daemon' | head -n1)
    [ -n "$_wl" ] && export WAYLAND_DISPLAY="$(basename "$_wl")"
    unset _wl
fi
unset _runtime

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


# ── ¿Está linux-wallpaperengine? ────────────────────────────────────────────
#
# ESTE SCRIPT DEPENDE DE UN BINARIO QUE NADA INSTALA.
#
# WALLPAPER_ENGINE_BIN apunta a ~/linux-wallpaperengine/build/output/, que es
# donde lo deja su build, pero ni install.sh ni packages.txt ni el modulo de
# NixOS lo compilan: hay que clonarlo y compilarlo a mano. Con el binario
# ausente, este script hacia dos cosas que dejaban el escritorio roto:
#
#   1. pintaba un PNG NEGRO con awwm y lo ponia de fondo, para tapar el
#      wallpaper anterior mientras el motor arrancaba; y
#   2. luego lanzaba `linux-wallpaperengine` a pelo, sin comprobar que
#      existiera (linea 139: sin ruta, sin $WALLPAPER_ENGINE_BIN), y con el
#      resultado en $SS_FILE.
#
# El motor no arrancaba nunca, la captura no se generaba, y el escritorio se
# quedaba con el fondo NEGRO que habia puesto en el paso 1. Sin un solo error:
# el negro es indistinguible de "todavia no ha pintado".
#
# Ahora se comprueba ANTES de tocar nada. Si el motor no esta, no se pinta de
# negro, y si el proyecto trae una imagen de vista previa se pone esa con el
# backend estatico, que es lo que se ve de todas formas. Si no trae ninguna,
# se avisa por stderr y se sale sin haber modificado el fondo.
ENGINE_BIN=""
for candidato in \
    "$WALLPAPER_ENGINE_BIN" \
    "$(command -v linux-wallpaperengine 2>/dev/null || true)"; do
    [ -n "$candidato" ] && [ -x "$candidato" ] && { ENGINE_BIN="$candidato"; break; }
done

HAVE_ENGINE=false
[ -n "$ENGINE_BIN" ] && HAVE_ENGINE=true

# La vista previa se busca SIEMPRE, la use o no el motor: es lo que se pondra de
# fondo en el camino estatico.
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

# ── CAMINO ESTATICO ────────────────────────────────────────────────────────
#
# Sin motor no hay animacion, pero hay una imagen, y ponerla es infinitamente
# mejor que dejar la pantalla en negro. wallpaper-backend es el que decide
# entre awww y mpvpaper, escribe el cache que leen los watchers, y ya sabe
# resolver el entorno del compositor.
if [[ "$HAVE_ENGINE" == false ]]; then
    if [[ -n "$WALLPAPER_IMAGE" && -x "$HOME/.local/bin/wallpaper-backend" ]]; then
        echo "wallpaper-apply: linux-wallpaperengine no esta instalado; se pone la vista previa estatica." >&2
        "$HOME/.local/bin/wallpaper-backend" apply "$WALLPAPER_IMAGE" >/dev/null 2>&1 || true
    else
        echo "wallpaper-apply: linux-wallpaperengine no esta instalado y este proyecto no trae" >&2
        echo "  vista previa utilizable. No se toca el fondo. Para animacion, compila" >&2
        echo "  linux-wallpaperengine en $WALLPAPER_ENGINE_BIN." >&2
    fi
    exit 0
fi

# ── CAMINO CON MOTOR ────────────────────────────────────────────────────────
#
# A partir de aqui si hay motor, asi que el negro de transicion tiene sentido:
# se pinta mientras el motor carga y este lo sustituye.
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

pkill -f "$ENGINE_BIN" 2>/dev/null || true

if [[ -z "$WALLPAPER_IMAGE" ]]; then
    SS_FILE="$SCREENSHOT_DIR/$(basename "$WALLPAPER_DIR").png"
    # Se llama con la ruta comprobada, no a pelo. La version anterior usaba el
    # literal `linux-wallpaperengine` y dependia de que el PATH del usuario
    # lo tuviera, que es justo lo que no pasa en una sesion de SDDM o en un
    # servicio de systemd.
    ("$ENGINE_BIN" --screenshot "$SS_FILE" --bg "$WALLPAPER_DIR" >/dev/null 2>&1 &)
    sleep 2
    WALLPAPER_IMAGE="$SS_FILE"
fi

WAL_SUCCESS=false
if [[ -n "$WAL_CMD" && -f "$WALLPAPER_IMAGE" ]]; then
    if timeout 10 "$WAL_CMD" -i "$WALLPAPER_IMAGE" -n -q -s 2>/dev/null; then
        WAL_SUCCESS=true
    fi
fi

if [[ "$WAL_SUCCESS" == false && -n "$HASH" && -n "$THUMB_FOLDER" ]]; then
    cached_thumb="$THUMB_FOLDER/$HASH.jpg"
    if [[ -f "$cached_thumb" ]]; then
        timeout 10 "$WAL_CMD" -i "$cached_thumb" -n -q -s 2>/dev/null && WAL_SUCCESS=true || true
    fi
fi

if [[ "$WAL_SUCCESS" == true && -x "$HOME/.local/bin/modern-pywal-sync" ]]; then
    ("$HOME/.local/bin/modern-pywal-sync" >/dev/null 2>&1 &)
fi

for i in "${!MONITORS[@]}"; do
    MON="${MONITORS[$i]}"
    CMD=(
        "$ENGINE_BIN"
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