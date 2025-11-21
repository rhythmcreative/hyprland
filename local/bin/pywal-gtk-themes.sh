#!/bin/bash

# Script para generar temas GTK basados en pywal y hacerlos disponibles en nwg-look
# Uso: ./pywal-gtk-themes.sh [imagen.jpg]

THEMES_DIR="$HOME/.themes"
PYWAL_DIR="$HOME/.cache/wal"

# Función para generar tema con wpgtk
generate_wpgtk_theme() {
    local image="$1"
    local theme_name="pywal-$(basename "$image" | sed 's/\.[^.]*$//')"
    
    echo "Generando tema con wpgtk para: $image"
    
    # Generar colores con pywal
    wal -i "$image" -n
    
    # Usar wpgtk para generar tema GTK
    if command -v wpg >/dev/null 2>&1; then
        wpg -s "$image"
        wpg -A "$theme_name"
    else
        echo "wpgtk no está disponible. Intentando con themix-gui..."
        generate_themix_theme "$image"
    fi
}

# Función para generar tema con themix-gui
generate_themix_theme() {
    local image="$1"
    local theme_name="pywal-$(basename "$image" | sed 's/\.[^.]*$//')"
    
    echo "Generando tema con themix-gui para: $image"
    
    # Generar colores con pywal
    wal -i "$image" -n
    
    # Crear archivo de configuración temporal para themix
    local temp_config="/tmp/themix_pywal_config"
    
    # Leer colores de pywal y convertirlos al formato de themix
    if [[ -f "$PYWAL_DIR/colors.json" ]]; then
        python3 << EOF
import json
import os

# Leer colores de pywal
with open('$PYWAL_DIR/colors.json', 'r') as f:
    pywal_colors = json.load(f)

colors = pywal_colors['colors']
special = pywal_colors['special']

# Configuración básica para themix
config = {
    'BG': colors['color0'][1:],
    'FG': colors['color15'][1:],
    'SEL_BG': colors['color1'][1:],
    'SEL_FG': colors['color15'][1:],
    'ACCENT_BG': colors['color4'][1:],
    'TXT_BG': colors['color0'][1:],
    'TXT_FG': colors['color15'][1:],
    'BTN_BG': colors['color8'][1:],
    'BTN_FG': colors['color15'][1:],
}

with open('$temp_config', 'w') as f:
    for key, value in config.items():
        f.write(f"{key}={value}\n")
EOF
        
        # Generar tema con themix-gui usando CLI
        if command -v oomox-cli >/dev/null 2>&1; then
            oomox-cli -o "$theme_name" "$temp_config"
        fi
    fi
}

# Función para crear un tema básico manualmente si otros métodos fallan
create_basic_theme() {
    local image="$1"
    local theme_name="pywal-$(basename "$image" | sed 's/\.[^.]*$//')"
    local theme_dir="$THEMES_DIR/$theme_name"
    
    echo "Creando tema básico para: $image"
    
    # Generar colores con pywal
    wal -i "$image" -n
    
    # Crear directorio del tema
    mkdir -p "$theme_dir/gtk-3.0"
    mkdir -p "$theme_dir/gtk-2.0"
    
    # Generar gtk.css básico usando colores de pywal
    if [[ -f "$PYWAL_DIR/colors.sh" ]]; then
        source "$PYWAL_DIR/colors.sh"
        
        cat > "$theme_dir/gtk-3.0/gtk.css" << EOF
/* Tema GTK3 generado automáticamente desde pywal */
@define-color theme_bg_color $color0;
@define-color theme_fg_color $color15;
@define-color theme_selected_bg_color $color1;
@define-color theme_selected_fg_color $color15;
@define-color insensitive_bg_color $color8;
@define-color insensitive_fg_color $color7;
@define-color borders $color8;
@define-color warning_color $color3;
@define-color error_color $color1;
@define-color success_color $color2;

window {
    background-color: @theme_bg_color;
    color: @theme_fg_color;
}

entry {
    background-color: $color0;
    color: @theme_fg_color;
    border: 1px solid @borders;
}

button {
    background-color: $color8;
    color: @theme_fg_color;
    border: 1px solid @borders;
}

button:hover {
    background-color: $color7;
}

.titlebar {
    background-color: $color0;
    color: @theme_fg_color;
}

headerbar {
    background-color: $color0;
    color: @theme_fg_color;
}
EOF

        # Crear gtkrc para GTK2
        cat > "$theme_dir/gtk-2.0/gtkrc" << EOF
# Tema GTK2 generado automáticamente desde pywal
gtk-color-scheme = "base_color:$color0\nfg_color:$color15\ntooltip_fg_color:$color15\nselected_bg_color:$color1\nselected_fg_color:$color15\ntext_color:$color15\nbg_color:$color0\ntooltip_bg_color:$color0"

style "default" {
    fg[NORMAL]        = @fg_color
    fg[ACTIVE]        = @fg_color
    fg[INSENSITIVE]   = darker(@fg_color)
    fg[SELECTED]      = @selected_fg_color
    fg[PRELIGHT]      = @fg_color
    
    bg[NORMAL]        = @bg_color
    bg[ACTIVE]        = darker(@bg_color)
    bg[INSENSITIVE]   = @bg_color
    bg[SELECTED]      = @selected_bg_color
    bg[PRELIGHT]      = shade(1.1, @bg_color)
    
    base[NORMAL]      = @base_color
    base[ACTIVE]      = darker(@base_color)
    base[INSENSITIVE] = @base_color
    base[SELECTED]    = @selected_bg_color
    base[PRELIGHT]    = @base_color
    
    text[NORMAL]      = @text_color
    text[ACTIVE]      = @text_color
    text[INSENSITIVE] = darker(@text_color)
    text[SELECTED]    = @selected_fg_color
    text[PRELIGHT]    = @text_color
}

widget_class "*" style "default"
EOF

        echo "Tema '$theme_name' creado en: $theme_dir"
    fi
}

# Función principal
main() {
    if [[ $# -eq 0 ]]; then
        echo "Uso: $0 <imagen>"
        echo "Genera un tema GTK basado en los colores de la imagen usando pywal"
        exit 1
    fi
    
    local image="$1"
    
    if [[ ! -f "$image" ]]; then
        echo "Error: La imagen '$image' no existe"
        exit 1
    fi
    
    echo "Generando tema GTK para: $image"
    
    # Intentar diferentes métodos en orden de preferencia
    if command -v wpg >/dev/null 2>&1; then
        generate_wpgtk_theme "$image"
    elif command -v oomox-cli >/dev/null 2>&1; then
        generate_themix_theme "$image"
    else
        echo "Generando tema básico..."
        create_basic_theme "$image"
    fi
    
    echo "¡Tema generado! Puedes seleccionarlo en nwg-look"
    echo "Para aplicar el tema inmediatamente, ejecuta: nwg-look"
}

# Ejecutar función principal
main "$@"
