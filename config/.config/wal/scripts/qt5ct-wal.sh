#!/bin/bash

# Script para actualizar la configuración de qt5ct con los colores de pywal

# Verificar que existe el archivo de colores
if [[ ! -f ~/.cache/wal/colors-qt5ct.conf ]]; then
    echo "Error: No se encontró el archivo de colores de qt5ct"
    exit 1
fi

# Crear backup de la configuración actual de qt5ct si existe
if [[ -f ~/.config/qt5ct/qt5ct.conf ]]; then
    cp ~/.config/qt5ct/qt5ct.conf ~/.config/qt5ct/qt5ct.conf.backup
fi

# Configurar qt5ct para usar el esquema de colores de pywal
cat > ~/.config/qt5ct/qt5ct.conf << EOF
[Appearance]
color_scheme_path=/home/$USER/.config/qt5ct/colors/wal.conf
custom_palette=true
icon_theme=Papirus-Dark
standard_dialogs=default
style=Fusion

[Fonts]
fixed=@Variant(\0\0\0@\0\0\0\x12\0M\0o\0n\0o\0s\0p\0\x61\0\x63\0\x65@$\0\0\0\0\0\0\xff\xff\xff\xff\x5\x1\0\x32\x10)
general=@Variant(\0\0\0@\0\0\0\x12\0S\0\x61\0n\0s\0 \0S\0\x65\0r\0i\0\x66@$\0\0\0\0\0\0\xff\xff\xff\xff\x5\x1\0\x32\x10)

[Interface]
activate_item_on_single_click=1
buttonbox_layout=0
cursor_flash_time=1000
dialog_buttons_have_icons=1
double_click_interval=400
gui_effects=@Invalid()
keyboard_scheme=2
menus_have_icons=true
show_shortcuts_in_context_menus=true
stylesheets=@Invalid()
toolbutton_style=4
underline_shortcut=1
wheel_scroll_lines=3

[SettingsWindow]
geometry=@ByteArray(\x1\xd9\xd0\xcb\0\x3\0\0\0\0\x2\x80\0\0\x1\x90\0\0\x5\x7f\0\0\x4\x37\0\0\x2\x80\0\0\x1\x90\0\0\x5\x7f\0\0\x4\x37\0\0\0\0\0\0\0\0\a\x80\0\0\x2\x80\0\0\x1\x90\0\0\x5\x7f\0\0\x4\x37)
EOF

echo "Configuración de qt5ct actualizada con el esquema de colores de pywal"