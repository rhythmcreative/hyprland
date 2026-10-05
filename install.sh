#!/bin/bash

# --- Rhythm Hyprland Installer (Omarchy Style Presentation) ---
# Automated, modular, and resilient deployment for Arch Linux & Hyprland.
# NixOS does not use this script: it deploys the same desktop through
# flake.nix (the preflight below detects it and points there).

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

# NixOS does not use the Arch steps below at all. Instead of stopping with
# directions, this same command installs the desktop only: it auto-detects
# user and GPU, writes a standalone home-manager flake under
# ~/.config/home-manager, and activates it. No questions, no system rebuild,
# no sudo, no /etc writes. Override the guesses with RHYTHM_USER/RHYTHM_GPU.
if [ -f /etc/NIXOS ] || { [ -f /etc/os-release ] && grep -q '^ID=nixos' /etc/os-release; }; then
    install_nixos() {
        [ "$(id -u)" -eq 0 ] && { echo "ERROR: run as your user, not root."; exit 1; }
        # No sudo needed: desktop-only install, everything is user-owned.

        # git comes with NixOS most of the time; otherwise fetch it through
        # nix itself so this stays a one-command install.
        if ! command -v git >/dev/null 2>&1; then
            echo "Installing git through nix..."
            NIX_CONFIG="experimental-features = nix-command flakes" \
                nix --extra-experimental-features "nix-command flakes" \
                profile install nixpkgs#git 2>/dev/null || {
                    echo "ERROR: could not get git. Install it and retry."; exit 1; }
            export PATH="$HOME/.nix-profile/bin:$PATH"
        fi

        # Flakes for this session. /etc/nix/nix.conf is off-limits: on NixOS
        # it is often a read-only store symlink, so appending fails with
        # "Read-only file system". Persistence comes from nix.settings in
        # the generated flake below, applied by the rebuild.
        export NIX_CONFIG="experimental-features = nix-command flakes"

        local repo="$HOME/hyprland"
        if [ ! -d "$repo/.git" ]; then
            echo "Cloning the desktop into $repo..."
            git clone --depth=1 https://github.com/rhythmcreative/hyprland.git "$repo" || exit 1
        else
            echo "Using existing checkout at $repo."
        fi

        # Desktop only: standalone home-manager, no system rebuild.
        # No sudo, no /etc writes, no bootloader changes: the same modules
        # as homes/rhythm/home.nix, activated for this user only.
        # Fully non-interactive: values are auto-detected, override with
        # RHYTHM_USER / RHYTHM_GPU in the rare case the guess is wrong.
        local user="${RHYTHM_USER:-$USER}" guess_gpu="${RHYTHM_GPU:-auto}" rel hm_dir
        rel=$(grep -oP '^VERSION_ID="\K[^"]+' /etc/os-release 2>/dev/null || echo "25.11")
        if [ "$guess_gpu" = "auto" ]; then
            for dev in /sys/bus/pci/devices/*; do
                [ "$(cat "$dev/class" 2>/dev/null)" = "0x030000" ] || [ "$(cat "$dev/class" 2>/dev/null)" = "0x030200" ] || continue
                case "$(cat "$dev/vendor" 2>/dev/null)" in
                    0x10de) guess_gpu="nvidia" ;;
                    0x1002) [ "$guess_gpu" = "auto" ] && guess_gpu="amd" ;;
                    0x8086) [ "$guess_gpu" = "auto" ] && guess_gpu="intel" ;;
                esac
            done
        fi
        echo "Installing desktop for user=$user gpu=$guess_gpu"
        [ "$guess_gpu" = "nvidia" ] && echo "NOTE: NVIDIA needs unfree. If the build refuses, add nixpkgs.config.allowUnfree = true; to $HOME/.config/home-manager/flake.nix."

        # A home-manager consumer flake of this repo (main): self-contained,
        # survives even if ~/hyprland is deleted later.
        hm_dir="$HOME/.config/home-manager"
        if [ -e "$hm_dir/flake.nix" ] || [ -e "$hm_dir/home.nix" ]; then
            local stamp
            stamp=$(date +%Y%m%d-%H%M%S)
            mkdir -p "$HOME/.config/home-manager.bak-$stamp"
            cp -rf "$hm_dir/flake.nix" "$hm_dir/flake.lock" "$hm_dir/home.nix" \
                "$HOME/.config/home-manager.bak-$stamp/" 2>/dev/null || true
            echo "Previous home-manager config backed up to ~/.config/home-manager.bak-$stamp."
        fi
        mkdir -p "$hm_dir"
        cat > "$hm_dir/flake.nix" << EOF2
{
  description = "Rhythm Hyprland desktop (standalone home-manager)";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland = {
      url = "github:rhythmcreative/hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { nixpkgs, home-manager, hyprland, ... }: {
    homeConfigurations."$user" = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ hyprland.overlays.default ];
      };
      modules = [
        hyprland.homeManagerModules.rhythm-hyprland
        {
          home.username = "$user";
          home.homeDirectory = "/home/$user";
          home.stateVersion = "$rel";
          # No dconf bus service exists in a standalone install (on NixOS
          # only programs.dconf.enable provides it, system-wide), so the
          # dconfSettings activation step would die with ServiceUnknown.
          # Theme/font/cursor still land via GTK settings.ini; re-enable
          # this if you ever add programs.dconf to your system config.
          dconf.enable = false;
          rhythm = {
            enable = true;
            username = "$user";
            gpu = "$guess_gpu";
          };
        }
      ];
    };
  };
}
EOF2

        echo "Activating the desktop (downloads several GB the first time)..."
        # Always track this repo's latest main. nix reuses flake.lock
        # silently: without this, a lock from a previous run keeps building
        # the old modules forever (e.g. fixes never arrive). Only our own
        # input moves; nixpkgs/home-manager stay pinned by the lock.
        nix --extra-experimental-features "nix-command flakes" flake lock \
            --update-input hyprland "$hm_dir" || exit 1
        # Activation talks to systemd --user over the user bus. Two traps:
        # 1. Under 'su'/'sudo -i' there is no user manager at all.
        # 2. Worse, the chain inherits root's XDG_RUNTIME_DIR=/run/user/0,
        #    so the bus looks reachable but belongs to root: activation
        #    then dies with cryptic GDBus ServiceUnknown. Drop foreign
        #    runtime dirs before doing anything.
        if [ -n "${XDG_RUNTIME_DIR:-}" ] \
            && [ "$(stat -c %u "$XDG_RUNTIME_DIR" 2>/dev/null || echo none)" != "$(id -u)" ]; then
            unset XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS
        fi
        if [ -z "${XDG_RUNTIME_DIR:-}" ] && [ -d "/run/user/$(id -u)" ]; then
            export XDG_RUNTIME_DIR="/run/user/$(id -u)"
        fi
        if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "${XDG_RUNTIME_DIR:-/nonexistent}/bus" ]; then
            export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
        fi
        if ! systemctl --user show-environment >/dev/null 2>&1 \
            || [ "${XDG_RUNTIME_DIR:-}" != "/run/user/$(id -u)" ]; then
            echo "ERROR: no user systemd/D-Bus session for $user."
            echo "Did you get here via 'su' or 'sudo -i'? That starts no user"
            echo "manager (or leaves you on root's bus). Log in directly"
            echo "(TTY or display manager) and retry; on headless boxes"
            echo "'loginctl enable-linger $user' (as root, once) plus a fresh"
            echo "login also works."
            exit 1
        fi
        local act
        act=$(nix --extra-experimental-features "nix-command flakes" build --no-link --print-out-paths \
            "$hm_dir#homeConfigurations.\"$user\".activationPackage") || exit 1
        # The activate script takes no backup flag (only --driver-version):
        # existing files are preserved via HOME_MANAGER_BACKUP_EXT instead.
        HOME_MANAGER_BACKUP_EXT=backup "$act/activate" || exit 1
        echo ""
        echo "Done. Log out, switch to a TTY (Ctrl+Alt+F2) and run Hyprland to enter the desktop."
    }
    install_nixos
    exit $?
fi

# If running outside the cloned repository (e.g. standalone curl pipe), clone first
if [ -z "$DOTFILES_DIR" ] || [ ! -f "$DOTFILES_DIR/logo.txt" ] || [ ! -d "$DOTFILES_DIR/.config" ]; then
    # mktemp -d y no una ruta fija en /tmp. Con "/tmp/rhythm-hyprland" cualquier
    # otro usuario de la maquina puede ganar la carrera de creacion del
    # directorio, quedarse con el y poner su propio install.sh, que despues se
    # ejecuta con `exec bash`. Ahora el directorio se reserva atomico y es 0700.
    CLONE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/rhythm-hyprland.XXXXXXXX")
    echo "Cloning rhythmcreative/hyprland repository to $CLONE_DIR..."
    if ! command -v git >/dev/null 2>&1; then
        echo "Installing git..."
        sudo pacman -S --needed --noconfirm git
    fi
    # clone necesita que el destino no exista, y mktemp ya lo ha creado.
    rmdir "$CLONE_DIR"
    git clone --depth=1 https://github.com/rhythmcreative/hyprland.git "$CLONE_DIR"
    if [ -e /dev/tty ]; then
        exec bash "$CLONE_DIR/install.sh" "$@" < /dev/tty
    else
        exec bash "$CLONE_DIR/install.sh" "$@"
    fi
fi

# El tema de cursor del login y las reglas de monitor del greeter viven en
# rhythm-sddm-deploy, que es el unico sitio que escribe esos ficheros de
# sistema. Aqui no se duplican: si estuvieran en los dos sitios, el installer
# pondria una cosa y el OTA otra.
#
# Lo que hay en /usr y /etc no lo sincroniza el OTA por su cuenta
# (rhythm-materialize solo va a ~/.config y ~/.local/bin), asi que ese mismo
# script lo llama tambien system-ota. Sin eso, una actualizacion dejaba el
# sddm.conf apuntando al start-hyprland de siempre y las piezas nuevas a medias,
# que es peor que no tenerlas.

# El log va a un mktemp y no a "/tmp/hyprland-install-$USER.log", que se puede
# adivinar de sobra. En esa ruta fija, otro usuario del equipo crea el fichero
# como enlace simbolico que apunte a ~/.bashrc o a lo que sea, y el ": >" de
# abajo lo deja en cero. Con mktemp no hay forma de saber el nombre de antes.
LOG_FILE=$(mktemp "/tmp/hyprland-install-${USER:-$(id -un)}.XXXXXX.log" 2>/dev/null || true)
if [ -z "$LOG_FILE" ] || ! touch "$LOG_FILE" 2>/dev/null; then
    mkdir -p "$HOME/.cache" 2>/dev/null || true
    LOG_FILE="$HOME/.cache/hyprland-install.log"
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
RESUME_MODE=false
# Marca de pasos completados, para poder reanudar una instalacion que se corto.
# Antes no existia: al volver a ejecutar el instalador empezaba otra vez desde el
# principio, y el sincronizador de dotfiles movia cada carpeta a .bak y ponia la
# del repo encima, con lo que una segunda ejecucion destruia el .bak bueno y
# cualquier cambio local que no estuviera en el repo.
STEP_MARKER="${XDG_CACHE_HOME:-$HOME/.cache}/rhythm-install.steps"

# Devuelve 0 si el paso ya se completo en una ejecucion anterior y estamos
# reanudando.
step_done() {
    [ "$RESUME_MODE" = true ] || return 1
    [ -f "$STEP_MARKER" ] || return 1
    grep -qxF "$1" "$STEP_MARKER" 2>/dev/null
}

# Anota un paso como completado.
mark_step() {
    mkdir -p "$(dirname "$STEP_MARKER")" 2>/dev/null || return 0
    grep -qxF "$1" "$STEP_MARKER" 2>/dev/null || printf '%s\n' "$1" >> "$STEP_MARKER"
}

# Envoltorio de un paso: si estamos reanudando y ya se hizo, se salta.
run_step() {
    local nombre="$1"; shift
    if step_done "$nombre"; then
        section "$nombre (skipped: already done)"
        return 0
    fi
    "$@"
    mark_step "$nombre"
}

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
  --resume                   Continue an interrupted install: steps already done
                             are skipped, and configs that are already identical
                             to the repo are left alone instead of being backed
                             up and overwritten
  -h, --help                 Show this help message and exit

One-line installation:
  bash -c "$(curl -fsSL --connect-timeout 10 --max-time 60 https://raw.githubusercontent.com/rhythmcreative/hyprland/main/install.sh)"

Examples:
  ./install.sh --update
  ./install.sh --resume
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
        --resume|resume)
            RESUME_MODE=true
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

    # Autenticar una vez aqui para que las ~45 llamadas a sudo que hay mas abajo
    # no pidan la contrasena una por una. El timestamp de sudo dura 15 minutos y
    # algunos bloques tardan mas (compilar kernel headers, instalar paquetes AUR),
    # asi que ademas se refresca antes de cada paso largo.
    if ! sudo -v; then
        echo "ERROR: Se necesita autenticacion de sudo para instalar paquetes."
        exit 1
    fi

    if [ ! -f /etc/arch-release ]; then
        # NixOS exits at the top of this script with directions to the flake.
        # Anything else landing here is a distro this installer knows nothing
        # about: no pacman, no AUR, no /usr layout to write to.
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
        # Directorio privado para el build de yay. Con /tmp/yay fijo, otro usuario
        # de la maquina puede crear ese directorio antes que nosotros, meter su
        # PKGBUILD y ejecutar lo que quiera en cuanto makepkg lo lee.
        local yay_dir
        yay_dir=$(mktemp -d "${TMPDIR:-/tmp}/yay-build.XXXXXXXX")
        git clone https://aur.archlinux.org/yay.git "$yay_dir" >> "$LOG_FILE" 2>&1
        # makepkg puede tardar mas de los 15 minutos del timestamp de sudo, y
        # al packagear llama a sudo por su cuenta. Refrescar aqui evita que
        # pida la contrasena a mitad del build.
        sudo -v
        (cd "$yay_dir" && makepkg -si --noconfirm) >> "$LOG_FILE" 2>&1
        rm -rf "$yay_dir"
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
            sudo -v
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
        # Directorio privado para el clone. Con "/tmp/rust-dock-build" fijo,
        # otro usuario de la maquina puede dejar ahí un Cargo.toml con codigo
        # suyo: el build compila lo que encuentre, y despues se instala como
        # ~/.local/bin/rust-dock, que se ejecuta en cada arranque.
        source_dir=$(mktemp -d "${TMPDIR:-/tmp}/rust-dock-build.XXXXXXXX")
        rmdir "$source_dir"   # git clone necesita que el destino no exista
        if git clone --depth=1 https://github.com/rhythmcreative/rust-dock.git "$source_dir" >> "$LOG_FILE" 2>&1; then
            temp_clone=true
        else
            step_warn "Could not clone rust-dock repository. Skipping build."
            rm -rf "$source_dir"
            return
        fi
    fi

    # Que el build se zampe su error con "|| true" era peor de lo que parece: si
    # fallaba, el codigo seguia al "if [ -f ... ]" y, como un binario de una
    # compilacion anterior seguia ahi, lo instalaba como si fuera el nuevo. Se
    # borra antes de compilar y se mira el resultado de verdad.
    rm -f "$source_dir/target/release/rust-dock" 2>/dev/null || true

    local build_ok=1
    gum spin --spinner dot --title "Compiling rust-dock (release)..." --padding "0 0 0 $PADDING_LEFT" -- \
        bash -c "cd '$source_dir' && cargo build --release >> '$LOG_FILE' 2>&1" || build_ok=0

    if [ "$build_ok" -ne 1 ] || [ ! -f "$source_dir/target/release/rust-dock" ]; then
        step_warn "rust-dock build failed. Inspect $LOG_FILE for details."
        # Nada se instala. Antes, un fallo de compilacion podia acabar
        # desplegando el binario de una version anterior.
        [ "$temp_clone" = true ] && rm -rf "$source_dir"
        return
    fi

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
        PACMAN_INSTALL=("brave-bin" "vesktop" "visual-studio-code-bin")
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
                --selected="Brave Browser (brave-bin) [AUR]" \
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
            "Random selection (50, FireWalls root + Best-Collection)" \
            "All FireWalls (root + Best-Collection, ~850 imgs)" \
            "Skip wallpaper download" || true)
        case "$WP_CHOICE" in
            *"All"*)              WALLPAPER_MODE="all" ;;
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

    # El monitors.conf se aparta antes de tocar nada y se vuelve a poner al final.
    # Antes solo se restauraba si no existia ya, y como el repo no lo trae, en una
    # reinstalacion se perdia el de nwg-displays: se movia entero a .bak y la
    # comprobacion de "si ya existe" se hacia despues de copiar, cuando el
    # fichero ya no estaba donde tocaba.
    #
    # Va a un mktemp y no a ~/.cache: es un temporal de esta sola ejecucion, y
    # ~/.cache/rhythm-install lo puede borrar cualquier limpieza automatica a
    # mitad de la instalacion, con lo que el monitors.conf se perderia sin
    # haber aviso. monitors.conf lo genera nwg-displays y rehacerlo a mano es
    # lo masmolesto de todo el setup.
    local saved_monitors=""
    if [ -f "$HOME/.config/hypr/monitors.conf" ]; then
        saved_monitors=$(mktemp "/tmp/rhythm-monitors.XXXXXX.conf") || saved_monitors=""
        if [ -n "$saved_monitors" ]; then
            cp -f "$HOME/.config/hypr/monitors.conf" "$saved_monitors"
        else
            step_warn "No se pudo apartar monitors.conf; se sobrescribira."
        fi
    fi

    step_item "Linking configurations into ~/.config/..."
    local synced=0 skipped=0 backed=0
    for item in .config/*; do
        [ -e "$item" ] || continue
        local name
        name=$(basename "$item")
        local target="$HOME/.config/$name"

        if [ -e "$target" ]; then
            # Si ya es identico a lo del repo, no se toca. Esto es lo que
            # hace que reanudar una instalacion cortada no destroce nada: la
            # mayoria ya estan desplegadas y son iguales.
            if diff -rq "$item" "$target" >/dev/null 2>&1; then
                skipped=$((skipped + 1))
                continue
            fi

            if [ "$REPLACE_CONFIGS_ALL" = true ]; then
                rm -rf "$target"
            else
                # El .bak anterior NO se borra. Se le añade la fecha, para que
                # al reanudar no se pierda el .bak de la instalacion
                # anterior: antes un "rm -rf .bak" hacia que en la segunda
                # ejecucion el .bak fuera una copia de los dotfiles, que no
                # sirve para deshacer nada.
                local stamp
                stamp=$(date +%Y%m%d-%H%M%S)
                if [ -e "$target.bak" ]; then
                    mv "$target" "$target.bak-$stamp"
                else
                    mv "$target" "$target.bak"
                fi
                backed=$((backed + 1))
            fi
        fi

        cp -r "$DOTFILES_DIR/.config/$name" "$target"
        synced=$((synced + 1))
    done
    step_ok "Config files synchronized ($synced deployed, $skipped already in place, $backed backed up)."

    # Restore the saved monitors.conf, if we had one
    if [ -n "$saved_monitors" ] && [ -f "$saved_monitors" ]; then
        cp -f "$saved_monitors" "$HOME/.config/hypr/monitors.conf"
        # Comprobar que ha llegado entero: si no, se ha perdido la configuracion
        # de monitores, que es lo mas caro de rehacer de todo el setup.
        if [ -s "$HOME/.config/hypr/monitors.conf" ]; then
            step_ok "Preserved existing monitors.conf."
        else
            step_warn "monitors.conf quedo vacio al restaurarlo; revisa nwg-displays."
        fi
        rm -f "$saved_monitors"
    elif [ -f "$HOME/.config/hypr.bak/monitors.conf" ] && [ ! -f "$HOME/.config/hypr/monitors.conf" ]; then
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

    # Stamp the installed version.
    #
    # Solo ota-updater escribia ~/.version, y solo al ACTUALIZAR. En una
    # instalacion limpia no existia, asi que rhythm caia al tercer candidato:
    # `git describe --tags --always`, que sin un tag alcanza devuelve un hash de
    # commit. El status de la OTA de unrecien instalado decia "e5169c6" en lugar de
    # una version, y `rhythm` no tenia forma de saber si habia algo que actualizar.
    #
    # Se escribe DESPUES de desplegar, y con el .version del repo. Si no esta, se
    # cae al tag mas alto, que es lo que hay que preferir si los dos no coinciden:
    # .version llega tarde al repo cuando se etiqueta una release, y en ese
    # intervalo el tag es el numero bueno.
    step_item "Stamping the installed version..."
    local stamped="" del_fichero="" del_tag=""
    if [ -f "$DOTFILES_DIR/.version" ]; then
        del_fichero=$(tr -d '[:space:]' < "$DOTFILES_DIR/.version")
    fi
    if [ -d "$DOTFILES_DIR/.git" ]; then
        del_tag=$(git -C "$DOTFILES_DIR" tag --list 'v*' 2>/dev/null | sed 's/^v//' | sort -V | tail -n1 || true)
    fi
    # Se queda con el MAYOR de los dos, no con el primero que aparezca. Medido:
    # con .version en 0.22 y el tag en v0.23,UDI en el orden de antes sellaba 0.22
    # y rhythm se creeia dos versiones por detras de donde estaba. El .version
    # llega tarde al repo cuando se etiqueta una release, y en ese intervalo el
    # tag es el numero bueno.
    stamped=$(printf '%s\n%s\n' "$del_fichero" "$del_tag" | grep -E '^[0-9]+(\.[0-9]+)*$' | sort -V | tail -n1 || true)
    if [ -n "$stamped" ]; then
        printf '%s\n' "$stamped" > "$HOME/.version"
        step_ok "Installed version stamped: $stamped"
    else
        step_warn "Could not determine the version; ~/.version not written."
    fi

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
        # Limpieza: elimina wallpapers antiguos para dejar solo FireWalls
        rm -rf "${WALL_DIR:?}/"* 2>/dev/null || true
        # Directorio privado y con nombre aleatorio, como el resto de temporales
        # del script. Con "/tmp/wallpaper_install" fijo, otro usuario del equipo
        # puede dejar ese directorio ya hecho y con "firewalls" apuntando donde
        # quiera, y el clone de abajo acaba escribiendo ahi dentro.
        local TEMP_WALL
        TEMP_WALL=$(mktemp -d "${TMPDIR:-/tmp}/wallpaper_install.XXXXXXXX") || TEMP_WALL="$HOME/.cache/wallpaper_install.$$"
        mkdir -p "$TEMP_WALL"
        
        local FW_REPO="https://github.com/deadduck-09/FireWalls.git"
        local FW_DIR="$TEMP_WALL/firewalls"

        local CHOICE="$MODE"
        if [ -z "$CHOICE" ]; then
            CHOICE=$(gum choose --header "Select download mode" \
                "All FireWalls (root + Best-Collection, ~850 imgs)" \
                "Random Selection (50, root + Best-Collection)" \
                "Skip")
        fi

        if [[ "$CHOICE" == *"All FireWalls"* || "$CHOICE" == "all" || "$CHOICE" == "Download All Wallpapers (~600MB)" ]]; then
            step_item "Cloning FireWalls collection (root + subcarpetas, ~850 imgs)..."
            rm -rf "$FW_DIR" || true
            if git clone --depth 1 --filter=blob:none --sparse "$FW_REPO" "$FW_DIR" >> "$LOG_FILE" 2>&1 \
                && (cd "$FW_DIR" && git sparse-checkout set Desktop/Wallpapers >> "$LOG_FILE" 2>&1); then
                if find "$FW_DIR/Desktop/Wallpapers" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) -print -quit 2>/dev/null | grep -q .; then
                    find "$FW_DIR/Desktop/Wallpapers" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) -exec cp {} "$WALL_DIR/" \; >> "$LOG_FILE" 2>&1 || step_warn "No se pudieron copiar wallpapers."
                else
                    step_warn "Coleccion clonada pero sin ficheros en Desktop/Wallpapers."
                fi
            else
                step_warn "No se pudo clonar la coleccion de wallpapers, se omite paso opcional."
            fi
        elif [[ "$CHOICE" == *"Random"* || "$CHOICE" == "random" ]]; then
            step_item "Downloading 50 random wallpapers (root + Best-Collection)..."
            local TREE_JSON
            TREE_JSON=$(curl -fsSL --connect-timeout 10 --max-time 60 "https://api.github.com/repos/deadduck-09/FireWalls/git/trees/main?recursive=1" 2>/dev/null || true)
            local URL_LIST=""
            if [ -n "$TREE_JSON" ] && command -v jq >/dev/null 2>&1; then
                # Cada ruta del arbol remoto se convierte en una URL, asi que se
                # filtra antes de construirla:
                #
                # - test(...) con ^\z ancla el final, no un grep suelto que
                #   aceptaria "x.jpg\nhttp://otro-sitio/x.jpg".
                # - El primer filtro de jq exige que la ruta no lleve salto de
                #   linea, que es lo que permitiria inyectar una URL distinta.
                #
                # Una ruta con un salto embebido no es una imagen valida de este
                # repo, asi que descartarla no pierde nada real.
                URL_LIST=$(echo "$TREE_JSON" | jq -r '
                    .tree[]?
                    | select(.type=="blob")
                    | .path
                    | select(test("^Desktop/Wallpapers/[^\\n]*$"))
                    | select(test("\\.(jpg|jpeg|png|webp|gif)$"; "i"))
                    | "https://raw.githubusercontent.com/deadduck-09/FireWalls/main/\(.)"
                ' 2>/dev/null || true)
            fi
            if [ -n "$URL_LIST" ]; then
                # En paralelo, no en serie. Antes era un `while read` con un
                # curl cada vez: 50 ficheros x ~1 s cada uno = casi un minuto
                # de reloj, casi todos en espera de red.
                #
                # La concurrencia va acotada a proposito (-P 6).Meterle 50 a la
                # vez no es mas rapido de forma utilizable: GitHub corta por
                # tasa y acabariaFallando mas descargas que las que ahorra,
                # y se pelea por el ancho de banda con el resto del instalador.
                local _wp_urls
                _wp_urls=$(echo "$URL_LIST" | shuf -n 50)
                local _wp_n
                _wp_n=$(echo "$_wp_urls" | grep -c . || true)

                step_item "Downloading $_wp_n wallpapers (6 in parallel)..."
                export WALL_DIR LOG_FILE
                # -P 6 en paralelo, -I {} una linea por invocacion, y el cuerpo
                # va en un `sh -c` para que xargs lo ejecute en un subshell con
                # las variables del entorno ya exportadas.
                printf '%s\n' "$_wp_urls" | grep . | xargs -P 6 -I {} sh -c '
                    url="$1"
                    # -g desactiva el glob de curl: sin el, un nombre con
                    # llaves "{a,b}" se expande a varias peticiones y una sola
                    # wallpaper puede multiplicar el trabajo. Ademas se exige el
                    # origen esperado, para que nada se descargue de otro sitio
                    # aunque la lista venga manipulada.
                    case "$url" in
                        https://raw.githubusercontent.com/deadduck-09/FireWalls/main/*) ;;
                        *) echo "origen no permitido: $url" >>"$LOG_FILE"; exit 0 ;;
                    esac
                    dest="$WALL_DIR/$(basename "$url")"
                    # Descarga a un temporal y renombra al final: si se corta a
                    # mitad, no queda un .png corrupto que luego parezca bueno.
                    tmp="$dest.part.$$"
                    if curl -g -fsSL --connect-timeout 10 --max-time 120 "$url" -o "$tmp" >>"$LOG_FILE" 2>&1; then
                        mv -f "$tmp" "$dest"
                    else
                        rm -f "$tmp"
                    fi
                ' _ {} || true
            else
                step_warn "Could not fetch wallpaper list (API vacia/rate-limit), cloning full collection instead."
                rm -rf "$FW_DIR" || true
                if git clone --depth 1 --filter=blob:none --sparse "$FW_REPO" "$FW_DIR" >> "$LOG_FILE" 2>&1 \
                    && (cd "$FW_DIR" && git sparse-checkout set Desktop/Wallpapers >> "$LOG_FILE" 2>&1); then
                    if find "$FW_DIR/Desktop/Wallpapers" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) -print -quit 2>/dev/null | grep -q .; then
                        find "$FW_DIR/Desktop/Wallpapers" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) -exec cp {} "$WALL_DIR/" \; >> "$LOG_FILE" 2>&1 || step_warn "No se pudieron copiar wallpapers."
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
        #
        # El login se pinta SOLO en el panel del portatil, y por eso el
        # compositor no se arranca directamente sino con un envoltorio. La regla
        # que apaga el monitor externo no puede escribirse en la config: con la
        # tapa cerrada no hay panel y dejaria el login sin ninguna pantalla, y
        # esta version de Hyprland no expone getMonitors en Lua para preguntar.
        # sddm-greeter-monitor mira /sys/class/drm, que ya esta poblado cuando
        # SDDM levanta el compositor, y decide ahi.
        #
        # hyprland.lua deja de ser una config y pasa a ser una PLANTILLA: el
        # envoltorio sustituye la marca de monitor por las reglas y arranca
        # Hyprland con el resultado.
        #
        # Las cuatro piezas de sistema (envoltorio, plantilla, sddm.conf y el
        # drop-in del cursor) las escribe rhythm-sddm-deploy, no este installer.
        # Es el mismo script que llama el OTA, y asi no pueden divergir: si
        # aqui se pusiera el CompositorCommand a mano y el tema del cursor aqui,
        # una actualizacion dejaria el sddm.conf de una forma y el cursor de
        # otra.
        if [ -x "$HOME/.local/bin/rhythm-sddm-deploy" ]; then
            if "$HOME/.local/bin/rhythm-sddm-deploy" "$DOTFILES_DIR"; then
                step_ok "SDDM greeter deployed (login on the internal panel only, cursor set)."
            else
                step_warn "El greeter de SDDM quedo a medias. Mira ~/.cache/rhythm-sddm-deploy.log"
            fi
        else
            step_warn "rhythm-sddm-deploy no esta en ~/.local/bin; el login se quedaria como este."
        fi

        # Red de seguridad: si algun dia hay que volver a X11, se renombra este
        # fichero a .disabled y se restaura xsetup.conf.
        [ -f "/etc/sddm.conf.d/xsetup.conf" ] && sudo mv -f /etc/sddm.conf.d/xsetup.conf /etc/sddm.conf.d/xsetup.conf.disabled
        if [ -f "$DOTFILES_DIR/sddm/Xsetup" ]; then
            sudo cp -f "$DOTFILES_DIR/sddm/Xsetup" /etc/sddm/Xsetup
            sudo chmod +x /etc/sddm/Xsetup
        fi

        # Sudoers NOPASSWD helper for live pywal sync
        #
        # El helper NO puede vivir en ~/.local/bin. sudoers solo restringe el
        # nombre del fichero, no quien lo controla: como el usuario puede
        # reescribirlo cuando quiera, sustituirlo por lo que sea y ejecutarlo
        # con `sudo` sin contrasena ES escalada a root. Ryoku tiene el mismo
        # problema resuelto de otra forma: el binario se instala en
        # /usr/bin, que es de root, y ahi el nombre si restringe el codigo.
        #
        # Ademas el helper valida ahora todo lo que viene de la cache del
        # usuario antes de tocar el tema (colores y ficheros), asi que el
        # NOPASSWD no le da a root nada que el usuario no pueda ya hacer.
        sudo mkdir -p /etc/sudoers.d /usr/local/lib/rhythm
        if [ -f "$DOTFILES_DIR/.local/bin/sddm-auto-sync-local" ]; then
            sudo install -m 755 -o root -g root \
                "$DOTFILES_DIR/.local/bin/sddm-auto-sync-local" \
                /usr/local/lib/rhythm/sddm-auto-sync-local
        fi
        echo "$USER ALL=(root) NOPASSWD: /usr/local/lib/rhythm/sddm-auto-sync-local" | sudo tee /etc/sudoers.d/sddm-sync > /dev/null
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

    # Verificacion final: el doctor mira lo desplegado (ficheros) y, con
    # compositor delante, lo vivo (servicios, isla, fondo, hypridle, sddm).
    # Desde TTY las comprobaciones en vivo se saltan solas. Solo avisa: un
    # fallo aqui no revierte una instalacion que por lo demas esta bien.
    if [ -x "$HOME/.local/bin/rhythm-doctor" ]; then
        step_item "Verifying the installation..."
        "$HOME/.local/bin/rhythm-doctor" --verify >> "$LOG_FILE" 2>&1 \
            && step_ok "Installation verified." \
            || step_warn "Doctor found issues. Check $LOG_FILE or run rhythm-doctor."
    fi
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

if [ "$RESUME_MODE" = true ]; then
    clear_logo
    gum style --foreground 6 --bold --padding "0 0 1 $PADDING_LEFT" "Resuming installation"
    if [ -f "$STEP_MARKER" ]; then
        if grep -qxF "finished" "$STEP_MARKER" 2>/dev/null; then
            # La instalacion anterior llego a terminarse, asi que --resume no
            # tiene nada que reanudar. Saltarselo todo haria creer al usuario
            # que se ha instalado todo, cuando en realidad no se ha ejecutado
            # ni un solo paso en esta ejecucion.
            gum style --foreground 3 --padding "0 0 1 $PADDING_LEFT" "La instalacion anterior ya se completo."
            gum style --foreground 7 --padding "0 0 1 $PADDING_LEFT" "Ejecuta el instalador sin --resume para instalarlo de verdad."
            exit 1
        fi
        gum style --foreground 7 --padding "0 0 1 $PADDING_LEFT" "Steps already done: $(wc -l < "$STEP_MARKER")"
    else
        gum style --foreground 3 --padding "0 0 1 $PADDING_LEFT" "No step marker found, so nothing is skipped."
    fi
    echo ""
fi

preflight_checks
check_existing_installation
run_step "aur-helper" install_yay
run_step "software-choices" first_run_choices

run_step "software" step_software
run_step "applications" step_applications
run_step "dotfiles" step_dotfiles
run_step "wallpapers" step_wallpapers
run_step "system" step_system

mark_step "finished"

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
