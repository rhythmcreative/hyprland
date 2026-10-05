#!/usr/bin/env bash


CONFIG="$1/config.json"



# Las rutas de config.json empiezan por "~/".
#
# Antes traian /home/rhythmcreative escrito a fuego. install.sh lo tapaba con
# un sed global, pero solo en Arch: en NixOS home-manager despliega este
# fichero desde el store sin pasar por ahi, y find "$wallpaper_path" se
# quedaba en un home inexistente sin decir nada. Expandir aqui funciona igual
# en los dos, y no depende de que nadie reescriba el fichero al desplegarlo.
expand_home() { printf '%s' "${1/#\~/$HOME}"; }

wallpaper_path=$(expand_home "$(jq -r '.wallpaper_path' "$CONFIG")")
cache_path=$(expand_home "$(jq -r '.cache_path' "$CONFIG")")
cache_batch_size=$(jq -r '.cache_batch_size' "$CONFIG")

mkdir -p "$cache_path"

echo "Wallpaper path: $wallpaper_path"
echo "Cache path: $cache_path"

find "$wallpaper_path" -type f \( \
    -iname "*.jpg" -o \
    -iname "*.jpeg" -o \
    -iname "*.png" \
\) | while read -r img; do

    filename=$(basename "$img")
    out="$cache_path/$filename"

    if [[ -f "$out" ]]; then
        continue
    fi

    echo "Generating thumbnail for $filename"


    magick "$img" -thumbnail x500 -strip -quality 85 "$out" &

    # Only limit jobs if batch_size > 0
    if (( cache_batch_size > 0 )); then
        while (( $(jobs -rp | wc -l) >= cache_batch_size )); do
            wait -n
        done
    fi

done

wait

echo "Thumbnail generation complete."
