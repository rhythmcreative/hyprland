#!/bin/bash

# --- Rhythm Arch Hyprland Installer v3 (Neon Cyberpunk) ---

# Colors & Aesthetic
CLR_NEON_GREEN="#50FA7B"
CLR_NEON_PURPLE="#BD93F9"
CLR_CYAN="#8BE9FD"
CLR_RED="#FF5555"
CLR_BG="#282A36"

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# --- INITIAL SETUP ---
if [ "$EUID" -eq 0 ]; then
    gum style --foreground "$CLR_RED" --bold " [ERROR] Do not run this script as root."
    exit 1
fi

# Ensure gum is installed
if ! command -v gum > /dev/null; then
    sudo pacman -S --needed --noconfirm gum git base-devel stow zsh curl > /dev/null 2>&1
fi

# --- UI COMPONENTS ---

print_banner() {
    clear
    # Original ASCII Art with Neon Purple
    echo -e "\033[38;2;189;147;249m"
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
    echo -e "\033[0m"
    
    gum style \
        --foreground "$CLR_NEON_GREEN" \
        --border-foreground "$CLR_NEON_PURPLE" \
        --border rounded \
        --align center --width 100 --margin "1 0" \
        "HYPER-INSTALADOR v3.0 | SYSTEM DEPLOYMENT INITIATED"
}

section() {
    echo ""
    gum style \
        --background "$CLR_NEON_PURPLE" --foreground "$CLR_BG" \
        --bold --padding "0 2" --margin "1 0" \
        " SECTION: $1 "
}

info() {
    gum style --foreground "$CLR_CYAN" "  [SYSTEM] $1"
}

success() {
    gum style --foreground "$CLR_NEON_GREEN" "  [DONE] $1"
}

# --- LOGIC ---

install_yay() {
    if ! command -v yay > /dev/null; then
        section "DEPENDENCY: AUR HELPER"
        gum spin --spinner dots --title "Deploying yay..." -- sleep 2
        git clone https://aur.archlinux.org/yay.git /tmp/yay > /dev/null 2>&1
        cd /tmp/yay && makepkg -si --noconfirm > /dev/null 2>&1
        cd "$DOTFILES_DIR"
        success "yay helper initialized."
    fi
}

