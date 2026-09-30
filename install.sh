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


DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")

# If running outside the cloned repository (e.g. standalone curl pipe), clone first
if [ -z "$DOTFILES_DIR" ] || [ ! -f "$DOTFILES_DIR/logo.txt" ] || [ ! -d "$DOTFILES_DIR/.config" ]; then
    CLONE_DIR="/tmp/rhythm-hyprland"
    echo "Cloning rhythmcreative/hyprland repository to $CLONE_DIR..."
    if ! command -v git >/dev/null 2>&1; then
        echo "Installing git..."
        sudo pacman -S --needed --noconfirm git
    fi
    rm -rf "$CLONE_DIR"
    git clone --depth=1 https://github.com/rhythmcreative/hyprland.git "$CLONE_DIR"
    if [ -e /dev/tty ]; then
        exec bash "$CLONE_DIR/install.sh" "$@" < /dev/tty
    else
        exec bash "$CLONE_DIR/install.sh" "$@"
    fi
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
SKIP_APPS=false
REPLACE_CONFIGS_ALL=false
INSTALL_MODE="custom"
PACMAN_INSTALL=()
FLATPAK_INSTALL=()
SET_ZSH=true
UPDATE_MODE=false

show_help() {
    cat << 'EOF'
Rhythm Hyprland Installer (Omarchy Style)

Usage:
  ./install.sh [OPTIONS]

Options:
  -u, --update               Update existing installation (sync configs, helpers, & packages)
  -y, --yes                  Assume yes to all prompts (unattended mode)
  --preview, --dry-run       Simulate installation workflow without system changes
  --no-reboot                Do not prompt or execute reboot upon completion
  --wallpapers <mode>        Wallpaper download mode: all, random, none
  --skip-wallpapers          Skip downloading wallpaper packs
  --gpu <type>               GPU driver stack: nvidia, amd, intel, auto, none
  --skip-gpu                 Skip GPU driver detection and setup
  --skip-rust-dock           Skip building rust-dock from source
  --skip-flatpaks            Skip Flatpak package installation
  --skip-apps                Skip optional application selection menu
  --replace-configs-all      Directly overwrite existing configs without .bak backups
  -h, --help                 Show this help message and exit

One-line installation:
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/rhythmcreative/hyprland/main/install.sh)"

Examples:
  ./install.sh --update
  ./install.sh --preview
  ./install.sh -y --no-reboot --skip-wallpapers
  ./install.sh --gpu nvidia --wallpapers random
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--update|update)
            UPDATE_MODE=true
            shift
            ;;
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
        --skip-apps)
            SKIP_APPS=true
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
        if command -v gum >/dev/null 2>&1; then
            gum style --foreground 2 --padding "1 0 0 $PADDING_LEFT" "$(<"$LOGO_PATH")"
        else
            cat "$LOGO_PATH"
        fi
    fi
}

section() {
    echo ""
    if command -v gum >/dev/null 2>&1; then
        gum style --foreground 6 --bold --padding "0 0 0 $PADDING_LEFT" ":: $1"
    else
        printf "%s\033[1;36m:: %s\033[0m\n" "$PADDING_LEFT_SPACES" "$1"
    fi
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
        starship

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

        # Audio Architecture
        pipewire
        pipewire-pulse
        wireplumber
        pavucontrol
        playerctl
        pamixer
        rnnoise
        noise-suppression-for-voice

        # Hardware, Screen & Capture Tools
        brightnessctl
        v4l-utils
        lsof
        swappy
        grim
        slurp
        wl-clipboard
        wf-recorder
        libnotify
        socat
        xorg-xrandr

        # Qt Frameworks (Quickshell, SDDM & Theming)
        qt5-graphicaleffects
        qt5-quickcontrols2
        qt5-svg
        qt5-declarative
        qt6-declarative
        qt6-5compat
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
        python-pillow
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

        # Power Management
        power-profiles-daemon
        upower

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
        pacman-contrib
        cliphist
        mpv
        mpvpaper
        gnome-network-displays
        htop
        btop
        fastfetch
        inotify-tools
        psmisc
        xdg-user-dirs

        # Snapshots and filesystem rollback (pre-OTA safety nets)
        btrfs-progs
        snapper
        timeshift
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

}

