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

# --- Global Variables ---
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
DOTFILES_DIR="$SCRIPT_DIR"

# --- Package Lists for Arch Linux ---

# Essential packages for system utilities, building, etc.
ARCH_BASE_PACKAGES=(
    git curl wget unzip btop stow jq polkit-kde-agent qt5ct playerctl brightnessctl bc
)

# Build tools required for AUR packages and other software
ARCH_BUILD_TOOLS=(
    base-devel cmake meson go rust cargo gettext cairo pango gdk-pixbuf2 glib2
    python-pip
)

# Hyprland and its core ecosystem components
ARCH_HYPRLAND_ECOSYSTEM=(
    sddm hyprland hyprlock hyprpicker xdg-desktop-portal-hyprland
    waybar rofi python-pywal swww grim slurp swappy
    dolphin thunar network-manager-applet
)

# Theming, fonts, icons, and cursors
ARCH_THEMING_PACKAGES=(
    nwg-look nwg-displays
    noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-font-awesome
    ttf-jetbrains-mono-nerd imagemagick
    bibata-cursor-theme adwaita-icon-theme tela-circle-icon-theme-all
)

# Audio (Pipewire) and Bluetooth support
ARCH_AUDIO_BLUETOOTH=(
    pipewire wireplumber pipewire-audio pipewire-pulse pavucontrol
    bluez bluez-utils blueman
)

# Main applications from official repos and the AUR
# Essential applications (Terminal and Browser)
ARCH_ESSENTIAL_APPS=(
    kitty librewolf-bin python-pywalfox
)

# Extra applications (Games, Social, Tools, etc.)
ARCH_EXTRA_APPS=(
    chromium vesktop-bin steam virtualbox virtualbox-host-dkms
    prismlauncher minecraft-launcher balena-etcher
    telegram-desktop curseforge visual-studio-code-bin libreoffice-fresh
    obsidian obs-studio partitionmanager antigravity
)

# --- Package Lists for Ubuntu/Debian ---

# Essential packages
UBUNTU_BASE_PACKAGES=(
    git curl wget unzip btop stow jq policykit-1-gnome qt5ct playerctl brightnessctl bc
    build-essential cmake meson golang rustc cargo gettext libcairo2-dev libpango1.0-dev libgdk-pixbuf2.0-dev libglib2.0-dev
    libgtk-3-dev scdoc
    python3-pip python3-venv
)

# Hyprland Ecosystem (Note: Hyprland is not in standard Ubuntu repos usually, user might need PPA)
# We install available tools.
UBUNTU_HYPRLAND_ECOSYSTEM=(
    sddm waybar rofi grim slurp
    thunar network-manager-gnome
)
# Missing in standard Ubuntu: hyprland, hyprlock, hyprpicker, swww (might need manual install or PPA)
# Removed: python3-pywal (install via pip), swappy (needs manual install)

# Theming
UBUNTU_THEMING_PACKAGES=(
    fonts-noto fonts-noto-cjk fonts-noto-color-emoji fonts-font-awesome
    imagemagick
)
# Missing: nwg-look, nwg-displays (often AUR or external), ttf-jetbrains-mono-nerd (manual), bibata-cursor-theme, tela-circle...

# Audio/Bluetooth
UBUNTU_AUDIO_BLUETOOTH=(
    pipewire wireplumber pipewire-pulse pavucontrol
    bluez blueman
)

# Apps
UBUNTU_ESSENTIAL_APPS=(
    kitty
)
# Missing: librewolf (needs repo), python-pywalfox (pip)

UBUNTU_EXTRA_APPS=(
    chromium-browser steam virtualbox
    telegram-desktop code libreoffice
    obs-studio partitionmanager
)

# List of applications to be installed via Flatpak
FLATPAK_APPS=(
    com.heroicgameslauncher.hgl
    org.vinegarhq.Sober
)


# --- Function Declarations ---

detect_os() {
    if [ -f /etc/arch-release ]; then
        DISTRO="arch"
        info "Arch Linux detected."
    elif [ -f /etc/os-release ]; then
        # Check for Ubuntu or Debian
        if grep -qE "ID=ubuntu|ID=debian" /etc/os-release; then
            DISTRO="ubuntu"
            info "Ubuntu/Debian detected."
        else
            error "Unsupported distribution. This script supports Arch Linux and Ubuntu/Debian."
            exit 1
        fi
    else
        error "Could not detect OS. Aborting."
        exit 1
    fi
}

