#!/bin/bash

# --- Rhythm Arch Hyprland Installer v3 (Minimal White / Omarchy Inspired) ---
# Instalador profesional, modular y robusto para Arch Linux y Hyprland

set -eEo pipefail

# Error handling trap
handle_error() {
    local exit_code=$?
    local line_number=$1
    echo ""
    echo "  [ERROR] Ocurrio un fallo en la linea $line_number (codigo de salida: $exit_code)."
    echo "  [ERROR] La instalacion se detuvo para proteger la integridad del sistema."
    exit $exit_code
}
trap 'handle_error $LINENO' ERR

# Environment variables for gum aesthetic
export GUM_CHOOSE_CURSOR_FOREGROUND="7"
export GUM_CHOOSE_HEADER_FOREGROUND="7"
export GUM_CHOOSE_SELECTED_FOREGROUND="7"
export GUM_SPIN_SPINNER_FOREGROUND="7"
export GUM_STYLE_FOREGROUND="7"
export GUM_CONFIRM_PROMPT_FOREGROUND="7"
export GUM_CONFIRM_SELECTED_BACKGROUND="7"
export GUM_CONFIRM_SELECTED_FOREGROUND="0"

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# --- UI LOGGING HELPERS ---
section() {
    echo ""
    gum style --bold --margin "1 0" --underline "$MSG_SECTION $1 "
}

info() {
    echo "  [SISTEMA] $1"
}

success() {
    echo "  [OK] $1"
}

warn() {
    echo "  [AVISO] $1"
}

error() {
    echo "  [ERROR] $1"
}

print_banner() {
    clear
    echo "██████╗ ██╗  ██╗██╗   ██╗████████╗██╗  ██╗███╗   ███╗ ██████╗██████╗ ███████╗ █████╗ ████████╗██╗██╗   ██╗███████╗"
    echo "██╔══██╗██║  ██║╚██╗ ██╔╝╚══██╔══╝██║  ██║████╗ ████║██╔════╝██╔══██╗██╔════╝██╔══██╗╚══██╔══╝██║██║   ██║██╔════╝"
    echo "██████╔╝███████║ ╚████╔╝    ██║   ███████║██╔████╔██║██║     ██████╔╝█████╗  ███████║   ██║   ██║██║   ██║█████╗  "
    echo "██╔══██╗██╔══██║  ╚██╔╝     ██║   ██╔══██║██║╚██╔╝██║██║     ██╔══██╗██╔══╝  ██╔══██║   ██║   ██║╚██╗ ██╔╝██╔══╝  "
    echo "██║  ██║██║  ██║   ██║      ██║   ██║  ██║██║ ╚═╝ ██║╚██████╗██║  ██║███████╗██║  ██║   ██║   ██║ ╚████╔╝ ███████╗"
    echo "╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝      ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═══╝  ╚══════╝"
    echo ""
    echo "██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗"
    echo "██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝"
    echo "██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗"
    echo "██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║"
    echo "██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║"
    echo "╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝"
    echo ""
}