# --- UNIVERSAL APPLICATION DISCOVERY (PACMAN + AUR SEARCH WITH FZF) ---
unified_app_search() {
    clear_logo
    echo ""
    if ! command -v yay > /dev/null 2>&1; then
        install_yay
    fi

    step_item "Launching fzf search (120,000+ Pacman & AUR packages)..."
    step_item "[TAB] Select multiple, [ENTER] Confirm, [ESC] Skip"
    sleep 0.8

    local fzf_args=(
        --multi
        --ansi
        --prompt="Search Packages > "
        --header="[TAB] Toggle Select | [ENTER] Confirm Selection | [ESC] Skip Search"
        --preview 'yay -Si {1} 2>/dev/null || pacman -Si {1} 2>/dev/null || echo "Loading info..."'
        --preview-window 'right:55%:wrap'
        --bind 'change:top'
    )

    local SELECTED_SEARCH
    SELECTED_SEARCH=$(yay -Slqa 2>/dev/null | fzf "${fzf_args[@]}" || true)

    if [[ -n "$SELECTED_SEARCH" ]]; then
        local count=0
        while IFS= read -r app; do
            [ -z "$app" ] && continue
            PACMAN_INSTALL+=("$app")
            ((count++))
        done <<< "$SELECTED_SEARCH"
        step_ok "Added $count packages from universal search."
        sleep 1
    else
        step_item "No packages selected from search."
        sleep 0.5
    fi
}

