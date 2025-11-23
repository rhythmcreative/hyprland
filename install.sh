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
    bibata-cursor-theme adwaita-icon-theme tela-circle-icon-theme-all
)

# Audio (Pipewire) and Bluetooth support
AUDIO_BLUETOOTH=(
    pipewire wireplumber pipewire-audio pipewire-pulse pavucontrol
    bluez bluez-utils blueman network-manager-applet
)

# Main applications from official repos and the AUR
APPLICATIONS=(
    kitty librewolf-bin chromium vesktop-bin steam virtualbox virtualbox-host-dkms
    prismlauncher minecraft-launcher balena-etcher-bin
    telegram-desktop curseforge-client-bin visual-studio-code-bin libreoffice-fresh
    obsidian obs-studio partitionmanager antigravity
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

init_submodules() {
    info "Initializing and updating Git submodules..."
    if ! git submodule update --init --recursive; then
        error "Failed to update submodules. Please check your Git configuration and network."
        exit 1
    fi
    success "Submodules updated successfully."
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

detect_and_install_asus_tools() {
    if ! command -v dmidecode &> /dev/null; then
        info "'dmidecode' not found. Installing it for hardware detection..."
        yay -S --needed --noconfirm dmidecode
    fi

    if sudo dmidecode -s system-manufacturer | grep -q "ASUSTeK"; then
        info "ASUS hardware detected."
        if [[ -t 0 ]]; then # Check if running in an interactive terminal
            read -p "Do you want to install ASUS-specific tools (asusctl, rog-control-center)? (y/N): " response
            if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                info "Installing ASUS tools..."
                yay -S --needed --noconfirm asusctl rog-control-center
                success "ASUS tools installed."
            else
                warning "Skipping ASUS tools installation."
            fi
        else
            warning "Running in a non-interactive shell. Skipping ASUS tools installation by default."
        fi
    else
        info "No ASUS hardware detected. Skipping ASUS tools installation."
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

copy_configs() {
    info "Copying configuration files to their final destination..."

    local SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
    local DOTFILES_DIR="$SCRIPT_DIR"
    local BACKUP_DIR="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"

    local CONFIG_DIRS=("hypr" "rofi" "wal" "kitty")
    local LOCAL_DIRS=("bin")
    local HOME_FILES=(".zshrc") # New array for files directly in HOME

    mkdir -p "$HOME/.config"
    mkdir -p "$HOME/.local"
    mkdir -p "$HOME/Pictures"

    copy_item() {
        local src=$1
        local dest=$2
        
        if [ -e "$dest" ]; then
            warning "Backing up existing file/directory: $dest"
            local backup_path="$BACKUP_DIR/${dest#$HOME}"
            mkdir -p "$(dirname "$backup_path")"
            mv "$dest" "$backup_path"
        fi
        
        info "🚚 Copying $src -> $dest"
        cp -r "$src" "$dest"
    }

    # Copy .config directories
    for dir in "${CONFIG_DIRS[@]}"; do
        local src="$DOTFILES_DIR/config/$dir"
        local dest="$HOME/.config/$dir"
        [ -d "$src" ] && copy_item "$src" "$dest"
    done

    # Copy Waybar config separately from the root
    local WAYBAR_SRC="$DOTFILES_DIR/waybar"
    local WAYBAR_DEST="$HOME/.config/waybar"
    [ -d "$WAYBAR_SRC" ] && copy_item "$WAYBAR_SRC" "$WAYBAR_DEST"

    # Copy .local directories
    for dir in "${LOCAL_DIRS[@]}"; do
        local src="$DOTFILES_DIR/local/$dir"
        local dest="$HOME/.local/$dir"
        [ -d "$src" ] && copy_item "$src" "$dest"
    done

    # Copy files directly to HOME
    for file in "${HOME_FILES[@]}"; do
        local src="$DOTFILES_DIR/$file"
        local dest="$HOME/$file"
        [ -f "$src" ] && copy_item "$src" "$dest"
    done

    # Copy Wallpapers directory
    local WALLPAPERS_SRC="$DOTFILES_DIR/Pictures/Wallpapers"
    local WALLPAPERS_DEST="$HOME/Pictures/Wallpapers"
    [ -d "$WALLPAPERS_SRC" ] && copy_item "$WALLPAPERS_SRC" "$WALLPAPERS_DEST"
    
    success "Configuration files copied."
}



setup_sddm() {
    info "Ensuring SDDM is installed and configuring theme..."
    yay -S --needed --noconfirm sddm

    # Copy the SDDM theme
    info "Copying SDDM theme..."
    if [ -d "$DOTFILES_DIR/sddm/themes/sddm-astronaut-theme" ]; then
        sudo cp -r "$DOTFILES_DIR/sddm/themes/sddm-astronaut-theme" "/usr/share/sddm/themes/"
    else
        warning "SDDM astronaut theme not found in repository. Skipping theme setup."
        return
    fi

    # Copy the SDDM configuration
    info "Copying SDDM configuration..."
    if [ -f "$DOTFILES_DIR/config/sddm.conf.d/theme.conf" ]; then
        sudo mkdir -p "/etc/sddm.conf.d"
        sudo cp "$DOTFILES_DIR/config/sddm.conf.d/theme.conf" "/etc/sddm.conf.d/"
    else
        warning "SDDM theme configuration not found. Skipping theme setup."
        return
    fi

    if ! command -v sddm &> /dev/null; then
        error "SDDM was not found after installation. Cannot enable service."
        return 1
    fi

    sudo systemctl enable --now sddm.service
    success "SDDM service enabled, configured with the astronaut theme, and started."
}

final_setup() {
    success "✅ Installation complete!"
    echo ""
    info "--- NEXT STEPS ---"
    warning "1. A REBOOT is highly recommended for all changes to take effect."
    warning "2. Run Pywal to generate your initial color scheme. Find a wallpaper you like and run:"
    echo "   wal -i /path/to/your/wallpaper.jpg"
    warning "3. After rebooting, SDDM will start with its default theme."
    warning "4. The custom astronaut theme was removed from the setup due to persistent permission issues. You can attempt to install it manually later."
    echo ""
}

# --- Main Execution ---
main() {
    detect_os
    init_submodules
    install_aur_helper
    detect_gpu_and_install_drivers
    detect_and_install_asus_tools
    install_yay_packages
    install_flatpak_and_apps
    setup_bluetooth
    copy_configs
    setup_sddm
    final_setup
}

# Run the script
main