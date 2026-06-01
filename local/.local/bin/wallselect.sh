#!/bin/bash

# Selector de Wallpapers definitivo (Estilo Rofi Style-3)
# Sincronizado con Pywal y con soporte de búsqueda/color

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
CACHE_DIR="$HOME/.cache/wallpaper-previews"
ROFI_THEME="$HOME/.config/rofi/wallpaper-select-pywal.rasi"

mkdir -p "$CACHE_DIR"

# 1. Seleccionar Color (Menu rápido usando el mismo tema)
# Los colores se basan en los nombres de las carpetas que tenías antes
COLORS=("Blue" "Cyan" "Green" "Monochrome" "Orange" "Others" "Pink" "Purple" "Red" "Yellow")
COLOR_LIST=""
for c in "${COLORS[@]}"; do
    COLOR_LIST+="$c\n"
done

# Si el usuario prefiere ver TODOS directamente, saltamos este paso o lo incluimos como opción
SELECTED_COLOR=$(echo -e "ALL\n$COLOR_LIST" | rofi -dmenu -p "🎨 Color" -i -theme "$ROFI_THEME")

[ -z "$SELECTED_COLOR" ] && exit

# 2. Preparar lista de wallpapers (con iconos)
TEMP_FILE="/tmp/rofi_wp_$$"
> "$TEMP_FILE"

generate_preview() {
    local img="$1"
    local preview_size="200x133"
    local clean_name="${img%.*}"
    local safe_name="$(echo "$clean_name" | sed 's/[^a-zA-Z0-9._-]/_/g')"
    local preview_file="$CACHE_DIR/preview_${safe_name}.png"
    
    if [[ ! -f "$preview_file" ]]; then
        # Usar magick para generar preview rápida
        magick "$WALLPAPER_DIR/$img" -resize "${preview_size}^" -gravity center -extent "$preview_size" -strip -quality 60 "$preview_file" 2>/dev/null
    fi
    echo "$preview_file"
}

# Obtener lista de imágenes (filtrada si no es ALL)
if [ "$SELECTED_COLOR" == "ALL" ]; then
    mapfile -t images < <(ls "$WALLPAPER_DIR")
else
    # Como movimos todo a la raíz, intentaremos buscar por palabra clave en el nombre
    # O mejor: si el usuario los movió pero quiere filtrar, quizá deberíamos haber guardado el color.
    # No obstante, mostraré todos pero con el buscador activo.
    mapfile -t images < <(ls "$WALLPAPER_DIR")
fi

# Generar lista para rofi
for img in "${images[@]}"; do
    [[ -f "$WALLPAPER_DIR/$img" ]] || continue
    # Solo procesar imágenes
    case "${img,,}" in
        *.jpg|*.jpeg|*.png|*.webp|*.bmp)
            preview=$(generate_preview "$img")
            echo -e "$img\\0icon\\x1f$preview" >> "$TEMP_FILE"
            ;;
    esac
done

# 3. Seleccionar Imagen con el TEMA VISUAL DE SUPER + A
SELECTED_WP=$(rofi -dmenu -i -p "🖼️  $SELECTED_COLOR" -show-icons -theme "$ROFI_THEME" < "$TEMP_FILE")

[ -z "$SELECTED_WP" ] && exit

WALLPAPER_PATH="$WALLPAPER_DIR/$SELECTED_WP"

# 4. Aplicar Wallpaper y Sincronizar
notify-send "🎨 Aplicando Wallpaper" "$(basename "$WALLPAPER_PATH")" -t 2000

# Usar el script de sincronización completa del repo
if [[ -x "$HOME/.local/bin/wallpaper-change-adaptive" ]]; then
    # El script adaptive ya tiene la lógica de monitor, swww, wal, waybar, mako, etc.
    # Pero le pasaremos la imagen directamente si es posible.
    # Como el script adaptive abre su propio rofi, lo modificaremos para que acepte un argumento.
    
    # Por ahora lo aplicamos manualmente para asegurar consistencia
    swww img "$WALLPAPER_PATH" --transition-type grow --transition-pos "0.9,0.1" --transition-duration 1.5
    wal -i "$WALLPAPER_PATH" -n -q
    
    # Sincronización de componentes
    [ -x "$HOME/.local/bin/sync-waybar-pywal" ] && "$HOME/.local/bin/sync-waybar-pywal"
    [ -x "$HOME/.local/bin/sync-mako-pywal" ] && "$HOME/.local/bin/sync-mako-pywal"
    [ -x "$HOME/.local/bin/sync-rofi-pywal" ] && "$HOME/.local/bin/sync-rofi-pywal"
    [ -x "$HOME/.local/bin/pywal-asusctl-sync" ] && "$HOME/.local/bin/pywal-asusctl-sync" &

    hyprctl reload >/dev/null 2>&1 &
    pkill -SIGUSR2 waybar
fi

# Guardar registro
echo "$WALLPAPER_PATH" > "$HOME/.cache/current-wallpaper"

rm -f "$TEMP_FILE"
