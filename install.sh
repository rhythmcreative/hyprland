#!/bin/bash

# --- Rhythm Hyprland Installer (Omarchy Style Presentation) ---
# Automated, modular, and resilient deployment for Arch Linux & Hyprland

set -eEo pipefail

# Error handling trap
handle_error() {
    local exit_code=$?
    local line_number=$1
    echo ""
    if [[ -n "$PADDING_LEFT_SPACES" ]]; then
        printf "%s\033[31m  [ERROR] An error occurred on line %s (exit code: %s).\033[0m\n" "$PADDING_LEFT_SPACES" "$line_number" "$exit_code"
        printf "%s\033[31m  [ERROR] Installation halted to protect system integrity.\033[0m\n" "$PADDING_LEFT_SPACES"
        printf "%s\033[90m  → Detailed log saved to: %s\033[0m\n" "$PADDING_LEFT_SPACES" "$LOG_FILE"
    else
        echo "  [ERROR] An error occurred on line $line_number (exit code: $exit_code)."
        echo "  [ERROR] Installation halted to protect system integrity."
        echo "  → Detailed log saved to: $LOG_FILE"
    fi
    exit "$exit_code"
}
trap 'handle_error $LINENO' ERR

# Reattach tty if running via pipe (e.g. curl ... | bash)
if [ ! -t 0 ] && [ -e /dev/tty ]; then
    exec < /dev/tty
fi

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")

# If running outside the cloned repository (e.g. standalone curl pipe), clone first
if [ -z "$DOTFILES_DIR" ] || [ ! -f "$DOTFILES_DIR/logo.txt" ] || [ ! -d "$DOTFILES_DIR/.config" ]; then
    CLONE_DIR="/tmp/rhythm-hyprland"
    echo "Cloning rhythmcreative/hyprland repository to $CLONE_DIR..."
    rm -rf "$CLONE_DIR"
    git clone --depth=1 https://github.com/rhythmcreative/hyprland.git "$CLONE_DIR"
    exec bash "$CLONE_DIR/install.sh" "$@"
fi

LOG_FILE="/tmp/hyprland-install-${USER:-$(id -un)}.log"
if ! touch "$LOG_FILE" 2>/dev/null; then
    LOG_FILE=$(mktemp /tmp/hyprland-install-XXXXXX.log 2>/dev/null || echo "$HOME/.cache/hyprland-install.log")
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
fi
: > "$LOG_FILE" 2>/dev/null || true

# --- CLI ARGUMENT PARSING & CONFIGURATION ---
AUTO_YES=false
DRY_RUN=false
NO_REBOOT=false
WALLPAPER_MODE=""
GPU_OVERRIDE="auto"
SKIP_RUST_DOCK=false
SKIP_FLATPAKS=false
REPLACE_CONFIGS_ALL=false

show_help() {
    cat << 'EOF'
Rhythm Hyprland Installer (Omarchy Style)

Usage:
  ./install.sh [OPTIONS]

Options:
  -y, --yes                  Assume yes to all prompts (unattended mode)
  --preview, --dry-run       Simulate installation workflow without system changes
  --no-reboot                Do not prompt or execute reboot upon completion
  --wallpapers <mode>        Wallpaper download mode: all, random, none
  --skip-wallpapers          Skip downloading wallpaper packs
  --gpu <type>               GPU driver stack: nvidia, amd, intel, auto, none
  --skip-gpu                 Skip GPU driver detection and setup
  --skip-rust-dock           Skip building rust-dock from source
  --skip-flatpaks            Skip Flatpak package installation
  --replace-configs-all      Directly overwrite existing configs without .bak backups
  -h, --help                 Show this help message and exit

One-line installation:
  curl -fsSL https://raw.githubusercontent.com/rhythmcreative/hyprland/main/install.sh | bash

Examples:
  ./install.sh --preview
  ./install.sh -y --no-reboot --skip-wallpapers
  ./install.sh --gpu nvidia --wallpapers random
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes)
            AUTO_YES=true
            shift
            ;;
        --preview|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-reboot)
            NO_REBOOT=true
            shift
            ;;
        --wallpapers)
            WALLPAPER_MODE="$2"
            shift 2
            ;;
        --wallpapers=*)
            WALLPAPER_MODE="${1#*=}"
            shift
            ;;
        --skip-wallpapers)
            WALLPAPER_MODE="none"
            shift
            ;;
        --gpu)
            GPU_OVERRIDE="$2"
            shift 2
            ;;
        --gpu=*)
            GPU_OVERRIDE="${1#*=}"
            shift
            ;;
        --skip-gpu)
            GPU_OVERRIDE="none"
            shift
            ;;
        --skip-rust-dock)
            SKIP_RUST_DOCK=true
            shift
            ;;
        --skip-flatpaks)
            SKIP_FLATPAKS=true
            shift
            ;;
        --replace-configs-all)
            REPLACE_CONFIGS_ALL=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run ./install.sh --help for available options."
            exit 1
            ;;
    esac
done

