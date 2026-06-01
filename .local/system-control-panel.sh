#!/bin/bash

# Panel de Control del Sistema

# Obtener colores de pywal
source ~/.cache/wal/colors.sh

# Configuración de rofi
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
    height: 500px;
    width: 420px;
    border: 3px;
    border-color: @border-col;
    background-color: @bg-col;
    border-radius: 18px;
}

mainbox {
    background-color: @bg-col;
    border-radius: 15px;
    padding: 18px;
}

inputbar {
    children: [prompt,entry];
    background-color: @bg-col-light;
    border-radius: 10px;
    padding: 6px;
    border: 2px;
    border-color: @border-col;
    margin: 0px 0px 18px 0px;
}

prompt {
    background-color: @blue;
    padding: 6px 10px;
    text-color: @bg-col;
    border-radius: 8px;
    margin: 0px 10px 0px 0px;
    font: \"JetBrainsMono Nerd Font Bold 11\";
}

entry {
    padding: 6px;
    margin: 0px 0px 0px 10px;
    text-color: @fg-col;
    background-color: transparent;
    font: \"JetBrainsMono Nerd Font 11\";
}

listview {
    border: 0px;
    padding: 6px 0px 0px;
    margin: 10px 0px 0px 0px;
    columns: 1;
    background-color: @bg-col;
    scrollbar: false;
    spacing: 8px;
}

element {
    padding: 10px 14px;
    background-color: @bg-col;
    text-color: @fg-col;
    border-radius: 10px;
    border: 2px solid transparent;
}

element selected {
    background-color: @selected-col;
    text-color: @bg-col;
    border: 2px solid @border-col;
}

element-text {
    font: \"JetBrainsMono Nerd Font Medium 11\";
}
"

# Función para mostrar notificaciones
notify() {
    notify-send -t 3000 -i "preferences-system" "System Control" "$1"
}

# Opciones del panel de control
options="🔊  Control de Audio
🖥️  Configuración de Monitores
🌐  Configuración de Red
🔋  Estado de Batería
💾  Información del Sistema
🎨  Temas y Apariencia
📁  Administrador de Archivos
⚙️  Configuración de Hyprland
🔧  Herramientas del Sistema
📊  Monitor de Recursos
🔐  Configuración de Seguridad
🖱️  Dispositivos de Entrada"

# Mostrar el menú
chosen=$(echo "$options" | rofi -dmenu -p "Panel de Control" -theme-str "$ROFI_CONFIG")

case $chosen in
    *"Control de Audio"*)
        # Abrir control de volumen
        if command -v pavucontrol >/dev/null 2>&1; then
            pavucontrol &
        elif command -v alsamixer >/dev/null 2>&1; then
            $terminal -e alsamixer
        else
            notify "No hay herramienta de audio disponible"
        fi
        ;;
    *"Configuración de Monitores"*)
        # Abrir configuración de monitores
        if command -v wdisplays >/dev/null 2>&1; then
            wdisplays &
        elif command -v nwg-displays >/dev/null 2>&1; then
            nwg-displays &
        else
            # Mostrar información de monitores actual
            notify "Información de monitores:"
            hyprctl monitors
        fi
        ;;
    *"Configuración de Red"*)
        # Abrir administrador de red
        if command -v nm-connection-editor >/dev/null 2>&1; then
            nm-connection-editor &
        elif command -v nmtui >/dev/null 2>&1; then
            $terminal -e nmtui
        else
            notify "Configurando red..."
            # Mostrar estado de red básico
            $terminal -e bash -c "echo 'Estado de Red:'; ip a; echo; echo 'Presiona Enter para continuar...'; read"
        fi
        ;;
    *"Estado de Batería"*)
        # Mostrar información de batería
        if command -v acpi >/dev/null 2>&1; then
            battery_info=$(acpi -b)
            notify "$battery_info"
            $terminal -e bash -c "echo 'Información de Batería:'; acpi -bi; echo; echo 'Presiona Enter para continuar...'; read"
        else
            notify "Información de batería no disponible"
        fi
        ;;
    *"Información del Sistema"*)
        # Mostrar información del sistema
        if command -v neofetch >/dev/null 2>&1; then
            $terminal -e neofetch
        elif command -v fastfetch >/dev/null 2>&1; then
            $terminal -e fastfetch
        else
            $terminal -e bash -c "echo 'Información del Sistema:'; uname -a; echo; lscpu | head -10; echo; free -h; echo; df -h; echo; echo 'Presiona Enter para continuar...'; read"
        fi
        ;;
    *"Temas y Apariencia"*)
        # Abrir selector de temas
        if [ -f ~/.local/bin/wallpaper-selector-hyde ]; then
            ~/.local/bin/wallpaper-selector-hyde
        else
            notify "Configurando temas..."
            # Alternativa básica para cambio de temas
            $terminal -e bash -c "echo 'Aplicando nuevo tema...'; wal -i ~/Pictures/Wallpapers/ -o ~/.local/bin/reload-pywal; echo 'Tema aplicado!'; sleep 2"
        fi
        ;;
    *"Administrador de Archivos"*)
        # Abrir administrador de archivos con privilegios
        if command -v dolphin >/dev/null 2>&1; then
            pkexec dolphin / &
        elif command -v thunar >/dev/null 2>&1; then
            pkexec thunar / &
        elif command -v nautilus >/dev/null 2>&1; then
            pkexec nautilus / &
        else
            $terminal -e sudo mc /
        fi
        ;;
    *"Configuración de Hyprland"*)
        # Abrir configuración de Hyprland
        if command -v code >/dev/null 2>&1; then
            code ~/.config/hypr/hyprland.conf
        elif command -v gedit >/dev/null 2>&1; then
            gedit ~/.config/hypr/hyprland.conf &
        else
            $terminal -e nano ~/.config/hypr/hyprland.conf
        fi
        ;;
    *"Herramientas del Sistema"*)
        # Submenu de herramientas
        tools_options="🔧  Editor de Registros