# --- LOCALIZATION ---
setup_language() {
    LANG_CHOICE=$(gum choose --header "Select Language / Selecciona Idioma" "Español" "English")
    
    case "$LANG_CHOICE" in
        "Español")
            MSG_ERROR_ROOT="No ejecutes este script como root."
            MSG_SECTION="SECCION:"
            MSG_CORE_INSTALL="Instalando paquetes base y dependencias del sistema..."
            MSG_SEARCH_PROMPT="Buscar Apps: "
            MSG_SEARCH_HEADER="[TAB] Seleccionar | [ENTER] Instalar | [ESC] Omitir"
            MSG_SEARCH_LAUNCH="Iniciando buscador de aplicaciones interactivas (Oficial + AUR)..."
            MSG_DRIVER_HEADER="DRIVERS DE HARDWARE"
            MSG_DEPLOY_DRIVERS="Instalando controladores detectados..."
            MSG_FLATPAK_CONFIRM="Deseas instalar aplicaciones Flatpak de tu lista flatpaks.txt?"
            MSG_WALL_CONFIRM="Deseas descargar paquetes adicionales de fondos de pantalla?"
            MSG_ZSH_CONFIRM="Establecer Zsh como tu shell por defecto?"
            MSG_REBOOT_CONFIRM="Deseas reiniciar el sistema ahora para iniciar Hyprland?"
            MSG_DONE="Instalacion completada con exito."
            ;;
        *)
            MSG_ERROR_ROOT="Do not run this script as root."
            MSG_SECTION="SECTION:"
            MSG_CORE_INSTALL="Installing core system packages and dependencies..."
            MSG_SEARCH_PROMPT="Search Apps: "
            MSG_SEARCH_HEADER="[TAB] Select Multiple | [ENTER] Install | [ESC] Skip"
            MSG_SEARCH_LAUNCH="Launching interactive application discovery (Official + AUR)..."
            MSG_DRIVER_HEADER="HARDWARE DRIVERS"
            MSG_DEPLOY_DRIVERS="Deploying detected hardware drivers..."
            MSG_FLATPAK_CONFIRM="Install Flatpaks from flatpaks.txt list?"
            MSG_WALL_CONFIRM="Download additional wallpaper packs?"
            MSG_ZSH_CONFIRM="Set Zsh as your default shell?"
            MSG_REBOOT_CONFIRM="Reboot system now to start Hyprland?"
            MSG_DONE="Installation completed successfully."
            ;;
    esac
}