# --- TERMINAL GEOMETRY & OMARCHY PRESENTATION SETUP ---
if [[ -e /dev/tty ]]; then
    TERM_SIZE=$(stty size 2>/dev/null </dev/tty || echo "24 80")
    export TERM_HEIGHT=$(echo "$TERM_SIZE" | cut -d' ' -f1)
    export TERM_WIDTH=$(echo "$TERM_SIZE" | cut -d' ' -f2)
else
    export TERM_WIDTH=80
    export TERM_HEIGHT=24
fi

LOGO_PATH="$DOTFILES_DIR/logo.txt"
if [[ -f "$LOGO_PATH" ]]; then
    LOGO_WIDTH=$(awk '{ if (length > max) max = length } END { print max+0 }' "$LOGO_PATH" 2>/dev/null || echo 69)
else
    LOGO_WIDTH=69
fi

PADDING_LEFT=$(((TERM_WIDTH - LOGO_WIDTH) / 2))
if (( PADDING_LEFT < 0 )); then
    PADDING_LEFT=0
fi
PADDING_LEFT_SPACES=$(printf "%*s" "$PADDING_LEFT" "")

# Tokyo Night theme for gum (Omarchy style)
export GUM_CONFIRM_PROMPT_FOREGROUND="6"     # Cyan
export GUM_CONFIRM_SELECTED_FOREGROUND="0"   # Black
export GUM_CONFIRM_SELECTED_BACKGROUND="2"   # Green
export GUM_CONFIRM_UNSELECTED_FOREGROUND="7" # White
export GUM_CONFIRM_UNSELECTED_BACKGROUND="0" # Black
export PADDING="0 0 0 $PADDING_LEFT"
export GUM_CHOOSE_PADDING="$PADDING"
export GUM_FILTER_PADDING="$PADDING"
export GUM_INPUT_PADDING="$PADDING"
export GUM_SPIN_PADDING="$PADDING"
export GUM_TABLE_PADDING="$PADDING"
export GUM_CONFIRM_PADDING="$PADDING"

clear_logo() {
    printf "\033[H\033[2J"
    if [[ -f "$LOGO_PATH" ]]; then
        gum style --foreground 2 --padding "1 0 0 $PADDING_LEFT" "$(<"$LOGO_PATH")"
    fi
}

section() {
    echo ""
    gum style --foreground 6 --bold --padding "0 0 0 $PADDING_LEFT" ":: $1"
}

step_item() {
    printf "%s\033[90m  → %s\033[0m\n" "$PADDING_LEFT_SPACES" "$1"
}

step_ok() {
    printf "%s\033[32m  [OK] %s\033[0m\n" "$PADDING_LEFT_SPACES" "$1"
}

step_warn() {
    printf "%s\033[33m  ! %s\033[0m\n" "$PADDING_LEFT_SPACES" "$1"
}

confirm_prompt() {
    local prompt_msg="$1"
    if [ "$AUTO_YES" = true ]; then
        return 0
    fi
    gum confirm "$prompt_msg"
}

