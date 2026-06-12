#!/bin/bash

# --- Rhythm Arch Hyprland Installer v3 (Minimal White) ---

# Colors & Aesthetic (Synchronized with Terminal Theme)
# We set these environment variables to ensure 'gum' uses terminal defaults
export GUM_CHOOSE_CURSOR_FOREGROUND="7"
export GUM_CHOOSE_HEADER_FOREGROUND="7"
export GUM_CHOOSE_SELECTED_FOREGROUND="7"
export GUM_SPIN_SPINNER_FOREGROUND="7"
export GUM_STYLE_FOREGROUND="7"
export GUM_CONFIRM_PROMPT_FOREGROUND="7"
export GUM_CONFIRM_SELECTED_BACKGROUND="7"
export GUM_CONFIRM_SELECTED_FOREGROUND="0"

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# --- LOCALIZATION ---
setup_language() {
    LANG_CHOICE=$(gum choose --header "Select Language / Selecciona Idioma" "English" "Español")
    
    case "$LANG_CHOICE" in
        "Español")
            MSG_ERROR_ROOT=" [ERROR] No ejecutes este script como root."
            MSG_SECTION=" SECCION: "
            MSG_CORE_INSTALL="Instalando nucleo del sistema..."
            MSG_SEARCH_PROMPT="Buscar Apps: "
            MSG_SEARCH_HEADER="[TAB] Seleccionar | [ENTER] Instalar | [ESC] Omitir"
            MSG_SEARCH_LAUNCH="Lanzando herramienta de busqueda (Oficial + AUR)..."
            MSG_DRIVER_HEADER="DRIVERS GRAFICOS (Selecciona tu hardware)"
            MSG_DEPLOY_DRIVERS="Instalando drivers de hardware..."
            MSG_FLATPAK_CONFIRM="¿Instalar Flatpaks de tu lista flatpaks.txt?"
            MSG_WALL_CONFIRM="¿Descargar fondos de pantalla personalizados?"
            MSG_ZSH_CONFIRM="¿Establecer Zsh como shell por defecto?"
            MSG_DONE="Despliegue completado."
            ;;
        *)
            # Default to English
            MSG_ERROR_ROOT=" [ERROR] Do not run this script as root."
            MSG_SECTION=" SECTION: "
            MSG_CORE_INSTALL="Installing system core..."
            MSG_SEARCH_PROMPT="Search Apps: "
            MSG_SEARCH_HEADER="[TAB] Select Multiple | [ENTER] Install | [ESC] Skip"
            MSG_SEARCH_LAUNCH="Launching Interactive Search Tool (Official + AUR)..."
            MSG_DRIVER_HEADER="GRAPHICS DRIVERS (Select your hardware)"
            MSG_DEPLOY_DRIVERS="Deploying hardware drivers..."
            MSG_FLATPAK_CONFIRM="Install Flatpaks from your flatpaks.txt list?"
            MSG_WALL_CONFIRM="Download custom wallpaper assets?"
            MSG_ZSH_CONFIRM="Set Zsh as your default shell?"
            MSG_DONE="Deployment complete."
            ;;
    esac
}

# --- INITIAL SETUP ---
if [ "$EUID" -eq 0 ]; then
    echo "Do not run as root."
    exit 1
fi

# Check if running on Arch Linux
if [ ! -f /etc/arch-release ]; then
    echo "ERROR: This script is only compatible with Arch Linux."
    exit 1
fi

# Ensure core dependencies are installed
if ! command -v gum > /dev/null || ! command -v fzf > /dev/null; then
    sudo pacman -S --needed --noconfirm gum fzf git base-devel stow zsh curl > /dev/null 2>&1
fi

setup_language