# --- PREFLIGHT CHECKS ---
preflight_checks() {
    if [ "$EUID" -eq 0 ]; then
        echo "ERROR: Do not run this script as root."
        exit 1
    fi

    if [ ! -f /etc/arch-release ]; then
        echo "ERROR: Este instalador solo es compatible con Arch Linux."
        exit 1
    fi

    # Check internet connectivity
    if ! ping -c 1 archlinux.org >/dev/null 2>&1 && ! curl -s --head https://archlinux.org >/dev/null 2>&1; then
        echo "ERROR: No hay conexion activa a internet. Conectate a la red antes de continuar."
        exit 1
    fi

    # Optimize pacman config if not done yet
    if grep -q "^#ParallelDownloads" /etc/pacman.conf 2>/dev/null; then
        sudo sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
    fi
    if grep -q "^#Color" /etc/pacman.conf 2>/dev/null; then
        sudo sed -i 's/^#Color/Color/' /etc/pacman.conf
    fi
    if grep -q "^#\[multilib\]" /etc/pacman.conf 2>/dev/null; then
        sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
        sudo pacman -Sy
    fi

    # Core bootstrap tools
    local bootstrap_pkgs=()
    for pkg in gum fzf git base-devel stow zsh curl sudo; do
        if ! pacman -Q "$pkg" >/dev/null 2>&1; then
            bootstrap_pkgs+=("$pkg")
        fi
    done
    if [ ${#bootstrap_pkgs[@]} -gt 0 ]; then
        sudo pacman -S --needed --noconfirm "${bootstrap_pkgs[@]}" >/dev/null 2>&1
    fi
}

# --- AUR HELPER INSTALLATION ---
install_yay() {
    if ! command -v yay > /dev/null 2>&1; then
        section "DEPENDENCIAS: AUR HELPER (YAY)"
        info "Instalando yay..."
        sudo pacman -S --needed --noconfirm base-devel git
        rm -rf /tmp/yay
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        (cd /tmp/yay && makepkg -si --noconfirm)
        rm -rf /tmp/yay
        cd "$DOTFILES_DIR"
        if command -v yay > /dev/null 2>&1; then
            success "yay helper inicializado correctamente."
        else
            error "No se pudo compilar yay."
            exit 1
        fi
    fi
}

# --- HARDWARE DETECTION ---
auto_detect_drivers() {
    section "DETECCION AUTOMATICA DE HARDWARE"
    local EXTRA_PKGS=()
    
    # GPU Detection
    local GPU_INFO
    GPU_INFO=$(lspci 2>/dev/null | grep -i -E "vga|3d|display" || true)

    if [[ $GPU_INFO == *"NVIDIA"* ]]; then
        info "GPU NVIDIA detectada. Agregando controladores propietarios y utilidades..."
        EXTRA_PKGS+=(nvidia-open nvidia-settings nvidia-utils nvidia-prime lib32-nvidia-utils)
    fi
    if [[ $GPU_INFO == *"Advanced Micro Devices"* ]] || [[ $GPU_INFO == *"ATI"* ]]; then
        info "GPU AMD detectada. Agregando controladores Mesa y Vulkan..."
        EXTRA_PKGS+=(lib32-mesa vulkan-radeon lib32-vulkan-radeon mesa-utils)
    fi
    if [[ $GPU_INFO == *"Intel"* ]]; then
        info "GPU Intel detectada. Agregando aceleracion por hardware y Vulkan..."
        EXTRA_PKGS+=(intel-media-driver libva-intel-driver vulkan-intel)
    fi

    # Laptop / Device Specific Detection
    local SYS_VENDOR PROD_NAME
    SYS_VENDOR=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)
    PROD_NAME=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)

    if [[ $SYS_VENDOR == *"ASUSTeK"* ]]; then
        info "Hardware ASUS detectado. Agregando soporte Asusctl y Supergfxctl..."
        EXTRA_PKGS+=(asusctl supergfxctl rog-control-center)
    fi

    if [[ $PROD_NAME == *"Surface"* ]]; then
        info "Hardware Microsoft Surface detectado. Agregando utilidades Surface..."
        EXTRA_PKGS+=(linux-surface linux-surface-headers surface-control)
    fi

    if [ ${#EXTRA_PKGS[@]} -gt 0 ]; then
        info "Instalando paquetes especificos: ${EXTRA_PKGS[*]}"
        yay -S --needed --noconfirm "${EXTRA_PKGS[@]}" || warn "Algunos controladores opcionales no pudieron instalarse."
        success "Controladores configurados."
    else
        info "No se requirieron controladores especiales adicionales."
    fi
}

# --- RUST DOCK DEPLOYMENT ---
install_rust_dock() {
    section "DESPLIEGUE DE RUST-DOCK"

    info "Instalando dependencias de compilacion para rust-dock..."
    yay -S --needed --noconfirm rust pkgconf gtk4 gtk4-layer-shell grim > /dev/null 2>&1

    if ! command -v cargo > /dev/null 2>&1; then
        warn "Cargo no encontrado tras instalar rust. Omitiendo compilacion automatica de rust-dock."
        return
    fi

    info "Compilando rust-dock desde codigo fuente..."
    local source_dir=""
    local temp_clone=false

    if [ -d "$DOTFILES_DIR/../rust-dock" ] && [ -f "$DOTFILES_DIR/../rust-dock/Cargo.toml" ]; then
        source_dir="$DOTFILES_DIR/../rust-dock"
    elif [ -d "$HOME/rust-dock" ] && [ -f "$HOME/rust-dock/Cargo.toml" ]; then
        source_dir="$HOME/rust-dock"
    else
        source_dir="/tmp/rust-dock-build"
        rm -rf "$source_dir"
        if git clone --depth=1 https://github.com/rhythmcreative/rust-dock.git "$source_dir" > /dev/null 2>&1; then
            temp_clone=true
        else
            warn "No se pudo clonar el repositorio de rust-dock. Omitiendo."
            return
        fi
    fi

    gum spin --spinner dot --title "Compilando rust-dock en release..." -- \
        bash -c "cd '$source_dir' && cargo build --release 2>&1 | tail -3 > /tmp/rust-dock-build.log" || true

    if [ -f "$source_dir/target/release/rust-dock" ]; then
        mkdir -p "$HOME/.local/bin"
        cp -f "$source_dir/target/release/rust-dock" "$HOME/.local/bin/rust-dock"
        chmod +x "$HOME/.local/bin/rust-dock"
        
        mkdir -p "$HOME/.local/share/rust-dock"
        if [ ! -f "$HOME/.local/share/rust-dock/pinned" ]; then
            cat > "$HOME/.local/share/rust-dock/pinned" << 'PINNED'
kitty
chromium
vesktop
org.telegram.desktop
PINNED
        fi
        success "rust-dock instalado en ~/.local/bin/rust-dock"
    else
        warn "La compilacion de rust-dock fallo. Consulta /tmp/rust-dock-build.log."
    fi

    if [ "$temp_clone" = true ]; then
        rm -rf "$source_dir"
    fi
}

# --- SYSTEM PACKAGES DEPLOYMENT ---
step_software() {
    section "PAQUETES Y COMPONENTES PRINCIPALES"

    # Core packages including Quickshell for Dynamic Island, Waybar, Rofi, Audio, Portal, Qt, etc.
    local CORE_PKGS=(
        # Compositor y entorno
        hyprland
        hypridle
        hyprlock
        hyprpicker
        hyprpm
        xdg-desktop-portal-hyprland
        xdg-desktop-portal-gtk

        # Barras, islas y lanzadores
        waybar
        quickshell
        rofi-wayland

        # Terminal y Shell
        kitty
        zsh
        zsh-autosuggestions
        zsh-syntax-highlighting

        # Gestores de archivos y miniaturas
        thunar
        thunar-archive-plugin
        thunar-volman
        file-roller
        gvfs
        tumbler
        ffmpegthumbnailer
        poppler-glib
        libgsf
        libopenraw
        libgepub
        gwenview

        # Red y Bluetooth
        networkmanager
        network-manager-applet
        bluez
        bluez-utils
        blueman
        bluez-obex

        # Arquitectura de sonido
        pipewire
        pipewire-pulse
        wireplumber
        pavucontrol
        playerctl
        pamixer

        # Control de hardware y captura
        brightnessctl
        swappy
        grim
        slurp
        wl-clipboard
        libnotify
        socat

        # Frameworks Qt (Requeridos para SDDM y Quickshell)
        qt5-graphicaleffects
        qt5-quickcontrols2
        qt5-svg
        qt5-declarative
        qt6-declarative
        qt6-quickcontrols2
        qt6-svg
        qt6-wayland
        qt5ct
        qt6ct
        kvantum

        # Login manager y autenticacion
        sddm
        polkit-kde-agent
        gnome-keyring

        # Temas, iconos, cursores y fondos
        nwg-look
        bibata-cursor-theme
        tela-circle-icon-theme-all
        python-pywal
        awww
        cava

        # Fuentes
        ttf-jetbrains-mono-nerd
        otf-font-awesome
        ttf-font-awesome

        # Utilidades del sistema
        flatpak
        stow
        curl
        unzip
        jq
        bc
        imagemagick
        htop
        fastfetch
    )

    info "$MSG_CORE_INSTALL"
    yay -S --needed --noconfirm "${CORE_PKGS[@]}"

    # Install rust-dock from source
    install_rust_dock

    # Install Hyprland plugins via hyprpm
    section "PLUGINS DE HYPRLAND"
    if command -v hyprpm > /dev/null 2>&1; then
        info "Sincronizando repositorios de plugins oficiales..."
        hyprpm add https://github.com/hyprwm/hyprland-plugins 2>&1 | tail -1 || true
        hyprpm update 2>&1 | tail -1 || true
        info "Habilitando plugins hyprbars, hyprexpo..."
        hyprpm enable hyprbars 2>&1 | tail -1 || true
        hyprpm enable hyprexpo 2>&1 | tail -1 || true
        hyprpm reload 2>&1 || true
        success "Plugins de Hyprland configurados."
    else
        warn "hyprpm no disponible. Omitiendo plugins de Hyprland."
    fi

    # Hardware drivers detection
    auto_detect_drivers

    # Unified app search
    unified_app_search

    # Flatpaks deployment
    if gum confirm "$MSG_FLATPAK_CONFIRM"; then
        if [ -f "$DOTFILES_DIR/flatpaks.txt" ]; then
            section "DESPLIEGUE FLATPAK"
            sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
            while read -r app; do
                [ -z "$app" ] || [[ "$app" =~ ^# ]] && continue
                info "Instalando: $app"
                sudo flatpak install -y --system flathub "$app" || true
            done < "$DOTFILES_DIR/flatpaks.txt"
            success "Flatpaks procesados."
        fi
    fi
}

unified_app_search() {
    section "DESCUBRIMIENTO OPCIONAL DE APLICACIONES"
    info "$MSG_SEARCH_LAUNCH"
    
    local fzf_args=(
      --multi
      --ansi
      --prompt="$MSG_SEARCH_PROMPT"
      --header="$MSG_SEARCH_HEADER"
      --preview 'yay -Si {1} 2>/dev/null || echo "Cargando informacion..." '
      --preview-window 'right:60%:wrap'
      --bind 'change:top'
    )

    local SELECTED_APPS
    SELECTED_APPS=$(yay -Slqa | fzf "${fzf_args[@]}" || true)

    if [[ -n "$SELECTED_APPS" ]]; then
        info "Instalando aplicaciones seleccionadas..."
        yay -S --needed --noconfirm $SELECTED_APPS
        success "Aplicaciones adicionales instaladas."
    else
        info "No se seleccionaron aplicaciones adicionales."
    fi
}

# --- DOTFILES DEPLOYMENT ---
step_dotfiles() {
    section "SINCRONIZACION DE CONFIGURACIONES (DOTFILES)"
    mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share" "$HOME/.cache"
    
    cd "$DOTFILES_DIR"

    info "Copiando carpetas de configuracion a ~/.config/..."
    for item in .config/*; do
        [ -e "$item" ] || continue
        local name
        name=$(basename "$item")
        local target="$HOME/.config/$name"
        
        if [ -e "$target" ]; then
            info "Creando respaldo de .config/$name -> .config/$name.bak"
            rm -rf "$target.bak"
            mv "$target" "$target.bak"
        fi
        
        cp -r "$DOTFILES_DIR/.config/$name" "$target"
        echo "  INSTALADO: .config/$name"
    done

    # Generate default monitors.conf if missing
    if [ ! -f "$HOME/.config/hypr/monitors.conf" ]; then
        info "Generando monitors.conf generico..."
        cat > "$HOME/.config/hypr/monitors.conf" << 'MONCONF'
# Archivo autogenerado por el instalador
# Editalo con nwg-displays o manualmente: monitor=NOMBRE,RESOLUCION@TASA,POSICION,ESCALA
monitor=,preferred,auto,1
MONCONF
    fi

    info "Copiando ejecutables a ~/.local/bin/..."
    for file in .local/bin/*; do
        [ -e "$file" ] || continue
        local name
        name=$(basename "$file")
        local target="$HOME/.local/bin/$name"
        
        if [ -e "$target" ]; then
            rm -rf "$target.bak"
            mv "$target" "$target.bak"
        fi
        
        cp -f "$DOTFILES_DIR/$file" "$target"
        chmod +x "$target"
    done
    chmod +x "$HOME/.local/bin"/* 2>/dev/null || true
    echo "  INSTALADO: Scripts ejecutables en ~/.local/bin/"

    # Handle shell & gtk dotfiles if present
    for pkg in zsh bash gtk; do
        if [ -d "$pkg" ]; then
            find "$pkg" -mindepth 1 -maxdepth 1 -name ".*" | while read -r file; do
                local name
                name=$(basename "$file")
                local target="$HOME/$name"
                if [ -e "$target" ]; then
                    rm -rf "$target.bak"
                    mv "$target" "$target.bak"
                fi
                cp -r "$DOTFILES_DIR/$file" "$target"
                echo "  INSTALADO: ~/$name"
            done
        fi
    done

    info "Adaptando rutas fijas al usuario actual ($USER)..."
    grep -rIl "/home/rhythmcreative" "$HOME/.config" "$HOME/.local/bin" "$HOME/.bashrc" "$HOME/.zshrc" 2>/dev/null | while read -r file; do
        sed -i "s|/home/rhythmcreative|$HOME|g" "$file" 2>/dev/null || true
    done

    # Enable user systemd service for Dynamic Island
    info "Habilitando servicio systemd de usuario para Dynamic Island..."
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable waybar-island.service 2>/dev/null || true

    # Default GTK Theme configuration
    info "Aplicando temas GTK por defecto..."
    gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Ice" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "Tela-circle" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null || true
    
    success "Dotfiles desplegados y adaptados al usuario."
}

# --- WALLPAPERS DOWNLOAD ---
step_wallpapers() {
    section "PAQUETES DE FONDOS DE PANTALLA"
    if gum confirm "$MSG_WALL_CONFIRM"; then
        local WALL_DIR="$HOME/Pictures/Wallpapers"
        mkdir -p "$WALL_DIR"
        local TEMP_WALL="/tmp/wallpaper_install"
        mkdir -p "$TEMP_WALL"
        
        local REPO_URL="https://raw.githubusercontent.com/rhythmcreative/wallpapers/main"
        local HEADER_TEXT="Selecciona el modo de descarga"
        [ "$LANG_CHOICE" == "English" ] && HEADER_TEXT="Select download protocol"

        local CHOICE
        CHOICE=$(gum choose --header "$HEADER_TEXT" \
            "DESCARGAR TODOS LOS PACKS (4GB+)" \
            "SELECCIONAR PACKS ESPECIFICOS" \
            "SELECCION ALEATORIA (3 PACKS)" \
            "OMITIR")
        
        if [ "$CHOICE" == "DESCARGAR TODOS LOS PACKS (4GB+)" ]; then
            for i in {1..49}; do
                info "Descargando pack $i/49..."
                curl -L "$REPO_URL/pack_$i.zip" -o "$TEMP_WALL/pack_$i.zip"
                unzip -q -o "$TEMP_WALL/pack_$i.zip" -d "$TEMP_WALL"
                [ -d "$TEMP_WALL/pack_$i" ] && cp -r "$TEMP_WALL/pack_$i"/* "$WALL_DIR/" && rm -rf "$TEMP_WALL/pack_$i"
                rm -f "$TEMP_WALL/pack_$i.zip"
            done
        elif [ "$CHOICE" == "SELECCIONAR PACKS ESPECIFICOS" ]; then
            local PLACEHOLDER="Numeros separados por espacio (ej: 1 5 12)"
            [ "$LANG_CHOICE" == "English" ] && PLACEHOLDER="Numbers separated by space (e.g. 1 5 12)"
            local PACKS
            PACKS=$(gum input --placeholder "$PLACEHOLDER")
            for p in $PACKS; do
                info "Descargando pack $p..."
                curl -L "$REPO_URL/pack_$p.zip" -o "$TEMP_WALL/pack_$p.zip"
                unzip -q -o "$TEMP_WALL/pack_$p.zip" -d "$TEMP_WALL"
                [ -d "$TEMP_WALL/pack_$p" ] && cp -r "$TEMP_WALL/pack_$p"/* "$WALL_DIR/" && rm -rf "$TEMP_WALL/pack_$p"
                rm -f "$TEMP_WALL/pack_$p.zip"
            done
        elif [ "$CHOICE" == "SELECCION ALEATORIA (3 PACKS)" ]; then
            info "Descargando 3 packs aleatorios..."
            for i in {1..3}; do
                local p
                p=$(shuf -i 1-49 -n 1)
                info "Descargando pack $p..."
                curl -L "$REPO_URL/pack_$p.zip" -o "$TEMP_WALL/pack_$p.zip"
                unzip -q -o "$TEMP_WALL/pack_$p.zip" -d "$TEMP_WALL"
                [ -d "$TEMP_WALL/pack_$p" ] && cp -r "$TEMP_WALL/pack_$p"/* "$WALL_DIR/" && rm -rf "$TEMP_WALL/pack_$p"
                rm -f "$TEMP_WALL/pack_$p.zip"
            done
        fi
        rm -rf "$TEMP_WALL"
        success "Fondos descargados en ~/Pictures/Wallpapers."
    fi
}

# --- SYSTEM INTEGRATION & SERVICES ---
step_system() {
    section "SERVICIOS DEL SISTEMA Y FINALIZACION"
    
    if gum confirm "$MSG_ZSH_CONFIRM"; then
        if [ "$SHELL" != "$(which zsh)" ]; then
            sudo chsh -s "$(which zsh)" "$USER"
            success "Shell predeterminada cambiada a Zsh."
        fi
    fi

    # SDDM Theme and Sudoers Sync Integration
    if [ -d "$DOTFILES_DIR/sddm/sddm-astronaut-theme" ]; then
        info "Instalando tema SDDM Astronaut..."
        sudo mkdir -p /usr/share/sddm/themes
        sudo cp -r "$DOTFILES_DIR/sddm/sddm-astronaut-theme" /usr/share/sddm/themes/
        
        sudo mkdir -p /etc/sddm.conf.d /etc/sddm
        echo -e "[Theme]\nCurrent=sddm-astronaut-theme" | sudo tee /etc/sddm.conf.d/theme.conf > /dev/null

        # Multi-monitor detection for SDDM
        info "Configurando soporte multi-monitor para pantalla de inicio..."
        sudo tee /etc/sddm/Xsetup > /dev/null << 'XSETUP'
#!/bin/sh
get_width() {
    xrandr --query | awk -v m="$1" '
        $0 ~ m " connected" { f=1; next }
        f && /^[[:space:]]+[0-9]+x/ { split($1,a,"x"); print a[1]; exit }
        f && !/^[[:space:]]/ { exit }
    '
}
i=0
while [ "$i" -lt 10 ]; do
    xrandr --query | grep -q " connected" && break
    sleep 0.5
    i=$((i + 1))
done
CONNECTED=$(xrandr --query | awk '/connected/ && !/disconnected/ { print $1 }')
COUNT=$(printf '%s\n' "$CONNECTED" | grep -c .)
if [ "$COUNT" -eq 0 ]; then
    xrandr --auto
    exit 0
fi
EXTERNALS=$(printf '%s\n' "$CONNECTED" | grep -vE '^(eDP|LVDS)')
INTERNAL=$(printf '%s\n'  "$CONNECTED" | grep -E  '^(eDP|LVDS)')
X=0
FIRST=true
for mon in $EXTERNALS; do
    W=$(get_width "$mon")
    [ -z "$W" ] && W=1920
    if [ "$FIRST" = true ]; then
        xrandr --output "$mon" --auto --pos "${X}x0" --primary
        FIRST=false
    else
        xrandr --output "$mon" --auto --pos "${X}x0"
    fi
    X=$((X + W))
done
for mon in $INTERNAL; do
    W=$(get_width "$mon")
    [ -z "$W" ] && W=1920
    if [ "$FIRST" = true ]; then
        xrandr --output "$mon" --auto --pos "${X}x0" --primary
        FIRST=false
    else
        xrandr --output "$mon" --auto --pos "${X}x0"
    fi
    X=$((X + W))
done
XSETUP
        sudo chmod +x /etc/sddm/Xsetup
        echo -e "[X11]\nDisplayCommand=/etc/sddm/Xsetup" | sudo tee /etc/sddm.conf.d/xsetup.conf > /dev/null

        # SDDM NOPASSWD helper for pywal live background sync
        info "Configurando permisos de sincronizacion de fondos para SDDM..."
        sudo mkdir -p /etc/sudoers.d
        echo "$USER ALL=(root) NOPASSWD: $HOME/.local/bin/sddm-auto-sync-local" | sudo tee /etc/sudoers.d/sddm-sync > /dev/null
        sudo chmod 440 /etc/sudoers.d/sddm-sync

        # Pywal hook for SDDM
        mkdir -p "$HOME/.config/wal/hooks"
        cat > "$HOME/.config/wal/hooks/sddm-sync.sh" << EOF
#!/bin/bash
if [ -x "$HOME/.local/bin/sddm-sync-wrapper" ]; then
    "$HOME/.local/bin/sddm-sync-wrapper" >/dev/null 2>&1 || true
fi
EOF
        chmod +x "$HOME/.config/wal/hooks/sddm-sync.sh"

        # Generate initial color palette from SDDM wallpaper
        local SDDM_WALLPAPER="$DOTFILES_DIR/sddm/sddm-astronaut-theme/Backgrounds/current_wallpaper.jpg"
        if [ -f "$SDDM_WALLPAPER" ]; then
            wal -i "$SDDM_WALLPAPER" -n -q 2>/dev/null || true
            mkdir -p "$HOME/.cache"
            echo "$SDDM_WALLPAPER" > "$HOME/.cache/current-wallpaper"
        fi
    fi

    info "Habilitando servicios esenciales del sistema..."
    sudo systemctl enable NetworkManager bluetooth sddm 2>/dev/null || true
    sudo systemctl start NetworkManager bluetooth 2>/dev/null || true

    # PAM gnome-keyring configuration
    info "Configurando desbloqueo automatico de gnome-keyring..."
    for pam_file in /etc/pam.d/login /etc/pam.d/sddm; do
        if [ -f "$pam_file" ] && ! grep -q "pam_gnome_keyring.so" "$pam_file"; then
            sudo sed -i '/^auth.*pam_unix/a auth       optional     pam_gnome_keyring.so' "$pam_file"
            sudo sed -i '/^session.*pam_unix/a session    optional     pam_gnome_keyring.so auto_start' "$pam_file"
        fi
    done

    # Pipewire audio configuration
    info "Habilitando servicios de audio Pipewire..."
    systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true

    # Add user to required hardware groups
    info "Agregando usuario a los grupos de hardware..."
    sudo usermod -aG video,input,render,wheel,audio,storage "$USER"
    
    success "Servicios y permisos del sistema configurados."
}

# --- MAIN EXECUTION ---
preflight_checks
print_banner
setup_language

gum spin --spinner pulse --title "INICIANDO INSTALACION..." -- sleep 1

install_yay
step_software
step_dotfiles
step_wallpapers
step_system

# Calibration with modern-pywal-sync
if [ -x "$HOME/.local/bin/modern-pywal-sync" ]; then
    gum spin --spinner dot --title "CALIBRANDO COLORES Y TEMAS DEL SISTEMA..." -- bash -c "$HOME/.local/bin/modern-pywal-sync >/dev/null 2>&1 || true"
fi

# --- SUMMARY & COMPLETION ---
clear
section "RESUMEN"
echo "  $MSG_DONE"
echo ""

# Do not restart SDDM abruptly if inside an active Wayland/X11 session
if [ -n "$WAYLAND_DISPLAY" ] || [ -n "$DISPLAY" ]; then
    info "Actualmente estas en una sesion grafica activa."
    info "Reinicia el equipo para iniciar con SDDM y cargar todas las configuraciones y grupos nuevos."
    if gum confirm "$MSG_REBOOT_CONFIRM"; then
        sudo reboot
    fi
else
    info "Iniciando gestor de sesion SDDM..."
    sudo systemctl start sddm
fi
