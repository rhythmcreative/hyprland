#!/bin/bash
#
# install.sh
#
# Comprehensive installation script for rhythmcreative's dotfiles.
# This script installs packages, drivers, applications, and sets up the system
# configuration for a complete Hyprland desktop environment on Arch Linux.
#

# --- Colors for output ---
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

# --- Log functions ---
info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $1"
}

success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $1"
}

warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $1"
}

error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $1"
}

# --- Script setup ---
# Exit immediately if a command exits with a non-zero status.
set -e

# --- Package Lists for Arch Linux ---

# Essential packages for system utilities, building, etc.
BASE_PACKAGES=(
    git curl wget unzip btop stow jq polkit-kde-agent qt5ct playerctl brightnessctl
)

# Build tools required for AUR packages and other software
BUILD_TOOLS=(
    base-devel cmake meson go rust cargo gettext cairo pango gdk-pixbuf2 glib2
)

# Hyprland and its core ecosystem components
HYPRLAND_ECOSYSTEM=(
    sddm hyprland hyprpm hyprlock hyprpicker xdg-desktop-portal-hyprland
    waybar rofi python-pywal swww mako grim slurp swappy
    dolphin thunar
)

# Theming, fonts, icons, and cursors
THEMING_PACKAGES=(
    nwg-look nwg-displays
    noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-font-awesome
    bibata-cursor-theme adwaita-icon-theme
)

# Audio (Pipewire) and Bluetooth support
AUDIO_BLUETOOTH=(
    pipewire wireplumber pipewire-audio pipewire-pulse pavucontrol
    bluez bluez-utils blueman network-manager-applet
)

# Main applications from official repos and the AUR
APPLICATIONS=(
    kitty librewolf-bin chromium vesktop-bin steam virtualbox virtualbox-host-dkms
    asusctl rog-control-center prismlauncher minecraft-launcher balena-etcher-bin
    telegram-desktop curseforge-client-bin visual-studio-code-bin libreoffice-fresh
    obsidian obs-studio
)

# List of applications to be installed via Flatpak
FLATPAK_APPS=(
    com.heroicgameslauncher.hgl
    org.vinegarhq.Sober
)


# --- Function Declarations ---

detect_os() {
    if [ -f /etc/arch-release ]; then
        info "Arch Linux detected. Proceeding with installation."
    else
        error "This script is designed for Arch Linux. Aborting."
        exit 1
    fi
}

install_aur_helper() {
    if ! command -v yay &> /dev/null; then
        info "'yay' not found. Installing it now..."
        if ! command -v git &> /dev/null; then
            sudo pacman -S --needed --noconfirm git
        fi
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        (cd /tmp/yay && makepkg -si --noconfirm)
        success "'yay' has been installed."
    else
        info "'yay' is already installed."
    fi
}

detect_gpu_and_install_drivers() {
    if lspci | grep -Ei 'NVIDIA|3D controller' | grep -q NVIDIA; then
        info "NVIDIA GPU detected."
        if [[ -t 0 ]]; then # Check if running in an interactive terminal
            read -p "Do you want to install the NVIDIA drivers? (y/N): " response
            if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                info "Installing NVIDIA drivers..."
                yay -S --needed --noconfirm nvidia-dkms nvidia-utils libva-nvidia-driver egl-wayland
                success "NVIDIA drivers installed."
                warning "A reboot is required to load the new drivers."
            else
                warning "Skipping NVIDIA driver installation."
            fi
        else
            warning "Running in a non-interactive shell. Skipping NVIDIA driver installation by default."
            warning "To install NVIDIA drivers, run this script in an interactive shell."
        fi
    else
        info "No NVIDIA GPU detected. Skipping NVIDIA driver installation."
    fi
}

install_yay_packages() {
    info "Installing all required packages from official repositories and AUR..."
    warning "This process may take a long time."

    # Combine all package lists
    local all_packages=(
        "${BASE_PACKAGES[@]}"
        "${BUILD_TOOLS[@]}"
        "${HYPRLAND_ECOSYSTEM[@]}"
        "${THEMING_PACKAGES[@]}"
        "${AUDIO_BLUETOOTH[@]}"
        "${APPLICATIONS[@]}"
    )

    yay -S --needed --noconfirm "${all_packages[@]}"
    success "All packages have been installed."
}