step_software() {
    section "CORE SYSTEM DEPLOYMENT"
    
    CORE_PKGS="hyprland sddm hypridle hyprlock hyprpicker xdg-desktop-portal-hyprland waybar rofi kitty networkmanager network-manager-applet bluez bluez-utils pipewire pipewire-pulse wireplumber pavucontrol playerctl pamixer brightnessctl gvfs polkit-kde-agent swappy grim slurp nwg-look bibata-cursor-theme tela-circle-icon-theme-all otf-font-awesome ttf-jetbrains-mono-nerd flatpak python-pywal swww stow qt5-graphicaleffects qt5-quickcontrols2 qt5-svg qt5-declarative curl unzip"
    
    info "Installing base aesthetics and environment..."
    yay -S --needed --noconfirm $CORE_PKGS

    section "MODULE SELECTION"
    SELECTED_SW=$(gum choose --no-limit --header "Select sub-modules to install (SPACE to mark)" \
        "NVIDIA Drivers" \
        "ASUS ROG/TUF Tools" \
        "Brave Browser" \
        "Vesktop (Discord)" \
        "Telegram Desktop" \
        "Visual Studio Code" \
        "Obsidian" \
        "OBS Studio" \
        "Steam" \
        "Thunar" \
        "Dolphin" \
        "Flatpaks")

    EXTRA_PKGS=""
    [[ $SELECTED_SW == *"NVIDIA Drivers"* ]] && EXTRA_PKGS="$EXTRA_PKGS nvidia-open-dkms nvidia-settings nvidia-utils"
    [[ $SELECTED_SW == *"ASUS ROG/TUF Tools"* ]] && EXTRA_PKGS="$EXTRA_PKGS asusctl supergfxctl rog-control-center"
    [[ $SELECTED_SW == *"Brave Browser"* ]] && EXTRA_PKGS="$EXTRA_PKGS brave-origin-nightly-bin"
    [[ $SELECTED_SW == *"Vesktop"* ]] && EXTRA_PKGS="$EXTRA_PKGS vesktop"
    [[ $SELECTED_SW == *"Telegram Desktop"* ]] && EXTRA_PKGS="$EXTRA_PKGS telegram-desktop"
    [[ $SELECTED_SW == *"Visual Studio Code"* ]] && EXTRA_PKGS="$EXTRA_PKGS code"
    [[ $SELECTED_SW == *"Obsidian"* ]] && EXTRA_PKGS="$EXTRA_PKGS obsidian"
    [[ $SELECTED_SW == *"OBS Studio"* ]] && EXTRA_PKGS="$EXTRA_PKGS obs-studio"
    [[ $SELECTED_SW == *"Thunar"* ]] && EXTRA_PKGS="$EXTRA_PKGS thunar"
    [[ $SELECTED_SW == *"Dolphin"* ]] && EXTRA_PKGS="$EXTRA_PKGS dolphin"

    if [[ $SELECTED_SW == *"Steam"* ]]; then
        if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
            info "Enabling multilib..."
            sudo sed -i '/^#\[multilib\]/,+1 s/^#//' /etc/pacman.conf
            sudo pacman -Sy > /dev/null 2>&1
        fi
        EXTRA_PKGS="$EXTRA_PKGS steam"
    fi

    if [ ! -z "$EXTRA_PKGS" ]; then
        info "Deploying selected modules..."
        yay -S --needed --noconfirm $EXTRA_PKGS
    fi

    if [[ $SELECTED_SW == *"Flatpaks"* ]]; then
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
    if gum confirm "Synchronize local configuration files?"; then
        mkdir -p ~/.config ~/.local/bin
        stow -v -R -t ~ .config .local zsh bash gtk
        success "Local configs linked."
    fi
}

step_wallpapers() {
    section "NEURAL WALLPAPER PACKS"
    if gum confirm "Download custom wallpaper assets?"; then
        WALL_DIR="$HOME/Pictures/Wallpapers"
        mkdir -p "$WALL_DIR"
        TEMP_WALL="/tmp/wallpaper_install"
        mkdir -p "$TEMP_WALL"
        
        REPO_URL="https://raw.githubusercontent.com/rhythmcreative/wallpapers/main"
        
        CHOICE=$(gum choose --header "Select download protocol" \
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
            PACKS=$(gum input --placeholder "Numbers separated by space (e.g., 1 5 40)")
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
    
    if gum confirm "Initialize Zsh with Oh-My-Zsh?"; then
        [ "$SHELL" != "$(which zsh)" ] && sudo chsh -s "$(which zsh)" "$USER"
        if [ ! -d "$HOME/.oh-my-zsh" ]; then
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended > /dev/null 2>&1
        fi
    fi

    if gum confirm "Enable core services (Net/BT/Login)?"; then
        sudo systemctl enable NetworkManager bluetooth sddm
        
        if [ -d "$DOTFILES_DIR/sddm/sddm-astronaut-theme" ]; then
            sudo mkdir -p /usr/share/sddm/themes
            sudo cp -r "$DOTFILES_DIR/sddm/sddm-astronaut-theme" /usr/share/sddm/themes/
            sudo mkdir -p /etc/sddm.conf.d
            echo -e "[Theme]\nCurrent=sddm-astronaut-theme" | sudo tee /etc/sddm.conf.d/theme.conf > /dev/null
        fi
        success "Services operational."
    fi

    sudo usermod -aG video,input,render,wheel $USER
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
    gum spin --spinner moon --title "CALIBRATING COLORS..." -- bash "$HOME/.local/bin/modern-pywal-sync"
fi

section "DEPLOYMENT COMPLETE"
gum style --foreground "$CLR_NEON_GREEN" --bold "System successfully reconfigured. Pulse check passed."

if gum confirm "Execute graphical environment now (Start SDDM)?"; then
    sudo systemctl start sddm
else
    echo "Manual reboot required."
fi