📊  Monitor de Procesos
🗂️  Administrador de Paquetes
🔒  Administrador de Servicios
🧹  Limpieza del Sistema"
        
        tool_chosen=$(echo "$tools_options" | rofi -dmenu -p "Herramientas" -theme-str "$ROFI_CONFIG")
        
        case $tool_chosen in
            *"Editor de Registros"*)
                if command -v gnome-logs >/dev/null 2>&1; then
                    gnome-logs &
                else
                    $terminal -e journalctl -f
                fi
                ;;
            *"Monitor de Procesos"*)
                if command -v btop >/dev/null 2>&1; then
                    $terminal -e btop
                elif command -v htop >/dev/null 2>&1; then
                    $terminal -e htop
                else
                    $terminal -e top
                fi
                ;;
            *"Administrador de Paquetes"*)
                if command -v pamac-manager >/dev/null 2>&1; then
                    pamac-manager &
                else
                    $terminal -e bash -c "echo 'Actualizando sistema...'; sudo pacman -Syu; echo 'Presiona Enter para continuar...'; read"
                fi
                ;;
            *"Administrador de Servicios"*)
                $terminal -e bash -c "echo 'Servicios del Sistema:'; systemctl list-units --type=service; echo; echo 'Presiona Enter para continuar...'; read"
                ;;
            *"Limpieza del Sistema"*)
                $terminal -e bash -c "echo 'Limpiando sistema...'; sudo pacman -Sc; journalctl --vacuum-time=7d; echo 'Limpieza completada!'; sleep 2"
                ;;
        esac
        ;;
    *"Monitor de Recursos"*)
        # Abrir monitor de recursos
        if command -v gnome-system-monitor >/dev/null 2>&1; then
            gnome-system-monitor &
        elif command -v btop >/dev/null 2>&1; then
            $terminal -e btop
        elif command -v htop >/dev/null 2>&1; then
            $terminal -e htop
        else
            $terminal -e top
        fi
        ;;
    *"Configuración de Seguridad"*)
        # Opciones de seguridad
        security_options="🛡️  Estado del Firewall
🔐  Configurar Contraseñas
🔒  Bloquear Pantalla
👥  Gestión de Usuarios"
        
        sec_chosen=$(echo "$security_options" | rofi -dmenu -p "Seguridad" -theme-str "$ROFI_CONFIG")
        
        case $sec_chosen in
            *"Estado del Firewall"*)
                $terminal -e bash -c "echo 'Estado del Firewall:'; sudo ufw status verbose; echo; echo 'Presiona Enter para continuar...'; read"
                ;;
            *"Configurar Contraseñas"*)
                $terminal -e passwd
                ;;
            *"Bloquear Pantalla"*)
                hyprlock
                ;;
            *"Gestión de Usuarios"*)
                $terminal -e bash -c "echo 'Usuarios del Sistema:'; cat /etc/passwd | grep '/home'; echo; echo 'Presiona Enter para continuar...'; read"
                ;;
        esac
        ;;
    *"Dispositivos de Entrada"*)
        # Configuración de dispositivos de entrada
        input_info=$(hyprctl devices -j | jq -r '.keyboards[].name, .mice[].name' 2>/dev/null || echo "Información no disponible")
        notify "Dispositivos conectados"
        $terminal -e bash -c "echo 'Dispositivos de Entrada:'; hyprctl devices; echo; echo 'Presiona Enter para continuar...'; read"
        ;;
    *)
        exit 0
        ;;
esac