install_flatpak_and_apps() {
    info "Installing Flatpak and setting up Flathub..."
    yay -S --needed --noconfirm flatpak
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    info "Installing applications via Flatpak..."
    sudo flatpak install -y --noninteractive flathub "${FLATPAK_APPS[@]}"
    success "Flatpak applications installed."
    warning "Note on other apps: 'Twitter'/'X' does not have an official Linux client. Use the web version. 'zapzap' is likely WhatsApp; you can search for a client like 'whatsie' on the AUR or use a web wrapper."
}

setup_bluetooth() {
    info "Enabling and starting Bluetooth service..."
    sudo systemctl enable --now bluetooth.service
    success "Bluetooth service has been enabled."
}

create_symlinks() {
    info "Creating symbolic links for dotfiles..."

    local SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
    local DOTFILES_DIR="$SCRIPT_DIR"
    local BACKUP_DIR="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"

    local CONFIG_DIRS=("hypr" "waybar" "rofi" "wal" "kitty")
    local LOCAL_DIRS=("bin")

    mkdir -p "$HOME/.config"
    mkdir -p "$HOME/.local"
    mkdir -p "$HOME/Pictures"

    link_item() {
        local src=$1
        local dest=$2
        
        if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$src" ]; then
            info "✔ Link already exists: $dest"
            return
        fi

        if [ -e "$dest" ]; then
            warning "Backing up existing file/directory: $dest"
            mkdir -p "$(dirname "$BACKUP_DIR/$dest")"
            mv "$dest" "$BACKUP_DIR/$dest"
        fi
        
        info "🔗 Linking $dest -> $src"
        ln -s "$src" "$dest"
    }

    for dir in "${CONFIG_DIRS[@]}"; do
        local src="$DOTFILES_DIR/config/$dir"
        local dest="$HOME/.config/$dir"
        [ -d "$src" ] && link_item "$src" "$dest"
    done

    for dir in "${LOCAL_DIRS[@]}"; do
        local src="$DOTFILES_DIR/local/$dir"
        local dest="$HOME/.local/$dir"
        [ -d "$src" ] && link_item "$src" "$dest"
    done

    local WALLPAPERS_SRC="$DOTFILES_DIR/Pictures/Wallpapers"
    local WALLPAPERS_DEST="$HOME/Pictures/Wallpapers"
    [ -d "$WALLPAPERS_SRC" ] && link_item "$WALLPAPERS_SRC" "$WALLPAPERS_DEST"
    
    success "Symbolic links created."
}

setup_sddm() {
    info "Configuring SDDM..."

    if ! command -v sddm &> /dev/null; then
        error "SDDM was not found after installation. Aborting SDDM setup."
        return 1
    fi

    local SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
    local THEME_SRC_DIR="$SCRIPT_DIR/sddm/themes/sddm-astronaut-theme"
    local CONFIG_SRC_FILE="$SCRIPT_DIR/sddm/sddm.conf.d/astronaut.conf"

    if [ ! -d "$THEME_SRC_DIR" ]; then
        error "SDDM theme source directory not found. Aborting SDDM setup."
        return 1
    fi
    if [ ! -f "$CONFIG_SRC_FILE" ]; then
        error "SDDM config source file not found. Aborting SDDM setup."
        return 1
    fi

    info "Installing SDDM theme and configuration..."
    sudo mkdir -p "/usr/share/sddm/themes"
    sudo cp -r "$THEME_SRC_DIR" "/usr/share/sddm/themes/"
    sudo mkdir -p "/etc/sddm.conf.d"
    sudo cp "$CONFIG_SRC_FILE" "/etc/sddm.conf.d/"

    info "Enabling SDDM service..."
    sudo systemctl enable sddm.service
    success "SDDM configured and enabled."
}

final_setup() {
    success "✅ Installation complete!"
    echo ""
    info "--- NEXT STEPS ---"
    warning "1. A REBOOT is highly recommended for all changes to take effect."
    warning "2. Run Pywal to generate your initial color scheme. Find a wallpaper you like and run:"
    echo "   wal -i /path/to/your/wallpaper.jpg"
    warning "3. After rebooting, you should be greeted by the new SDDM login screen."
    echo ""
}

# --- Main Execution ---
main() {
    detect_os
    install_aur_helper
    detect_gpu_and_install_drivers
    install_yay_packages
    install_flatpak_and_apps
    setup_bluetooth
    create_symlinks
    setup_sddm
    final_setup
}

# Run the script
main