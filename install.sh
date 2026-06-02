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
        gum spin --spinner dot --title "Deploying yay..." -- sleep 2
        git clone https://aur.archlinux.org/yay.git /tmp/yay > /dev/null 2>&1
        cd /tmp/yay && makepkg -si --noconfirm > /dev/null 2>&1
        cd "$DOTFILES_DIR"
        success "yay helper initialized."
    fi
}

step_software() {
    section "CORE SYSTEM DEPLOYMENT"
    
    CORE_PKGS="hyprland sddm hypridle hyprlock hyprpicker xdg-desktop-portal-hyprland waybar rofi kitty networkmanager network-manager-applet bluez bluez-utils pipewire pipewire-pulse wireplumber pavucontrol playerctl pamixer brightnessctl gvfs polkit-kde-agent swappy grim slurp nwg-look bibata-cursor-theme tela-circle-icon-theme-all otf-font-awesome ttf-jetbrains-mono-nerd flatpak python-pywal awww stow qt5-graphicaleffects qt5-quickcontrols2 qt5-svg qt5-declarative curl unzip zsh-autosuggestions zsh-syntax-highlighting ulauncher nwg-displays wl-clipboard xdg-utils jq bc quickshell-git imagemagick htop fastfetch bluez-obex gwenview"
    
    info "Installing system core..."
    yay -S --needed --noconfirm $CORE_PKGS

    section "CUSTOM MODULE DEPLOYMENT"
    
    # 1. GRAPHICS & DRIVERS
    SELECTED_DRIVERS=$(gum choose --no-limit --header "󰒲 GRAPHICS DRIVERS (Select your hardware)" \
        "NVIDIA Proprietary" \
        "NVIDIA Open-Source (DKMS)" \
        "AMD Open-Source (Mesa)" \
        "Intel Graphics" \
        "ASUS Laptop Tools" \
        "Surface Laptop Tools")

    # 2. INTERNET & BROWSERS
    SELECTED_BROWSERS=$(gum choose --no-limit --header "󰖟 WEB BROWSERS" \
        "Brave Browser" \
        "Firefox (Developer Edition)" \
        "Google Chrome" \
        "Microsoft Edge" \
        "Zen Browser")

    # 3. PRODUCTIVITY & DEV
    SELECTED_PROD=$(gum choose --no-limit --header "󰈙 PRODUCTIVITY & DEVELOPMENT" \
        "VS Code" \
        "Obsidian" \
        "Telegram" \
        "Discord (Vesktop)" \
        "Slack" \
        "Docker & Compose" \
        "Node.js & NPM" \
        "Python Suite")

    # 4. MEDIA & GAMING
    SELECTED_MEDIA=$(gum choose --no-limit --header "󰝚 MEDIA & GAMING" \
        "Steam" \
        "Lutris" \
        "OBS Studio" \
        "VLC Media Player" \
        "Spotify" \
        "GIMP" \
        "Inkscape")

    # 5. FILE MANAGERS & UTILS
    SELECTED_UTILS=$(gum choose --no-limit --header "󰀶 SYSTEM UTILITIES" \
        "Thunar (XFCE)" \
        "Dolphin (KDE)" \
        "Ranger (CLI)" \
        "Btop" \
        "Timeshift" \
        "Flatpaks (Pack List)")

    EXTRA_PKGS=""
    
    # Process Drivers
    [[ $SELECTED_DRIVERS == *"NVIDIA Proprietary"* ]] && EXTRA_PKGS="$EXTRA_PKGS nvidia nvidia-settings nvidia-utils"
    [[ $SELECTED_DRIVERS == *"NVIDIA Open-Source (DKMS)"* ]] && EXTRA_PKGS="$EXTRA_PKGS nvidia-open-dkms nvidia-settings nvidia-utils"
    [[ $SELECTED_DRIVERS == *"AMD Open-Source (Mesa)"* ]] && EXTRA_PKGS="$EXTRA_PKGS lib32-mesa vulkan-radeon lib32-vulkan-radeon mesa-utils"
    [[ $SELECTED_DRIVERS == *"Intel Graphics"* ]] && EXTRA_PKGS="$EXTRA_PKGS intel-media-driver libva-intel-driver vulkan-intel"
    [[ $SELECTED_DRIVERS == *"ASUS Laptop Tools"* ]] && EXTRA_PKGS="$EXTRA_PKGS asusctl supergfxctl rog-control-center"
    [[ $SELECTED_DRIVERS == *"Surface Laptop Tools"* ]] && EXTRA_PKGS="$EXTRA_PKGS linux-surface linux-surface-headers surface-control"

    # Process Browsers
    [[ $SELECTED_BROWSERS == *"Brave Browser"* ]] && EXTRA_PKGS="$EXTRA_PKGS brave-bin"
    [[ $SELECTED_BROWSERS == *"Firefox (Developer Edition)"* ]] && EXTRA_PKGS="$EXTRA_PKGS firefox-developer-edition"
    [[ $SELECTED_BROWSERS == *"Google Chrome"* ]] && EXTRA_PKGS="$EXTRA_PKGS google-chrome"
    [[ $SELECTED_BROWSERS == *"Microsoft Edge"* ]] && EXTRA_PKGS="$EXTRA_PKGS microsoft-edge-stable-bin"
    [[ $SELECTED_BROWSERS == *"Zen Browser"* ]] && EXTRA_PKGS="$EXTRA_PKGS zen-browser-bin"

    # Process Productivity
    [[ $SELECTED_PROD == *"VS Code"* ]] && EXTRA_PKGS="$EXTRA_PKGS code"
    [[ $SELECTED_PROD == *"Obsidian"* ]] && EXTRA_PKGS="$EXTRA_PKGS obsidian"
    [[ $SELECTED_PROD == *"Telegram"* ]] && EXTRA_PKGS="$EXTRA_PKGS telegram-desktop"
    [[ $SELECTED_PROD == *"Discord (Vesktop)"* ]] && EXTRA_PKGS="$EXTRA_PKGS vesktop"
    [[ $SELECTED_PROD == *"Slack"* ]] && EXTRA_PKGS="$EXTRA_PKGS slack-desktop"
    [[ $SELECTED_PROD == *"Docker & Compose"* ]] && EXTRA_PKGS="$EXTRA_PKGS docker docker-compose"
    [[ $SELECTED_PROD == *"Node.js & NPM"* ]] && EXTRA_PKGS="$EXTRA_PKGS nodejs npm"
    [[ $SELECTED_PROD == *"Python Suite"* ]] && EXTRA_PKGS="$EXTRA_PKGS python-pip python-black ruff"

    # Process Media
    [[ $SELECTED_MEDIA == *"Steam"* ]] && EXTRA_PKGS="$EXTRA_PKGS steam"
    [[ $SELECTED_MEDIA == *"Lutris"* ]] && EXTRA_PKGS="$EXTRA_PKGS lutris"
    [[ $SELECTED_MEDIA == *"OBS Studio"* ]] && EXTRA_PKGS="$EXTRA_PKGS obs-studio"
    [[ $SELECTED_MEDIA == *"VLC Media Player"* ]] && EXTRA_PKGS="$EXTRA_PKGS vlc"
    [[ $SELECTED_MEDIA == *"Spotify"* ]] && EXTRA_PKGS="$EXTRA_PKGS spotify"
    [[ $SELECTED_MEDIA == *"GIMP"* ]] && EXTRA_PKGS="$EXTRA_PKGS gimp"
    [[ $SELECTED_MEDIA == *"Inkscape"* ]] && EXTRA_PKGS="$EXTRA_PKGS inkscape"

    # Process Utils
    [[ $SELECTED_UTILS == *"Thunar (XFCE)"* ]] && EXTRA_PKGS="$EXTRA_PKGS thunar thunar-archive-plugin thunar-volman"
    [[ $SELECTED_UTILS == *"Dolphin (KDE)"* ]] && EXTRA_PKGS="$EXTRA_PKGS dolphin ark kio-gdrive"
    [[ $SELECTED_UTILS == *"Ranger (CLI)"* ]] && EXTRA_PKGS="$EXTRA_PKGS ranger libcaca highlight atool"
    [[ $SELECTED_UTILS == *"Btop"* ]] && EXTRA_PKGS="$EXTRA_PKGS btop"
    [[ $SELECTED_UTILS == *"Timeshift"* ]] && EXTRA_PKGS="$EXTRA_PKGS timeshift"

    if [ ! -z "$EXTRA_PKGS" ]; then
        info "Deploying selected modules..."
        yay -S --needed --noconfirm $EXTRA_PKGS
    fi

    if [[ $SELECTED_UTILS == *"Flatpaks (Pack List)"* ]]; then
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
    if gum confirm "Copy configuration files to system (Physical Copy)?"; then
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
            
            cp "$DOTFILES_DIR/.local/bin/$file" "$target"
            chmod +x "$target"
        done
        echo "  COPY: bin contents => ~/.local/bin/"

        # 3. Handle other packages (zsh, bash, gtk) that go into $HOME
        for pkg in zsh bash gtk; do
            if [ -d "$pkg" ]; then
                find "$pkg" -maxdepth 1 -name ".*" | while read -r file; do
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
    
    if gum confirm "Set Zsh as your default shell?"; then
        [ "$SHELL" != "$(which zsh)" ] && sudo chsh -s "$(which zsh)" "$USER"
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
gum style --foreground "$CLR_NEON_GREEN" --bold "System successfully reconfigured. Pulse check passed. Launching UI..."

# Start graphical environment automatically
sudo systemctl start sddm
