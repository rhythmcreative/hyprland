#!/bin/bash

# Menú de capturas de pantalla avanzado

# Obtener colores de pywal
source ~/.cache/wal/colors.sh

# Configuración de rofi (más compacta para el menú de capturas)
ROFI_CONFIG="
* {
    bg-col: $color0;
    bg-col-light: $color8;
    border-col: $color1;
    selected-col: $color1;
    blue: $color4;
    fg-col: $foreground;
    fg-col2: $color15;
    grey: $color8;
}

window {
    height: 360px;
    width: 350px;
    border: 3px;
    border-color: @border-col;
    background-color: @bg-col;
    border-radius: 15px;
}

mainbox {
    background-color: @bg-col;
    border-radius: 12px;
    padding: 15px;
}

inputbar {
    children: [prompt,entry];
    background-color: @bg-col-light;
    border-radius: 8px;
    padding: 4px;
    border: 2px;
    border-color: @border-col;
    margin: 0px 0px 15px 0px;
}

prompt {
    background-color: @blue;
    padding: 4px 8px;
    text-color: @bg-col;
    border-radius: 6px;
    margin: 0px 8px 0px 0px;
    font: \"JetBrainsMono Nerd Font Bold 10\";
}

entry {
    padding: 4px;
    margin: 0px 0px 0px 8px;
    text-color: @fg-col;
    background-color: transparent;
    font: \"JetBrainsMono Nerd Font 10\";
}

listview {
    border: 0px;
    padding: 4px 0px 0px;
    margin: 8px 0px 0px 0px;
    columns: 1;
    background-color: @bg-col;
    scrollbar: false;
    spacing: 6px;
}

element {
    padding: 8px 12px;
    background-color: @bg-col;
    text-color: @fg-col;
    border-radius: 8px;
    border: 2px solid transparent;
}

element selected {
    background-color: @selected-col;
    text-color: @bg-col;
    border: 2px solid @border-col;
}

element-text {
    font: \"JetBrainsMono Nerd Font Medium 10\";
}
"

# Directorio para capturas
SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SCREENSHOT_DIR"

# Función para mostrar notificaciones
notify() {
    notify-send -t 3000 -i "camera-photo" "Screenshot" "$1"
}

# Opciones del menú
options="📷  Pantalla Completa
🖼️  Área Seleccionada  
🪟  Ventana Activa
⏱️  Captura en 5 segundos
🎬  Grabar Pantalla
📱  Captura con Cursor
🖥️  Monitor Específico
📋  Captura al Portapapeles"

# Mostrar el menú
chosen=$(echo "$options" | rofi -dmenu -p "Screenshot Menu" -theme-str "$ROFI_CONFIG")

# Nombre de archivo con timestamp
timestamp=$(date +"%Y%m%d_%H%M%S")
filename="$SCREENSHOT_DIR/screenshot_$timestamp.png"

case $chosen in
    *"Pantalla Completa"*)
        notify "Capturando pantalla completa..."
        grim "$filename"
        if [ $? -eq 0 ]; then
            notify "Captura guardada: $filename"
        else
            notify "Error al capturar pantalla"
        fi
        ;;
    *"Área Seleccionada"*)
        notify "Selecciona un área..."
        grim -g "$(slurp)" "$filename"
        if [ $? -eq 0 ]; then
            notify "Captura de área guardada: $filename"
        else
            notify "Captura cancelada"
        fi
        ;;
    *"Ventana Activa"*)
        notify "Capturando ventana activa..."
        grim -g "$(hyprctl activewindow -j | jq -r '.at[0],.at[1],.size[0],.size[1]' | tr '\n' ' ' | awk '{print $1","$2" "$3"x"$4}')" "$filename"
        if [ $? -eq 0 ]; then
            notify "Captura de ventana guardada: $filename"
        else
            notify "Error al capturar ventana"
        fi
        ;;
    *"Captura en 5 segundos"*)
        notify "Captura en 5 segundos... Prepárate!"
        for i in {5..1}; do
            notify-send -t 1000 "Screenshot" "Capturando en $i..."
            sleep 1
        done
        grim "$filename"
        if [ $? -eq 0 ]; then
            notify "Captura con delay guardada: $filename"
        else
            notify "Error al capturar pantalla"
        fi
        ;;
    *"Grabar Pantalla"*)
        # Verificar si ya hay una grabación activa
        if pgrep -f "wf-recorder" > /dev/null; then
            pkill -f "wf-recorder"
            notify "Grabación detenida"
        else
            video_file="$SCREENSHOT_DIR/recording_$timestamp.mp4"
            notify "Iniciando grabación... Presiona Super+Backspace y selecciona 'Grabar Pantalla' nuevamente para detener"
            wf-recorder -f "$video_file" &
        fi
        ;;
    *"Captura con Cursor"*)
        notify "Capturando con cursor..."
        grim -c "$filename"
        if [ $? -eq 0 ]; then
            notify "Captura con cursor guardada: $filename"
        else
            notify "Error al capturar pantalla"
        fi
        ;;
    *"Monitor Específico"*)
        # Listar monitores disponibles
        monitors=$(hyprctl monitors -j | jq -r '.[].name')
        monitor=$(echo "$monitors" | rofi -dmenu -p "Selecciona Monitor" -theme-str "$ROFI_CONFIG")
        
        if [ -n "$monitor" ]; then
            notify "Capturando monitor: $monitor"
            grim -o "$monitor" "$filename"
            if [ $? -eq 0 ]; then
                notify "Captura del monitor guardada: $filename"
            else
                notify "Error al capturar monitor"
            fi
        fi
        ;;
    *"Captura al Portapapeles"*)
        notify "Capturando al portapapeles..."
        grim - | wl-copy
        if [ $? -eq 0 ]; then
            notify "Captura copiada al portapapeles"
        else
            notify "Error al copiar al portapapeles"
        fi
        ;;
    *)
        exit 0
        ;;
esac