update_repos() {
    if [ "$DISTRO" == "arch" ]; then
        info "Updating Arch repositories..."
        sudo pacman -Sy
    elif [ "$DISTRO" == "ubuntu" ]; then
        info "Updating Ubuntu repositories..."
        sudo apt update
    fi
}

install_pkgs() {
    local pkgs=("$@")
    if [ ${#pkgs[@]} -eq 0 ]; then
        return
    fi

    if [ "$DISTRO" == "arch" ]; then
        yay -S --needed --noconfirm "${pkgs[@]}"
    elif [ "$DISTRO" == "ubuntu" ]; then
        # Filter out packages that might not exist or have different names if not handled
        # For now, we assume the list passed is correct for the distro
        sudo apt install -y "${pkgs[@]}"
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
    if [ "$DISTRO" != "arch" ]; then
        return
    fi

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
                if [ "$DISTRO" == "arch" ]; then
                    yay -S --needed --noconfirm nvidia-dkms nvidia-utils libva-nvidia-driver egl-wayland
                elif [ "$DISTRO" == "ubuntu" ]; then
                    # Ubuntu usually has a helper 'ubuntu-drivers', but we can try installing a standard meta-package
                    # or instruct user. 'nvidia-driver-535' is common, but versions change.
                    # Best to use the auto-install tool if available.
                    if command -v ubuntu-drivers &> /dev/null; then
                        sudo ubuntu-drivers autoinstall
                    else
                        warning "ubuntu-drivers tool not found. Installing generic nvidia-driver."
                        sudo apt install -y nvidia-driver-535
                    fi
                fi
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
        install_pkgs dmidecode
    fi

    if sudo dmidecode -s system-manufacturer | grep -q "ASUSTeK"; then
        info "ASUS hardware detected."
        if [[ -t 0 ]]; then # Check if running in an interactive terminal
            read -p "Do you want to install ASUS-specific tools (asusctl, rog-control-center)? (y/N): " response
            if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                info "Installing ASUS tools..."
                if [ "$DISTRO" == "arch" ]; then
                    yay -S --needed --noconfirm asusctl rog-control-center
                    success "ASUS tools installed."
                else
                    warning "ASUS tools (asusctl) installation is not automated for Ubuntu in this script."
                    warning "Please check https://asus-linux.org/ for Ubuntu installation instructions."
                fi
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

install_packages() {
    info "Installing all required packages..."
    warning "This process may take a long time."

    # Ask user for installation mode
    local install_mode="essential"
    if [[ -t 0 ]]; then
        echo ""
        info "--- Installation Options ---"
        echo "1) Essential (Base system, Hyprland, Theming, Audio, Kitty, Librewolf)"
        echo "2) Full (Everything above + Chromium, Discord/Vesktop, Steam, VirtualBox, Minecraft, Telegram, VSCode, LibreOffice, Obsidian, OBS, etc.)"
        read -p "Select installation mode [1/2] (default: 1): " choice
        if [[ "$choice" == "2" ]]; then
            install_mode="full"
        fi
    fi

    # Combine package lists based on mode and distro
    local all_packages=()
    if [ "$DISTRO" == "arch" ]; then
        all_packages+=(
            "${ARCH_BASE_PACKAGES[@]}"
            "${ARCH_BUILD_TOOLS[@]}"
            "${ARCH_HYPRLAND_ECOSYSTEM[@]}"
            "${ARCH_THEMING_PACKAGES[@]}"
            "${ARCH_AUDIO_BLUETOOTH[@]}"
            "${ARCH_ESSENTIAL_APPS[@]}"
        )
        if [[ "$install_mode" == "full" ]]; then
            all_packages+=("${ARCH_EXTRA_APPS[@]}")
        fi
    elif [ "$DISTRO" == "ubuntu" ]; then
        all_packages+=(
            "${UBUNTU_BASE_PACKAGES[@]}"
            "${UBUNTU_HYPRLAND_ECOSYSTEM[@]}"
            "${UBUNTU_THEMING_PACKAGES[@]}"
            "${UBUNTU_AUDIO_BLUETOOTH[@]}"
            "${UBUNTU_ESSENTIAL_APPS[@]}"
        )
        if [[ "$install_mode" == "full" ]]; then
            all_packages+=("${UBUNTU_EXTRA_APPS[@]}")
        fi
    fi

    if [[ "$install_mode" == "full" ]]; then
        info "Selected: Full Installation"
        INSTALL_MODE="full" # Export for other functions
    else
        info "Selected: Essential Installation"
        INSTALL_MODE="essential"
    fi

    install_pkgs "${all_packages[@]}"
    
    # Post-package installation steps for Ubuntu
    if [ "$DISTRO" == "ubuntu" ]; then
        info "Installing Pywal via pip (not in apt repos)..."
        # Ensure pip is installed (should be from UBUNTU_BASE_PACKAGES)
        # We use --break-system-packages if on newer python versions, or just pip3
        # To be safe and avoid breaking system python, we should use pipx or user install, 
        # but for dotfiles script, user install is often preferred.
        pip3 install --user pywal
        success "Pywal installed via pip."
        
        info "Installing Swappy from source (not in apt repos)..."
        if ! command -v swappy &> /dev/null; then
             git clone https://github.com/jomo/swappy.git /tmp/swappy
             (cd /tmp/swappy && meson setup build && ninja -C build && sudo ninja -C build install)
             success "Swappy installed from source."
        else
             info "Swappy is already installed."
        fi
    fi

    success "Selected packages have been installed."
}

install_flatpak_and_apps() {
    if [[ "$INSTALL_MODE" != "full" ]]; then
        info "Skipping Flatpak applications (Essential mode selected)."
        return
    fi

    info "Installing Flatpak and setting up Flathub..."
    install_pkgs flatpak
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    info "Installing applications via Flatpak..."
    sudo flatpak install -y --noninteractive flathub "${FLATPAK_APPS[@]}"
    success "Flatpak applications installed."
    warning "Note on other apps: 'Twitter'/'X' does not have an official Linux client. Use the web version. 'zapzap' is likely WhatsApp; you can search for a client like 'whatsie' on the AUR or use a web wrapper."
}

setup_audio() {
    info "Setting up PipeWire audio service..."
    systemctl --user enable --now pipewire.socket
    systemctl --user enable --now pipewire-pulse.socket
    systemctl --user enable --now wireplumber.service
    success "PipeWire audio service enabled."
}

setup_bluetooth() {
    info "Enabling and starting Bluetooth service..."
    sudo systemctl enable --now bluetooth.service
    success "Bluetooth service has been enabled."
}

setup_network() {
    info "Setting up NetworkManager..."
    sudo systemctl enable --now NetworkManager.service
    success "NetworkManager service enabled and started."
}

setup_pywalfox() {
    info "Setting up Pywalfox for Librewolf..."
    if command -v pywalfox &> /dev/null; then
        local PYWALFOX_BIN=""
        
        # Search for the main.sh script
        # Search for the main.sh script
        # Try to find it in common locations
        PYWALFOX_BIN=$(find /usr/lib/python* /usr/local/lib/python* "$HOME/.local/lib/python*" -name "main.sh" 2>/dev/null | grep "pywalfox/bin/main.sh" | head -n 1)

        if [ -z "$PYWALFOX_BIN" ] && [ -e "$HOME/.local/bin/pywalfox" ]; then
             # Try to resolve symlink or find relative main.sh if strictly needed, 
             # but usually we need the actual python script path for the manifest.
             # Let's search deeper.
             PYWALFOX_BIN=$(find "$HOME/.local" /usr/lib /usr/local/lib -type f -path "*/pywalfox/bin/main.sh" 2>/dev/null | head -n 1)
        fi

        if [ -z "$PYWALFOX_BIN" ]; then
             # Fallback search
             PYWALFOX_BIN=$(find "$HOME/.local" /usr/lib /usr/local/lib -type f -path "*/pywalfox/bin/main.sh" 2>/dev/null | head -n 1)
        fi

        if [ -n "$PYWALFOX_BIN" ]; then
            info "Found Pywalfox daemon at: $PYWALFOX_BIN"
            info "Fixing permissions..."
            sudo chmod +x "$PYWALFOX_BIN"

            # Manually install the manifest to avoid 'operation not permitted' errors from the tool itself
            local MANIFEST_CONTENT='{
  "name": "pywalfox",
  "description": "Pywalfox",
  "path": "'"$PYWALFOX_BIN"'",
  "type": "stdio",
  "allowed_extensions": [ "pywalfox@frewacom.org" ]
}'
            
            # Install for Librewolf
            local LIBREWOLF_DIR="$HOME/.librewolf/native-messaging-hosts"
            mkdir -p "$LIBREWOLF_DIR"
            echo "$MANIFEST_CONTENT" > "$LIBREWOLF_DIR/pywalfox.json"
            info "Installed Pywalfox manifest for Librewolf."

            # Install for Firefox (Mozilla)
            local MOZILLA_DIR="$HOME/.mozilla/native-messaging-hosts"
            mkdir -p "$MOZILLA_DIR"
            echo "$MANIFEST_CONTENT" > "$MOZILLA_DIR/pywalfox.json"
            info "Installed Pywalfox manifest for Firefox."

            success "Pywalfox native messaging host configured manually."
        else
            warning "Could not locate 'main.sh' for Pywalfox. Attempting standard install..."
            pywalfox install
        fi
    else
        warning "pywalfox command not found. Skipping setup."
    fi
}

copy_configs() {
    info "Copying configuration files to their final destination..."

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

setup_pywal() {
    info "Setting initial color scheme with Pywal..."
    local wallpaper_dir="$HOME/Pictures/Wallpapers"
    local default_wallpaper="$wallpaper_dir/10. Animated.gif"

    if [ -f "$default_wallpaper" ]; then
        info "Found default wallpaper: $default_wallpaper"
        # The -a flag sets the alpha transparency for the terminal
        wal -i "$default_wallpaper" -a 85
        success "Pywal color scheme generated."
        
        # --- NEW: Generate and Apply GTK Theme & Icons ---
        info "Generating and applying Pywal GTK Theme..."
        
        # 1. Generate the theme using our script
        if [ -x "$HOME/.local/bin/generate-pywal-gtk-theme" ]; then
            "$HOME/.local/bin/generate-pywal-gtk-theme"
        else
            warning "generate-pywal-gtk-theme script not found or not executable."
        fi
        
        local GTK_THEME="PywalSync-Mono"
        local ICON_THEME="Tela-circle"

        # 2. Apply via gsettings (GNOME/GTK4)
        if command -v gsettings &> /dev/null; then
            gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME"
            gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME"
            success "Applied GTK theme ($GTK_THEME) and Icons ($ICON_THEME) via gsettings."
        fi

        # 3. Update gtk-3.0 settings.ini (GTK3 apps & nwg-look)
        local gtk3_settings="$HOME/.config/gtk-3.0/settings.ini"
        mkdir -p "$(dirname "$gtk3_settings")"
        if [ ! -f "$gtk3_settings" ]; then
            echo -e "[Settings]\ngtk-theme-name=$GTK_THEME\ngtk-icon-theme-name=$ICON_THEME" > "$gtk3_settings"
        else
            # Update GTK Theme
            if grep -q "gtk-theme-name" "$gtk3_settings"; then
                sed -i "s/gtk-theme-name=.*/gtk-theme-name=$GTK_THEME/" "$gtk3_settings"
            else
                sed -i "/\[Settings\]/a gtk-theme-name=$GTK_THEME" "$gtk3_settings"
            fi
            # Update Icon Theme
            if grep -q "gtk-icon-theme-name" "$gtk3_settings"; then
                sed -i "s/gtk-icon-theme-name=.*/gtk-icon-theme-name=$ICON_THEME/" "$gtk3_settings"
            else
                sed -i "/\[Settings\]/a gtk-icon-theme-name=$ICON_THEME" "$gtk3_settings"
            fi
        fi
        success "Updated $gtk3_settings"

        # 4. Update .gtkrc-2.0 (Legacy GTK2 apps)
        local gtk2_rc="$HOME/.gtkrc-2.0"
        touch "$gtk2_rc"
        # Update GTK Theme
        if grep -q "gtk-theme-name" "$gtk2_rc"; then
            sed -i "s/gtk-theme-name=.*/gtk-theme-name=\"$GTK_THEME\"/" "$gtk2_rc"
        else
            echo "gtk-theme-name=\"$GTK_THEME\"" >> "$gtk2_rc"
        fi
        # Update Icon Theme
        if grep -q "gtk-icon-theme-name" "$gtk2_rc"; then
            sed -i "s/gtk-icon-theme-name=.*/gtk-icon-theme-name=\"$ICON_THEME\"/" "$gtk2_rc"
        else
            echo "gtk-icon-theme-name=\"$ICON_THEME\"" >> "$gtk2_rc"
        fi
        success "Updated $gtk2_rc"

    else
        warning "Default wallpaper not found at $default_wallpaper."
        warning "Skipping initial Pywal setup. Please run 'wal' manually."
    fi
}




setup_sddm() {
    info "Ensuring SDDM is installed and configuring theme..."
    if [ "$DISTRO" == "arch" ]; then
        install_pkgs sddm qt6-5compat qt6-declarative qt6-svg qt6-virtualkeyboard
    elif [ "$DISTRO" == "ubuntu" ]; then
        install_pkgs sddm qml-module-qtquick-layouts qml-module-qtquick-controls2 qml-module-qtquick-window2
        # Ubuntu might need more specific qt6 packages if the theme uses qt6, 
        # but sddm in ubuntu repos might still be qt5 based or have different deps.
        # We install basic sddm.
    fi

    # Copy the SDDM theme
    info "Copying SDDM theme..."
    if [ -d "$DOTFILES_DIR/sddm/themes/sddm-astronaut-theme" ]; then
        sudo cp -r "$DOTFILES_DIR/sddm/themes/sddm-astronaut-theme" "/usr/share/sddm/themes/"
        
        # Ensure the default wallpaper is present in the theme
        local default_wallpaper="$DOTFILES_DIR/Pictures/Wallpapers/10. Animated.gif"
        if [ -f "$default_wallpaper" ]; then
             sudo mkdir -p "/usr/share/sddm/themes/sddm-astronaut-theme/Backgrounds/"
             sudo cp "$default_wallpaper" "/usr/share/sddm/themes/sddm-astronaut-theme/Backgrounds/"
             success "Default wallpaper copied to SDDM theme."
        fi

        success "SDDM astronaut theme copied to /usr/share/sddm/themes/."
    else
        warning "SDDM astronaut theme not found in repository at $DOTFILES_DIR/sddm/themes/. Skipping theme setup."
        return
    fi

    # Copy the SDDM configuration
    info "Copying SDDM configuration..."
    if [ -f "$DOTFILES_DIR/config/sddm.conf.d/theme.conf" ]; then
        sudo mkdir -p "/etc/sddm.conf.d"
        sudo cp "$DOTFILES_DIR/config/sddm.conf.d/theme.conf" "/etc/sddm.conf.d/"
        success "SDDM configuration copied."
    else
        warning "SDDM theme configuration not found at $DOTFILES_DIR/config/sddm.conf.d/theme.conf. Skipping theme configuration."
        # If the theme config is missing, a default one should be generated or instruct the user.
        # For now, let's assume the user will handle it manually if the dotfile is missing.
    fi

    if ! command -v sddm &> /dev/null; then
        error "SDDM was not found after installation. Cannot enable service."
        return 1
    fi

    sudo systemctl enable --now sddm.service
    success "SDDM service enabled, configured with the astronaut theme, and started."
}


setup_sddm_sudoers() {
    info "Configuring sudoers for SDDM wallpaper sync..."
    local SUDOERS_FILE="/etc/sudoers.d/sddm-wallpaper-sync"
    local USER_NAME=$(whoami)
    
    # Paths to allow
    local SCRIPT_1="/usr/share/sddm/themes/sddm-astronaut-theme/pywal-sync.sh"
    local SCRIPT_2="/home/$USER_NAME/.local/bin/sync-sddm-wallpaper"
    
    # Create temporary file content
    # We use a temporary file to validate syntax if possible, but here we just write it.
    # Note: We use tee to write to /etc/sudoers.d/ which requires root.
    
    echo "$USER_NAME ALL=(ALL) NOPASSWD: $SCRIPT_1, $SCRIPT_2" | sudo tee "$SUDOERS_FILE" > /dev/null
    
    # Set correct permissions
    sudo chmod 0440 "$SUDOERS_FILE"
    
    success "Sudoers configured for SDDM sync."
}



final_setup() {
    success "✅ Installation complete!"
    echo ""
    info "--- NEXT STEPS ---"
    warning "1. A REBOOT is highly recommended for all changes to take effect."
    warning "2. Run Pywal to generate your initial color scheme. Find a wallpaper you like and run:"
    echo "   wal -i /path/to/your/wallpaper.jpg"
    warning "3. After rebooting, SDDM should start with the astronaut theme."
    warning "4. For Pywalfox to work, you need to install the addon in Librewolf from the Firefox addon store."
    echo ""
}

# --- Main Execution ---
main() {
    detect_os
    update_repos
    init_submodules
    install_aur_helper
    detect_gpu_and_install_drivers
    detect_and_install_asus_tools
    install_packages
    install_flatpak_and_apps
    setup_audio
    setup_network
    setup_bluetooth
    setup_pywalfox
    copy_configs
    setup_pywal
    setup_sddm
    setup_sddm_sudoers
    final_setup
}

# Run the script
main