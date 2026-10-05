#!/usr/bin/env bash
# Genera thumbnails de los fondos que aun no los tienen.
#
# LLAMADO DESDE
#   .config/quickshell/wallpaper/Selector.qml:70
#       echo '<lista de rutas>' | .../batch-thumbnails.sh
#
#   El script se ejecuta en lotes: la Isla agrupa las peticiones y las manda
#   todas por stdin, en vez de lanzar un convert por fondo. Por eso lee de
#   stdin en vez de recibir argumentos.
#
#   NO ESTABA EN EL REPO. El pipeline de miniaturas estaba muerto: el selector
#   lanzaba un binario inexistente y, como la salida se descartaba, lo unico
#   que se veia era que las miniaturas no aparecian nunca.
#
# ENTRADA
#   Una ruta por linea. Se ignoran las vacias y las que ya tienen thumbnail,
#   porque el trabajo llega ya filtrado desde QML pero no hace falta fiarse.
#
# SALIDA
#   Thumbnails en $THUMB_DIR, 400x225 y JPEG, que es lo que espera el QML.
#   Nada por stdout: quien llama solo quiere que el fichero exista.

set -uo pipefail

THUMB_DIR="${THUMB_DIR:-$HOME/.cache/wallpaper-thumbs}"
PEDIDAS_MAX="${THUMB_PENDING_MAX:-200}"
ANCHO="${THUMB_WIDTH:-400}"
ALTO="${THUMB_HEIGHT:-225}"
CALIDAD="${THUMB_QUALITY:-82}"

mkdir -p "$THUMB_DIR" 2>/dev/null || { echo "batch-thumbnails: no se pudo crear $THUMB_DIR" >&2; exit 1; }

# El generador. Se prueba en orden: si hay ImageMagick, va magick (v7) o
# convert (v6). En NixOS el paquete se llama imagemagick y trae los dos, y en
# Arch suele ser v7. Sin ninguno de los dos no hay miniaturas, y se dice en
# vez de fallar en silencio.
if command -v magick >/dev/null 2>&1; then
    CONVERT=(magick)
elif command -v convert >/dev/null 2>&1; then
    CONVERT=(convert)
else
    echo "batch-thumbnails: ni magick ni convert; el selector no tendra miniaturas" >&2
    exit 1
fi

contador=0
generados=0

while IFS= read -r f; do
    [ -n "$f" ] || continue

    # basura en stdin (un prompt, un CR) no debe abortar el lote
    f="${f%$'\r'}"
    [ -f "$f" ] || continue

    contador=$((contador + 1))
    [ "$contador" -gt "$PEDIDAS_MAX" ] && break

    # stem unico por ruta: dos fondos con el mismo nombre en carpetas
    # distintas no deben pisarse el thumbnail
    stem="$(printf '%s' "$f" | md5sum | cut -c1-16)"
    destino="$THUMB_DIR/$stem.jpg"

    [ -f "$destino" ] && continue

    tmp="$destino.$$"
    if "${CONVERT[@]}" "$f" -auto-orient \
        -resize "${ANCHO}x${ALTO}^" \
        -gravity center -extent "${ANCHO}x${ALTO}" \
        -quality "$CALIDAD" "$tmp" 2>/dev/null; then
        # renombrado al final: un temporal a medias deja un .jpg corrupto que
        # el selector lo daria por bueno y no volveria a pedirlo
        mv -f "$tmp" "$destino" 2>/dev/null && generados=$((generados + 1)) || rm -f "$tmp"
    else
        rm -f "$tmp" 2>/dev/null
    fi
done

[ "$generados" -gt 0 ] && echo "batch-thumbnails: $generados generados en $THUMB_DIR" >&2
exit 0