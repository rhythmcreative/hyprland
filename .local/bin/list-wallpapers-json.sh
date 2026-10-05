#!/usr/bin/env bash
# Lista los fondos de una carpeta como JSON para el selector de la Isla.
#
# LLAMADO DESDE
#   .config/quickshell/wallpaper/Selector.qml:1230
#       staticFinder.command = [ ".../list-wallpapers-json.sh", staticWallpaperFolder ];
#
#   El Selector no puede leer el disco (QML no tiene E/S de ficheros), asi que
#   lanza este script y lee su salida. Salida: un array JSON de objetos con el
#   nombre, la ruta y el thumb, EN ORDEN, un objeto por linea, que es como lo
#   consume el Import de QML.
#
#   ESTE FICHERO NO ESTABA EN EL REPO. La ruta era absoluta y apuntaba a
#   /home/rhythmcreative/.local/bin/, o sea que en cualquier otra maquina
#   fallaba con "no such file", y el selector de fondos no llegaba a pintar
#   lista. En Arch se notaba; en NixOS, donde Selector.qml vive en un symlink
#   del store, igual.
#
# USO
#   list-wallpapers-json.sh [directorio]
#   Sin argumento: ~/Pictures/Wallpapers

set -uo pipefail

DIR="${1:-$HOME/Pictures/Wallpapers}"

[ -d "$DIR" ] || { echo "[]"; exit 0; }

# Nombre de un thumbnail putative para este fondo.
#
# El generador de thumbs esta en este mismo directorio, asi que el prefijo se
# deduce de el en vez de fijarlo aqui: si el pipeline cambia de nombre, esto no
# devuelve rutas que no existen.
thumb_for() {
    local base="$1"
    local gen
    for gen in "$HOME/.cache/wallpaper-thumbs" "$HOME/.cache/thumbnails"; do
        if [ -d "$gen" ]; then
            printf '%s/%s.jpg' "$gen" "$base"
            return 0
        fi
    done
    return 1
}

# Solo las extensiones que el backend sabe pintar. wallpaper-backend decide
# entre awww (estatico) y mpvpaper (animado) por la extension, asi que listar
# un .txt seria ofrecerle algo que luego no sabe pintar.
find "$DIR" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
    -print0 2>/dev/null \
| sort -z \
| while IFS= read -r -d '' f; do
    base="$(basename "$f")"
    stem="${base%.*}"

    case "${base,,}" in
        *.gif) animated=true ;;
        *)     animated=false ;;
    esac

    thumb=""
    if t="$(thumb_for "$stem")"; then
        [ -f "$t" ] && thumb="$t"
    fi

    # printf con %s en todos los valores: un nombre de fichero con comillas o
    # backslashes no puede romper el JSON. jq haria esto mejor, pero el orden
    # tiene que conservarse y aqi se genera linea a linea a proposito.
    printf '{"name":%s,"path":%s,"thumb":%s,"animated":%s}\n' \
        "$(printf '%s' "$base" | jq -Rsa .)" \
        "$(printf '%s' "$f" | jq -Rsa .)" \
        "$(printf '%s' "$thumb" | jq -Rsa .)" \
        "$animated"
done

exit 0