# --- HARDWARE DETECTION ---
auto_detect_drivers() {
    section "AUTOMATIC HARDWARE DETECTION"
    EXTRA_PKGS=""
    
    # GPU Detection
    GPU_INFO=$(lspci | grep -i vga)
    if [[ $GPU_INFO == *"NVIDIA"* ]]; then
        info "Detected NVIDIA GPU. Adding proprietary drivers..."
        EXTRA_PKGS="$EXTRA_PKGS nvidia nvidia-settings nvidia-utils"
    elif [[ $GPU_INFO == *"Advanced Micro Devices"* ]] || [[ $GPU_INFO == *"ATI"* ]]; then
        info "Detected AMD GPU. Adding Mesa drivers..."
        EXTRA_PKGS="$EXTRA_PKGS lib32-mesa vulkan-radeon lib32-vulkan-radeon mesa-utils"
    elif [[ $GPU_INFO == *"Intel"* ]]; then
        info "Detected Intel Graphics. Adding media drivers..."
        EXTRA_PKGS="$EXTRA_PKGS intel-media-driver libva-intel-driver vulkan-intel"
    fi

    # Laptop/Hardware Specific Detection
    SYS_VENDOR=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)
    PROD_NAME=$(cat /sys/class/dmi/id/product_name 2>/dev/null)

    if [[ $SYS_VENDOR == *"ASUSTeK"* ]]; then
        info "Detected ASUS hardware. Adding ASUS laptop tools..."
        EXTRA_PKGS="$EXTRA_PKGS asusctl supergfxctl rog-control-center"
    fi

    if [[ $PROD_NAME == *"Surface"* ]]; then
        info "Detected Surface hardware. Adding Surface kernel tools..."
        EXTRA_PKGS="$EXTRA_PKGS linux-surface linux-surface-headers surface-control"
    fi

    if [ ! -z "$EXTRA_PKGS" ]; then
        info "Deploying detected hardware drivers: $EXTRA_PKGS"
        yay -S --needed --noconfirm $EXTRA_PKGS
    else
        info "No specific hardware drivers required or detected."
    fi
}

# --- UI COMPONENTS ---