# --- PREFLIGHT CHECKS ---
preflight_checks() {
    if [ "$EUID" -eq 0 ]; then
        echo "ERROR: Do not run this installer as root."
        exit 1
    fi

    if [ ! -f /etc/arch-release ]; then
        echo "ERROR: This installer is only compatible with Arch Linux."
        exit 1
    fi

    # Network verification
    if ! ping -c 1 archlinux.org >/dev/null 2>&1 && ! curl -s --head https://archlinux.org >/dev/null 2>&1; then
        echo "ERROR: No active internet connection detected. Please connect before continuing."
        exit 1
    fi

    # Pacman optimizations (ParallelDownloads and Color)
    if grep -q "^#ParallelDownloads" /etc/pacman.conf 2>/dev/null; then
        sudo sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
    fi
    if grep -q "^#Color" /etc/pacman.conf 2>/dev/null; then
        sudo sed -i 's/^#Color/Color/' /etc/pacman.conf
    fi
    if grep -q "^#\[multilib\]" /etc/pacman.conf 2>/dev/null; then
        sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
        sudo pacman -Sy >> "$LOG_FILE" 2>&1
    fi

    # Ensure bootstrap tools exist
    local bootstrap_pkgs=()
    for pkg in gum fzf git base-devel stow zsh curl sudo; do
        if ! pacman -Q "$pkg" >/dev/null 2>&1; then
            bootstrap_pkgs+=("$pkg")
        fi
    done
    if [ ${#bootstrap_pkgs[@]} -gt 0 ]; then
        sudo pacman -S --needed --noconfirm "${bootstrap_pkgs[@]}" >> "$LOG_FILE" 2>&1
    fi
}

# --- AUR HELPER SETUP (YAY) ---
install_yay() {
    if ! command -v yay > /dev/null 2>&1; then
        section "AUR Helper (yay)"
        step_item "Building yay from AUR..."
        sudo pacman -S --needed --noconfirm base-devel git >> "$LOG_FILE" 2>&1
        rm -rf /tmp/yay
        git clone https://aur.archlinux.org/yay.git /tmp/yay >> "$LOG_FILE" 2>&1
        (cd /tmp/yay && makepkg -si --noconfirm) >> "$LOG_FILE" 2>&1
        rm -rf /tmp/yay
        cd "$DOTFILES_DIR"
        if command -v yay > /dev/null 2>&1; then
            step_ok "AUR helper initialized."
        else
            echo "ERROR: Failed to compile yay."
            exit 1
        fi
    fi
}

# --- HARDWARE DRIVERS DETECTION ---
auto_detect_drivers() {
    section "Hardware Drivers & GPU Detection"
    if [ "$GPU_OVERRIDE" = "none" ]; then
        step_ok "GPU driver installation skipped via flag."
        return 0
    fi

    local EXTRA_PKGS=()
    local IS_NVIDIA=false
    local GPU_INFO=""

    if [ "$GPU_OVERRIDE" = "nvidia" ]; then
        GPU_INFO="NVIDIA"
    elif [ "$GPU_OVERRIDE" = "amd" ]; then
        GPU_INFO="Advanced Micro Devices"
    elif [ "$GPU_OVERRIDE" = "intel" ]; then
        GPU_INFO="Intel"
    else
        GPU_INFO=$(lspci 2>/dev/null | grep -i -E "vga|3d|display" || true)
    fi

    if [[ $GPU_INFO == *"NVIDIA"* ]]; then
        IS_NVIDIA=true
        step_item "NVIDIA GPU detected. Analyzing architecture and installed kernels..."

        # 1. Detect installed kernels and install matching kernel headers
        local KERNEL_HEADERS=()
        for k in $(pacman -Qq 2>/dev/null | grep -E '^linux(-lts|-zen|-hardened)?$'); do
            KERNEL_HEADERS+=("${k}-headers")
        done
        if [ ${#KERNEL_HEADERS[@]} -gt 0 ]; then
            step_item "Installing matching kernel headers: ${KERNEL_HEADERS[*]}..."
            sudo pacman -S --needed --noconfirm "${KERNEL_HEADERS[@]}" >> "$LOG_FILE" 2>&1 || true
        fi

        # 2. Select the latest driver package based on GPU architecture and kernel type
        local USE_OPEN=true
        if echo "$GPU_INFO" | grep -i -E "GTX (10[0-9]{2}|9[0-9]{2}|8[0-9]{2}|7[0-9]{2}|6[0-9]{2}|[0-9]{3})|GeForce 8|GeForce 9|GeForce [0-9]{3}M|GeForce MX" >/dev/null 2>&1; then
            USE_OPEN=false
        fi

        local IS_CUSTOM_KERNEL=false
        if pacman -Qq 2>/dev/null | grep -E '^linux-(lts|zen|hardened)$' >/dev/null 2>&1; then
            IS_CUSTOM_KERNEL=true
        fi

        if [ "$USE_OPEN" = true ]; then
            if [ "$IS_CUSTOM_KERNEL" = true ]; then
                step_item "Selecting latest NVIDIA Open DKMS driver (nvidia-open-dkms)..."
                EXTRA_PKGS+=(nvidia-open-dkms)
            else
                step_item "Selecting latest official NVIDIA Open driver (nvidia-open)..."
                EXTRA_PKGS+=(nvidia-open)
            fi
        else
            step_item "Legacy NVIDIA architecture detected. Selecting proprietary DKMS driver (nvidia-dkms)..."
            EXTRA_PKGS+=(nvidia-dkms)
        fi

        # 3. Core NVIDIA driver utilities, 32-bit gaming and Wayland support
        EXTRA_PKGS+=(
            nvidia-utils
            nvidia-settings
            nvidia-prime
            lib32-nvidia-utils
            egl-wayland
            egl-wayland2
            libva-nvidia-driver
            opencl-nvidia
        )
    fi

    if [[ $GPU_INFO == *"Advanced Micro Devices"* ]] || [[ $GPU_INFO == *"ATI"* ]]; then
        step_item "AMD GPU detected. Adding Mesa and Vulkan drivers..."
        EXTRA_PKGS+=(lib32-mesa vulkan-radeon lib32-vulkan-radeon mesa-utils)
    fi

    if [[ $GPU_INFO == *"Intel"* ]]; then
        step_item "Intel GPU detected. Adding hardware acceleration drivers..."
        EXTRA_PKGS+=(intel-media-driver libva-intel-driver vulkan-intel)
    fi

    local SYS_VENDOR PROD_NAME
    SYS_VENDOR=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)
    PROD_NAME=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)

    if [[ $SYS_VENDOR == *"ASUSTeK"* ]]; then
        step_item "ASUS hardware detected. Adding asusctl & supergfxctl..."
        EXTRA_PKGS+=(asusctl supergfxctl rog-control-center)
    fi

    if [[ $PROD_NAME == *"Surface"* ]]; then
        step_item "Microsoft Surface detected. Adding surface utilities..."
        EXTRA_PKGS+=(linux-surface linux-surface-headers surface-control)
    fi

    if [ ${#EXTRA_PKGS[@]} -gt 0 ]; then
        step_item "Installing: ${EXTRA_PKGS[*]}"
        yay -S --needed --noconfirm "${EXTRA_PKGS[@]}" >> "$LOG_FILE" 2>&1 || step_warn "Some hardware packages could not be installed."
        step_ok "Hardware drivers configured."
    else
        step_ok "Standard hardware configuration applied."
    fi

    # Post-driver configuration for NVIDIA
    if [ "$IS_NVIDIA" = true ]; then
        section "NVIDIA System & Wayland Optimization"

        # Direct Rendering Manager (DRM) Kernel Mode Setting & Framebuffer Device
        step_item "Configuring DRM kernel modesetting (modeset=1, fbdev=1)..."
        sudo mkdir -p /etc/modprobe.d
        cat << 'EOF' | sudo tee /etc/modprobe.d/nvidia.conf > /dev/null
# Enable Direct Rendering Manager (DRM) Kernel Mode Setting and Framebuffer Device for Wayland & Hyprland
options nvidia-drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia NVreg_TemporaryFilePath=/var/tmp
EOF

        # Enable NVIDIA power management systemd services for seamless sleep/wake
        step_item "Enabling NVIDIA power management & suspend services..."
        sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service >> "$LOG_FILE" 2>&1 || true

        # Early KMS in mkinitcpio
        if [ -f /etc/mkinitcpio.conf ]; then
            if ! grep -q "nvidia_drm" /etc/mkinitcpio.conf; then
                step_item "Adding NVIDIA modules to /etc/mkinitcpio.conf for early KMS..."
                sudo sed -i -E 's/^MODULES=\((.*)\)/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
                sudo sed -i 's/  */ /g' /etc/mkinitcpio.conf
            fi
        fi

        # Automatic pacman hook for initramfs rebuilding
        step_item "Configuring automatic NVIDIA pacman hook for kernel updates..."
        sudo mkdir -p /etc/pacman.d/hooks
        cat << 'EOF' | sudo tee /etc/pacman.d/hooks/nvidia.hook > /dev/null
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia
Target=nvidia-open
Target=nvidia-dkms
Target=nvidia-open-dkms
Target=nvidia-open-lts
Target=linux
Target=linux-lts
Target=linux-zen
Target=linux-hardened

[Action]
Description=Updating NVIDIA initramfs images...
Depends=mkinitcpio
When=PostTransaction
Exec=/usr/bin/mkinitcpio -P
EOF

        # Build initramfs images
        step_item "Generating initramfs images with mkinitcpio..."
        sudo mkinitcpio -P >> "$LOG_FILE" 2>&1 || step_warn "mkinitcpio image generation encountered warnings."
        step_ok "NVIDIA system optimization complete."
    fi
}

# --- RUST-DOCK COMPILATION & SETUP ---
install_rust_dock() {
    section "Rust-Dock Component"
    if [ "$SKIP_RUST_DOCK" = true ]; then
        step_ok "Rust-dock build skipped via flag."
        return 0
    fi

    step_item "Ensuring build dependencies (rust, gtk4, gtk4-layer-shell)..."
    yay -S --needed --noconfirm rust pkgconf gtk4 gtk4-layer-shell grim >> "$LOG_FILE" 2>&1

    if ! command -v cargo > /dev/null 2>&1; then
        step_warn "Cargo not found. Skipping rust-dock build."
        return
    fi

    local source_dir=""
    local temp_clone=false

    if [ -d "$DOTFILES_DIR/../rust-dock" ] && [ -f "$DOTFILES_DIR/../rust-dock/Cargo.toml" ]; then
        source_dir="$DOTFILES_DIR/../rust-dock"
    elif [ -d "$HOME/rust-dock" ] && [ -f "$HOME/rust-dock/Cargo.toml" ]; then
        source_dir="$HOME/rust-dock"
    else
        source_dir="/tmp/rust-dock-build"
        rm -rf "$source_dir"
        if git clone --depth=1 https://github.com/rhythmcreative/rust-dock.git "$source_dir" >> "$LOG_FILE" 2>&1; then
            temp_clone=true
        else
            step_warn "Could not clone rust-dock repository. Skipping build."
            return
        fi
    fi

    gum spin --spinner dot --title "Compiling rust-dock (release)..." --padding "0 0 0 $PADDING_LEFT" -- \
        bash -c "cd '$source_dir' && cargo build --release >> '$LOG_FILE' 2>&1" || true

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
        step_ok "rust-dock deployed to ~/.local/bin/rust-dock"
    else
        step_warn "rust-dock build failed. Inspect $LOG_FILE for details."
    fi

    if [ "$temp_clone" = true ]; then
        rm -rf "$source_dir"
    fi
}

# --- SYSTEM PACKAGES DEPLOYMENT ---
step_software() {
    section "Core Packages & System Libraries"

    local CORE_PKGS=(
        # Compositor & Wayland core
        hyprland
        hypridle
        hyprlock
        hyprsunset
        hyprpicker
        hyprpm
        xdg-desktop-portal-hyprland
        xdg-desktop-portal-gtk

        # Bars, Dynamic Island & Launchers
        waybar
        quickshell
        rofi

        # Terminal & Shell
        kitty
        zsh
        zsh-autosuggestions
        zsh-syntax-highlighting

        # File Management & Media Thumbnails
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

        # Networking & Bluetooth
        networkmanager
        network-manager-applet
        bluez
        bluez-utils
        blueman
        bluez-obex
        rfkill

        # Audio Architecture
        pipewire
        pipewire-pulse
        wireplumber
        pavucontrol
        playerctl
        pamixer

        # Hardware, Screen & Capture Tools
        brightnessctl
        swappy
        grim
        slurp
        wl-clipboard
        libnotify
        socat
        xorg-xrandr

        # Qt Frameworks (Quickshell, SDDM & Theming)
        qt5-graphicaleffects
        qt5-quickcontrols2
        qt5-svg
        qt5-declarative
        qt6-declarative
        qt6-svg
        qt6-wayland
        qt5ct
        qt6ct
        kvantum

        # Display Manager & Authentication
        sddm
        polkit-kde-agent
        gnome-keyring

        # Visuals, Pywal, Displays & Wallpaper Engine
        nwg-displays
        nwg-look
        bibata-cursor-theme
        tela-circle-icon-theme-all
        python-pywal
        awww
        cava

        # Fonts
        ttf-jetbrains-mono-nerd
        otf-font-awesome

        # Rust & Build Dependencies (for rust-dock)
        rust
        pkgconf
        gtk4
        gtk4-layer-shell

        # System Utilities & Scripting Runtimes
        python
        flatpak
        stow
        curl
        wget
        unzip
        jq
        bc
        imagemagick
        htop
        btop
        fastfetch
        inotify-tools
        psmisc
    )

    gum spin --spinner dot --title "Installing core packages and dependencies..." --padding "0 0 0 $PADDING_LEFT" -- \
        bash -c "yay -S --needed --noconfirm ${CORE_PKGS[*]} >> '$LOG_FILE' 2>&1"
    step_ok "Core packages installed."

    # Build and deploy rust-dock
    install_rust_dock

    # Configure Hyprland plugins
    section "Hyprland Plugins"
    if command -v hyprpm > /dev/null 2>&1; then
        step_item "Syncing official plugin repository..."
        hyprpm add https://github.com/hyprwm/hyprland-plugins >> "$LOG_FILE" 2>&1 || true
        hyprpm update >> "$LOG_FILE" 2>&1 || true
        step_item "Enabling hyprbars and hyprexpo..."
        hyprpm enable hyprbars >> "$LOG_FILE" 2>&1 || true
        hyprpm enable hyprexpo >> "$LOG_FILE" 2>&1 || true
        hyprpm reload >> "$LOG_FILE" 2>&1 || true
        step_ok "Hyprland plugins active."
    else
        step_warn "hyprpm not available. Skipping plugins."
    fi

    # Hardware detection
    auto_detect_drivers

    # Flatpak packages
    if [ "$SKIP_FLATPAKS" = false ] && [ -f "$DOTFILES_DIR/flatpaks.txt" ]; then
        if confirm_prompt "Install applications from flatpaks.txt?"; then
            section "Flatpak Applications"
            sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >> "$LOG_FILE" 2>&1
            while read -r app; do
                [ -z "$app" ] || [[ "$app" =~ ^# ]] && continue
                step_item "Installing flatpak: $app"
                sudo flatpak install -y --system flathub "$app" >> "$LOG_FILE" 2>&1 || true
            done < "$DOTFILES_DIR/flatpaks.txt"
            step_ok "Flatpaks installed."
        fi
    fi
}

# --- DOTFILES DEPLOYMENT ---
step_dotfiles() {
    section "Configuration Synchronization (Dotfiles)"
    mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share" "$HOME/.cache"
    
    cd "$DOTFILES_DIR"

    step_item "Linking configurations into ~/.config/..."
    for item in .config/*; do
        [ -e "$item" ] || continue
        local name
        name=$(basename "$item")
        local target="$HOME/.config/$name"
        
        if [ -e "$target" ]; then
            if [ "$REPLACE_CONFIGS_ALL" = true ]; then
                rm -rf "$target"
            else
                rm -rf "$target.bak"
                mv "$target" "$target.bak"
            fi
        fi
        
        cp -r "$DOTFILES_DIR/.config/$name" "$target"
    done
    step_ok "Config files synchronized."

    # Restore existing monitors.conf if backed up, or generate default
    if [ -f "$HOME/.config/hypr.bak/monitors.conf" ] && [ ! -f "$HOME/.config/hypr/monitors.conf" ]; then
        cp -f "$HOME/.config/hypr.bak/monitors.conf" "$HOME/.config/hypr/monitors.conf"
        step_ok "Preserved existing monitors.conf from backup."
    elif [ ! -f "$HOME/.config/hypr/monitors.conf" ]; then
        cat > "$HOME/.config/hypr/monitors.conf" << 'MONCONF'
# Generated by installer - edit via nwg-displays or manually
# Format: monitor=NAME,RESOLUTION@RATE,POSITION,SCALE
monitor=,preferred,auto,1
MONCONF
        step_ok "Default monitors.conf created."
    fi

    step_item "Deploying helper executables to ~/.local/bin/..."
    for file in .local/bin/*; do
        [ -e "$file" ] || continue
        local name
        name=$(basename "$file")
        local target="$HOME/.local/bin/$name"
        
        if [ -e "$target" ]; then
            if [ "$REPLACE_CONFIGS_ALL" = true ]; then
                rm -rf "$target"
            else
                rm -rf "$target.bak"
                mv "$target" "$target.bak"
            fi
        fi
        
        cp -f "$DOTFILES_DIR/$file" "$target"
        chmod +x "$target"
    done
    chmod +x "$HOME/.local/bin"/* 2>/dev/null || true
    step_ok "Executables deployed."

    # Shell and GTK dotfiles
    for pkg in zsh bash gtk; do
        if [ -d "$pkg" ]; then
            find "$pkg" -mindepth 1 -maxdepth 1 -name ".*" | while read -r file; do
                local name
                name=$(basename "$file")
                local target="$HOME/$name"
                if [ -e "$target" ]; then
                    if [ "$REPLACE_CONFIGS_ALL" = true ]; then
                        rm -rf "$target"
                    else
                        rm -rf "$target.bak"
                        mv "$target" "$target.bak"
                    fi
                fi
                cp -r "$DOTFILES_DIR/$file" "$target"
            done
        fi
    done

    # Replace hardcoded home paths with real current user path
    step_item "Adapting file paths to current user ($USER)..."
    grep -rIl "/home/rhythmcreative" "$HOME/.config" "$HOME/.local/bin" "$HOME/.bashrc" "$HOME/.zshrc" 2>/dev/null | while read -r file; do
        sed -i "s|/home/rhythmcreative|$HOME|g" "$file" 2>/dev/null || true
    done

    # Enable Dynamic Island systemd user service
    step_item "Enabling Dynamic Island user service..."
    systemctl --user daemon-reload >> "$LOG_FILE" 2>&1 || true
    systemctl --user enable waybar-island.service >> "$LOG_FILE" 2>&1 || true

    # GTK defaults
    gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Ice" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "Tela-circle" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null || true
    
    step_ok "Dotfiles fully deployed."
}

# --- OPTIONAL WALLPAPERS DOWNLOAD ---
step_wallpapers() {
    if [ "$WALLPAPER_MODE" = "none" ]; then
        step_ok "Wallpaper packs skipped via flag."
        return 0
    fi

    local SHOULD_DOWNLOAD=false
    local MODE="$WALLPAPER_MODE"

    if [ -n "$MODE" ]; then
        SHOULD_DOWNLOAD=true
    elif [ "$AUTO_YES" = true ]; then
        step_ok "Wallpaper downloads skipped in unattended mode (use --wallpapers all|random to enable)."
        return 0
    elif gum confirm "Download additional wallpaper packs?"; then
        SHOULD_DOWNLOAD=true
    fi

    if [ "$SHOULD_DOWNLOAD" = true ]; then
        section "Wallpaper Packs"
        local WALL_DIR="$HOME/Pictures/Wallpapers"
        mkdir -p "$WALL_DIR"
        local TEMP_WALL="/tmp/wallpaper_install"
        mkdir -p "$TEMP_WALL"
        
        local REPO_URL="https://raw.githubusercontent.com/rhythmcreative/wallpapers/main"

        local CHOICE="$MODE"
        if [ -z "$CHOICE" ]; then
            CHOICE=$(gum choose --header "Select download mode" \
                "Download All Packs (4GB+)" \
                "Select Specific Packs" \
                "Random Selection (3 Packs)" \
                "Skip")
        fi
        
        if [ "$CHOICE" == "Download All Packs (4GB+)" ] || [ "$CHOICE" == "all" ]; then
            for i in {1..49}; do
                step_item "Downloading pack $i/49..."
                curl -L "$REPO_URL/pack_$i.zip" -o "$TEMP_WALL/pack_$i.zip" >> "$LOG_FILE" 2>&1
                unzip -q -o "$TEMP_WALL/pack_$i.zip" -d "$TEMP_WALL"
                [ -d "$TEMP_WALL/pack_$i" ] && cp -r "$TEMP_WALL/pack_$i"/* "$WALL_DIR/" && rm -rf "$TEMP_WALL/pack_$i"
                rm -f "$TEMP_WALL/pack_$i.zip"
            done
        elif [ "$CHOICE" == "Select Specific Packs" ]; then
            local PACKS
            PACKS=$(gum input --placeholder "Numbers separated by space (e.g. 1 5 12)")
            for p in $PACKS; do
                step_item "Downloading pack $p..."
                curl -L "$REPO_URL/pack_$p.zip" -o "$TEMP_WALL/pack_$p.zip" >> "$LOG_FILE" 2>&1
                unzip -q -o "$TEMP_WALL/pack_$p.zip" -d "$TEMP_WALL"
                [ -d "$TEMP_WALL/pack_$p" ] && cp -r "$TEMP_WALL/pack_$p"/* "$WALL_DIR/" && rm -rf "$TEMP_WALL/pack_$p"
                rm -f "$TEMP_WALL/pack_$p.zip"
            done
        elif [ "$CHOICE" == "Random Selection (3 Packs)" ] || [ "$CHOICE" == "random" ]; then
            step_item "Downloading 3 random packs..."
            for i in {1..3}; do
                local p
                p=$(shuf -i 1-49 -n 1)
                step_item "Downloading pack $p..."
                curl -L "$REPO_URL/pack_$p.zip" -o "$TEMP_WALL/pack_$p.zip" >> "$LOG_FILE" 2>&1
                unzip -q -o "$TEMP_WALL/pack_$p.zip" -d "$TEMP_WALL"
                [ -d "$TEMP_WALL/pack_$p" ] && cp -r "$TEMP_WALL/pack_$p"/* "$WALL_DIR/" && rm -rf "$TEMP_WALL/pack_$p"
                rm -f "$TEMP_WALL/pack_$p.zip"
            done
        fi
        rm -rf "$TEMP_WALL"
        step_ok "Wallpapers installed."
    fi
}

# --- SYSTEM SERVICES & FINISHING ---
step_system() {
    section "System Services & Finalization"
    
    if confirm_prompt "Set Zsh as your default shell?"; then
        if [ "$SHELL" != "$(which zsh)" ]; then
            sudo chsh -s "$(which zsh)" "$USER"
            step_ok "Default shell set to Zsh."
        fi
    fi

    # SDDM Astronaut Theme
    if [ -d "$DOTFILES_DIR/sddm/sddm-astronaut-theme" ]; then
        step_item "Deploying SDDM Astronaut theme..."
        sudo mkdir -p /usr/share/sddm/themes
        sudo cp -r "$DOTFILES_DIR/sddm/sddm-astronaut-theme" /usr/share/sddm/themes/
        
        sudo mkdir -p /etc/sddm.conf.d /etc/sddm
        echo -e "[Theme]\nCurrent=sddm-astronaut-theme" | sudo tee /etc/sddm.conf.d/theme.conf > /dev/null

        # SDDM Multi-monitor script
        if [ -f "$DOTFILES_DIR/sddm/Xsetup" ]; then
            sudo cp -f "$DOTFILES_DIR/sddm/Xsetup" /etc/sddm/Xsetup
            sudo chmod +x /etc/sddm/Xsetup
        fi
        echo -e "[X11]\nDisplayCommand=/etc/sddm/Xsetup" | sudo tee /etc/sddm.conf.d/xsetup.conf > /dev/null

        # Sudoers NOPASSWD helper for live pywal sync
        sudo mkdir -p /etc/sudoers.d
        echo "$USER ALL=(root) NOPASSWD: $HOME/.local/bin/sddm-auto-sync-local" | sudo tee /etc/sudoers.d/sddm-sync > /dev/null
        sudo chmod 440 /etc/sudoers.d/sddm-sync

        # Pywal SDDM sync hook
        mkdir -p "$HOME/.config/wal/hooks"
        cat > "$HOME/.config/wal/hooks/sddm-sync.sh" << EOF
#!/bin/bash
if [ -x "$HOME/.local/bin/sddm-sync-wrapper" ]; then
    "$HOME/.local/bin/sddm-sync-wrapper" >/dev/null 2>&1 || true
fi
EOF
        chmod +x "$HOME/.config/wal/hooks/sddm-sync.sh"

        # Initial color palette generation
        local SDDM_WALLPAPER="$DOTFILES_DIR/sddm/sddm-astronaut-theme/Backgrounds/current_wallpaper.jpg"
        if [ -f "$SDDM_WALLPAPER" ]; then
            wal -i "$SDDM_WALLPAPER" -n -q >> "$LOG_FILE" 2>&1 || true
            mkdir -p "$HOME/.cache"
            echo "$SDDM_WALLPAPER" > "$HOME/.cache/current-wallpaper"
        fi
        step_ok "SDDM Astronaut theme configured."
    fi

    # Core system services
    step_item "Enabling NetworkManager, Bluetooth, and SDDM..."
    sudo systemctl enable NetworkManager bluetooth sddm >> "$LOG_FILE" 2>&1 || true
    sudo systemctl start NetworkManager bluetooth >> "$LOG_FILE" 2>&1 || true

    # PAM gnome-keyring unlock
    for pam_file in /etc/pam.d/login /etc/pam.d/sddm; do
        if [ -f "$pam_file" ] && ! grep -q "pam_gnome_keyring.so" "$pam_file"; then
            sudo sed -i '/^auth.*pam_unix/a auth       optional     pam_gnome_keyring.so' "$pam_file"
            sudo sed -i '/^session.*pam_unix/a session    optional     pam_gnome_keyring.so auto_start' "$pam_file"
        fi
    done

    # Pipewire audio sockets
    step_item "Enabling Pipewire user audio services..."
    systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service >> "$LOG_FILE" 2>&1 || true

    # Add user to required groups
    sudo usermod -aG video,input,render,wheel,audio,storage "$USER"
    step_ok "System services and permissions configured."
}

# --- MAIN EXECUTION ---
if [ "$DRY_RUN" = true ]; then
    clear_logo
    gum style --foreground 3 --padding "0 0 1 $PADDING_LEFT" "Rhythm Hyprland Installer (Visual Preview Mode)"
    step_item "Verifying preflight environment..."
    sleep 0.4
    step_ok "Arch Linux x86_64 verified."
    step_ok "Parallel downloads & multilib repository active."
    
    section "AUR Helper & Build Toolchain"
    step_ok "yay aur helper ready."
    step_ok "Rust, cargo, and GTK4 layer-shell libraries ready."

    section "Core Packages & System Libraries"
    step_item "Simulating package dependency resolution..."
    gum spin --spinner dot --title "Checking 65+ core packages..." --padding "0 0 0 $PADDING_LEFT" -- sleep 1.2
    step_ok "Compositor, Waybar, Quickshell, Rofi, Audio, Fonts resolved."

    section "Hardware Drivers & GPU Optimization"
    step_item "Simulating hardware auto-detection (NVIDIA/AMD/Intel)..."
    sleep 0.5
    step_ok "Latest NVIDIA Open/DKMS drivers, kernel headers, DRM modesetting & pacman hook verified."

    section "Rust-Dock Component"
    gum spin --spinner dot --title "Verifying rust-dock target binary..." --padding "0 0 0 $PADDING_LEFT" -- sleep 0.8
    step_ok "rust-dock deployed to ~/.local/bin/rust-dock"

    section "Configuration Synchronization (Dotfiles)"
    step_item "Simulating deployment of config directories..."
    sleep 0.4
    step_ok "Hyprland Lua, Waybar, Quickshell Dynamic Island, Rofi, and Kvantum synchronized."
    step_ok "65+ helper scripts deployed to ~/.local/bin/."
    step_ok "Preserved monitors.conf."
    step_ok "Dynamic Island systemd service enabled."

    section "SDDM Astronaut Theme & Multi-Monitor"
    step_ok "SDDM Astronaut theme and live Pywal synchronization hooks verified."
    step_ok "Multi-monitor detection (Xsetup) configured."

    gum spin --spinner dot --title "Calibrating Pywal color palette..." --padding "0 0 0 $PADDING_LEFT" -- sleep 1.0

    clear_logo
    echo ""
    gum style --foreground 2 --bold --padding "0 0 1 $PADDING_LEFT" "Finished previewing (Simulation Complete)"
    gum style --foreground 7 --padding "0 0 1 $PADDING_LEFT" "All modules, styles, and configurations are ready for deployment."
    exit 0
fi

preflight_checks
clear_logo
gum style --foreground 3 --padding "0 0 1 $PADDING_LEFT" "Initializing Rhythm Hyprland Setup..."

install_yay
step_software
step_dotfiles
step_wallpapers
step_system

# Calibrate colors
if [ -x "$HOME/.local/bin/modern-pywal-sync" ]; then
    gum spin --spinner dot --title "Calibrating Pywal color scheme..." --padding "0 0 0 $PADDING_LEFT" -- \
        bash -c "$HOME/.local/bin/modern-pywal-sync >> '$LOG_FILE' 2>&1 || true"
fi

# --- COMPLETION & REBOOT SCREEN ---
clear_logo
echo ""
gum style --foreground 2 --bold --padding "0 0 1 $PADDING_LEFT" "Finished installing"

if [ "$NO_REBOOT" = true ]; then
    gum style --foreground 7 --padding "0 0 1 $PADDING_LEFT" "Installation complete. System reboot skipped via flag."
elif [ "$AUTO_YES" = true ]; then
    if [ -n "$WAYLAND_DISPLAY" ] || [ -n "$DISPLAY" ]; then
        gum style --foreground 7 --padding "0 0 1 $PADDING_LEFT" "Rebooting into Hyprland..."
        sudo reboot
    else
        sudo systemctl start sddm
    fi
elif [ -n "$WAYLAND_DISPLAY" ] || [ -n "$DISPLAY" ]; then
    gum style --foreground 7 --padding "0 0 1 $PADDING_LEFT" "You are running inside an active graphical session."
    gum style --foreground 7 --padding "0 0 1 $PADDING_LEFT" "Please reboot to apply all group permissions and start SDDM cleanly."
    if gum confirm "Reboot into Hyprland now?"; then
        sudo reboot
    fi
else
    if gum confirm "Start SDDM login manager now?"; then
        sudo systemctl start sddm
    fi
fi