# --- FIRST RUN SETUP CHOICES (OMARCHY TUI WIZARD) ---
first_run_choices() {
    if [ "$AUTO_YES" = true ]; then
        INSTALL_MODE="custom"
        PACMAN_INSTALL=("chromium" "vesktop" "visual-studio-code-bin")
        FLATPAK_INSTALL=("io.missioncenter.MissionCenter")
        [ -z "$WALLPAPER_MODE" ] && WALLPAPER_MODE="random"
        SET_ZSH=true
        return 0
    fi

    clear_logo
    echo ""
    gum style --foreground 3 --bold --padding "0 0 1 $PADDING_LEFT" "Get ready to make a few choices..."

    if [ "$SKIP_APPS" = true ]; then
        INSTALL_MODE="minimal"
    else
        local MODE_RAW
        MODE_RAW=$(gum choose \
            --height 8 \
            --header="Select software installation mode:" \
            --cursor-prefix="> " \
            "Custom Categorized Menus (Browsers, Chat, Dev, Media, Gaming, Utilities)" \
            "Universal Package Search with fzf (Search & install ANY package from Pacman + AUR)" \
            "Full Package Stack (Install all 125 packages from packages.txt)" \
            "Minimal Desktop Core (Essential Hyprland stack only)" || true)

        if [[ "$MODE_RAW" == *"Full Package Stack"* ]]; then
            INSTALL_MODE="full"
        elif [[ "$MODE_RAW" == *"Minimal"* ]] || [ -z "$MODE_RAW" ]; then
            INSTALL_MODE="minimal"
        elif [[ "$MODE_RAW" == *"Universal Package Search"* ]]; then
            INSTALL_MODE="custom"
            unified_app_search
        else
            INSTALL_MODE="custom"

            # 1. Browsers
            clear_logo
            echo ""
            gum style --foreground 6 --bold --padding "0 0 1 $PADDING_LEFT" ":: Web Browsers (1/5)"
            local BROWSERS_LIST=(
                "Brave Browser (brave-bin) [AUR]"
                "Brave Origin Nightly (brave-origin-nightly-bin) [AUR]"
                "Chromium (chromium) [Arch]"
                "Firefox (firefox) [Arch]"
                "Firefox Developer Edition (firefox-developer-edition) [AUR]"
                "Google Chrome (google-chrome) [AUR]"
                "Microsoft Edge (microsoft-edge-stable-bin) [AUR]"
                "Zen Browser (zen-browser-bin) [AUR]"
            )
            local SEL_BROWSERS
            SEL_BROWSERS=$(printf "%s\n" "${BROWSERS_LIST[@]}" | gum choose --no-limit --height 10 \
                --selected="Chromium (chromium) [Arch]" \
                --header="Space = Toggle, Enter = Confirm Category" \
                --cursor-prefix="> " --selected-prefix="[x] " --unselected-prefix="[ ] " || true)

            # 2. Communication
            clear_logo
            echo ""
            gum style --foreground 6 --bold --padding "0 0 1 $PADDING_LEFT" ":: Communication & Social (2/5)"
            local COMM_LIST=(
                "Discord / Vesktop (vesktop) [AUR]"
                "Telegram Desktop (telegram-desktop) [Arch]"
                "Slack Desktop (slack-desktop) [AUR]"
                "WhatsApp / ZapZap (zapzap) [AUR]"
                "Spotify (spotify) [AUR]"
            )
            local SEL_COMM
            SEL_COMM=$(printf "%s\n" "${COMM_LIST[@]}" | gum choose --no-limit --height 10 \
                --selected="Discord / Vesktop (vesktop) [AUR]" \
                --header="Space = Toggle, Enter = Confirm Category" \
                --cursor-prefix="> " --selected-prefix="[x] " --unselected-prefix="[ ] " || true)

            # 3. Development
            clear_logo
            echo ""
            gum style --foreground 6 --bold --padding "0 0 1 $PADDING_LEFT" ":: Productivity & Development (3/5)"
            local DEV_LIST=(
                "Visual Studio Code (visual-studio-code-bin) [AUR]"
                "Neovim (neovim) [Arch]"
                "Obsidian (obsidian) [AUR]"
                "LibreOffice Fresh (libreoffice-fresh) [Arch]"
                "LocalSend (localsend-bin) [AUR]"
                "Docker & Docker Compose (docker docker-compose) [Arch]"
                "Node.js & NPM (nodejs npm) [Arch]"
                "Python Suite (python-pip python-black ruff) [Arch]"
                "GitKraken (gitkraken) [AUR]"
                "Ollama (ollama) [Arch/AUR]"
            )
            local SEL_DEV
            SEL_DEV=$(printf "%s\n" "${DEV_LIST[@]}" | gum choose --no-limit --height 10 \
                --selected="Visual Studio Code (visual-studio-code-bin) [AUR]" \
                --header="Space = Toggle, Enter = Confirm Category" \
                --cursor-prefix="> " --selected-prefix="[x] " --unselected-prefix="[ ] " || true)

            # 4. Media & Gaming
            clear_logo
            echo ""
            gum style --foreground 6 --bold --padding "0 0 1 $PADDING_LEFT" ":: Media, Creativity & Gaming (4/5)"
            local MEDIA_LIST=(
                "Steam (steam) [Arch/Multilib]"
                "Lutris (lutris) [Arch]"
                "Heroic Games Launcher (heroic-games-launcher-bin) [AUR]"
                "OBS Studio (obs-studio) [Arch]"
                "VLC Media Player (vlc) [Arch]"
                "MPV Media Player (mpv) [Arch]"
                "GIMP (gimp) [Arch]"
                "Inkscape (inkscape) [Arch]"
                "Kdenlive (kdenlive) [Arch]"
                "Blender (blender) [Arch]"
                "Audacity (audacity) [Arch]"
            )
            local SEL_MEDIA
            SEL_MEDIA=$(printf "%s\n" "${MEDIA_LIST[@]}" | gum choose --no-limit --height 10 \
                --header="Space = Toggle, Enter = Confirm Category" \
                --cursor-prefix="> " --selected-prefix="[x] " --unselected-prefix="[ ] " || true)

            # 5. System Utilities
            clear_logo
            echo ""
            gum style --foreground 6 --bold --padding "0 0 1 $PADDING_LEFT" ":: System Utilities & Flatpaks (5/5)"
            local UTILS_LIST=(
                "VirtualBox (virtualbox virtualbox-host-modules-arch virtualbox-guest-iso) [Arch]"
                "Timeshift (timeshift) [Arch]"
                "Thunar File Manager (thunar thunar-archive-plugin thunar-volman) [Arch]"
                "Dolphin File Manager (dolphin ark) [Arch]"
                "Btop (btop) [Arch]"
                "Fastfetch (fastfetch) [Arch]"
                "Mission Center (io.missioncenter.MissionCenter) [Flatpak]"
                "Clapper (com.github.rafostar.Clapper) [Flatpak]"
                "Eye of GNOME (org.gnome.eog) [Flatpak]"
                "Sober (org.vinegarhq.Sober) [Flatpak]"
            )
            local SEL_UTILS
            SEL_UTILS=$(printf "%s\n" "${UTILS_LIST[@]}" | gum choose --no-limit --height 10 \
                --selected="Mission Center (io.missioncenter.MissionCenter) [Flatpak]" \
                --header="Space = Toggle, Enter = Confirm Category" \
                --cursor-prefix="> " --selected-prefix="[x] " --unselected-prefix="[ ] " || true)

            local ALL_SELECTED="${SEL_BROWSERS}"$'\n'"${SEL_COMM}"$'\n'"${SEL_DEV}"$'\n'"${SEL_MEDIA}"$'\n'"${SEL_UTILS}"

            while IFS= read -r line; do
                [ -z "$line" ] && continue
                case "$line" in
                    *"(brave-bin)"*)                    PACMAN_INSTALL+=("brave-bin") ;;
                    *"(brave-origin-nightly-bin)"*)     PACMAN_INSTALL+=("brave-origin-nightly-bin") ;;
                    *"(chromium)"*)                     PACMAN_INSTALL+=("chromium") ;;
                    *"(firefox)"*)                      PACMAN_INSTALL+=("firefox") ;;
                    *"(firefox-developer-edition)"*)    PACMAN_INSTALL+=("firefox-developer-edition") ;;
                    *"(google-chrome)"*)                PACMAN_INSTALL+=("google-chrome") ;;
                    *"(microsoft-edge-stable-bin)"*)    PACMAN_INSTALL+=("microsoft-edge-stable-bin") ;;
                    *"(zen-browser-bin)"*)              PACMAN_INSTALL+=("zen-browser-bin") ;;
                    *"(vesktop)"*)                      PACMAN_INSTALL+=("vesktop") ;;
                    *"(telegram-desktop)"*)             PACMAN_INSTALL+=("telegram-desktop") ;;
                    *"(slack-desktop)"*)                PACMAN_INSTALL+=("slack-desktop") ;;
                    *"(zapzap)"*)                       PACMAN_INSTALL+=("zapzap") ;;
                    *"(spotify)"*)                      PACMAN_INSTALL+=("spotify") ;;
                    *"(visual-studio-code-bin)"*)       PACMAN_INSTALL+=("visual-studio-code-bin") ;;
                    *"(neovim)"*)                       PACMAN_INSTALL+=("neovim") ;;
                    *"(obsidian)"*)                     PACMAN_INSTALL+=("obsidian") ;;
                    *"(libreoffice-fresh)"*)            PACMAN_INSTALL+=("libreoffice-fresh") ;;
                    *"(localsend-bin)"*)                PACMAN_INSTALL+=("localsend-bin") ;;
                    *"(docker docker-compose)"*)        PACMAN_INSTALL+=("docker" "docker-compose") ;;
                    *"(nodejs npm)"*)                   PACMAN_INSTALL+=("nodejs" "npm") ;;
                    *"(python-pip python-black ruff)"*) PACMAN_INSTALL+=("python-pip" "python-black" "ruff") ;;
                    *"(gitkraken)"*)                    PACMAN_INSTALL+=("gitkraken") ;;
                    *"(ollama)"*)                       PACMAN_INSTALL+=("ollama") ;;
                    *"(steam)"*)                        PACMAN_INSTALL+=("steam") ;;
                    *"(lutris)"*)                       PACMAN_INSTALL+=("lutris") ;;
                    *"(heroic-games-launcher-bin)"*)    PACMAN_INSTALL+=("heroic-games-launcher-bin") ;;
                    *"(obs-studio)"*)                   PACMAN_INSTALL+=("obs-studio") ;;
                    *"(vlc)"*)                          PACMAN_INSTALL+=("vlc") ;;
                    *"(mpv)"*)                          PACMAN_INSTALL+=("mpv") ;;
                    *"(gimp)"*)                         PACMAN_INSTALL+=("gimp") ;;
                    *"(inkscape)"*)                     PACMAN_INSTALL+=("inkscape") ;;
                    *"(kdenlive)"*)                     PACMAN_INSTALL+=("kdenlive") ;;
                    *"(blender)"*)                      PACMAN_INSTALL+=("blender") ;;
                    *"(audacity)"*)                     PACMAN_INSTALL+=("audacity") ;;
                    *"(virtualbox virtualbox-host-modules-arch virtualbox-guest-iso)"*) PACMAN_INSTALL+=("virtualbox" "virtualbox-host-modules-arch" "virtualbox-guest-iso") ;;
                    *"(timeshift)"*)                    PACMAN_INSTALL+=("timeshift") ;;
                    *"(thunar thunar-archive-plugin thunar-volman)"*) PACMAN_INSTALL+=("thunar" "thunar-archive-plugin" "thunar-volman") ;;
                    *"(dolphin ark)"*)                  PACMAN_INSTALL+=("dolphin" "ark") ;;
                    *"(btop)"*)                         PACMAN_INSTALL+=("btop") ;;
                    *"(fastfetch)"*)                    PACMAN_INSTALL+=("fastfetch") ;;
                    *"(io.missioncenter.MissionCenter)"*) FLATPAK_INSTALL+=("io.missioncenter.MissionCenter") ;;
                    *"(com.github.rafostar.Clapper)"*)    FLATPAK_INSTALL+=("com.github.rafostar.Clapper") ;;
                    *"(org.gnome.eog)"*)                  FLATPAK_INSTALL+=("org.gnome.eog") ;;
                    *"(org.vinegarhq.Sober)"*)            FLATPAK_INSTALL+=("org.vinegarhq.Sober") ;;
                esac
            done <<< "$ALL_SELECTED"

            # Optional fzf search after categories
            clear_logo
            echo ""
            gum style --foreground 6 --bold --padding "0 0 1 $PADDING_LEFT" ":: Additional Custom Software"
            if confirm_prompt "Would you like to search and add any extra packages with fzf?"; then
                unified_app_search
            fi
        fi
    fi

    # Wallpaper collection choice
    if [ -z "$WALLPAPER_MODE" ]; then
        clear_logo
        echo ""
        gum style --foreground 6 --bold --padding "0 0 1 $PADDING_LEFT" ":: Wallpaper Collection"
        local WP_CHOICE
        WP_CHOICE=$(gum choose --height 6 \
            --header="Select wallpaper download mode:" \
            --cursor-prefix="> " \
            "Random selection (3 packs)" \
            "All packs (49 packs, ~4GB)" \
            "Skip wallpaper download" || true)
        case "$WP_CHOICE" in
            *"All packs"*)        WALLPAPER_MODE="all" ;;
            *"Random"*)           WALLPAPER_MODE="random" ;;
            *"Skip"*)             WALLPAPER_MODE="none" ;;
            *)                    WALLPAPER_MODE="none" ;;
        esac
    fi

    # Shell choice
    clear_logo
    echo ""
    gum style --foreground 6 --bold --padding "0 0 1 $PADDING_LEFT" ":: Shell Configuration"
    if confirm_prompt "Set Zsh as your default shell?"; then
        SET_ZSH=true
    else
        SET_ZSH=false
    fi

    clear_logo
    echo ""
    gum style --foreground 2 --bold --padding "0 0 1 $PADDING_LEFT" "Deploying Rhythm Hyprland..."
    sleep 1
}