print_banner() {
    clear
    # ASCII Art using terminal default foreground color
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

section() {
    echo ""
    gum style --bold --margin "1 0" --underline "$MSG_SECTION $1 "
}

info() {
    echo "  [SYSTEM] $1"
}

success() {
    echo "  [DONE] $1"
}

# --- LOGIC ---

install_yay() {
    if ! command -v yay > /dev/null; then
        section "DEPENDENCY: AUR HELPER"
        gum spin --spinner dot --title "Deploying yay..." -- sleep 2
        git clone https://aur.archlinux.org/yay.git /tmp/yay > /dev/null 2>&1
        cd /tmp/yay && makepkg -si --noconfirm > /dev/null 2>&1
        cd "$DOTFILES_DIR"
        success "yay helper initialized."
    fi
}

unified_app_search() {
    section "UNIFIED APPLICATION DISCOVERY"
    info "$MSG_SEARCH_LAUNCH"
    
    # Configuration for fzf to provide a rich preview of pacman/yay packages
    fzf_args=(
      --multi
      --ansi
      --prompt="$MSG_SEARCH_PROMPT"
      --header="$MSG_SEARCH_HEADER"
      --preview 'yay -Si {1} 2>/dev/null || echo "Loading info..." '
      --preview-window 'right:60%:wrap'
      --bind 'change:top'
    )

    # Fetch all available packages from repositories and AUR
    SELECTED_APPS=$(yay -Slqa | fzf "${fzf_args[@]}")

    if [[ -n "$SELECTED_APPS" ]]; then
        info "Deploying selected applications..."
        yay -S --needed --noconfirm $SELECTED_APPS
        success "Applications installed."
    else
        info "No additional applications selected."
    fi
}

install_rust_dock() {
    section "RUST-DOCK DEPLOYMENT"

    # Build-time deps: Rust toolchain + GTK4 headers + layer-shell headers + pkg-config
    info "Installing rust-dock build dependencies..."
    yay -S --needed --noconfirm \
        rust \
        pkgconf \
        gtk4 \
        gtk4-layer-shell \
        grim \
        > /dev/null 2>&1

    # Verify the toolchain is actually usable before trying to compile
    if ! command -v cargo > /dev/null 2>&1; then
        info "WARNING: cargo not found after installing rust. Skipping rust-dock build."
        info "  You can build it manually: git clone https://github.com/rhythmcreative/rust-dock.git && cd rust-dock && cargo build --release"
        return
    fi

    info "Building rust-dock from source..."
    local build_dir="/tmp/rust-dock-build"
    rm -rf "$build_dir"

    if ! git clone --depth=1 https://github.com/rhythmcreative/rust-dock.git "$build_dir" > /dev/null 2>&1; then
        info "WARNING: Could not clone rust-dock repository. Skipping."
        return
    fi

    gum spin --spinner dot --title "Compiling rust-dock (this may take a minute)..." -- \
        bash -c "cd '$build_dir' && cargo build --release 2>&1 | tail -3 > /tmp/rust-dock-build.log"

    if [ -f "$build_dir/target/release/rust-dock" ]; then
        mkdir -p "$HOME/.local/bin"
        cp "$build_dir/target/release/rust-dock" "$HOME/.local/bin/rust-dock"
        chmod +x "$HOME/.local/bin/rust-dock"
        success "rust-dock installed to ~/.local/bin/rust-dock"
    else
        info "WARNING: rust-dock build failed. Check /tmp/rust-dock-build.log for details."
        info "  Manual build: git clone https://github.com/rhythmcreative/rust-dock.git && cd rust-dock && cargo build --release"
    fi
    rm -rf "$build_dir"
}

step_software() {
    section "CORE SYSTEM DEPLOYMENT"
    
    CORE_PKGS="hyprland sddm hypridle hyprlock hyprpicker xdg-desktop-portal-hyprland waybar rofi kitty networkmanager network-manager-applet bluez bluez-utils blueman pipewire pipewire-pulse wireplumber pavucontrol playerctl pamixer brightnessctl gvfs polkit-kde-agent swappy grim slurp nwg-look bibata-cursor-theme tela-circle-icon-theme-all otf-font-awesome ttf-jetbrains-mono-nerd flatpak python-pywal awww stow qt5-graphicaleffects qt5-quickcontrols2 qt5-svg qt5-declarative qt6-svg curl unzip zsh-autosuggestions zsh-syntax-highlighting ulauncher nwg-displays wl-clipboard xdg-utils jq bc quickshell imagemagick htop fastfetch bluez-obex gwenview tumbler ffmpegthumbnailer poppler-glib libgsf libopenraw libgepub kvantum qt5ct qt6ct gnome-keyring cava"

    info "$MSG_CORE_INSTALL"
    yay -S --needed --noconfirm $CORE_PKGS

    section "CUSTOM MODULE DEPLOYMENT"

    # Build and install rust-dock from source
    install_rust_dock

    # Automatic Driver Detection
    auto_detect_drivers

    # Interactive Application Discovery
    unified_app_search

    if gum confirm "$MSG_FLATPAK_CONFIRM"; then
        if [ -f "$DOTFILES_DIR/flatpaks.txt" ]; then
            section "FLATPAK DEPLOYMENT"
            sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
            while read -r app; do
                [ -z "$app" ] || [[ "$app" =~ ^# ]] && continue
                info "Installing: $app"
                sudo flatpak install -y --system flathub "$app"
            done < "$DOTFILES_DIR/flatpaks.txt"
        fi
    fi
}

step_dotfiles() {
    section "DOTFILES SYNC"
    # Ensure base directories exist
    mkdir -p ~/.config ~/.local/bin
    
    cd "$DOTFILES_DIR"

    info "Copying configurations..."
    
    # 1. Handle .config (Copy each item individually to ~/.config/)
    for item in .config/*; do
        [ -e "$item" ] || continue
        name=$(basename "$item")
        target="$HOME/.config/$name"
        
        if [ -e "$target" ]; then
            info "Backing up existing .config/$name"
            mv "$target" "$target.bak"
        fi
        
        cp -r "$DOTFILES_DIR/.config/$name" "$target"
        echo "  COPY: $name => ~/.config/$name"
    done

    # 2. Handle .local/bin (Copy each file individually to ~/.local/bin/)
    for file in .local/bin/*; do
        [ -e "$file" ] || continue
        name=$(basename "$file")
        target="$HOME/.local/bin/$name"
        
        if [ -e "$target" ]; then
            mv "$target" "$target.bak"
        fi
        
        cp "$DOTFILES_DIR/$file" "$target"
        chmod +x "$target"
    done
    echo "  COPY: bin contents => ~/.local/bin/"

    # 3. Handle other packages (zsh, bash, gtk) that go into $HOME
    for pkg in zsh bash gtk; do
        if [ -d "$pkg" ]; then
            find "$pkg" -mindepth 1 -maxdepth 1 -name ".*" | while read -r file; do
                name=$(basename "$file")
                target="$HOME/$name"
                
                if [ -e "$target" ]; then
                    info "Backing up existing $name"
                    mv "$target" "$target.bak"
                fi
                
                cp -r "$DOTFILES_DIR/$file" "$target"
                echo "  COPY: $name => ~/$name"
            done
        fi
    done
    
    success "Local configs copied (Physical installation complete)."
    
    info "Fixing hardcoded paths for current user..."
    # Replace hardcoded home path in copied text files
    grep -rIl "/home/rhythmcreative" "$HOME/.config" "$HOME/.local/bin" "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.gtkrc-2.0" 2>/dev/null | while read -r file; do
        sed -i "s|/home/rhythmcreative|$HOME|g" "$file"
        echo "  FIXED: $file"
    done
}

step_wallpapers() {
    section "NEURAL WALLPAPER PACKS"
    if gum confirm "$MSG_WALL_CONFIRM"; then
        WALL_DIR="$HOME/Pictures/Wallpapers"
        mkdir -p "$WALL_DIR"
        TEMP_WALL="/tmp/wallpaper_install"
        mkdir -p "$TEMP_WALL"
        
        REPO_URL="https://raw.githubusercontent.com/rhythmcreative/wallpapers/main"
        
        HEADER_TEXT="Select download protocol"
        [ "$LANG_CHOICE" == "Español" ] && HEADER_TEXT="Selecciona el protocolo de descarga"

        CHOICE=$(gum choose --header "$HEADER_TEXT" \
            "DEPLOY ALL PACKS (4GB+)" \
            "SELECT SPECIFIC PACKS" \
            "RANDOM NEURAL SELECTION" \
            "ABORT")
        
        if [ "$CHOICE" == "DEPLOY ALL PACKS (4GB+)" ]; then
            for i in {1..49}; do
                info "Downloading pack $i/49..."
                curl -L "$REPO_URL/pack_$i.zip" -o "$TEMP_WALL/pack_$i.zip"
                unzip -q -o "$TEMP_WALL/pack_$i.zip" -d "$TEMP_WALL"
                [ -d "$TEMP_WALL/pack_$i" ] && cp -r "$TEMP_WALL/pack_$i"/* "$WALL_DIR/" && rm -rf "$TEMP_WALL/pack_$i"
                rm "$TEMP_WALL/pack_$i.zip"
            done
        elif [ "$CHOICE" == "SELECT SPECIFIC PACKS" ]; then
            PLACEHOLDER="Numbers separated by space (e.g., 1 5 40)"
            [ "$LANG_CHOICE" == "Español" ] && PLACEHOLDER="Numeros separados por espacios (ej: 1 5 40)"
            PACKS=$(gum input --placeholder "$PLACEHOLDER")
            for p in $PACKS; do
                info "Downloading pack $p..."
                curl -L "$REPO_URL/pack_$p.zip" -o "$TEMP_WALL/pack_$p.zip"
                unzip -q -o "$TEMP_WALL/pack_$p.zip" -d "$TEMP_WALL"
                [ -d "$TEMP_WALL/pack_$p" ] && cp -r "$TEMP_WALL/pack_$p"/* "$WALL_DIR/" && rm -rf "$TEMP_WALL/pack_$p"
                rm "$TEMP_WALL/pack_$p.zip"
            done
        elif [ "$CHOICE" == "RANDOM NEURAL SELECTION" ]; then
            info "Choosing 3 random archives..."
            for i in {1..3}; do
                p=$(shuf -i 1-49 -n 1)
                info "Downloading pack $p..."
                curl -L "$REPO_URL/pack_$p.zip" -o "$TEMP_WALL/pack_$p.zip"
                unzip -q -o "$TEMP_WALL/pack_$p.zip" -d "$TEMP_WALL"
                [ -d "$TEMP_WALL/pack_$p" ] && cp -r "$TEMP_WALL/pack_$p"/* "$WALL_DIR/" && rm -rf "$TEMP_WALL/pack_$p"
                rm "$TEMP_WALL/pack_$p.zip"
            done
        fi
        rm -rf "$TEMP_WALL"
        success "Wallpapers localized."
    fi
}

step_system() {
    section "SYSTEM FINALIZATION"
    
    if gum confirm "$MSG_ZSH_CONFIRM"; then
        [ "$SHELL" != "$(which zsh)" ] && sudo chsh -s "$(which zsh)" "$USER"
    fi

    # --- AUTOMATIC SERVICE ACTIVATION ---
    section "SERVICE CALIBRATION"

    if [ -d "$DOTFILES_DIR/sddm/sddm-astronaut-theme" ]; then
        info "Instalando tema SDDM Astronaut y configurando sincronización..."
        sudo mkdir -p /usr/share/sddm/themes
        sudo cp -r "$DOTFILES_DIR/sddm/sddm-astronaut-theme" /usr/share/sddm/themes/
        
        # Configurar SDDM para usar el tema
        sudo mkdir -p /etc/sddm.conf.d /etc/sddm
        echo -e "[Theme]\nCurrent=sddm-astronaut-theme" | sudo tee /etc/sddm.conf.d/theme.conf > /dev/null

        # --- MULTI-MONITOR AUTOMÁTICO ---
        info "Configurando soporte multi-monitor automático para SDDM..."
        sudo tee /etc/sddm/Xsetup > /dev/null << 'XSETUP'
#!/bin/sh
# Detectar y configurar todos los monitores conectados automáticamente

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

        # --- INTEGRACIÓN SDDM-ROOT-HELPER (Sincronización Pywal) ---
        # 1. Configurar permisos sudo para que el script de sincronización se ejecute sin contraseña
        info "Configurando permisos NOPASSWD para sincronización de SDDM..."
        sudo mkdir -p /etc/sudoers.d
        echo "$USER ALL=(root) NOPASSWD: $HOME/.local/bin/sddm-auto-sync-local" | sudo tee /etc/sudoers.d/sddm-sync > /dev/null
        sudo chmod 440 /etc/sudoers.d/sddm-sync

        # 2. Asegurar que los scripts de sincronización tengan permisos de ejecución
        chmod +x "$HOME/.local/bin/sddm-auto-sync-local" "$HOME/.local/bin/sddm-sync-wrapper" "$HOME/.local/bin/sync-sddm-wallpaper-sudo"

        # 3. Crear hook de pywal para sincronización automática si no existe
        info "Configurando hooks de Pywal para SDDM..."
        mkdir -p "$HOME/.config/wal/hooks"
        cat > "$HOME/.config/wal/hooks/sddm-sync.sh" << EOF
#!/bin/bash
# Hook para sincronizar SDDM cuando cambia el wallpaper
if [ -f "$HOME/.local/bin/sddm-sync-wrapper" ]; then
    "$HOME/.local/bin/sddm-sync-wrapper"
fi
EOF
        chmod +x "$HOME/.config/wal/hooks/sddm-sync.sh"

        # 4. Generar colores iniciales ANTES de iniciar SDDM para que el tema no se vea roto
        SDDM_WALLPAPER="$DOTFILES_DIR/sddm/sddm-astronaut-theme/Backgrounds/current_wallpaper.jpg"
        if [ -f "$SDDM_WALLPAPER" ]; then
            info "Generando paleta de colores inicial desde el fondo de SDDM..."
            wal -i "$SDDM_WALLPAPER" -n -q
            
            # Pre-configurar el cache para que Hyprland lo use al iniciar
            mkdir -p "$HOME/.cache"
            echo "$SDDM_WALLPAPER" > "$HOME/.cache/current-wallpaper"

            # Ejecutar sincronización manual inicial
            if [ -f "$HOME/.local/bin/sddm-sync-wrapper" ]; then
                bash "$HOME/.local/bin/sddm-sync-wrapper" || info "Warning: Initial SDDM sync failed, will retry later."
            fi
        fi
    fi
    success "Services operational and SDDM synchronization configured."

    info "Habilitando servicios de sistema esenciales..."
    sudo systemctl enable NetworkManager bluetooth sddm
    sudo systemctl start NetworkManager bluetooth

    info "Configurando gnome-keyring para Wayland..."
    # Enable PAM integration so gnome-keyring unlocks automatically on login
    if [ -f /etc/pam.d/login ] && ! grep -q "gnome-keyring-daemon" /etc/pam.d/login; then
        sudo sed -i '/^auth.*pam_unix/a auth       optional     pam_gnome_keyring.so' /etc/pam.d/login
        sudo sed -i '/^session.*pam_unix/a session    optional     pam_gnome_keyring.so auto_start' /etc/pam.d/login
    fi
    # Also apply to SDDM PAM profile if it exists
    if [ -f /etc/pam.d/sddm ] && ! grep -q "gnome-keyring-daemon" /etc/pam.d/sddm; then
        sudo sed -i '/^auth.*pam_unix/a auth       optional     pam_gnome_keyring.so' /etc/pam.d/sddm
        sudo sed -i '/^session.*pam_unix/a session    optional     pam_gnome_keyring.so auto_start' /etc/pam.d/sddm
    fi

    info "Iniciando arquitectura de audio (Pipewire)..."
    systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service

    sudo usermod -aG video,input,render,wheel,audio $USER
}

# --- EXECUTION ---

print_banner
gum spin --spinner pulse --title "ACCESSING SYSTEM CORE..." -- sleep 2

install_yay
step_software
step_dotfiles
step_wallpapers
step_system

# Final master sync
if [ -f "$HOME/.local/bin/modern-pywal-sync" ]; then
    # Ensure pywal has initial colors to work with if it's a first install
    if [ ! -f "$HOME/.cache/wal/colors.sh" ]; then
        SDDM_WALLPAPER="$DOTFILES_DIR/sddm/sddm-astronaut-theme/Backgrounds/current_wallpaper.jpg"
        DEFAULT_WALLPAPER="$HOME/.config/hypr/wallpapers/default.jpg"
        
        if [ -f "$SDDM_WALLPAPER" ]; then
            info "Generating initial color palette from Astronaut wallpaper..."
            wal -i "$SDDM_WALLPAPER" -n -q || true
        elif [ -f "$DEFAULT_WALLPAPER" ]; then
            info "Generating initial color palette from default wallpaper..."
            wal -i "$DEFAULT_WALLPAPER" -n -q || true
        fi
    fi
    
    gum spin --spinner dot --title "CALIBRATING COLORS & SDDM..." -- bash -c "$HOME/.local/bin/modern-pywal-sync || true"
fi

# --- FINAL SCREEN ---
clear

echo "  ██████╗ ███████╗██████╗ ██╗      ██████╗ ██╗   ██╗███████╗██████╗ "
echo "  ██╔══██╗██╔════╝██╔══██╗██║     ██╔═══██╗╚██╗ ██╔╝██╔════╝██╔══██╗"
echo "  ██║  ██║█████╗  ██████╔╝██║     ██║   ██║ ╚████╔╝ █████╗  ██║  ██║"
echo "  ██║  ██║██╔══╝  ██╔═══╝ ██║     ██║   ██║  ╚██╔╝  ██╔══╝  ██║  ██║"
echo "  ██████╔╝███████╗██║     ███████╗╚██████╔╝   ██║   ███████╗██████╔╝"
echo "  ╚═════╝ ╚══════╝╚═╝     ╚══════╝ ╚═════╝    ╚═╝   ╚══════╝╚═════╝ "
echo ""

gum style \
    --border double \
    --margin "0 2" \
    --padding "1 3" \
    --border-foreground 7 \
    --bold \
    "RHYTHM CREATIVE DOTFILES  //  ARCH + HYPRLAND  //  DEPLOYMENT COMPLETE"

echo ""

gum style --border normal --border-foreground 7 --margin "0 2" --padding "0 2" \
    "$(printf '%-22s %s\n' "WALLPAPERS" "~/Pictures/Wallpapers")"

echo ""

gum style --border normal --border-foreground 7 --margin "0 2" --padding "0 2" \
    "$(printf '%s\n' "COLORS  ->  sync automatically on wallpaper change"
       printf '%s\n' "MANUAL  ->  ~/.local/bin/pywal-wallpaper-sync")"

echo ""
gum style --margin "0 4" --bold "  INITIALIZING DISPLAY MANAGER..."
echo ""

sudo systemctl start sddm