# --- APPLICATION DEPLOYMENT STEP ---
step_applications() {
    section "Optional Software & Applications"

    if [ "$INSTALL_MODE" = "minimal" ]; then
        step_ok "Optional applications skipped (minimal core stack)."
        return 0
    fi

    if [ "$INSTALL_MODE" = "full" ]; then
        if [ -f "$DOTFILES_DIR/packages.txt" ]; then
            step_item "Reading package list from packages.txt..."
            local FULL_PKGS=()
            while IFS= read -r pkg || [ -n "$pkg" ]; do
                pkg=$(echo "$pkg" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
                [ -z "$pkg" ] && continue
                [[ "$pkg" =~ ^# ]] && continue
                [[ "$pkg" == *-debug ]] && continue
                FULL_PKGS+=("$pkg")
            done < "$DOTFILES_DIR/packages.txt"

            if [ ${#FULL_PKGS[@]} -gt 0 ]; then
                step_item "Deploying full package stack (${#FULL_PKGS[@]} packages via yay)..."
                yay -S --needed --noconfirm "${FULL_PKGS[@]}" >> "$LOG_FILE" 2>&1 || step_warn "Some packages from packages.txt encountered errors during installation."
            fi
        fi

        if [ -f "$DOTFILES_DIR/flatpaks.txt" ] && [ "$SKIP_FLATPAKS" = false ]; then
            step_item "Configuring Flathub and deploying default Flatpaks..."
            sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >> "$LOG_FILE" 2>&1 || true
            while IFS= read -r fapp || [ -n "$fapp" ]; do
                fapp=$(echo "$fapp" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
                [ -z "$fapp" ] && continue
                [[ "$fapp" =~ ^# ]] && continue
                step_item "Installing flatpak: $fapp"
                sudo flatpak install -y --system flathub "$fapp" >> "$LOG_FILE" 2>&1 || true
            done < "$DOTFILES_DIR/flatpaks.txt"
        fi

        step_ok "Full package stack successfully deployed."
        return 0
    fi

    if [ ${#PACMAN_INSTALL[@]} -eq 0 ] && [ ${#FLATPAK_INSTALL[@]} -eq 0 ]; then
        step_ok "No optional applications selected."
        return 0
    fi

    if [ ${#PACMAN_INSTALL[@]} -gt 0 ]; then
        local unique_pkgs=($(printf "%s\n" "${PACMAN_INSTALL[@]}" | sort -u))
        PACMAN_INSTALL=("${unique_pkgs[@]}")
        step_item "Installing selected native/AUR packages (${#PACMAN_INSTALL[@]} items): ${PACMAN_INSTALL[*]}"
        gum spin --spinner dot --title "Installing applications via yay..." --padding "0 0 0 $PADDING_LEFT" -- \
            bash -c "yay -S --needed --noconfirm ${PACMAN_INSTALL[*]} >> '$LOG_FILE' 2>&1" || step_warn "Some native packages could not be installed."
    fi

    if [ ${#FLATPAK_INSTALL[@]} -gt 0 ] && [ "$SKIP_FLATPAKS" = false ]; then
        step_item "Configuring Flathub and installing selected Flatpaks (${#FLATPAK_INSTALL[@]} items)..."
        sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >> "$LOG_FILE" 2>&1 || true
        for app in "${FLATPAK_INSTALL[@]}"; do
            step_item "Installing flatpak: $app"
            sudo flatpak install -y --system flathub "$app" >> "$LOG_FILE" 2>&1 || true
        done
    fi

    step_ok "Application selection successfully deployed."
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
        # Nada de __pycache__ ni .pyc: son restos de pruebas y no deben viajar
        # a ~/.local/bin.
        case "$name" in
            __pycache__|*.pyc) continue ;;
        esac
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
    [ -f "$HOME/.local/bin/system-ota" ] && ln -sf "$HOME/.local/bin/system-ota" "$HOME/.local/bin/ota-updater" 2>/dev/null || true
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

    # Create standard user directories (Videos, Pictures, Music, Downloads, etc.)
    step_item "Creating standard user directories..."
    xdg-user-dirs-update >> "$LOG_FILE" 2>&1 || true
    mkdir -p "$HOME/Videos/Recordings" "$HOME/Pictures/Screenshots" "$HOME/Pictures/Wallpapers"

    # Enable all Dynamic Island & system user services
    #
    # Antes habia aqui una lista a mano de siete unidades, y el actualizador OTA
    # tenia otra distinta. Con dos listas, un servicio nuevo se habilitaba en una
    # instalacion nueva y no en una actualizacion, o al reves, segun donde se
    # hubiera anadido. Ahora los dos llaman al mismo guion, que decide mirando el
    # WantedBy de cada unidad, asi que no hay nada que mantener.
    step_item "Enabling Dynamic Island and background services..."
    if [ -x "$HOME/.local/bin/enable-user-services" ]; then
        "$HOME/.local/bin/enable-user-services" --now >> "$LOG_FILE" 2>&1 || step_warn "Some user services could not be enabled."
    else
        systemctl --user daemon-reload >> "$LOG_FILE" 2>&1 || true
        step_warn "enable-user-services missing; falling back to the service list."
        for u in waybar-island.service wallpaper-monitor-watcher.service rust-dock-monitor-watcher.service \
                 rhythm-power-profile.service privacy-shield.service rhythm-bluetooth-agent.service; do
            systemctl --user enable --now "$u" >> "$LOG_FILE" 2>&1 || true
        done
        systemctl --user enable --now rhythm-ota-check.timer >> "$LOG_FILE" 2>&1 || true
    fi

    # Enable system-level power-profiles-daemon (required by auto-power-profile)
    sudo systemctl enable --now power-profiles-daemon >> "$LOG_FILE" 2>&1 || true

    # Run pending dotfiles migrations (idempotent, Omarchy-style)
    if [ -x "$HOME/.local/bin/rhythm-migrate" ]; then
        step_item "Running dotfiles migrations..."
        RHYTHM_REPO="$DOTFILES_DIR" "$HOME/.local/bin/rhythm-migrate" >> "$LOG_FILE" 2>&1 || step_warn "Some migrations reported issues."
    fi

    # Configure Waybar battery modules for target machine (0, 1, or 2+ batteries)
    if [ -f "$HOME/.config/waybar/scripts/auto-battery-setup.sh" ]; then
        chmod +x "$HOME/.config/waybar/scripts/auto-battery-setup.sh" 2>/dev/null || true
        step_item "Configuring Waybar battery detection..."
        "$HOME/.config/waybar/scripts/auto-battery-setup.sh" >> "$LOG_FILE" 2>&1 || true
    fi

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
        
        local FW_REPO="https://github.com/deadduck-09/FireWalls.git"
        local FW_DIR="$TEMP_WALL/firewalls"

        local CHOICE="$MODE"
        if [ -z "$CHOICE" ]; then
            CHOICE=$(gum choose --header "Select download mode" \
                "Download All Wallpapers (~600MB)" \
                "Random Selection (50 Wallpapers)" \
                "Skip")
        fi

        if [ "$CHOICE" == "Download All Wallpapers (~600MB)" ] || [ "$CHOICE" == "all" ]; then
            step_item "Cloning FireWalls collection (root + subcarpetas, ~850 imgs)..."
            rm -rf "$FW_DIR" || true
            if git clone --depth 1 --filter=blob:none --sparse "$FW_REPO" "$FW_DIR" >> "$LOG_FILE" 2>&1 \
                && (cd "$FW_DIR" && git sparse-checkout set Desktop/Wallpapers >> "$LOG_FILE" 2>&1); then
                if find "$FW_DIR/Desktop/Wallpapers" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) -print -quit 2>/dev/null | grep -q .; then
                    find "$FW_DIR/Desktop/Wallpapers" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) -exec cp -n {} "$WALL_DIR/" \; >> "$LOG_FILE" 2>&1 || step_warn "No se pudieron copiar wallpapers."
                else
                    step_warn "Coleccion clonada pero sin ficheros en Desktop/Wallpapers."
                fi
            else
                step_warn "No se pudo clonar la coleccion de wallpapers, se omite paso opcional."
            fi
        elif [ "$CHOICE" == "Random Selection (50 Wallpapers)" ] || [ "$CHOICE" == "random" ]; then
            step_item "Downloading 50 random wallpapers (root + Best-Collection)..."
            local TREE_JSON
            TREE_JSON=$(curl -fsSL "https://api.github.com/repos/deadduck-09/FireWalls/git/trees/main?recursive=1" 2>/dev/null || true)
            local URL_LIST=""
            if [ -n "$TREE_JSON" ] && command -v jq >/dev/null 2>&1; then
                URL_LIST=$(echo "$TREE_JSON" | jq -r '.tree[]? | select(.type=="blob") | .path | select(startswith("Desktop/Wallpapers/")) | select(test("\\.(jpg|jpeg|png|webp|gif)$"; "i")) | "https://raw.githubusercontent.com/deadduck-09/FireWalls/main/\(.)"' 2>/dev/null | grep -E '\.(jpg|jpeg|png|webp|gif)$' || true)
            fi
            if [ -n "$URL_LIST" ]; then
                echo "$URL_LIST" | shuf -n 50 | while read -r url; do
                    [ -n "$url" ] || continue
                    curl -fsSL "$url" -o "$WALL_DIR/$(basename "$url")" >> "$LOG_FILE" 2>&1 || true
                done || true
            else
                step_warn "Could not fetch wallpaper list (API vacia/rate-limit), cloning full collection instead."
                rm -rf "$FW_DIR" || true
                if git clone --depth 1 --filter=blob:none --sparse "$FW_REPO" "$FW_DIR" >> "$LOG_FILE" 2>&1 \
                    && (cd "$FW_DIR" && git sparse-checkout set Desktop/Wallpapers >> "$LOG_FILE" 2>&1); then
                    if find "$FW_DIR/Desktop/Wallpapers" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) -print -quit 2>/dev/null | grep -q .; then
                        find "$FW_DIR/Desktop/Wallpapers" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) -exec cp -n {} "$WALL_DIR/" \; >> "$LOG_FILE" 2>&1 || step_warn "No se pudieron copiar wallpapers."
                    else
                        step_warn "Coleccion clonada pero sin ficheros en Desktop/Wallpapers."
                    fi
                else
                    step_warn "No se pudo clonar la coleccion de wallpapers, se omite paso opcional."
                fi
            fi
        fi
        rm -rf "$TEMP_WALL" || true
        step_ok "Wallpapers installed."
    fi
    return 0
}

# --- SYSTEM SERVICES & FINISHING ---
step_system() {
    section "System Services & Finalization"
    
    if [ "$SET_ZSH" = true ]; then
        if [ "$SHELL" != "$(which zsh)" ]; then
            sudo chsh -s "$(which zsh)" "$USER" >> "$LOG_FILE" 2>&1 || true
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

        # El greeter corre en WAYLAND, no en X11, y esto no es estetico.
        #
        # En un portatil con GPU hibrida el monitor externo cuelga de la tarjeta
        # discreta y el panel del portatil de la integrada. El servidor X que
        # levanta SDDM solo consecuguia encender una de las dos, asi que con las
        # dos conectadas el login se quedaba en negro y la unica salida era
        # reiniciar con el cable fuera. Hyprland ya conduce ambas GPUs sin
        # problema en la sesion normal, asi que se le da tambien el login.
        #
        # El Xsetup se sigue desplegando y queda de red de seguridad: es el
        # camino que se usa si hay que volver a X11.
        if [ -f "$DOTFILES_DIR/sddm/hyprland.lua" ]; then
            sudo cp -f "$DOTFILES_DIR/sddm/hyprland.lua" /usr/share/sddm/hyprland.lua
            sudo chmod 644 /usr/share/sddm/hyprland.lua
        fi
        echo -e "[General]\nDisplayServer=wayland\n\n[Wayland]\nCompositorCommand=start-hyprland -- --config /usr/share/sddm/hyprland.lua" \
            | sudo tee /etc/sddm.conf.d/10-wayland.conf > /dev/null

        # Red de seguridad: si algun dia hay que volver a X11, se renombra este
        # fichero a .disabled y se restaura xsetup.conf.
        [ -f "/etc/sddm.conf.d/xsetup.conf" ] && sudo mv -f /etc/sddm.conf.d/xsetup.conf /etc/sddm.conf.d/xsetup.conf.disabled
        if [ -f "$DOTFILES_DIR/sddm/Xsetup" ]; then
            sudo cp -f "$DOTFILES_DIR/sddm/Xsetup" /etc/sddm/Xsetup
            sudo chmod +x /etc/sddm/Xsetup
        fi

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
    systemctl --user enable --now pipewire.service >> "$LOG_FILE" 2>&1 || true

    # Add user to required groups (network for nmcli, lp for printing, optical for disc)
    sudo usermod -aG video,input,render,wheel,audio,storage,network,lp,optical "$USER"
    step_ok "System services and permissions configured."
}

# --- UPDATE WORKFLOW ---
step_update() {
    clear_logo
    echo ""
    gum style --foreground 6 --bold --padding "0 0 1 $PADDING_LEFT" "Rhythm Hyprland System Updater"
    gum style --foreground 7 --padding "0 0 1 $PADDING_LEFT" "Updating dotfiles, helper executables, and desktop configurations..."

    if [ -x "$DOTFILES_DIR/.local/bin/system-ota" ]; then
        if [ "$AUTO_YES" = true ]; then
            bash "$DOTFILES_DIR/.local/bin/system-ota" update
        else
            echo ""
            if gum confirm "Would you also like to update system packages with pacman?"; then
                bash "$DOTFILES_DIR/.local/bin/system-ota" update --system
            else
                bash "$DOTFILES_DIR/.local/bin/system-ota" update
            fi
        fi
    else
        step_dotfiles
        if [ -x "$HOME/.local/bin/modern-pywal-sync" ]; then
            bash -c "$HOME/.local/bin/modern-pywal-sync >> '$LOG_FILE' 2>&1 || true"
        fi
    fi

    # Reload systemd and re-enable all services after update
    #
    # Esto era una SEGUNDA lista de unidades, igual que la de mas arriba. Unificar
    # solo una de las dos deja el mismo problema: un servicio nuevo se habilita en
    # un sitio y no en el otro, y no se ve hasta que algo no arranca. Las dos
    # llaman a enable-user-services, que decide mirando el WantedBy de cada
    # unidad.
    step_item "Reloading systemd user services..."
    systemctl --user daemon-reload >> "$LOG_FILE" 2>&1 || true
    if [ -x "$HOME/.local/bin/enable-user-services" ]; then
        "$HOME/.local/bin/enable-user-services" --now >> "$LOG_FILE" 2>&1 || true
    else
        for u in waybar-island.service wallpaper-monitor-watcher.service rust-dock-monitor-watcher.service \
                 rhythm-power-profile.service privacy-shield.service rhythm-bluetooth-agent.service; do
            systemctl --user enable --now "$u" >> "$LOG_FILE" 2>&1 || true
        done
        systemctl --user enable --now rhythm-ota-check.timer >> "$LOG_FILE" 2>&1 || true
    fi
    sudo systemctl enable --now power-profiles-daemon >> "$LOG_FILE" 2>&1 || true

    # rust-dock: relanzar para que tome el binario recien desplegado
    if pgrep -x rust-dock >/dev/null 2>&1 || [ -x "$HOME/.local/bin/rust-dock-launcher" ]; then
        pkill -x rust-dock >> "$LOG_FILE" 2>&1 || true
        sleep 0.3
        "$HOME/.local/bin/rust-dock-launcher" >/dev/null 2>&1 &
    fi

    step_ok "Services reloaded."

    clear_logo
    echo ""
    gum style --foreground 2 --bold --padding "0 0 1 $PADDING_LEFT" "Update completed successfully"
    gum style --foreground 7 --padding "0 0 1 $PADDING_LEFT" "All configurations, helpers, and services have been updated."
    exit 0
}

check_existing_installation() {
    if [ "$UPDATE_MODE" = true ]; then
        step_update
    fi

    if [ "$AUTO_YES" = true ] || [ "$DRY_RUN" = true ]; then
        return 0
    fi

    if [ -d "$HOME/.config/hypr" ] && [ -f "$HOME/.local/bin/system-ota" ]; then
        clear_logo
        echo ""
        gum style --foreground 6 --bold --padding "0 0 1 $PADDING_LEFT" "Existing Rhythm Hyprland installation detected."
        local ACTION
        ACTION=$(gum choose \
            --header="Select installation action:" \
            --cursor-prefix="> " \
            "1. Update Existing Installation (Sync dotfiles, scripts, and updates)" \
            "2. Full Re-installation (Reinstall packages, themes, and configs)" || true)

        if [[ "$ACTION" == *"1. Update Existing Installation"* ]]; then
            UPDATE_MODE=true
            step_update
        fi
    fi
}

# --- MAIN EXECUTION ---
if [ "$UPDATE_MODE" = true ]; then
    step_update
fi

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

    section "Optional Software & Applications"
    step_item "Simulating interactive application menu..."
    sleep 0.4
    step_ok "Interactive multi-selection menu and universal fzf package search verified."

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
check_existing_installation
install_yay
first_run_choices

step_software
step_applications
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
