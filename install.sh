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
    # Drain any remaining bytes from pipe (e.g. curl | bash) so curl doesn't encounter EPIPE (error 23)
    if [ ! -t 0 ]; then
        cat >/dev/null 2>&1 || true
    fi
    exit "$exit_code"
}
trap 'handle_error $LINENO' ERR


DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")

# El log va a un mktemp y no a "/tmp/hyprland-install-$USER.log", que se puede
# adivinar de sobra. En esa ruta fija, otro usuario del equipo crea el fichero
# como enlace simbolico que apunte a ~/.bashrc o a lo que sea, y el ": >" de
# abajo lo deja en cero. Con mktemp no hay forma de saber el nombre de antes.
#
# Se crea aqui y no en su sitio de siempre (justo antes de los flags de Arch)
# porque la trampa de errores lo cita: la rama de NixOS sale mucho antes de
# aquel punto, y un fallo suyo imprimia "log saved to: " sin nada detras.
LOG_FILE=$(mktemp "/tmp/hyprland-install-${USER:-$(id -un)}.XXXXXX.log" 2>/dev/null || true)
if [ -z "$LOG_FILE" ] || ! touch "$LOG_FILE" 2>/dev/null; then
    mkdir -p "$HOME/.cache" 2>/dev/null || true
    LOG_FILE="$HOME/.cache/hyprland-install.log"
fi
: > "$LOG_FILE" 2>/dev/null || true

export PATH="$HOME/.cargo/bin:$HOME/.local/bin:/usr/local/bin:$PATH"
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env" 2>/dev/null || true

# Robust reboot helper that ignores systemd inhibitors (such as active APT or SSH sessions)
rhythm_reboot() {
    sudo systemctl reboot -i 2>/dev/null || sudo reboot -f 2>/dev/null || sudo reboot 2>/dev/null || true
}

# --- TERMINAL GEOMETRY & OMARCHY PRESENTATION SETUP ---
# Defined here, before the NixOS branch, and used by BOTH install paths. It used
# to live further down, after the NixOS branch had already exited, so that path
# had to grow its own copy of every helper (nixos_section, nixos_ok, nixos_item,
# nixos_logo) with no centring, no Tokyo Night colours for gum and no
# completion screen: the same installer printed two different desktops. One
# implementation, called with whichever checkout holds logo.txt.
rhythm_presentation_init() {
    local logo_dir="${1:-$DOTFILES_DIR}"
    if [[ -e /dev/tty ]]; then
        TERM_SIZE=$(stty size 2>/dev/null </dev/tty || echo "24 80")
        export TERM_HEIGHT=$(echo "$TERM_SIZE" | cut -d' ' -f1)
        export TERM_WIDTH=$(echo "$TERM_SIZE" | cut -d' ' -f2)
    else
        export TERM_WIDTH=80
        export TERM_HEIGHT=24
    fi

    LOGO_PATH="$logo_dir/logo.txt"
    if [[ -f "$LOGO_PATH" ]]; then
        LOGO_WIDTH=$(awk '{ if (length > max) max = length } END { print max+0 }' "$LOGO_PATH" 2>/dev/null || echo 69)
    else
        LOGO_WIDTH=69
    fi

    PADDING_LEFT=$(((TERM_WIDTH - LOGO_WIDTH) / 2))
    if (( PADDING_LEFT < 0 )); then
        PADDING_LEFT=0
    fi
    # A wide logo in a narrow terminal used to push every message to the right
    # edge and off screen, which read as "nothing shows". Cap the indent and
    # reserve the columns it takes so long lines wrap inside the visible area.
    if (( PADDING_LEFT > 8 )); then
        PADDING_LEFT=8
    fi
    PADDING_LEFT_SPACES=$(printf "%*s" "$PADDING_LEFT" "")
    # Width every message is wrapped to, so no line spills past the terminal.
    CONTENT_WIDTH=$((TERM_WIDTH - PADDING_LEFT))
    if (( CONTENT_WIDTH < 40 )); then
        CONTENT_WIDTH=40
    fi

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
}

# present_banner <green-bold> <normal>: the two closing lines of a finished run.
present_banner() {
    clear_logo
    echo ""
    gum style --foreground 2 --bold --width "${CONTENT_WIDTH:-80}" --padding "0 0 1 $PADDING_LEFT" -- "$1" 2>/dev/null \
        || printf "%s\033[1;32m%s\033[0m\n" "$PADDING_LEFT_SPACES" "$1"
    gum style --foreground 7 --width "${CONTENT_WIDTH:-80}" --padding "0 0 1 $PADDING_LEFT" -- "$2" 2>/dev/null \
        || printf "%s\033[0;37m%s\033[0m\n" "$PADDING_LEFT_SPACES" "$2"
    # Where the full output went. nix prints its own lines and gum draws over
    # the terminal, so on a run that ends with a clear screen there is no way
    # back to what happened; the log is the only record.
    [ -n "${LOG_FILE:-}" ] && rhythm_msg "8" "" "  → Full log:" "$LOG_FILE"
    return 0
}

clear_logo() {
    printf "\033[H\033[2J"
    if [[ -f "$LOGO_PATH" ]]; then
        if command -v gum >/dev/null 2>&1; then
            gum style --foreground 2 --width "${CONTENT_WIDTH:-80}" --padding "1 0 0 $PADDING_LEFT" -- "$(<"$LOGO_PATH")"
        else
            cat "$LOGO_PATH"
        fi
    fi
}

# Every message goes through gum with the same width and indent, so the whole
# run lines up in one column. step_item/step_ok/step_warn used to be raw
# printf: they printed without gum styling and, being longer than the
# terminal, their wrapped continuation started at column 0, which is what
# made parts of the NixOS output look flush left and "not gum".
section() {
    echo ""
    if command -v gum >/dev/null 2>&1; then
        gum style --foreground 6 --bold --width "${CONTENT_WIDTH:-80}" --padding "0 0 0 $PADDING_LEFT" -- ":: $1"
    else
        printf "%s\033[1;36m:: %s\033[0m\n" "$PADDING_LEFT_SPACES" "$1"
    fi
}

# rhythm_msg <ansi-color> <ansi-bold> <prefix> <text>
# gum does the padding and the wrapping; the printf fallback keeps the
# indent for terminals where gum is missing or fails.
rhythm_msg() {
    local color="$1" bold="$2" prefix="$3" text="$4"
    if command -v gum >/dev/null 2>&1; then
        local args=(style --width "${CONTENT_WIDTH:-80}" --padding "0 0 0 $PADDING_LEFT")
        [ -n "$color" ] && args+=(--foreground "$color")
        [ -n "$bold" ] && args+=(--bold)
        gum "${args[@]}" -- "$prefix $text" 2>/dev/null \
            || printf "%s%s%s%s\033[0m\n" "$PADDING_LEFT_SPACES" "$bold" "$prefix $text" "$color"
    else
        printf "%s%s%s%s%s\033[0m\n" "$PADDING_LEFT_SPACES" "$bold" "$prefix" "$text" "$color"
    fi
}

step_item() {
    rhythm_msg "7" "" "  →" "$1"
}

step_ok() {
    rhythm_msg "2" "" "  [OK]" "$1"
}

step_warn() {
    rhythm_msg "3" "" "  !" "$1"
}

confirm_prompt() {
    local prompt_msg="$1"
    if [ "${AUTO_YES:-false}" = true ]; then
        return 0
    fi
    gum confirm "$prompt_msg"
}

# nixos_spin <message> -- <command...>: a long step with something to look at.
#
# The NixOS path spends most of its time inside nix, which prints its own
# lines and then goes quiet while it downloads or builds, so a bare `nix
# build` left the terminal frozen for minutes with no explanation. The Arch
# installer wraps every slow step in gum spin; this does the same, and is the
# reason the two feel alike.
#
# With stdout not a terminal (piped into tee, CI, a log) a spinner is only
# escape codes, so print the message plainly and let the command speak.
#
# NEVER put a redirect on the rhythm_spin call itself
# (rhythm_spin "msg" -- cmd 2>>"$LOG_FILE"): the redirect applies to this
# whole function, gum draws the spinner on stderr, and the terminal goes
# fully dark for minutes (it looks like the installer died right after the
# logo). To log a step, redirect INSIDE: pass
# bash -c 'cmd >>"$LOG_FILE" 2>&1' so only the inner command is silenced.
rhythm_spin() {
    local msg="$1"; shift
    [ "${1:-}" = "--" ] && shift
    if command -v gum >/dev/null 2>&1 && [ -t 1 ]; then
        gum spin --spinner dot --title "$msg" -- "$@"
    else
        # The hint goes on its own line: appended to the message it ran past
        # the terminal width and wrapped back to column 0.
        step_item "$msg"
        step_item "This can take several minutes. Live log: ${LOG_FILE:-/tmp/hyprland-install.log}"
        "$@"
    fi
}
nixos_spin() {
    rhythm_spin "$@"
}

# --- PROGRESS BAR & PACKAGE INSTALLATION MONITOR ---
render_progress_bar() {
    local curr="$1"
    local total="$2"
    local label="${3:-Installing packages...}"
    [ "$total" -le 0 ] && total=1
    [ "$curr" -gt "$total" ] && curr="$total"
    local pct=$(( curr * 100 / total ))
    local bar_width=24
    local filled=$(( curr * bar_width / total ))
    local empty=$(( bar_width - filled ))

    local bar_fill=""
    local bar_empty=""
    local i
    for ((i=0; i<filled; i++)); do bar_fill="${bar_fill}█"; done
    for ((i=0; i<empty; i++)); do bar_empty="${bar_empty}░"; done

    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    local max_label_len=$(( cols - 50 ))
    [ "$max_label_len" -lt 12 ] && max_label_len=12
    if [ ${#label} -gt $max_label_len ]; then
        label="${label:0:$((max_label_len - 3))}..."
    fi

    if [ -t 1 ]; then
        printf "\r  [\033[38;5;39m%s\033[38;5;238m%s\033[0m] \033[1;37m%3d%%\033[0m \033[38;5;245m(%d/%d)\033[0m \033[38;5;252m%s\033[0m\033[K" \
            "$bar_fill" "$bar_empty" "$pct" "$curr" "$total" "$label"
    fi
}

clear_progress_bar() {
    if [ -t 1 ]; then
        printf "\r\033[K"
    fi
}

rhythm_install_with_progress() {
    local total="${1:-1}"
    local title="${2:-Installing packages...}"
    shift 2

    step_item "$title"

    if [ ! -t 1 ] || [ "${DRY_RUN:-false}" = true ]; then
        "$@" >> "$LOG_FILE" 2>&1
        return $?
    fi

    local curr=0
    local re_pacman="^\([[:space:]]*([0-9]+)/([0-9]+)\)[[:space:]]+(installing|upgrading|reinstalling|downloading)[[:space:]]+([^.[:space:]]+)"
    local re_apt_setup="^Setting up[[:space:]]+([^[:space:]:(]+)"
    local re_apt_get="^Get:[0-9]+[[:space:]]+"
    local re_dnf="^\[[[:space:]]*([0-9]+)/([0-9]+)\][[:space:]]+(Installing|Upgrading|Downloading):[[:space:]]+([^.[:space:]]+)"
    local re_apk="^\([[:space:]]*([0-9]+)/([0-9]+)\)[[:space:]]+(Installing|Upgrading|Downloading)[[:space:]]+([^.[:space:]]+)"
    local re_zypper="^(Installing|Retrieving):[[:space:]]+([^.[:space:]]+)[[:space:]]+\[([0-9]+)/([0-9]+)\]"
    local re_step="^::[[:space:]]+(.+)"

    render_progress_bar 0 "$total" "Starting package installation..."

    local cmd=("$@")
    if command -v stdbuf >/dev/null 2>&1; then
        cmd=(stdbuf -oL -eL "$@")
    fi

    "${cmd[@]}" 2>&1 | tr "\r" "\n" | while IFS= read -r line || [ -n "$line" ]; do
        echo "$line" >> "$LOG_FILE"
        if [[ "$line" =~ $re_pacman ]]; then
            curr="${BASH_REMATCH[1]}"
            local dyn_tot="${BASH_REMATCH[2]}"
            local action="${BASH_REMATCH[3]}"
            local pkg="${BASH_REMATCH[4]}"
            [ "$dyn_tot" -gt 0 ] && total="$dyn_tot"
            local action_label="Installing"
            [ "$action" = "downloading" ] && action_label="Downloading"
            render_progress_bar "$curr" "$total" "$action_label $pkg..."
        elif [[ "$line" =~ $re_dnf ]]; then
            curr="${BASH_REMATCH[1]}"
            local dyn_tot="${BASH_REMATCH[2]}"
            local action="${BASH_REMATCH[3]}"
            local pkg="${BASH_REMATCH[4]}"
            [ "$dyn_tot" -gt 0 ] && total="$dyn_tot"
            render_progress_bar "$curr" "$total" "$action $pkg..."
        elif [[ "$line" =~ $re_apk ]]; then
            curr="${BASH_REMATCH[1]}"
            local dyn_tot="${BASH_REMATCH[2]}"
            local action="${BASH_REMATCH[3]}"
            local pkg="${BASH_REMATCH[4]}"
            [ "$dyn_tot" -gt 0 ] && total="$dyn_tot"
            render_progress_bar "$curr" "$total" "$action $pkg..."
        elif [[ "$line" =~ $re_zypper ]]; then
            curr="${BASH_REMATCH[3]}"
            local dyn_tot="${BASH_REMATCH[4]}"
            local action="${BASH_REMATCH[1]}"
            local pkg="${BASH_REMATCH[2]}"
            [ "$dyn_tot" -gt 0 ] && total="$dyn_tot"
            render_progress_bar "$curr" "$total" "$action $pkg..."
        elif [[ "$line" =~ $re_apt_setup ]]; then
            curr=$((curr + 1))
            local pkg="${BASH_REMATCH[1]}"
            [ "$curr" -gt "$total" ] && curr="$total"
            render_progress_bar "$curr" "$total" "Configuring $pkg..."
        elif [[ "$line" =~ $re_apt_get ]]; then
            render_progress_bar "$curr" "$total" "Downloading packages..."
        elif [[ "$line" =~ $re_step ]]; then
            local step_name="${BASH_REMATCH[1]}"
            render_progress_bar "$curr" "$total" "$step_name"
        fi
    done
    local ret="${PIPESTATUS[0]}"
    render_progress_bar "$total" "$total" "Installation complete."
    [ -t 1 ] && printf "\n"
    return "$ret"
}

# Same reason as nixos_tui_ok: a TUI on a dumb/limited terminal never draws and
# never returns, so the run would hang on that step forever. Wrapping the
# spinner in the timeout costs nothing (builds run far longer than the
# timeout and gum is killed only if it stops rendering) and guarantees the
# installer always reaches the next message.

# NixOS does not use the Arch steps below at all. Instead of stopping with
# directions, this same command installs the desktop: it auto-detects user and
# GPU, activates a standalone home-manager flake under ~/.config/home-manager
# for the user scope (dotfiles, helpers, user units) and wires the repo's NixOS
# module into /etc/nixos for everything that has to be system wide (SDDM
# astronaut greeter, fonts, portals, audio denoising, user groups, the Hyprland
# session and every desktop program). Override the guesses with
# RHYTHM_USER/RHYTHM_GPU.
if [ -f /etc/NIXOS ] || { [ -f /etc/os-release ] && grep -q '^ID=nixos' /etc/os-release; }; then
    # Flags the Arch parser below understands, accepted here too. This branch
    # runs before it, and silently ignoring "--wallpapers all" or "-y" would
    # install something different from what was asked for.
    nixos_show_help() {
        cat << 'EOF'
Rhythm Hyprland Installer (NixOS backend)

Usage:
  ./install.sh [OPTIONS]

Options:
  -h, --help                 Show this help message and exit
  -y, --yes                  Assume yes to all prompts (unattended mode)
  --wallpapers <mode>        Wallpaper pack: all, random, none
  --skip-wallpapers          Same as --wallpapers none
  --flatpaks                 Install the Flatpak apps from flatpaks.txt
  --skip-flatpaks            Skip Flatpaks (default)
  --gpu <type>               GPU driver stack: nvidia, amd, intel, auto, none
  --skip-gpu                 Skip GPU detection (generic modesetting only)
  --no-system                Desktop for this user only: do not touch /etc/nixos
  -u, --update               Same as a normal run (there is no separate OTA on NixOS)

Environment overrides:
  RHYTHM_USER, RHYTHM_GPU            Auto-detected values
  RHYTHM_WALLPAPER, RHYTHM_FLATPAKS  Preset the choices
  RHYTHM_NO_CHOICES=1                Never prompt
  RHYTHM_NO_SYSTEM=1                 Do not touch /etc/nixos
  RHYTHM_NIXOS_CHANNEL=<name>        nixpkgs branch (default: your installed release)

One-line installation:
  curl -fsSL https://raw.githubusercontent.com/rhythmcreative/hyprland/main/install.sh | bash
EOF
    }

    install_nixos() {
        [ "$(id -u)" -eq 0 ] && { echo "ERROR: run as your user, not root."; exit 1; }

        local want_help=0
        AUTO_YES=false
        local opt_wall="" opt_flat="" opt_gpu="" opt_no_system=0
        while [ $# -gt 0 ]; do
            case "$1" in
                -h|--help) want_help=1 ;;
                -y|--yes) AUTO_YES=true ;;
                --wallpapers) shift; opt_wall="${1:-random}" ;;
                --wallpapers=*) opt_wall="${1#*=}" ;;
                --skip-wallpapers) opt_wall="none" ;;
                --flatpaks) opt_flat="1" ;;
                --skip-flatpaks) opt_flat="0" ;;
                --gpu) shift; opt_gpu="${1:-auto}" ;;
                --gpu=*) opt_gpu="${1#*=}" ;;
                --skip-gpu) opt_gpu="none" ;;
                --no-system) opt_no_system=1 ;;
                -u|--update) : ;;   # updates are a plain re-run on NixOS (ADR-0005)
                *) : ;;            # Arch-only flags mean nothing here
            esac
            shift
        done
        rhythm_presentation_init "$DOTFILES_DIR"
        if [ "$want_help" = 1 ]; then
            clear_logo
            nixos_show_help
            exit 0
        fi

        # stdin may be a pipe (curl | bash) while the terminal is still
        # reachable: gate menus on an openable /dev/tty, like gum does.
        nixos_can_ask() {
            [ "$AUTO_YES" = true ] && return 1
            nixos_tui_ok || return 1
            [ -t 0 ] && return 0
            [ -c /dev/tty ] || return 1
            : 2>/dev/null </dev/tty || return 1
        }

        # Whether gum's full-screen widgets can actually be drawn here.
        #
        # `gum style` works on any terminal, which is why the logo showed up and
        # made this look like a styling problem. `gum choose`/`gum confirm` are
        # Bubble Tea TUI programs: on a dumb/limited terminal (TERM=dumb, the
        # TERM=linux a NixOS getty sets, unknown) they never render and never
        # exit, so the installer froze on the logo with zero output, forever,
        # waiting for a key that could not be entered.
        #
        # A widget that cannot be drawn must never be started: fall back to
        # documented defaults and say so, so the run keeps going visibly.
        nixos_tui_ok() {
            [ -n "${TERM:-}" ] || return 1
            case "$TERM" in
                dumb|unknown|linux|vt100|nsterm) return 1 ;;
            esac
            [ -t 1 ] || [ -c /dev/tty ] || return 1
            return 0
        }
        # One-time note when the terminal cannot host the menus.
        nixos_tui_warned=""
        nixos_tui_note() {
            [ -n "$nixos_tui_warned" ] && return 0
            nixos_tui_warned=1
            step_warn "This terminal (TERM=${TERM:-none}) cannot show interactive"
            step_warn "menus; continuing with the defaults below, no input needed."
        }

        # git comes with NixOS most of the time; otherwise fetch it through
        # nix itself so this stays a one-command install.
        if ! command -v git >/dev/null 2>&1; then
            step_item "Installing git through nix..."
            NIX_CONFIG="experimental-features = nix-command flakes" \
                nix --extra-experimental-features "nix-command flakes" \
                profile install nixpkgs#git 2>/dev/null || {
                    step_warn "ERROR: could not get git. Install it and retry."; exit 1; }
            export PATH="$HOME/.nix-profile/bin:$PATH"
        fi

        # Flakes for this session. /etc/nix/nix.conf is off-limits: on NixOS
        # it is a store symlink, so appending fails with "Read-only file
        # system". The user config written below keeps `nix build` and
        # `home-manager switch` working afterwards; the system side gets the
        # same through nix.settings in the flake this installer writes to
        # /etc/nixos.
        # Flakes and performance optimizations for this session.
        # max-jobs = auto and http-connections = 50 ensure parallel downloads and builds.
        export NIX_CONFIG="experimental-features = nix-command flakes
max-jobs = auto
cores = 0
http-connections = 50"
        local nix_user_conf="$HOME/.config/nix/nix.conf"
        mkdir -p "$(dirname "$nix_user_conf")"
        if ! grep -q 'experimental-features' "$nix_user_conf" 2>/dev/null; then
            cat << 'EOF' > "$nix_user_conf"
experimental-features = nix-command flakes
max-jobs = auto
cores = 0
http-connections = 50
EOF
            step_item "Configured flakes and parallel downloads in $nix_user_conf."
        fi

        if ! command -v gum >/dev/null 2>&1; then
            step_item "Installing gum for the installer visuals (user profile only)..."
            if nixos_spin "Fetching gum..." -- \
                bash -c "nix --extra-experimental-features 'nix-command flakes' profile install nixpkgs#gum >>'$LOG_FILE' 2>&1"; then
                export PATH="$HOME/.nix-profile/bin:$PATH"
            else
                step_warn "gum is unavailable, continuing with plain prompts."
            fi
        fi
        # gum arrived after the geometry was measured: re-measure so the
        # centring and the gum padding use the real terminal.
        rhythm_presentation_init "$DOTFILES_DIR"

        local repo="$HOME/hyprland"
        if [ ! -d "$repo/.git" ]; then
            nixos_spin "Cloning the desktop into $repo..." -- \
                git clone --depth=1 https://github.com/rhythmcreative/hyprland.git "$repo" || exit 1
        else
            step_item "Using existing checkout at $repo."
            if [ -z "${RHYTHM_DEV:-}" ]; then
                git -C "$repo" pull --rebase origin main >/dev/null 2>&1 || true
            fi
        fi
        rhythm_presentation_init "$repo"
        clear_logo

        # User scope: standalone home-manager, no sudo, no /etc writes, the
        # same modules as homes/rhythm/home.nix, activated for this user only.
        # Auto-detected values; override with RHYTHM_USER / RHYTHM_GPU in the
        # rare case the guess is wrong.
        local user="${RHYTHM_USER:-$USER}" guess_gpu="${opt_gpu:-${RHYTHM_GPU:-auto}}" rel hm_dir
        rel=$(grep -oP '^VERSION_ID="\K[^"]+' /etc/os-release 2>/dev/null || true)
        if [ -z "$rel" ] && command -v nixos-version >/dev/null 2>&1; then
            rel=$(nixos-version 2>/dev/null | cut -d. -f1,2 || true)
        fi
        [ -z "$rel" ] && rel="25.11"
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
        local is_asus=false is_surface=false
        local sys_vendor prod_name
        sys_vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)
        prod_name=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
        [[ "$sys_vendor" == *"ASUSTeK"* ]] && is_asus=true
        [[ "$prod_name" == *"Surface"* ]] && is_surface=true

        section "Installing desktop for user=$user gpu=$guess_gpu"
        [ "$guess_gpu" = "nvidia" ] && step_item "NOTE: NVIDIA needs unfree. If a build refuses, add nixpkgs.config.allowUnfree = true; to /etc/nixos/flake.nix."
        [ "$is_asus" = true ] && step_ok "ASUS hardware detected (asusctl ROG integration enabled)."
        [ "$is_surface" = true ] && step_ok "Microsoft Surface detected (surface-control enabled)."

        # Arch-style choices, mapped to module options and packages. Skipped with
        # RHYTHM_NO_CHOICES=1 (or RHYTHM_WALLPAPER / RHYTHM_FLATPAKS set).
        # Every gum widget runs under `timeout`: a TUI that cannot draw would
        # otherwise block the whole install with no way to press a key.
        local wallpapers="${opt_wall:-${RHYTHM_WALLPAPER:-random}}"
        local flatpaks="${opt_flat:-${RHYTHM_FLATPAKS:-0}}"
        local -a nix_user_pkgs=()
        local enable_steam_system=false

        if [ -z "${RHYTHM_NO_CHOICES:-}" ] && nixos_can_ask && command -v gum >/dev/null 2>&1; then
            clear_logo
            echo ""
            gum style --foreground 3 --bold --padding "0 0 1 $PADDING_LEFT" "Get ready to make a few choices..."

            local mode_raw
            mode_raw=$(timeout 120 gum choose \
                --height 9 \
                --header="Select software installation mode:" \
                --cursor-prefix="> " \
                "Fast Core Desktop (Instant setup: Hyprland, Waybar, Island, Kitty, Thunar)" \
                "Custom Categorized Menus (Pick browsers, chat, dev, media apps)" \
                "Full Heavy Stack (Brave, Steam, VSCode, Discord, LibreOffice, GIMP...)" \
                "Search & Select ANY Packages with fzf (Nixpkgs database)" </dev/tty 2>/dev/null || true)

            nixos_search_packages() {
                if ! command -v fzf >/dev/null 2>&1; then
                    step_item "Installing fzf for package search..."
                    nix --extra-experimental-features "nix-command flakes" profile install nixpkgs#fzf >>"$LOG_FILE" 2>&1 || true
                fi
                clear_logo
                echo ""
                step_item "Launching package search (Search & install ANY package from Nixpkgs)..."
                step_item "[TAB] Select multiple, [ENTER] Confirm, [ESC] Skip"
                sleep 0.8

                local fzf_selection=""
                if command -v nix-env >/dev/null 2>&1; then
                    fzf_selection=$(nix-env -qaP 2>/dev/null | awk '{print $1}' | sort -u | fzf --multi --ansi \
                        --prompt="Search Nixpkgs > " \
                        --header="[TAB] Toggle Select | [ENTER] Confirm Selection | [ESC] Skip Search" \
                        --preview-window='right:55%:wrap' || true)
                fi

                if [ -n "$fzf_selection" ]; then
                    local count=0
                    while IFS= read -r app; do
                        [ -z "$app" ] && continue
                        # Strip channel prefix if present (e.g. nixos.brave -> brave, nixpkgs.brave -> brave)
                        app="${app#nixos.}"
                        app="${app#nixpkgs.}"
                        nix_user_pkgs+=("$app")
                        [ "$app" = "steam" ] && enable_steam_system=true
                        count=$((count + 1))
                    done <<< "$fzf_selection"
                    step_ok "Added $count packages from package search."
                    sleep 1
                else
                    step_item "No packages selected from search."
                    sleep 0.5
                fi
            }

            if [[ "$mode_raw" == *"Full Heavy Stack"* ]] || [[ "$mode_raw" == *"Full Package Stack"* ]]; then
                nix_user_pkgs+=(
                    "brave" "vesktop" "telegram-desktop" "spotify"
                    "vscode" "neovim" "obsidian" "libreoffice" "localsend"
                    "steam" "obs-studio" "vlc" "gimp" "fastfetch" "btop"
                )
                enable_steam_system=true
                flatpaks="1"
            elif [[ "$mode_raw" == *"Fast Core"* ]] || [[ "$mode_raw" == *"Minimal"* ]] || [ -z "$mode_raw" ]; then
                : # Fast core stack: essential Hyprland suite only (instant deployment)
            elif [[ "$mode_raw" == *"Search & Select ANY Packages"* ]]; then
                nixos_search_packages
            else
                # 1. Web Browsers
                clear_logo
                echo ""
                gum style --foreground 6 --bold --padding "0 0 1 $PADDING_LEFT" ":: Web Browsers (1/5)"
                local browsers_list=(
                    "Brave Browser (brave)"
                    "Chromium (chromium)"
                    "Firefox (firefox)"
                    "Firefox Developer Edition (firefox-devedition)"
                    "Google Chrome (google-chrome)"
                    "Microsoft Edge (microsoft-edge)"
                    "Zen Browser (zen-browser)"
                )
                local sel_browsers
                sel_browsers=$(printf "%s\n" "${browsers_list[@]}" | timeout 120 gum choose --no-limit --height 10 \
                    --selected="Brave Browser (brave)" \
                    --header="Space = Toggle, Enter = Confirm Category" \
                    --cursor-prefix="> " --selected-prefix="[x] " --unselected-prefix="[ ] " </dev/tty 2>/dev/null || true)

                # 2. Communication & Social
                clear_logo
                echo ""
                gum style --foreground 6 --bold --padding "0 0 1 $PADDING_LEFT" ":: Communication & Social (2/5)"
                local comm_list=(
                    "Discord / Vesktop (vesktop)"
                    "Telegram Desktop (telegram-desktop)"
                    "Slack Desktop (slack)"
                    "Spotify (spotify)"
                )
                local sel_comm
                sel_comm=$(printf "%s\n" "${comm_list[@]}" | timeout 120 gum choose --no-limit --height 10 \
                    --selected="Discord / Vesktop (vesktop)" \
                    --header="Space = Toggle, Enter = Confirm Category" \
                    --cursor-prefix="> " --selected-prefix="[x] " --unselected-prefix="[ ] " </dev/tty 2>/dev/null || true)

                # 3. Productivity & Development
                clear_logo
                echo ""
                gum style --foreground 6 --bold --padding "0 0 1 $PADDING_LEFT" ":: Productivity & Development (3/5)"
                local dev_list=(
                    "Visual Studio Code (vscode)"
                    "Neovim (neovim)"
                    "Obsidian (obsidian)"
                    "LibreOffice (libreoffice)"
                    "LocalSend (localsend)"
                    "Docker & Docker Compose (docker docker-compose)"
                    "Node.js & NPM (nodejs)"
                    "Python Suite (python3)"
                    "GitKraken (gitkraken)"
                    "Ollama (ollama)"
                )
                local sel_dev
                sel_dev=$(printf "%s\n" "${dev_list[@]}" | timeout 120 gum choose --no-limit --height 10 \
                    --selected="Visual Studio Code (vscode)" \
                    --header="Space = Toggle, Enter = Confirm Category" \
                    --cursor-prefix="> " --selected-prefix="[x] " --unselected-prefix="[ ] " </dev/tty 2>/dev/null || true)

                # 4. Media, Creativity & Gaming
                clear_logo
                echo ""
                gum style --foreground 6 --bold --padding "0 0 1 $PADDING_LEFT" ":: Media, Creativity & Gaming (4/5)"
                local media_list=(
                    "Steam (steam)"
                    "Lutris (lutris)"
                    "Heroic Games Launcher (heroic)"
                    "OBS Studio (obs-studio)"
                    "VLC Media Player (vlc)"
                    "MPV Media Player (mpv)"
                    "GIMP (gimp)"
                    "Inkscape (inkscape)"
                    "Kdenlive (kdenlive)"
                    "Blender (blender)"
                    "Audacity (audacity)"
                )
                local sel_media
                sel_media=$(printf "%s\n" "${media_list[@]}" | timeout 120 gum choose --no-limit --height 10 \
                    --header="Space = Toggle, Enter = Confirm Category" \
                    --cursor-prefix="> " --selected-prefix="[x] " --unselected-prefix="[ ] " </dev/tty 2>/dev/null || true)

                # 5. System Utilities & Flatpaks
                clear_logo
                echo ""
                gum style --foreground 6 --bold --padding "0 0 1 $PADDING_LEFT" ":: System Utilities & Flatpaks (5/5)"
                local utils_list=(
                    "Btop System Monitor (btop)"
                    "Fastfetch (fastfetch)"
                    "Mission Center (flatpak: io.missioncenter.MissionCenter)"
                    "Clapper Media Player (flatpak: com.github.rafostar.Clapper)"
                    "Eye of GNOME (flatpak: org.gnome.eog)"
                    "Sober Roblox Player (flatpak: org.vinegarhq.Sober)"
                )
                local sel_utils
                sel_utils=$(printf "%s\n" "${utils_list[@]}" | timeout 120 gum choose --no-limit --height 10 \
                    --selected="Mission Center (flatpak: io.missioncenter.MissionCenter)" \
                    --header="Space = Toggle, Enter = Confirm Category" \
                    --cursor-prefix="> " --selected-prefix="[x] " --unselected-prefix="[ ] " </dev/tty 2>/dev/null || true)

                local all_selected="${sel_browsers}"$'\n'"${sel_comm}"$'\n'"${sel_dev}"$'\n'"${sel_media}"$'\n'"${sel_utils}"
                while IFS= read -r line; do
                    [ -z "$line" ] && continue
                    case "$line" in
                        *"(brave)"*)                  nix_user_pkgs+=("brave") ;;
                        *"(chromium)"*)               nix_user_pkgs+=("chromium") ;;
                        *"(firefox)"*)                nix_user_pkgs+=("firefox") ;;
                        *"(firefox-devedition)"*)     nix_user_pkgs+=("firefox-devedition") ;;
                        *"(google-chrome)"*)          nix_user_pkgs+=("google-chrome") ;;
                        *"(microsoft-edge)"*)         nix_user_pkgs+=("microsoft-edge") ;;
                        *"(zen-browser)"*)            nix_user_pkgs+=("zen-browser") ;;
                        *"(vesktop)"*)                nix_user_pkgs+=("vesktop") ;;
                        *"(telegram-desktop)"*)       nix_user_pkgs+=("telegram-desktop") ;;
                        *"(slack)"*)                  nix_user_pkgs+=("slack") ;;
                        *"(spotify)"*)                nix_user_pkgs+=("spotify") ;;
                        *"(vscode)"*)                 nix_user_pkgs+=("vscode") ;;
                        *"(neovim)"*)                 nix_user_pkgs+=("neovim") ;;
                        *"(obsidian)"*)               nix_user_pkgs+=("obsidian") ;;
                        *"(libreoffice)"*)            nix_user_pkgs+=("libreoffice") ;;
                        *"(localsend)"*)              nix_user_pkgs+=("localsend") ;;
                        *"(docker docker-compose)"*)  nix_user_pkgs+=("docker" "docker-compose") ;;
                        *"(nodejs)"*)                 nix_user_pkgs+=("nodejs") ;;
                        *"(python3)"*)                nix_user_pkgs+=("python3") ;;
                        *"(gitkraken)"*)              nix_user_pkgs+=("gitkraken") ;;
                        *"(ollama)"*)                 nix_user_pkgs+=("ollama") ;;
                        *"(steam)"*)                  nix_user_pkgs+=("steam"); enable_steam_system=true ;;
                        *"(lutris)"*)                 nix_user_pkgs+=("lutris") ;;
                        *"(heroic)"*)                 nix_user_pkgs+=("heroic") ;;
                        *"(obs-studio)"*)             nix_user_pkgs+=("obs-studio") ;;
                        *"(vlc)"*)                    nix_user_pkgs+=("vlc") ;;
                        *"(mpv)"*)                    nix_user_pkgs+=("mpv") ;;
                        *"(gimp)"*)                   nix_user_pkgs+=("gimp") ;;
                        *"(inkscape)"*)               nix_user_pkgs+=("inkscape") ;;
                        *"(kdenlive)"*)               nix_user_pkgs+=("kdenlive") ;;
                        *"(blender)"*)                nix_user_pkgs+=("blender") ;;
                        *"(audacity)"*)               nix_user_pkgs+=("audacity") ;;
                        *"(btop)"*)                   nix_user_pkgs+=("btop") ;;
                        *"(fastfetch)"*)              nix_user_pkgs+=("fastfetch") ;;
                        *"(flatpak:"*)                flatpaks="1" ;;
                    esac
                done <<< "$all_selected"

                # Additional search or custom package input
                clear_logo
                echo ""
                gum style --foreground 6 --bold --padding "0 0 1 $PADDING_LEFT" ":: Additional Custom Software"
                if timeout 120 gum confirm "Would you like to search or add any extra packages from Nixpkgs?" </dev/tty 2>/dev/null; then
                    local add_choice
                    add_choice=$(timeout 120 gum choose \
                        --height 5 \
                        --header="How would you like to add packages?" \
                        --cursor-prefix="> " \
                        "Interactive Search with fzf" \
                        "Type package names manually (space-separated)" </dev/tty 2>/dev/null || true)

                    if [[ "$add_choice" == *"Interactive Search"* ]]; then
                        nixos_search_packages
                    elif [[ "$add_choice" == *"Type package names"* ]]; then
                        local custom_input
                        custom_input=$(timeout 120 gum input --prompt="Packages > " \
                            --placeholder="e.g. blender vlc kdenlive zed-editor" </dev/tty 2>/dev/null || true)
                        if [ -n "$custom_input" ]; then
                            for pkg_name in $custom_input; do
                                nix_user_pkgs+=("$pkg_name")
                                [ "$pkg_name" = "steam" ] && enable_steam_system=true
                            done
                            step_ok "Added custom packages: $custom_input"
                            sleep 1
                        fi
                    fi
                fi
            fi

            # Wallpaper selection prompt
            if [ -z "$opt_wall" ] && [ -z "${RHYTHM_WALLPAPER:-}" ]; then
                clear_logo
                echo ""
                gum style --foreground 6 --bold --padding "0 0 1 $PADDING_LEFT" ":: Wallpaper Collection"
                local wp_pick
                wp_pick=$(timeout 120 gum choose --height 6 \
                    --header="Select wallpaper download mode:" \
                    --cursor-prefix="> " \
                    "Random selection (50, FireWalls root + Best-Collection)" \
                    "All FireWalls (root + Best-Collection, ~850 imgs)" \
                    "Skip wallpaper download" </dev/tty 2>/dev/null || true)
                case "$wp_pick" in
                    *"All"*)    wallpapers="all" ;;
                    *"Random"*) wallpapers="random" ;;
                    *"Skip"*)   wallpapers="none" ;;
                esac
            fi
        elif [ -z "${RHYTHM_NO_CHOICES:-}" ]; then
            nixos_tui_note
        fi

        step_item "Wallpapers: $wallpapers - Flatpaks: $([ "$flatpaks" = "1" ] && echo on || echo off)"
        if [ "${#nix_user_pkgs[@]}" -gt 0 ]; then
            step_item "Selected packages: ${nix_user_pkgs[*]}"
        fi

        # Build formatted nix package list for home-manager
        local formatted_user_pkgs=""
        if [ "${#nix_user_pkgs[@]}" -gt 0 ]; then
            formatted_user_pkgs="          home.packages = with pkgs; ["
            for p in "${nix_user_pkgs[@]}"; do
                formatted_user_pkgs+=" $p"
            done
            formatted_user_pkgs+=" ];"
        fi

        # A home-manager consumer flake of this repo (main): self-contained,
        # survives even if ~/hyprland is deleted later. Rendered to a temp
        # file first: an unchanged flake is left alone entirely, so
        # re-running the installer does not litter ~/.config with a new
        # home-manager.bak-<timestamp> directory on every attempt.
        hm_dir="$HOME/.config/home-manager"
        mkdir -p "$hm_dir"
        local channel="${RHYTHM_NIXOS_CHANNEL:-nixos-$rel}"
        case "$channel" in
            nixos-*) : ;;
            *) channel="nixos-$rel" ;;
        esac
        local hm_url="github:nix-community/home-manager"
        if [[ "$channel" =~ ^nixos-([0-9]+\.[0-9]+)$ ]]; then
            hm_url="github:nix-community/home-manager/release-${BASH_REMATCH[1]}"
        fi
        local hyprland_url="${RHYTHM_FLAKE_URL:-github:rhythmcreative/hyprland}"
        if [ -z "${RHYTHM_FLAKE_URL:-}" ] && [ "${RHYTHM_DEV:-0}" = "1" ] && [ -d "$repo/.git" ]; then
            hyprland_url="path:$repo"
        fi

        local new_flake
        new_flake=$(mktemp)
        cat > "$new_flake" << EOF2
{
  description = "Rhythm Hyprland desktop (standalone home-manager)";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/$channel";
    home-manager = {
      url = "$hm_url";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland = {
      url = "$hyprland_url";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { nixpkgs, home-manager, hyprland, ... }: {
    homeConfigurations."$user" = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
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
            wallpaper.mode = "$wallpapers";
            features.flatpaks = $([ "$flatpaks" = "1" ] && echo true || echo false);
          };
${formatted_user_pkgs}
        }
      ];
    };
  };
}
EOF2

        # Swap the rendered flake in, keeping a timestamped copy of whatever
        # was there before. Compared by content, not just existence.
        if [ -e "$hm_dir/flake.nix" ] && cmp -s "$new_flake" "$hm_dir/flake.nix"; then
            rm -f "$new_flake"
            step_item "home-manager flake already up to date, left untouched."
        else
            if [ -e "$hm_dir/flake.nix" ] || [ -e "$hm_dir/home.nix" ]; then
                stamp=$(date +%Y%m%d-%H%M%S)
                mkdir -p "$HOME/.config/home-manager.bak-$stamp"
                cp -rf "$hm_dir/flake.nix" "$hm_dir/flake.lock" "$hm_dir/home.nix" \
                    "$HOME/.config/home-manager.bak-$stamp/" 2>/dev/null || true
                step_ok "Previous home-manager config backed up to ~/.config/home-manager.bak-$stamp."
            fi
            mv -f "$new_flake" "$hm_dir/flake.nix"
        fi

        section "Activating the desktop (downloads several GB the first time)"
        # Always track this repo's latest main. nix reuses flake.lock
        # silently: without this, a lock from a previous run keeps building
        # the old modules forever (e.g. fixes never arrive). Only our own
        # input moves; nixpkgs/home-manager stay pinned by the lock.
        nixos_spin "Fetching the latest desktop..." -- \
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
        # The long one: compositors, toolkits, fonts and every desktop program
        # as a closure. Minutes on a cold store, and nix goes quiet while it
        # works, so it gets a spinner. The store path goes to a file rather
        # than to stdout, otherwise the spinner's own output would land in it.
        act=""
        out_file=$(mktemp)
        step_item "Tip: to view live download progress in another terminal, run: tail -f \"$LOG_FILE\""
        nixos_spin "Building the desktop (several GB the first time)..." -- \
            bash -c "nix --extra-experimental-features 'nix-command flakes' build \
                --max-jobs auto --cores 0 \
                --no-link --print-out-paths \
                '$hm_dir#homeConfigurations.\"$user\".activationPackage' \
                > '$out_file' 2>>'$LOG_FILE'" || {
            step_warn "The desktop build failed. Last lines of $LOG_FILE:"
            tail -n 20 "$LOG_FILE" >&2 2>/dev/null || true
            rm -f "$out_file"
            exit 1
        }
        act=$(cat "$out_file")
        rm -f "$out_file"
        [ -n "$act" ] && [ -x "$act/activate" ] || {
            step_warn "nix build produced no activation package; see $LOG_FILE"
            exit 1
        }
        # The activate script takes no backup flag (only --driver-version):
        # existing files are preserved via HOME_MANAGER_BACKUP_EXT instead.
        # Activation is where a profile file collision surfaces (two packages
        # owning the same share/zsh/site-functions file aborts the whole run),
        # and the raw nix output for that is a wall of store paths. Detect it
        # and print the one command that fixes it instead of just dying.
        if ! nixos_spin "Linking your dotfiles, helpers and user services..." -- \
            env HOME_MANAGER_BACKUP_EXT=backup "$act/activate"; then
            if grep -q "already provides the following file" "$LOG_FILE" 2>/dev/null; then
                conflict=$(grep -o '/nix/store/[^"]*site-functions/[^"]*' "$LOG_FILE" 2>/dev/null | head -1 | xargs -r basename)
                step_warn "Two packages in your profile provide the same file${conflict:+ ($conflict)}."
                step_warn "This is the gum completion installed both by this installer"
                step_warn "(nix profile) and by home-manager. Fix it with:"
                echo ""
                step_item "nix profile remove gum"
                echo ""
                step_item "then re-run this installer; it puts gum back only if missing."
            fi
            step_warn "Activation failed. Last lines of $LOG_FILE:"
            tail -n 20 "$LOG_FILE" >&2 2>/dev/null || true
            exit 1
        fi
        echo ""
        # GitHub CLI + OpenCode at user level (nix profile, no rebuild).
        section "Developer tools (gh, opencode)"
        for tool in gh opencode; do
            if ! command -v "$tool" >/dev/null 2>&1; then
                nixos_spin "Installing $tool..." -- \
                    bash -c "nix --extra-experimental-features 'nix-command flakes' profile install 'nixpkgs#$tool' >>'$LOG_FILE' 2>&1" \
                    || step_item "Could not install $tool, skipping."
                export PATH="$HOME/.nix-profile/bin:$PATH"
            fi
        done
        if command -v gh >/dev/null 2>&1; then
            if gh auth status >/dev/null 2>&1; then
                step_ok "gh already authenticated."
            elif nixos_can_ask; then
                step_item "Authenticate GitHub CLI (browser/device flow)..."
                gh auth login || step_item "Skipped; run 'gh auth login' later."
            else
                step_item "Run 'gh auth login' later to authenticate GitHub CLI."
            fi
        fi
        command -v opencode >/dev/null 2>&1 \
            && step_ok "opencode ready ($(opencode --version 2>/dev/null | head -1))." \
            || true

        # System scope: SDDM, fonts, portals, audio and the desktop programs
        # live outside $HOME, so they need the NixOS module. Skip with
        # RHYTHM_NO_SYSTEM=1 or --no-system.
        system_status="skipped"
        if [ "${RHYTHM_NO_SYSTEM:-0}" = "1" ] || [ "$opt_no_system" = "1" ]; then
            step_item "System configuration skipped (--no-system). SDDM, fonts and"
            step_item "desktop programs stay uninstalled: log in from a TTY instead."
        else
            rhythm_setup_system "$user" "$guess_gpu" "$wallpapers" "$flatpaks" "$enable_steam_system" "$is_asus" "$is_surface" \
                && system_status="done" || system_status="failed"
        fi

        # Same closing screen as the Arch installer instead of dropping the
        # user at a bare prompt with no idea whether it worked.
        present_banner "Finished installing" \
            "Log out (or reboot) and pick Hyprland in the login screen."
        if [ "$system_status" = "done" ]; then
            rhythm_msg "7" "" "  → Update later:" \
                "cd /etc/nixos && sudo nix flake update && sudo nixos-rebuild switch"
        fi
        rhythm_msg "7" "" "  → Update your desktop only:" \
            "~/.config/home-manager, then home-manager switch --flake ~/.config/home-manager#$user"
        echo ""
    }

    # System scope: wire this repo's NixOS module into /etc/nixos.
    #
    # It used to write a five-line rhythm-sddm.nix (SDDM + Hyprland + SSH) and
    # stop there. That left the machine with a login screen on the default
    # breeze themes, no Nerd Fonts (so every waybar icon was a tofu box), no
    # xdg-desktop-portal (screen sharing dead), no rnnoise, the user outside
    # video/render/input/audio, and none of rhythm.desktopPackages at all:
    # SDDM started a compositor with no bar, no launcher and no terminal. The
    # module in modules/nixos already declares every one of those, so the
    # installer now installs the module instead of re-describing a subset of
    # it by hand.
    #
    # /etc/nixos/configuration.nix is never rewritten: the generated flake
    # imports it as a module, so the machine keeps whatever the installer of
    # NixOS wrote plus the user's own edits.
    rhythm_setup_system() {
        local user="$1" guess_gpu="$2" wallpapers="$3" flatpaks="$4" enable_steam="${5:-false}"
        local is_asus="${6:-false}" is_surface="${7:-false}"
        local etc_dir="/etc/nixos" channel

        channel="${RHYTHM_NIXOS_CHANNEL:-nixos-$rel}"
        case "$channel" in
            nixos-*) : ;;
            *) channel="nixos-$rel" ;;
        esac

        if [ ! -f "$etc_dir/configuration.nix" ]; then
            step_warn "No $etc_dir/configuration.nix: this looks like a flake-based system."
            step_item "Add these to your system modules and rebuild:"
            printf '%s\n' \
                '  inputs.hyprland.url = "github:rhythmcreative/hyprland";' \
                '  # in modules:' \
                '  imports = [ inputs.hyprland.nixosModules.rhythm-hyprland ];' \
                "  rhythm = { enable = true; username = \"$user\"; gpu = \"$guess_gpu\"; };"
            return 1
        fi

        local sddm_feature="true"
        if grep -rq "displayManager\.\(gdm\|lightdm\|greetd\|ly\)" "$etc_dir/" 2>/dev/null; then
            if [ "${RHYTHM_SDDM_FORCE:-0}" = "1" ]; then
                sddm_feature="true"
            else
                local prompt_sddm=false
                if nixos_can_ask; then
                    if timeout 60 gum confirm "Another display manager is configured in $etc_dir. Switch to SDDM (with Astronaut theme) as default?" </dev/tty 2>/dev/null; then
                        prompt_sddm=true
                    fi
                fi
                if [ "$prompt_sddm" = "true" ]; then
                    sddm_feature="true"
                else
                    step_warn "Existing display manager detected: keeping it and disabling SDDM."
                    sddm_feature="false"
                fi
            fi
        fi

        local hyprland_url="${RHYTHM_FLAKE_URL:-github:rhythmcreative/hyprland}"
        if [ -z "${RHYTHM_FLAKE_URL:-}" ] && [ "${RHYTHM_DEV:-0}" = "1" ] && [ -d "$repo/.git" ]; then
            hyprland_url="path:$repo"
        fi

        sudo -v || { echo "ERROR: sudo authentication needed."; exit 1; }

        section "System configuration (greeter, fonts, portals, audio, apps)"

        local host host_attr=""
        host=$(hostname 2>/dev/null || echo "nixos")
        [ -z "$host" ] && host="nixos"
        if [ "$host" != "nixos" ] && [ "$host" != "default" ]; then
            host_attr="        \"$host\" = sys;"
        fi

        # The generated flake, compared by content so re-runs are no-ops.
        local new_sys_flake sys_stamp
        new_sys_flake=$(mktemp)
        cat > "$new_sys_flake" << EOF3
{
  description = "Rhythm Hyprland desktop for NixOS (written by install.sh)";

  # Pinned to the release this machine was installed with, not
  # nixos-unstable: the installer must not drag the whole system across a
  # channel jump on its way to installing a desktop.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/$channel";
    hyprland = {
      url = "$hyprland_url";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, hyprland, ... }:
    let
      sys = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          # The machine's own configuration, imported untouched.
          ./configuration.nix
          hyprland.nixosModules.rhythm-hyprland
          {
            rhythm = {
              enable = true;
              username = "$user";
              gpu = "$guess_gpu";
              wallpaper.mode = "$wallpapers";
              features = {
                sddm = $sddm_feature;
                flatpaks = $([ "$flatpaks" = "1" ] && echo true || echo false);
                asus = $([ "$is_asus" = "true" ] && echo true || echo false);
                surface = $([ "$is_surface" = "true" ] && echo true || echo false);
              };
            };
$(if [ "$guess_gpu" = "nvidia" ]; then printf '            nixpkgs.config.allowUnfree = true;\n'; fi)
$(if [ "$enable_steam" = "true" ]; then printf '            programs.steam.enable = true;\n            nixpkgs.config.allowUnfree = true;\n'; fi)
            # This is a flake now, so make sure the next rebuild does not need
            # --extra-experimental-features to work.
            nix.settings.experimental-features = [ "nix-command" "flakes" ];
            # SSH server on by default (port 22 opens automatically), same as the
            # Arch installer leaves it.
            services.openssh.enable = true;
            # home-manager is deliberately NOT enabled here: the user scope is
            # the standalone flake in ~/.config/home-manager. Turning on
            # home-manager.users as well would give every file two owners and
            # two conflicting activations.
          }
        ];
      };
    in {
      nixosConfigurations = {
        nixos = sys;
        default = sys;
${host_attr}
      };
    };
}
EOF3

        if [ -e "$etc_dir/flake.nix" ] && cmp -s "$new_sys_flake" "$etc_dir/flake.nix"; then
            rm -f "$new_sys_flake"
            step_item "System flake already up to date, left untouched."
        else
            if [ -e "$etc_dir/flake.nix" ] || [ -e "$etc_dir/flake.lock" ]; then
                sys_stamp=$(date +%Y%m%d-%H%M%S)
                sudo mkdir -p "$etc_dir.bak-$sys_stamp"
                sudo cp -f "$etc_dir/flake.nix" "$etc_dir/flake.lock" \
                    "$etc_dir.bak-$sys_stamp/" 2>/dev/null || true
                step_ok "Previous system flake backed up to $etc_dir.bak-$sys_stamp."
            fi
            sudo cp -f "$new_sys_flake" "$etc_dir/flake.nix"
            sudo chmod 644 "$etc_dir/flake.nix"
            rm -f "$new_sys_flake"
            step_ok "Wrote $etc_dir/flake.nix (nixpkgs pinned to $channel)."
        fi

        if [ -d "$etc_dir/.git" ]; then
            sudo git -C "$etc_dir" add -A 2>/dev/null || true
        fi

        # The old hand-written stub enabled SDDM and programs.hyprland itself.
        # The module does both, so leaving the import in place would have two
        # definitions fighting over the display manager and the session entry.
        if grep -q 'rhythm-sddm\.nix' "$etc_dir/configuration.nix" 2>/dev/null; then
            sudo cp -f "$etc_dir/configuration.nix" \
                "$etc_dir/configuration.nix.bak-$(date +%Y%m%d-%H%M%S)"
            sudo sed -i '/rhythm-sddm\.nix/d' "$etc_dir/configuration.nix"
            step_ok "Removed the old ./rhythm-sddm.nix stub (the module covers it)."
        fi

        # Locked so nixos-rebuild does not hit dirty lock or permission issues
        sudo env NIX_CONFIG="experimental-features = nix-command flakes" \
            nix flake lock --update-input hyprland "$etc_dir" >>"$LOG_FILE" 2>&1 \
            || step_warn "Could not pre-lock $etc_dir; nixos-rebuild will do it."
        sudo chmod 644 "$etc_dir/flake.lock" 2>/dev/null || true
        step_ok "Flake inputs locked (nixpkgs $channel + latest desktop)."

        # nixos-rebuild prints its own progress, but it is the longest step of
        # the whole install, so it gets the same treatment as the user half.
        step_item "Tip: to view system rebuild progress in another terminal, run: tail -f \"$LOG_FILE\""
        if ! nixos_spin "Rebuilding the system (first run downloads several GB)..." -- \
            sudo env NIX_CONFIG="experimental-features = nix-command flakes
max-jobs = auto
cores = 0
http-connections = 50" \
            nixos-rebuild switch --max-jobs auto --cores 0 --flake "$etc_dir#nixos"; then
            step_warn "nixos-rebuild failed. Nothing was switched; your previous"
            step_warn "generation is still the live one. Last lines of $LOG_FILE:"
            tail -n 20 "$LOG_FILE" >&2 2>/dev/null || true
            step_warn "Fix it and re-run, or rebuild by hand:"
            step_warn "  sudo nixos-rebuild switch --flake $etc_dir#nixos"
            return 1
        fi
        step_ok "System rebuilt: SDDM astronaut greeter, Nerd Fonts, portals, PipeWire denoise, desktop apps."


        if sudo systemctl restart display-manager.service 2>/dev/null; then
            step_ok "Greeter is up: log out and pick Hyprland."
        else
            step_item "Could not restart the greeter live; reboot and pick Hyprland."
        fi
        step_item "Groups (video, render, input, audio) apply on your next login."
    }
    # Todo lo que salga de aqui (incluido el build de varios GB) queda en el
    # log que la trampa de errores cita al final.
    rhythm_nixos_log() {
        [ -n "${LOG_FILE:-}" ] || return 0
        "$@" 2>&1 | tee -a "$LOG_FILE"
        return "${PIPESTATUS[0]}"
    }

    rhythm_nixos_log install_nixos "$@"
    nixos_ret=$?
    # Drain any remaining bytes from pipe (e.g. curl | bash) so curl doesn't encounter EPIPE (error 23)
    if [ ! -t 0 ]; then
        cat >/dev/null 2>&1 || true
    fi
    exit "$nixos_ret"
fi

# Detect operating system
DISTRO="unknown"
if [ -f /etc/arch-release ] || grep -qi 'ID=.*arch' /etc/os-release 2>/dev/null; then
    DISTRO="arch"
elif [ -f /etc/fedora-release ] || grep -qi 'ID=.*fedora' /etc/os-release 2>/dev/null; then
    DISTRO="fedora"
elif grep -qi 'ID=.*ubuntu' /etc/os-release 2>/dev/null; then
    DISTRO="ubuntu"
elif [ -f /etc/debian_version ] || grep -qi 'ID=.*debian' /etc/os-release 2>/dev/null; then
    DISTRO="debian"
elif [ -f /etc/alpine-release ] || grep -qi 'ID=.*alpine' /etc/os-release 2>/dev/null; then
    DISTRO="alpine"
elif [ -f /etc/SuSE-release ] || grep -qiE 'ID=.*(opensuse|suse)' /etc/os-release 2>/dev/null; then
    DISTRO="opensuse"
fi
[ -n "${RHYTHM_DISTRO_OVERRIDE:-}" ] && DISTRO="$RHYTHM_DISTRO_OVERRIDE"

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
        if [ "$DISTRO" = "fedora" ]; then
            sudo dnf install -y git
        elif [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "ubuntu" ]; then
            sudo apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git
        elif [ "$DISTRO" = "alpine" ]; then
            sudo apk add --no-cache git
        elif [ "$DISTRO" = "opensuse" ]; then
            sudo zypper --non-interactive install git
        else
            sudo pacman -S --needed --noconfirm git
        fi
    fi
    # clone necesita que el destino no exista, y mktemp ya lo ha creado.
    rmdir "$CLONE_DIR"
    git clone --depth=1 https://github.com/rhythmcreative/hyprland.git "$CLONE_DIR"
    # Drain any remaining bytes from pipe (e.g. curl | bash) so curl doesn't encounter EPIPE (error 23)
    cat >/dev/null 2>&1 || true
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
ENABLE_SDDM=""
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
Rhythm Hyprland Installer (Omarchy Style) - Arch Linux & Fedora

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
  --sddm                     Set SDDM (Astronaut theme) as default display manager
  --no-sddm, --skip-sddm     Keep existing display manager without setting SDDM
  --replace-configs-all      Directly overwrite existing configs without .bak backups
  --resume                   Continue an interrupted install: steps already done
                             are skipped, and configs that are already identical
                             to the repo are left alone instead of being backed
                             up and overwritten
  -h, --help                 Show this help message and exit

One-line installation:
  curl -fsSL https://raw.githubusercontent.com/rhythmcreative/hyprland/main/install.sh | bash

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
        --sddm)
            ENABLE_SDDM=true
            shift
            ;;
        --no-sddm|--skip-sddm)
            ENABLE_SDDM=false
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

# Geometry, Tokyo Night gum theme and the shared helpers. Defined near the top
# of the file (the NixOS branch needs them too), initialised here so the Arch
# path keeps its exact previous presentation.
rhythm_presentation_init "$DOTFILES_DIR"

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

    if [ "$DISTRO" != "arch" ] && [ "$DISTRO" != "fedora" ] && [ "$DISTRO" != "debian" ] && [ "$DISTRO" != "ubuntu" ] && [ "$DISTRO" != "alpine" ] && [ "$DISTRO" != "opensuse" ]; then
        # NixOS exits at the top of this script with directions to the flake.
        # Anything else landing here is a distro this installer knows nothing
        # about: no pacman, no dnf, no apt, no apk, no zypper, no supported layout.
        echo "ERROR: This installer is only compatible with Arch Linux, Fedora, Debian, Ubuntu, Alpine, and openSUSE."
        exit 1
    fi

    # Network verification
    if ! ping -c 1 1.1.1.1 >/dev/null 2>&1 && ! curl -s --head https://github.com >/dev/null 2>&1; then
        echo "ERROR: No active internet connection detected. Please connect before continuing."
        exit 1
    fi

    if [ "$DISTRO" = "arch" ]; then
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
    elif [ "$DISTRO" = "fedora" ]; then
        # DNF optimizations (fastestmirror & max_parallel_downloads)
        if [ -f /etc/dnf/dnf.conf ]; then
            if ! grep -q "^max_parallel_downloads" /etc/dnf/dnf.conf; then
                echo "max_parallel_downloads=10" | sudo tee -a /etc/dnf/dnf.conf >/dev/null
            fi
            if ! grep -q "^fastestmirror" /etc/dnf/dnf.conf; then
                echo "fastestmirror=True" | sudo tee -a /etc/dnf/dnf.conf >/dev/null
            fi
        fi

        # Setup Charm official repository for gum
        if ! command -v gum >/dev/null 2>&1; then
            if [ ! -f /etc/yum.repos.d/charm.repo ]; then
                sudo rpm --import https://repo.charm.sh/yum/gpg.key >> "$LOG_FILE" 2>&1 || true
                sudo tee /etc/yum.repos.d/charm.repo >/dev/null << 'CHARM_EOF' || true
[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key
CHARM_EOF
            fi
        fi

        # Ensure bootstrap tools exist (supporting both DNF 4 and DNF 5)
        local dnf_bootstrap=(git curl sudo zsh fzf stow tar xz dnf-plugins-core)
        sudo dnf install -y "${dnf_bootstrap[@]}" 'dnf5-command(copr)' 'dnf5-plugins' gum >> "$LOG_FILE" 2>&1 || true

        # Standalone binary fallback for gum if repo install was bypassed
        if ! command -v gum >/dev/null 2>&1; then
            local tmp_gum
            tmp_gum=$(mktemp "${TMPDIR:-/tmp}/gum.XXXXXX.tar.gz")
            if curl -fsSL --connect-timeout 10 "https://github.com/charmbracelet/gum/releases/download/v0.14.5/gum_0.14.5_linux_x86_64.tar.gz" -o "$tmp_gum" >> "$LOG_FILE" 2>&1; then
                sudo tar -xzf "$tmp_gum" -C /usr/local/bin/ --strip-components=1 --wildcards '*/gum' >> "$LOG_FILE" 2>&1 || \
                sudo tar -xzf "$tmp_gum" -C /usr/local/bin/ gum >> "$LOG_FILE" 2>&1 || true
                sudo chmod +x /usr/local/bin/gum 2>/dev/null || true
            fi
            rm -f "$tmp_gum"
        fi

        # Enable RPM Fusion free & nonfree
        local fedora_ver
        fedora_ver=$(rpm -E %fedora 2>/dev/null || echo "41")
        sudo dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm" \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_ver}.noarch.rpm" >> "$LOG_FILE" 2>&1 || true

        # Enable essential Hyprland and ecosystem COPRs
        sudo dnf copr enable -y nett00n/hyprland >> "$LOG_FILE" 2>&1 || true
        sudo dnf copr enable -y errornointernet/quickshell >> "$LOG_FILE" 2>&1 || true
        sudo dnf copr enable -y tofik/nwg-shell >> "$LOG_FILE" 2>&1 || true
        sudo dnf copr enable -y alebastr/sway-extras >> "$LOG_FILE" 2>&1 || true
        sudo dnf copr enable -y scottames/awww >> "$LOG_FILE" 2>&1 || true
        sudo dnf copr enable -y solopasha/hyprland >> "$LOG_FILE" 2>&1 || true

        # Refresh metadata cache
        sudo dnf makecache >> "$LOG_FILE" 2>&1 || true
    elif [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "ubuntu" ]; then
        # Handle background unattended-upgrades / apt-daily lock
        if systemctl is-active --quiet apt-daily.service 2>/dev/null || systemctl is-active --quiet apt-daily-upgrade.service 2>/dev/null || pgrep -x apt-get >/dev/null 2>&1 || pgrep -x dpkg >/dev/null 2>&1; then
            step_item "Waiting for background package updates (apt-daily) to release lock..."
            sudo systemctl stop apt-daily.service apt-daily-upgrade.service 2>/dev/null || true
            local wait_count=0
            while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || pgrep -x apt-get >/dev/null 2>&1 || pgrep -x dpkg >/dev/null 2>&1; do
                sleep 2
                wait_count=$((wait_count + 2))
                [ $wait_count -ge 60 ] && break
            done
        fi
        echo 'DPkg::Lock::Timeout "60";' | sudo tee /etc/apt/apt.conf.d/99wait-for-lock >/dev/null 2>&1 || true

        if [ "$DISTRO" = "ubuntu" ]; then
            # Ensure software-properties-common is available for PPAs and universe repo is enabled
            sudo apt-get update -y >> "$LOG_FILE" 2>&1 || true
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common >> "$LOG_FILE" 2>&1 || true
            sudo add-apt-repository -y universe >> "$LOG_FILE" 2>&1 || true
            # Enable community Hyprland & Quickshell PPAs for Ubuntu
            sudo add-apt-repository -y ppa:cppiber/hyprland >> "$LOG_FILE" 2>&1 || true
            sudo add-apt-repository -y ppa:avengemedia/danklinux >> "$LOG_FILE" 2>&1 || true
            sudo apt-get update -y >> "$LOG_FILE" 2>&1 || true
        fi

        # Setup Charm repository for gum on Debian/Ubuntu
        if ! command -v gum >/dev/null 2>&1; then
            sudo mkdir -p /etc/apt/keyrings
            if curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor --yes -o /etc/apt/keyrings/charm.gpg >> "$LOG_FILE" 2>&1; then
                echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list > /dev/null
            fi
        fi

        # Ensure bootstrap tools exist
        local debian_bootstrap=(git curl sudo zsh fzf stow tar xz-utils build-essential ca-certificates gnupg python3 python3-pip python3-venv pipx)
        sudo apt-get update -y >> "$LOG_FILE" 2>&1 || true
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${debian_bootstrap[@]}" gum >> "$LOG_FILE" 2>&1 || true

        # Standalone binary fallback for gum if repo install had issues
        if ! command -v gum >/dev/null 2>&1; then
            local tmp_gum
            tmp_gum=$(mktemp "${TMPDIR:-/tmp}/gum.XXXXXX.tar.gz")
            if curl -fsSL --connect-timeout 10 "https://github.com/charmbracelet/gum/releases/download/v0.14.5/gum_0.14.5_linux_x86_64.tar.gz" -o "$tmp_gum" >> "$LOG_FILE" 2>&1; then
                sudo tar -xzf "$tmp_gum" -C /usr/local/bin/ --strip-components=1 --wildcards '*/gum' >> "$LOG_FILE" 2>&1 || \
                sudo tar -xzf "$tmp_gum" -C /usr/local/bin/ gum >> "$LOG_FILE" 2>&1 || true
                sudo chmod +x /usr/local/bin/gum 2>/dev/null || true
            fi
            rm -f "$tmp_gum"
        fi
    elif [ "$DISTRO" = "alpine" ]; then
        # Ensure community repo is active in /etc/apk/repositories
        if [ -f /etc/apk/repositories ]; then
            if grep -q '^#.*\/community' /etc/apk/repositories; then
                sudo sed -i 's/^#\(.*\/community\)/\1/' /etc/apk/repositories
            elif ! grep -q '\/community' /etc/apk/repositories; then
                local alpine_ver
                alpine_ver=$(cut -d. -f1,2 /etc/alpine-release 2>/dev/null || echo "edge")
                if [ "$alpine_ver" = "edge" ]; then
                    echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" | sudo tee -a /etc/apk/repositories >/dev/null
                else
                    echo "http://dl-cdn.alpinelinux.org/alpine/v${alpine_ver}/community" | sudo tee -a /etc/apk/repositories >/dev/null
                fi
            fi
        fi

        sudo apk update >> "$LOG_FILE" 2>&1 || true

        # Ensure bootstrap tools exist
        local alpine_bootstrap=(git curl sudo zsh fzf stow tar xz coreutils build-base bash py3-pip shadow ca-certificates)
        sudo apk add --no-cache "${alpine_bootstrap[@]}" >> "$LOG_FILE" 2>&1 || true

        # Try installing gum directly via apk (testing/edge or newer releases)
        sudo apk add --no-cache gum >> "$LOG_FILE" 2>&1 || true

        # Standalone binary fallback for gum if not in repositories
        if ! command -v gum >/dev/null 2>&1; then
            local tmp_gum
            tmp_gum=$(mktemp "${TMPDIR:-/tmp}/gum.XXXXXX.tar.gz")
            if curl -fsSL --connect-timeout 10 "https://github.com/charmbracelet/gum/releases/download/v0.14.5/gum_0.14.5_linux_x86_64.tar.gz" -o "$tmp_gum" >> "$LOG_FILE" 2>&1; then
                sudo tar -xzf "$tmp_gum" -C /usr/local/bin/ --strip-components=1 --wildcards '*/gum' >> "$LOG_FILE" 2>&1 || \
                sudo tar -xzf "$tmp_gum" -C /usr/local/bin/ gum >> "$LOG_FILE" 2>&1 || true
                sudo chmod +x /usr/local/bin/gum 2>/dev/null || true
            fi
            rm -f "$tmp_gum"
        fi
    elif [ "$DISTRO" = "opensuse" ]; then
        # Ensure Packman repository is enabled for multimedia codecs and tools if possible
        sudo zypper --non-interactive refresh >> "$LOG_FILE" 2>&1 || true

        # Ensure bootstrap tools exist
        local suse_bootstrap=(git curl zsh fzf stow tar xz which gzip shadow python3 python3-pipx)
        sudo zypper --non-interactive install --no-confirm "${suse_bootstrap[@]}" >> "$LOG_FILE" 2>&1 || true

        # Standalone binary fallback for gum on openSUSE
        if ! command -v gum >/dev/null 2>&1; then
            local tmp_gum
            tmp_gum=$(mktemp "${TMPDIR:-/tmp}/gum.XXXXXX.tar.gz")
            if curl -fsSL --connect-timeout 10 "https://github.com/charmbracelet/gum/releases/download/v0.14.5/gum_0.14.5_linux_x86_64.tar.gz" -o "$tmp_gum" >> "$LOG_FILE" 2>&1; then
                sudo tar -xzf "$tmp_gum" -C /usr/local/bin/ --strip-components=1 --wildcards '*/gum' >> "$LOG_FILE" 2>&1 || \
                sudo tar -xzf "$tmp_gum" -C /usr/local/bin/ gum >> "$LOG_FILE" 2>&1 || true
                sudo chmod +x /usr/local/bin/gum 2>/dev/null || true
            fi
            rm -f "$tmp_gum"
        fi
    fi
}

# --- AUR HELPER SETUP (YAY) ---
install_yay() {
    if [ "$DISTRO" = "fedora" ] || [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "ubuntu" ] || [ "$DISTRO" = "alpine" ] || [ "$DISTRO" = "opensuse" ]; then
        return 0
    fi
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
    fi

    if [ "$DISTRO" = "fedora" ]; then
        if [ "$IS_NVIDIA" = true ]; then
            step_item "Preparing Fedora RPM Fusion & Akmod driver for NVIDIA..."
            sudo dnf install -y kernel-devel kernel-headers akmod-nvidia xorg-x11-drv-nvidia-cuda libva-nvidia-driver >> "$LOG_FILE" 2>&1 || step_warn "Could not install some NVIDIA RPM packages."
        fi
        if [[ $GPU_INFO == *"Advanced Micro Devices"* ]] || [[ $GPU_INFO == *"ATI"* ]]; then
            step_item "AMD GPU detected. Adding Mesa and Vulkan drivers..."
            sudo dnf install -y mesa-dri-drivers mesa-vulkan-drivers vulkan-tools >> "$LOG_FILE" 2>&1 || true
        fi
        if [[ $GPU_INFO == *"Intel"* ]]; then
            step_item "Intel GPU detected. Adding hardware acceleration drivers..."
            sudo dnf install -y intel-media-driver libva-intel-driver vulkan-tools >> "$LOG_FILE" 2>&1 || true
        fi

        local SYS_VENDOR PROD_NAME
        SYS_VENDOR=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)
        PROD_NAME=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)

        if [[ $SYS_VENDOR == *"ASUSTeK"* ]]; then
            step_item "ASUS hardware detected. Enabling COPR and adding asusctl..."
            sudo dnf copr enable -y lukenukem/asus-linux >> "$LOG_FILE" 2>&1 || true
            sudo dnf install -y asusctl supergfxctl rog-control-center >> "$LOG_FILE" 2>&1 || true
        fi
        if [[ $PROD_NAME == *"Surface"* ]]; then
            step_item "Microsoft Surface detected. Adding surface kernel & utilities..."
            sudo dnf config-manager --add-repo=https://pkg.surfacelinux.com/fedora/linux-surface.repo >> "$LOG_FILE" 2>&1 || true
            sudo dnf install -y kernel-surface iptsd >> "$LOG_FILE" 2>&1 || true
        fi

        if [ "$IS_NVIDIA" = true ]; then
            section "NVIDIA System & Wayland Optimization (Fedora)"
            step_item "Configuring DRM kernel modesetting (modeset=1, fbdev=1)..."
            sudo mkdir -p /etc/modprobe.d
            cat << 'EOF' | sudo tee /etc/modprobe.d/nvidia.conf > /dev/null
# Enable Direct Rendering Manager (DRM) Kernel Mode Setting and Framebuffer Device for Wayland & Hyprland
options nvidia-drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia NVreg_TemporaryFilePath=/var/tmp
EOF
            step_item "Enabling NVIDIA power management & suspend services..."
            sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service >> "$LOG_FILE" 2>&1 || true

            step_item "Configuring dracut for early NVIDIA KMS..."
            sudo mkdir -p /etc/dracut.conf.d
            cat << 'EOF' | sudo tee /etc/dracut.conf.d/nvidia.conf > /dev/null
add_drivers+=" nvidia nvidia_modeset nvidia_uvm nvidia_drm "
EOF
            step_item "Rebuilding initramfs with dracut..."
            sudo dracut --force >> "$LOG_FILE" 2>&1 || step_warn "dracut rebuild had warnings."
            step_ok "NVIDIA system optimization complete."
        fi
        step_ok "Hardware drivers configured."
        return 0
    elif [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "ubuntu" ]; then
        if [ "$IS_NVIDIA" = true ]; then
            step_item "Preparing NVIDIA DKMS driver..."
            local kernel_headers="linux-headers-$(uname -r)"
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$kernel_headers" linux-headers-generic linux-headers-amd64 nvidia-driver nvidia-kernel-dkms nvidia-vulkan-icd libva-nvidia-driver >> "$LOG_FILE" 2>&1 || step_warn "Could not install some NVIDIA Debian/Ubuntu packages."
        fi
        if [[ $GPU_INFO == *"Advanced Micro Devices"* ]] || [[ $GPU_INFO == *"ATI"* ]]; then
            step_item "AMD GPU detected. Adding Mesa and Vulkan drivers..."
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mesa-va-drivers mesa-vulkan-drivers vulkan-tools libvulkan1 >> "$LOG_FILE" 2>&1 || true
        fi
        if [[ $GPU_INFO == *"Intel"* ]]; then
            step_item "Intel GPU detected. Adding hardware acceleration drivers..."
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y intel-media-va-driver-non-free intel-media-va-driver i965-va-driver-shaders i965-va-driver mesa-vulkan-drivers vulkan-tools libvulkan1 >> "$LOG_FILE" 2>&1 || true
        fi

        if [ "$IS_NVIDIA" = true ]; then
            section "NVIDIA System & Wayland Optimization ($DISTRO)"
            step_item "Configuring DRM kernel modesetting (modeset=1, fbdev=1)..."
            sudo mkdir -p /etc/modprobe.d
            cat << 'EOF' | sudo tee /etc/modprobe.d/nvidia.conf > /dev/null
# Enable Direct Rendering Manager (DRM) Kernel Mode Setting and Framebuffer Device for Wayland & Hyprland
options nvidia-drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia NVreg_TemporaryFilePath=/var/tmp
EOF
            step_item "Enabling NVIDIA power management & suspend services..."
            sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service >> "$LOG_FILE" 2>&1 || true
            step_item "Updating initramfs..."
            sudo update-initramfs -u >> "$LOG_FILE" 2>&1 || step_warn "initramfs update had warnings."
            step_ok "NVIDIA system optimization complete."
        fi
        step_ok "Hardware drivers configured."
        return 0
    elif [ "$DISTRO" = "alpine" ]; then
        if [ "$IS_NVIDIA" = true ]; then
            step_item "Preparing Alpine drivers for NVIDIA..."
            sudo apk add --no-cache mesa-dri-gallium mesa-va-gallium >> "$LOG_FILE" 2>&1 || true
        fi
        if [[ $GPU_INFO == *"Advanced Micro Devices"* ]] || [[ $GPU_INFO == *"ATI"* ]]; then
            step_item "AMD GPU detected. Adding Mesa and Vulkan drivers..."
            sudo apk add --no-cache mesa-dri-gallium mesa-va-gallium vulkan-loader mesa-vulkan-ati >> "$LOG_FILE" 2>&1 || true
        fi
        if [[ $GPU_INFO == *"Intel"* ]]; then
            step_item "Intel GPU detected. Adding hardware acceleration drivers..."
            sudo apk add --no-cache mesa-dri-gallium intel-media-driver libva-intel-driver mesa-vulkan-intel >> "$LOG_FILE" 2>&1 || true
        fi

        if [ "$IS_NVIDIA" = true ]; then
            section "NVIDIA System & Wayland Optimization (Alpine)"
            step_item "Configuring DRM kernel modesetting (modeset=1, fbdev=1)..."
            sudo mkdir -p /etc/modprobe.d
            cat << 'EOF' | sudo tee /etc/modprobe.d/nvidia.conf > /dev/null
# Enable Direct Rendering Manager (DRM) Kernel Mode Setting and Framebuffer Device for Wayland & Hyprland
options nvidia-drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia NVreg_TemporaryFilePath=/var/tmp
EOF
            step_ok "NVIDIA system optimization complete."
        fi
        step_ok "Hardware drivers configured."
        return 0
    elif [ "$DISTRO" = "opensuse" ]; then
        if [ "$IS_NVIDIA" = true ]; then
            step_item "Preparing openSUSE NVIDIA drivers..."
            sudo zypper --non-interactive install --no-confirm kernel-devel kernel-default-devel >> "$LOG_FILE" 2>&1 || true
        fi
        if [[ $GPU_INFO == *"Advanced Micro Devices"* ]] || [[ $GPU_INFO == *"ATI"* ]]; then
            step_item "AMD GPU detected. Adding Mesa and Vulkan drivers..."
            sudo zypper --non-interactive install --no-confirm Mesa-dri libvulkan_radeon vulkan-tools >> "$LOG_FILE" 2>&1 || true
        fi
        if [[ $GPU_INFO == *"Intel"* ]]; then
            step_item "Intel GPU detected. Adding hardware acceleration drivers..."
            sudo zypper --non-interactive install --no-confirm intel-media-driver libva-intel-driver libvulkan_intel vulkan-tools >> "$LOG_FILE" 2>&1 || true
        fi

        if [ "$IS_NVIDIA" = true ]; then
            section "NVIDIA System & Wayland Optimization (openSUSE)"
            step_item "Configuring DRM kernel modesetting (modeset=1, fbdev=1)..."
            sudo mkdir -p /etc/modprobe.d
            cat << 'EOF' | sudo tee /etc/modprobe.d/nvidia.conf > /dev/null
# Enable Direct Rendering Manager (DRM) Kernel Mode Setting and Framebuffer Device for Wayland & Hyprland
options nvidia-drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia NVreg_TemporaryFilePath=/var/tmp
EOF
            step_item "Enabling NVIDIA power management & suspend services..."
            sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service >> "$LOG_FILE" 2>&1 || true
            step_ok "NVIDIA system optimization complete."
        fi
        step_ok "Hardware drivers configured."
        return 0
    fi

    if [ "$IS_NVIDIA" = true ]; then
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
    if [ "$DISTRO" = "fedora" ]; then
        sudo dnf install -y rust cargo pkgconf-pkg-config gtk4-devel gtk4-layer-shell-devel grim >> "$LOG_FILE" 2>&1 || true
    elif [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "ubuntu" ]; then
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y cargo rustc pkg-config libgtk-4-dev grim libgtk4-layer-shell-dev >> "$LOG_FILE" 2>&1 || \
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y cargo rustc pkg-config libgtk-4-dev grim >> "$LOG_FILE" 2>&1 || true

        # Build gtk4-layer-shell from source if not available in repos (e.g. Debian 12 Bookworm)
        if ! pkg-config --exists gtk4-layer-shell-0 2>/dev/null; then
            step_item "Building gtk4-layer-shell from source for $DISTRO..."
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y meson ninja-build libwayland-dev wayland-protocols >> "$LOG_FILE" 2>&1 || true
            if command -v meson >/dev/null 2>&1 && command -v ninja >/dev/null 2>&1; then
                local gls_dir
                gls_dir=$(mktemp -d "${TMPDIR:-/tmp}/gtk4-layer-shell.XXXXXXXX")
                if git clone --depth=1 https://github.com/wmww/gtk4-layer-shell.git "$gls_dir" >> "$LOG_FILE" 2>&1; then
                    (cd "$gls_dir" && meson setup --prefix=/usr -Dexamples=false -Ddocs=false -Dtests=false build >> "$LOG_FILE" 2>&1 && \
                     ninja -C build >> "$LOG_FILE" 2>&1 && \
                     sudo ninja -C build install >> "$LOG_FILE" 2>&1 && \
                     sudo ldconfig 2>/dev/null || true)
                fi
                rm -rf "$gls_dir"
            fi
        fi
        export PKG_CONFIG_PATH="/usr/local/lib/x86_64-linux-gnu/pkgconfig:/usr/local/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:$PKG_CONFIG_PATH"
        export LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"
    elif [ "$DISTRO" = "alpine" ]; then
        sudo apk add --no-cache rust cargo pkgconf gtk4.0-dev gtk4-layer-shell-dev grim >> "$LOG_FILE" 2>&1 || true
    elif [ "$DISTRO" = "opensuse" ]; then
        sudo zypper --non-interactive install --no-confirm rust cargo pkg-config gtk4-devel gtk4-layer-shell-devel grim >> "$LOG_FILE" 2>&1 || true
    else
        yay -S --needed --noconfirm rust pkgconf gtk4 gtk4-layer-shell grim >> "$LOG_FILE" 2>&1 || true
    fi

    [ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env" 2>/dev/null || true
    export PATH="$HOME/.cargo/bin:$PATH"

    if ! command -v cargo > /dev/null 2>&1; then
        if [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "ubuntu" ]; then
            step_item "Installing Cargo & Rust toolchain..."
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y cargo rustc >> "$LOG_FILE" 2>&1 || true
            if ! command -v cargo > /dev/null 2>&1; then
                step_item "Installing Cargo via rustup fallback..."
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile minimal >> "$LOG_FILE" 2>&1 || true
                [ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env" 2>/dev/null || true
                export PATH="$HOME/.cargo/bin:$PATH"
            fi
        elif [ "$DISTRO" = "alpine" ]; then
            step_item "Installing Cargo & Rust on Alpine..."
            sudo apk add --no-cache cargo rust >> "$LOG_FILE" 2>&1 || true
        elif [ "$DISTRO" = "opensuse" ]; then
            step_item "Installing Cargo & Rust on openSUSE..."
            sudo zypper --non-interactive install --no-confirm cargo rust >> "$LOG_FILE" 2>&1 || true
        fi
    fi

    if ! command -v cargo > /dev/null 2>&1; then
        step_warn "Cargo not found. Skipping rust-dock build."
        return 0
    fi

    if ! pkg-config --exists gtk4-layer-shell-0 2>/dev/null; then
        step_warn "gtk4-layer-shell not found. Skipping rust-dock build (falling back to Waybar dock)."
        return 0
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
    rhythm_spin "Compiling rust-dock (release)..." -- \
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

# --- VISUAL ASSETS, ICONS & FONTS (FEDORA & DEBIAN) ---
install_themes_and_fonts() {
    section "Visual Assets, Icons & Typography"

    # 1. JetBrains Mono Nerd Font
    if ! fc-list : family 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
        step_item "Installing JetBrains Mono Nerd Font..."
        local font_dir="/usr/local/share/fonts/JetBrainsMonoNerd"
        sudo mkdir -p "$font_dir"
        local tmp_font
        tmp_font=$(mktemp "${TMPDIR:-/tmp}/jetbrains-font.XXXXXX.tar.xz")
        if curl -fsSL --connect-timeout 15 --max-time 180 \
            "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz" \
            -o "$tmp_font" >> "$LOG_FILE" 2>&1; then
            sudo tar -xf "$tmp_font" -C "$font_dir" >> "$LOG_FILE" 2>&1
            sudo fc-cache -f >> "$LOG_FILE" 2>&1 || true
            step_ok "JetBrains Mono Nerd Font installed."
        else
            step_warn "Could not download JetBrains Mono Nerd Font; system fonts will be used."
        fi
        rm -f "$tmp_font"
    else
        step_ok "JetBrains Mono Nerd Font already present."
    fi

    # 2. Tela Circle Icon Theme (All variants)
    if [ ! -d "/usr/share/icons/Tela-circle" ] && [ ! -d "$HOME/.local/share/icons/Tela-circle" ]; then
        step_item "Installing Tela Circle Icon Theme (All Variants)..."
        local tmp_tela
        tmp_tela=$(mktemp "${TMPDIR:-/tmp}/tela-circle.XXXXXX.tar.gz")
        if curl -fsSL --connect-timeout 15 --max-time 180 \
            "https://github.com/rhythmcreative/hyprland/releases/download/v0.25/tela-circle-icon-theme-all.tar.gz" \
            -o "$tmp_tela" >> "$LOG_FILE" 2>&1; then
            sudo mkdir -p /usr/share/icons
            sudo tar -xzf "$tmp_tela" -C /usr/share/icons/ >> "$LOG_FILE" 2>&1
            step_ok "Tela Circle Icon Theme deployed."
        else
            step_item "Installing Tela Circle Icon Theme from upstream..."
            local tela_src
            tela_src=$(mktemp -d "${TMPDIR:-/tmp}/tela-circle.XXXXXXXX")
            if git clone --depth=1 https://github.com/vinceliuice/Tela-circle-icon-theme.git "$tela_src" >> "$LOG_FILE" 2>&1; then
                sudo bash "$tela_src/install.sh" -a >> "$LOG_FILE" 2>&1 && step_ok "Tela Circle Icon Theme deployed." || step_warn "Could not install Tela Circle theme."
            else
                step_warn "Could not download Tela Circle theme."
            fi
            rm -rf "$tela_src"
        fi
        rm -f "$tmp_tela"
    else
        step_ok "Tela Circle Icon Theme already present."
    fi

    # 3. Bibata Cursor Theme
    if [ ! -d "/usr/share/icons/Bibata-Modern-Ice" ] && [ ! -d "$HOME/.local/share/icons/Bibata-Modern-Ice" ]; then
        step_item "Installing Bibata Modern Ice Cursor..."
        local tmp_bibata
        tmp_bibata=$(mktemp "${TMPDIR:-/tmp}/bibata.XXXXXX.tar.xz")
        if curl -fsSL --connect-timeout 15 --max-time 60 \
            "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Ice.tar.xz" \
            -o "$tmp_bibata" >> "$LOG_FILE" 2>&1 || \
           curl -fsSL --connect-timeout 15 --max-time 60 \
            "https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Ice.tar.xz" \
            -o "$tmp_bibata" >> "$LOG_FILE" 2>&1; then
            sudo mkdir -p /usr/share/icons
            sudo tar -xf "$tmp_bibata" -C /usr/share/icons/ >> "$LOG_FILE" 2>&1
            step_ok "Bibata Cursor Theme deployed."
        else
            step_warn "Could not download Bibata cursor theme."
        fi
        rm -f "$tmp_bibata"
    else
        step_ok "Bibata Cursor Theme already present."
    fi

    # 4. Pywal (Command-line color palette engine)
    if ! command -v wal >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/wal" ]; then
        step_item "Setting up Pywal..."
        if [ "$DISTRO" = "alpine" ]; then
            sudo apk add --no-cache py3-pywal >> "$LOG_FILE" 2>&1 || true
        elif [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "ubuntu" ]; then
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y python3-pip python3-venv pipx >> "$LOG_FILE" 2>&1 || true
        elif [ "$DISTRO" = "opensuse" ]; then
            sudo zypper --non-interactive install --no-confirm python3-pipx >> "$LOG_FILE" 2>&1 || true
        fi
        export PATH="$HOME/.local/bin:$PATH"
        if ! command -v wal >/dev/null 2>&1; then
            pipx install pywal >> "$LOG_FILE" 2>&1 || \
                pipx install --include-deps pywal >> "$LOG_FILE" 2>&1 || \
                pip3 install --break-system-packages --user pywal >> "$LOG_FILE" 2>&1 || \
                pip3 install --user pywal >> "$LOG_FILE" 2>&1 || true
        fi
        if command -v wal >/dev/null 2>&1 || [ -x "$HOME/.local/bin/wal" ]; then
            step_ok "Pywal initialized."
        else
            step_warn "Pywal pip installation encountered warnings."
        fi
    else
        step_ok "Pywal already present."
    fi
}

install_quickshell() {
    if command -v quickshell >/dev/null 2>&1; then
        return 0
    fi
    step_item "Setting up Quickshell..."
    if [ "$DISTRO" = "ubuntu" ]; then
        if sudo add-apt-repository -y ppa:outfoxxed/quickshell >> "$LOG_FILE" 2>&1; then
            sudo apt-get update >> "$LOG_FILE" 2>&1 || true
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y quickshell >> "$LOG_FILE" 2>&1 || true
        fi
    fi

    if command -v quickshell >/dev/null 2>&1; then
        step_ok "Quickshell installed via package manager."
        return 0
    fi

    # Universal portable package fallback (pkgforge anylinux AppImage, works on musl and glibc without FUSE)
    local arch
    arch="$(uname -m 2>/dev/null || echo "x86_64")"
    if [ "$arch" = "x86_64" ] || [ "$arch" = "amd64" ]; then
        arch="x86_64"
    elif [ "$arch" = "aarch64" ] || [ "$arch" = "arm64" ]; then
        arch="aarch64"
    fi

    local tmp_qs="/tmp/quickshell-${arch}.AppImage"
    rm -f "$tmp_qs"
    local dl_url=""
    dl_url=$(curl -sL https://api.github.com/repos/pkgforge-dev/Quickshell-AppImage/releases/latest 2>/dev/null | grep "browser_download_url" | grep "anylinux-${arch}\.AppImage\"" | head -n 1 | cut -d '"' -f 4 || true)
    if [ -z "$dl_url" ]; then
        dl_url="https://github.com/pkgforge-dev/Quickshell-AppImage/releases/latest/download/quickshell-0.3.1-1-anylinux-${arch}.AppImage"
    fi

    if [ -n "$dl_url" ] && curl -fsSL -L "$dl_url" -o "$tmp_qs" >> "$LOG_FILE" 2>&1; then
        if [ -s "$tmp_qs" ]; then
            sudo chmod +x "$tmp_qs"
            sudo install -m 755 "$tmp_qs" /usr/local/bin/quickshell >> "$LOG_FILE" 2>&1 || true
            rm -f "$tmp_qs"
            if command -v quickshell >/dev/null 2>&1; then
                step_ok "Quickshell universal binary installed in /usr/local/bin/quickshell."
                return 0
            fi
        fi
    fi
    rm -f "$tmp_qs"
    step_warn "Quickshell installation was skipped or encountered issues."
    return 1
}

install_starship() {
    if command -v starship >/dev/null 2>&1; then
        return 0
    fi
    step_item "Installing Starship shell prompt..."
    if curl -sS https://starship.rs/install.sh | sh -s -- -y >> "$LOG_FILE" 2>&1; then
        step_ok "Starship installed."
        return 0
    else
        step_warn "Starship installation skipped or failed."
        return 1
    fi
}

# --- SYSTEM PACKAGES DEPLOYMENT ---
step_software() {
    section "Core Packages & System Libraries"

    if [ "$DISTRO" = "fedora" ]; then
        sudo -v

        local FEDORA_CORE_PKGS=(
            hyprland
            hypridle
            hyprlock
            hyprsunset
            hyprpicker
            xdg-desktop-portal-hyprland
            xdg-desktop-portal-gtk
            waybar
            quickshell
            rofi-wayland
            kitty
            zsh
            zsh-autosuggestions
            zsh-syntax-highlighting
            starship
            thunar
            thunar-archive-plugin
            thunar-volman
            file-roller
            gvfs
            tumbler
            ffmpeg
            ffmpegthumbnailer
            poppler-glib
            libgsf
            gwenview
            NetworkManager
            network-manager-applet
            bluez
            bluez-obex
            blueman
            pipewire
            pipewire-pulseaudio
            wireplumber
            pavucontrol
            playerctl
            pamixer
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
            qt5-qtgraphicaleffects
            qt5-qtquickcontrols2
            qt5-qtsvg
            qt5-qtdeclarative
            qt6-qtdeclarative
            qt6-qt5compat
            qt6-qtsvg
            qt6-qtwayland
            qt5ct
            qt6ct
            kvantum
            sddm
            polkit-kde
            plasma-polkit-agent
            gnome-keyring
            nwg-displays
            nwg-look
            cava
            google-noto-fonts-common
            google-noto-sans-cjk-fonts
            google-noto-emoji-fonts
            fontawesome-fonts-all
            rust
            cargo
            pkgconf-pkg-config
            gtk4-devel
            gtk4-layer-shell-devel
            power-profiles-daemon
            upower
            python3
            python3-pip
            python3-pillow
            python3-gobject
            flatpak
            stow
            curl
            wget
            unzip
            jq
            bc
            ImageMagick
            cliphist
            mpv
            htop
            btop
            fastfetch
            inotify-tools
            psmisc
            xdg-user-dirs
            btrfs-progs
        )

        if ! rhythm_install_with_progress "${#FEDORA_CORE_PKGS[@]}" "Installing core packages via dnf..." \
            sudo dnf install -y --skip-broken --allowerasing "${FEDORA_CORE_PKGS[@]}"; then
            local total_f=${#FEDORA_CORE_PKGS[@]}
            local idx=0
            for pkg in "${FEDORA_CORE_PKGS[@]}"; do
                idx=$((idx + 1))
                render_progress_bar "$idx" "$total_f" "Installing $pkg (fallback)..."
                sudo dnf install -y --skip-broken --allowerasing "$pkg" >> "$LOG_FILE" 2>&1 || true
            done
            [ "$total_f" -gt 0 ] && [ -t 1 ] && printf "\n"
        fi

        for extra in awww swww mpvpaper hyprland-guiutils hyprland-qtutils ImageMagick; do
            sudo dnf install -y --skip-broken --allowerasing "$extra" >> "$LOG_FILE" 2>&1 || true
        done
        step_ok "Core packages installed."

        install_themes_and_fonts
        install_quickshell
        install_starship
        install_rust_dock
        auto_detect_drivers
        return 0
    elif [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "ubuntu" ]; then
        sudo -v

        # Ensure Debian backports is available if Debian 13 (Trixie)
        local debian_codename
        debian_codename=$(grep "VERSION_CODENAME" /etc/os-release 2>/dev/null | cut -d= -f2 || echo "trixie")
        [ -z "$debian_codename" ] && debian_codename="trixie"

        local DEBIAN_CORE_PKGS=(
            hyprland
            hypridle
            hyprlock
            hyprsunset
            hyprpicker
            xdg-desktop-portal-hyprland
            xdg-desktop-portal-gtk
            waybar
            quickshell
            rofi-wayland
            rofi
            kitty
            zsh
            zsh-autosuggestions
            zsh-syntax-highlighting
            starship
            thunar
            thunar-archive-plugin
            thunar-volman
            file-roller
            gvfs
            gvfs-backends
            gvfs-fuse
            tumbler
            ffmpeg
            ffmpegthumbnailer
            libgsf-1-114
            gwenview
            network-manager
            network-manager-gnome
            bluez
            bluez-obex
            blueman
            pipewire
            pipewire-pulse
            pipewire-alsa
            wireplumber
            pavucontrol
            playerctl
            pamixer
            brightnessctl
            brightness-udev
            v4l-utils
            lsof
            swappy
            grim
            slurp
            wl-clipboard
            wf-recorder
            libnotify-bin
            socat
            x11-xserver-utils
            qml-module-qtgraphicaleffects
            qml-module-qtquick-controls2
            qml-module-qtsvg
            qml-module-qtquick-shapes
            qml6-module-qtquick
            qml6-module-qtquick-controls
            qml6-module-qtquick-shapes
            qml6-module-qtquick-layouts
            qml6-module-qtquick-templates
            qml6-module-qtquick-window
            qml6-module-qtcore
            qml6-module-qt5compat
            qml6-module-qtmultimedia
            qml6-module-qtvirtualkeyboard
            libgtk4-layer-shell0
            libqt6svg6
            hyprpaper
            swaybg
            qt5ct
            qt6ct
            qt-style-kvantum
            qt-style-kvantum-themes
            sddm
            polkit-kde-agent-1
            gnome-keyring
            nwg-displays
            nwg-look
            cava
            fonts-noto
            fonts-noto-cjk
            fonts-noto-color-emoji
            fonts-font-awesome
            power-profiles-daemon
            upower
            python3
            python3-pip
            python3-pil
            python3-gi
            flatpak
            stow
            curl
            wget
            unzip
            jq
            bc
            imagemagick
            cliphist
            mpv
            htop
            btop
            fastfetch
            inotify-tools
            psmisc
            xdg-user-dirs
            btrfs-progs
            timeshift
        )

        export DEBIAN_FRONTEND=noninteractive
        if [ "${ENABLE_SDDM:-true}" = true ] && command -v debconf-set-selections >/dev/null 2>&1; then
            echo "sddm shared/default-x-display-manager select sddm" | sudo debconf-set-selections 2>/dev/null || true
            echo "shared/default-x-display-manager select sddm" | sudo debconf-set-selections 2>/dev/null || true
        fi
        if [ "$DISTRO" = "debian" ]; then
            if ! grep -rq "${debian_codename}-backports" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
                echo "deb http://deb.debian.org/debian ${debian_codename}-backports main contrib non-free" | sudo tee /etc/apt/sources.list.d/backports.list >/dev/null || true
                sudo apt-get update >> "$LOG_FILE" 2>&1 || true
            fi
            # Try batch install with backports priority for Hyprland ecosystem
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -t ${debian_codename}-backports hyprland hypridle hyprlock hyprsunset hyprpicker >> "$LOG_FILE" 2>&1 || true
        elif [ "$DISTRO" = "ubuntu" ]; then
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y hyprland hypridle hyprlock hyprsunset hyprpicker >> "$LOG_FILE" 2>&1 || true
        fi
        if ! rhythm_install_with_progress "${#DEBIAN_CORE_PKGS[@]}" "Installing core packages via apt-get..." \
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${DEBIAN_CORE_PKGS[@]}"; then
            local total_d=${#DEBIAN_CORE_PKGS[@]}
            local idx=0
            for pkg in "${DEBIAN_CORE_PKGS[@]}"; do
                idx=$((idx + 1))
                render_progress_bar "$idx" "$total_d" "Installing $pkg (fallback)..."
                sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$pkg" >> "$LOG_FILE" 2>&1 || true
            done
            [ "$total_d" -gt 0 ] && [ -t 1 ] && printf "\n"
        fi

        # Extra utilities if available in repos
        for extra in swww mpvpaper awww hyprpaper swaybg hyprland-guiutils hyprland-qtutils imagemagick; do
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$extra" >> "$LOG_FILE" 2>&1 || true
        done
        step_ok "Core packages installed."

        install_themes_and_fonts
        install_quickshell
        install_starship
        install_rust_dock
        auto_detect_drivers
        return 0
    elif [ "$DISTRO" = "alpine" ]; then
        sudo -v

        # Ensure testing repo is available for packages like hypridle, hyprlock, cava if needed
        if [ -f /etc/apk/repositories ] && ! grep -q '\/testing' /etc/apk/repositories; then
            echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" | sudo tee -a /etc/apk/repositories >/dev/null || true
            sudo apk update >> "$LOG_FILE" 2>&1 || true
        fi

        local ALPINE_CORE_PKGS=(
            # Compositor & Wayland core
            hyprland
            hypridle
            hyprlock
            hyprpicker
            xdg-desktop-portal-hyprland
            xdg-desktop-portal-gtk
            xwayland
            seatd
            seatd-openrc

            # Bars, Launchers & Shell
            waybar
            rofi-wayland
            kitty
            zsh
            zsh-autosuggestions
            zsh-syntax-highlighting
            starship

            # File Management & Media
            thunar
            thunar-archive-plugin
            thunar-volman
            file-roller
            gvfs
            tumbler
            ffmpeg
            ffmpegthumbnailer

            # Networking & Bluetooth
            networkmanager
            networkmanager-cli
            networkmanager-openrc
            bluez
            bluez-openrc
            blueman

            # Audio Architecture
            pipewire
            pipewire-pulse
            pipewire-alsa
            pipewire-openrc
            wireplumber
            pavucontrol
            playerctl
            pamixer

            # Screen, Hardware & Capture Tools
            brightnessctl
            swappy
            grim
            slurp
            wl-clipboard
            wf-recorder
            libnotify
            socat
            upower

            # Qt & SDDM
            qt5-qtwayland
            qt6-qtwayland
            qt6-qtdeclarative
            qt6-qt5compat
            qt6-qtsvg
            qt6-qtmultimedia
            qt6-qtvirtualkeyboard
            gtk4-layer-shell
            swaybg
            hyprpaper
            qt5ct
            qt6ct
            kvantum
            sddm
            sddm-openrc
            dbus
            dbus-openrc

            # Theming, Fonts & Utilities
            font-jetbrains-mono-nerd
            font-noto
            font-noto-cjk
            font-noto-emoji
            font-awesome
            py3-pywal
            py3-pillow
            cava
            flatpak
            stow
            curl
            wget
            unzip
            jq
            bc
            imagemagick
            mpv
            btop
            fastfetch
            inotify-tools
            psmisc
            xdg-user-dirs
            btrfs-progs
        )

        if ! rhythm_install_with_progress "${#ALPINE_CORE_PKGS[@]}" "Installing core packages via apk..." \
            sudo apk add --no-cache "${ALPINE_CORE_PKGS[@]}"; then
            local total_a=${#ALPINE_CORE_PKGS[@]}
            local idx=0
            for pkg in "${ALPINE_CORE_PKGS[@]}"; do
                idx=$((idx + 1))
                render_progress_bar "$idx" "$total_a" "Installing $pkg (fallback)..."
                sudo apk add --no-cache "$pkg" >> "$LOG_FILE" 2>&1 || true
            done
            [ "$total_a" -gt 0 ] && [ -t 1 ] && printf "\n"
        fi

        # Extra utilities if available
        for extra in swww mpvpaper awww hyprland-guiutils hyprland-qtutils imagemagick; do
            sudo apk add --no-cache "$extra" >> "$LOG_FILE" 2>&1 || true
        done
        step_ok "Core packages installed."

        install_themes_and_fonts
        install_quickshell
        install_starship
        install_rust_dock
        auto_detect_drivers
        return 0
    elif [ "$DISTRO" = "opensuse" ]; then
        sudo -v

        # Add X11:Wayland repository if Hyprland is not already found
        if ! zypper search -s hyprland >/dev/null 2>&1; then
            local suse_type="openSUSE_Tumbleweed"
            if grep -qi "leap" /etc/os-release 2>/dev/null; then
                suse_type="openSUSE_Leap_$(grep '^VERSION_ID=' /etc/os-release | cut -d\" -f2)"
            fi
            sudo zypper addrepo --check --refresh "https://download.opensuse.org/repositories/X11:Wayland/${suse_type}/X11:Wayland.repo" >> "$LOG_FILE" 2>&1 || true
            sudo zypper --non-interactive --gpg-auto-import-keys refresh >> "$LOG_FILE" 2>&1 || true
        fi

        local OPENSUSE_CORE_PKGS=(
            # Compositor & Wayland core
            hyprland
            hypridle
            hyprlock
            hyprsunset
            hyprpicker
            xdg-desktop-portal-hyprland
            xdg-desktop-portal-gtk
            xwayland

            # Bars, Launchers & Shell
            waybar
            rofi-wayland
            rofi
            kitty
            zsh
            zsh-autosuggestions
            zsh-syntax-highlighting
            starship

            # File Management & Media
            thunar
            thunar-plugin-archive
            thunar-volman
            file-roller
            gvfs
            tumbler
            ffmpeg
            ffmpegthumbnailer

            # Networking & Bluetooth
            NetworkManager
            NetworkManager-applet
            bluez
            blueman

            # Audio Architecture
            pipewire
            pipewire-pulse
            pipewire-alsa
            wireplumber
            pavucontrol
            playerctl
            pamixer

            # Screen, Hardware & Capture Tools
            brightnessctl
            swappy
            grim
            slurp
            wl-clipboard
            wf-recorder
            libnotify-tools
            socat
            upower

            # Qt & SDDM
            qt5-wayland
            qt6-wayland
            qt6-declarative-imports
            qt6-qt5compat-imports
            qt6-virtualkeyboard-imports
            qt6-svg
            gtk4-layer-shell
            swaybg
            hyprpaper
            qt5ct
            qt6ct
            kvantum-manager
            sddm
            sddm-qt6

            # Theming, Fonts & Utilities
            jetbrains-mono-fonts
            symbols-only-nerd-fonts
            noto-sans-fonts
            noto-coloremoji-fonts
            fontawesome-fonts
            python3-Pillow
            cava
            flatpak
            stow
            curl
            wget
            unzip
            jq
            bc
            ImageMagick
            mpv
            btop
            fastfetch
            inotify-tools
            psmisc
            xdg-user-dirs
            btrfs-progs
            snapper
        )

        if ! rhythm_install_with_progress "${#OPENSUSE_CORE_PKGS[@]}" "Installing core packages via zypper..." \
            sudo zypper --non-interactive install --no-confirm "${OPENSUSE_CORE_PKGS[@]}"; then
            local total_s=${#OPENSUSE_CORE_PKGS[@]}
            local idx=0
            for pkg in "${OPENSUSE_CORE_PKGS[@]}"; do
                idx=$((idx + 1))
                render_progress_bar "$idx" "$total_s" "Installing $pkg (fallback)..."
                sudo zypper --non-interactive install --no-confirm "$pkg" >> "$LOG_FILE" 2>&1 || true
            done
            [ "$total_s" -gt 0 ] && [ -t 1 ] && printf "\n"
        fi

        # Extra utilities if available in repos
        for extra in swww mpvpaper awww hyprland-guiutils hyprland-qtutils ImageMagick; do
            sudo zypper --non-interactive install --no-confirm "$extra" >> "$LOG_FILE" 2>&1 || true
        done
        step_ok "Core packages installed."

        install_themes_and_fonts
        install_quickshell
        install_starship
        install_rust_dock
        auto_detect_drivers
        return 0
    fi

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
        ffmpeg
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
        noto-fonts
        noto-fonts-cjk
        noto-fonts-emoji

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

    rhythm_install_with_progress "${#CORE_PKGS[@]}" "Installing core packages and dependencies via yay..." \
        yay -S --needed --noconfirm "${CORE_PKGS[@]}"
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
    if [ "$DISTRO" = "fedora" ]; then
        step_item "Launching fzf package search (Fedora DNF repositories)..."
        step_item "[TAB] Select multiple, [ENTER] Confirm, [ESC] Skip"
        sleep 0.8

        local fzf_args=(
            --multi
            --ansi
            --prompt="Search Packages > "
            --header="[TAB] Toggle Select | [ENTER] Confirm Selection | [ESC] Skip Search"
            --preview 'dnf info -C {1} 2>/dev/null || dnf info {1} 2>/dev/null || echo "Loading info..."'
            --preview-window 'right:55%:wrap'
            --bind 'change:top'
        )

        local SELECTED_SEARCH=""
        if command -v dnf >/dev/null 2>&1; then
            SELECTED_SEARCH=$( (dnf repoquery -q --available --queryformat "%{name}" 2>/dev/null || dnf list available 2>/dev/null | awk '{print $1}' | cut -d. -f1) | sort -u | fzf "${fzf_args[@]}" || true )
        fi

        if [[ -n "$SELECTED_SEARCH" ]]; then
            local count=0
            while IFS= read -r app; do
                [ -z "$app" ] && continue
                PACMAN_INSTALL+=("$app")
                count=$((count + 1))
            done <<< "$SELECTED_SEARCH"
            step_ok "Added $count packages from universal search."
            sleep 1
        else
            step_item "No packages selected from search."
            sleep 0.5
        fi
        return 0
    elif [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "ubuntu" ]; then
        step_item "Launching fzf package search ($DISTRO APT repositories)..."
        step_item "[TAB] Select multiple, [ENTER] Confirm, [ESC] Skip"
        sleep 0.8

        local fzf_args=(
            --multi
            --ansi
            --prompt="Search Packages > "
            --header="[TAB] Toggle Select | [ENTER] Confirm Selection | [ESC] Skip Search"
            --preview 'apt-cache show {1} 2>/dev/null || echo "Loading info..."'
            --preview-window 'right:55%:wrap'
            --bind 'change:top'
        )

        local SELECTED_SEARCH=""
        if command -v apt-cache >/dev/null 2>&1; then
            SELECTED_SEARCH=$(apt-cache pkgnames 2>/dev/null | sort -u | fzf "${fzf_args[@]}" || true)
        fi

        if [[ -n "$SELECTED_SEARCH" ]]; then
            local count=0
            while IFS= read -r app; do
                [ -z "$app" ] && continue
                PACMAN_INSTALL+=("$app")
                count=$((count + 1))
            done <<< "$SELECTED_SEARCH"
            step_ok "Added $count packages from universal search."
            sleep 1
        else
            step_item "No packages selected from search."
            sleep 0.5
        fi
        return 0
    elif [ "$DISTRO" = "alpine" ]; then
        step_item "Launching fzf package search (Alpine Linux APK repositories)..."
        step_item "[TAB] Select multiple, [ENTER] Confirm, [ESC] Skip"
        sleep 0.8

        local fzf_args=(
            --multi
            --ansi
            --prompt="Search Packages > "
            --header="[TAB] Toggle Select | [ENTER] Confirm Selection | [ESC] Skip Search"
            --preview 'apk info {1} 2>/dev/null || echo "Loading info..."'
            --preview-window 'right:55%:wrap'
            --bind 'change:top'
        )

        local SELECTED_SEARCH=""
        if command -v apk >/dev/null 2>&1; then
            SELECTED_SEARCH=$(apk list --available 2>/dev/null | awk '{print $1}' | sort -u | fzf "${fzf_args[@]}" || true)
        fi

        if [[ -n "$SELECTED_SEARCH" ]]; then
            local count=0
            while IFS= read -r app; do
                [ -z "$app" ] && continue
                PACMAN_INSTALL+=("$app")
                count=$((count + 1))
            done <<< "$SELECTED_SEARCH"
            step_ok "Added $count packages from universal search."
            sleep 1
        else
            step_item "No packages selected from search."
            sleep 0.5
        fi
        return 0
    elif [ "$DISTRO" = "opensuse" ]; then
        step_item "Launching fzf package search (openSUSE repositories)..."
        step_item "[TAB] Select multiple, [ENTER] Confirm, [ESC] Skip"
        sleep 0.8

        local fzf_args=(
            --multi
            --ansi
            --prompt="Search Packages > "
            --header="[TAB] Toggle Select | [ENTER] Confirm Selection | [ESC] Skip Search"
            --preview 'zypper info {1} 2>/dev/null || echo "Loading info..."'
            --preview-window 'right:55%:wrap'
            --bind 'change:top'
        )

        local SELECTED_SEARCH=""
        if command -v zypper >/dev/null 2>&1; then
            SELECTED_SEARCH=$(zypper packages 2>/dev/null | awk -F'|' 'NR>4 {gsub(/^[ \t]+|[ \t]+$/, "", $3); if ($3 != "") print $3}' | sort -u | fzf "${fzf_args[@]}" || true)
        fi

        if [[ -n "$SELECTED_SEARCH" ]]; then
            local count=0
            while IFS= read -r app; do
                [ -z "$app" ] && continue
                PACMAN_INSTALL+=("$app")
                count=$((count + 1))
            done <<< "$SELECTED_SEARCH"
            step_ok "Added $count packages from universal search."
            sleep 1
        else
            step_item "No packages selected from search."
            sleep 0.5
        fi
        return 0
    fi

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
            count=$((count + 1))
        done <<< "$SELECTED_SEARCH"
        step_ok "Added $count packages from universal search."
        sleep 1
    else
        step_item "No packages selected from search."
        sleep 0.5
    fi
}

# --- DISPLAY MANAGER DETECTION ---
detect_existing_display_manager() {
    local dm
    for dm in gdm gdm3 lightdm lxdm greetd ly cosmic-greeter slim; do
        if command -v systemctl >/dev/null 2>&1; then
            if systemctl is-enabled "$dm.service" >/dev/null 2>&1 || systemctl is-active "$dm.service" >/dev/null 2>&1; then
                echo "$dm"
                return 0
            fi
        elif command -v rc-status >/dev/null 2>&1; then
            if rc-status default 2>/dev/null | grep -q "$dm" || [ -f "/etc/runlevels/default/$dm" ]; then
                echo "$dm"
                return 0
            fi
        fi
    done
    if [ -e /etc/systemd/system/display-manager.service ]; then
        local target
        target=$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)
        if [ -n "$target" ] && [[ "$target" != *"sddm"* ]]; then
            basename "$target" .service
            return 0
        fi
    fi
    if [ -f /etc/X11/default-display-manager ]; then
        local debian_dm
        debian_dm=$(basename "$(cat /etc/X11/default-display-manager 2>/dev/null || true)")
        if [ -n "$debian_dm" ] && [ "$debian_dm" != "sddm" ]; then
            echo "$debian_dm"
            return 0
        fi
    fi
    return 1
}

# --- FIRST RUN SETUP CHOICES (OMARCHY TUI WIZARD) ---
first_run_choices() {
    if [ "$AUTO_YES" = true ]; then
        INSTALL_MODE="custom"
        PACMAN_INSTALL=("brave-bin" "vesktop" "visual-studio-code-bin")
        FLATPAK_INSTALL=("io.missioncenter.MissionCenter")
        [ -z "$WALLPAPER_MODE" ] && WALLPAPER_MODE="random"
        [ -z "$ENABLE_SDDM" ] && ENABLE_SDDM=true
        SET_ZSH=true
        return 0
    fi

    clear_logo
    echo ""
    gum style --foreground 3 --bold --padding "0 0 1 $PADDING_LEFT" "Get ready to make a few choices..."

    if [ "$SKIP_APPS" = true ]; then
        INSTALL_MODE="minimal"
    else
        local search_label="Universal Package Search with fzf (Search & install ANY package from Pacman + AUR)"
        local full_label="Full Package Stack (Install all 125 packages from packages.txt)"
        if [ "$DISTRO" = "fedora" ]; then
            search_label="Universal Package Search with fzf (Search & install ANY package from Fedora DNF)"
            full_label="Full Package Stack (Install full curated stack via DNF + Flatpaks)"
        elif [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "ubuntu" ]; then
            search_label="Universal Package Search with fzf (Search & install ANY package from APT)"
            full_label="Full Package Stack (Install full curated stack via APT + Flatpaks)"
        elif [ "$DISTRO" = "alpine" ]; then
            search_label="Universal Package Search with fzf (Search & install ANY package from Alpine APK)"
            full_label="Full Package Stack (Install full curated stack via APK + Flatpaks)"
        elif [ "$DISTRO" = "opensuse" ]; then
            search_label="Universal Package Search with fzf (Search & install ANY package from openSUSE)"
            full_label="Full Package Stack (Install full curated stack via Zypper + Flatpaks)"
        fi

        local MODE_RAW
        MODE_RAW=$(gum choose \
            --height 8 \
            --header="Select software installation mode:" \
            --cursor-prefix="> " \
            "Custom Categorized Menus (Browsers, Chat, Dev, Media, Gaming, Utilities)" \
            "$search_label" \
            "$full_label" \
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

            local repo_tag="[Arch]"
            local ext_tag="[AUR]"
            if [ "$DISTRO" = "fedora" ]; then
                repo_tag="[DNF]"
                ext_tag="[Flatpak]"
            elif [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "ubuntu" ]; then
                repo_tag="[APT]"
                ext_tag="[APT/Flatpak]"
            elif [ "$DISTRO" = "alpine" ]; then
                repo_tag="[APK]"
                ext_tag="[Flatpak]"
            elif [ "$DISTRO" = "opensuse" ]; then
                repo_tag="[Zypper]"
                ext_tag="[Flatpak]"
            fi

            # 1. Browsers
            clear_logo
            echo ""
            gum style --foreground 6 --bold --padding "0 0 1 $PADDING_LEFT" ":: Web Browsers (1/5)"
            local BROWSERS_LIST=(
                "Brave Browser (brave-bin) $ext_tag"
                "Brave Origin Nightly (brave-origin-nightly-bin) $ext_tag"
                "Chromium (chromium) $repo_tag"
                "Firefox (firefox) $repo_tag"
                "Firefox Developer Edition (firefox-developer-edition) $ext_tag"
                "Google Chrome (google-chrome) $ext_tag"
                "Microsoft Edge (microsoft-edge-stable-bin) $ext_tag"
                "Zen Browser (zen-browser-bin) $ext_tag"
            )
            local SEL_BROWSERS
            SEL_BROWSERS=$(printf "%s\n" "${BROWSERS_LIST[@]}" | gum choose --no-limit --height 10 \
                --selected="Brave Browser (brave-bin) $ext_tag" \
                --header="Space = Toggle, Enter = Confirm Category" \
                --cursor-prefix="> " --selected-prefix="[x] " --unselected-prefix="[ ] " || true)

            # 2. Communication
            clear_logo
            echo ""
            gum style --foreground 6 --bold --padding "0 0 1 $PADDING_LEFT" ":: Communication & Social (2/5)"
            local COMM_LIST=(
                "Discord / Vesktop (vesktop) $ext_tag"
                "Telegram Desktop (telegram-desktop) $repo_tag"
                "Slack Desktop (slack-desktop) $ext_tag"
                "WhatsApp / ZapZap (zapzap) $ext_tag"
                "Spotify (spotify) $ext_tag"
            )
            local SEL_COMM
            SEL_COMM=$(printf "%s\n" "${COMM_LIST[@]}" | gum choose --no-limit --height 10 \
                --selected="Discord / Vesktop (vesktop) $ext_tag" \
                --header="Space = Toggle, Enter = Confirm Category" \
                --cursor-prefix="> " --selected-prefix="[x] " --unselected-prefix="[ ] " || true)

            # 3. Development
            clear_logo
            echo ""
            gum style --foreground 6 --bold --padding "0 0 1 $PADDING_LEFT" ":: Productivity & Development (3/5)"
            local DEV_LIST=(
                "Visual Studio Code (visual-studio-code-bin) $ext_tag"
                "Neovim (neovim) $repo_tag"
                "Obsidian (obsidian) $ext_tag"
                "LibreOffice Fresh (libreoffice-fresh) $repo_tag"
                "LocalSend (localsend-bin) $ext_tag"
                "Docker & Docker Compose (docker docker-compose) $repo_tag"
                "Node.js & NPM (nodejs npm) $repo_tag"
                "Python Suite (python-pip python-black ruff) $repo_tag"
                "GitKraken (gitkraken) $ext_tag"
                "Ollama (ollama) $ext_tag"
            )
            local SEL_DEV
            SEL_DEV=$(printf "%s\n" "${DEV_LIST[@]}" | gum choose --no-limit --height 10 \
                --selected="Visual Studio Code (visual-studio-code-bin) $ext_tag" \
                --header="Space = Toggle, Enter = Confirm Category" \
                --cursor-prefix="> " --selected-prefix="[x] " --unselected-prefix="[ ] " || true)

            # 4. Media & Gaming
            clear_logo
            echo ""
            gum style --foreground 6 --bold --padding "0 0 1 $PADDING_LEFT" ":: Media, Creativity & Gaming (4/5)"
            local MEDIA_LIST=(
                "Steam (steam) $repo_tag"
                "Lutris (lutris) $repo_tag"
                "Heroic Games Launcher (heroic-games-launcher-bin) $ext_tag"
                "OBS Studio (obs-studio) $repo_tag"
                "VLC Media Player (vlc) $repo_tag"
                "MPV Media Player (mpv) $repo_tag"
                "GIMP (gimp) $repo_tag"
                "Inkscape (inkscape) $repo_tag"
                "Kdenlive (kdenlive) $repo_tag"
                "Blender (blender) $repo_tag"
                "Audacity (audacity) $repo_tag"
            )
            local SEL_MEDIA
            SEL_MEDIA=$(printf "%s\n" "${MEDIA_LIST[@]}" | gum choose --no-limit --height 10 \
                --header="Space = Toggle, Enter = Confirm Category" \
                --cursor-prefix="> " --selected-prefix="[x] " --unselected-prefix="[ ] " || true)

            # 5. System Utilities
            clear_logo
            echo ""
            gum style --foreground 6 --bold --padding "0 0 1 $PADDING_LEFT" ":: System Utilities & Flatpaks (5/5)"
            local vbox_label="VirtualBox (virtualbox virtualbox-host-modules-arch virtualbox-guest-iso) $repo_tag"
            [ "$DISTRO" != "arch" ] && vbox_label="VirtualBox (virtualbox) $repo_tag"
            local UTILS_LIST=(
                "$vbox_label"
                "Timeshift (timeshift) $repo_tag"
                "Thunar File Manager (thunar thunar-archive-plugin thunar-volman) $repo_tag"
                "Dolphin File Manager (dolphin ark) $repo_tag"
                "Btop (btop) $repo_tag"
                "Fastfetch (fastfetch) $repo_tag"
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
                    *"(virtualbox"*|*"(virtualbox "*|*"(virtualbox)"*)
                        if [ "$DISTRO" = "arch" ]; then
                            PACMAN_INSTALL+=("virtualbox" "virtualbox-host-modules-arch" "virtualbox-guest-iso")
                        else
                            PACMAN_INSTALL+=("virtualbox")
                        fi
                        ;;
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
            local fzf_prompt="Would you like to search and add any extra packages with fzf?"
            if [ "$DISTRO" = "fedora" ]; then
                fzf_prompt="Would you like to search and add extra packages from DNF with fzf?"
            elif [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "ubuntu" ]; then
                fzf_prompt="Would you like to search and add extra packages from APT with fzf?"
            elif [ "$DISTRO" = "alpine" ]; then
                fzf_prompt="Would you like to search and add extra packages from Alpine APK with fzf?"
            elif [ "$DISTRO" = "opensuse" ]; then
                fzf_prompt="Would you like to search and add extra packages from openSUSE with fzf?"
            elif [ "$DISTRO" = "arch" ]; then
                fzf_prompt="Would you like to search and add extra packages from Pacman/AUR with fzf?"
            fi
            if confirm_prompt "$fzf_prompt"; then
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

    # Display manager / greeter choice
    local DETECTED_DM=""
    DETECTED_DM=$(detect_existing_display_manager || true)
    if [ -z "$ENABLE_SDDM" ]; then
        if [ -n "$DETECTED_DM" ] && [ "$DETECTED_DM" != "sddm" ]; then
            clear_logo
            echo ""
            gum style --foreground 6 --bold --padding "0 0 1 $PADDING_LEFT" ":: Display Manager (Login Greeter)"
            gum style --foreground 7 --padding "0 0 1 $PADDING_LEFT" "Detected existing login greeter: $DETECTED_DM"
            if confirm_prompt "Set SDDM (with Astronaut theme) as your default login screen?"; then
                ENABLE_SDDM=true
            else
                ENABLE_SDDM=false
                step_item "Retaining $DETECTED_DM as the default login screen."
            fi
        else
            ENABLE_SDDM=true
        fi
    fi

    clear_logo
    echo ""
    gum style --foreground 2 --bold --padding "0 0 1 $PADDING_LEFT" "Deploying Rhythm Hyprland..."
    sleep 1
}

# --- APPLICATION DEPLOYMENT STEP ---
step_applications() {
    section "Optional Software & Applications"

    if [ "$DISTRO" = "fedora" ]; then
        if [ "$INSTALL_MODE" = "minimal" ]; then
            step_ok "Optional applications skipped (minimal core stack)."
            return 0
        fi

        if [ "$INSTALL_MODE" = "full" ]; then
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

        local DNF_APPS=()
        for app in "${PACMAN_INSTALL[@]}"; do
            case "$app" in
                brave-bin|brave-origin-nightly-bin) FLATPAK_INSTALL+=("com.brave.Browser") ;;
                google-chrome)                     FLATPAK_INSTALL+=("com.google.Chrome") ;;
                microsoft-edge-stable-bin)         FLATPAK_INSTALL+=("com.microsoft.Edge") ;;
                zen-browser-bin)                   FLATPAK_INSTALL+=("app.zen_browser.zen") ;;
                vesktop)                           FLATPAK_INSTALL+=("dev.vencord.Vesktop") ;;
                slack-desktop)                     FLATPAK_INSTALL+=("com.slack.Slack") ;;
                zapzap)                            FLATPAK_INSTALL+=("com.rtosta.zapzap") ;;
                spotify)                           FLATPAK_INSTALL+=("com.spotify.Client") ;;
                visual-studio-code-bin)            FLATPAK_INSTALL+=("com.visualstudio.code") ;;
                obsidian)                          FLATPAK_INSTALL+=("md.obsidian.Obsidian") ;;
                localsend-bin)                     FLATPAK_INSTALL+=("org.localsend.localsend_app") ;;
                gitkraken)                         FLATPAK_INSTALL+=("com.axosoft.GitKraken") ;;
                heroic-games-launcher-bin)         FLATPAK_INSTALL+=("com.heroicgameslauncher.hgl") ;;
                libreoffice-fresh)                 DNF_APPS+=("libreoffice") ;;
                docker-compose)                    DNF_APPS+=("docker-compose") ;;
                virtualbox*)                       DNF_APPS+=("VirtualBox") ;;
                *)                                 DNF_APPS+=("$app") ;;
            esac
        done

        if [ ${#DNF_APPS[@]} -gt 0 ]; then
            local unique_dnf=($(printf "%s\n" "${DNF_APPS[@]}" | sort -u))
            step_item "Installing selected native packages via dnf (${#unique_dnf[@]} items): ${unique_dnf[*]}"
            sudo dnf install -y --skip-broken "${unique_dnf[@]}" >> "$LOG_FILE" 2>&1 || step_warn "Some dnf packages could not be installed."
        fi

        if [ ${#FLATPAK_INSTALL[@]} -gt 0 ] && [ "$SKIP_FLATPAKS" = false ]; then
            local unique_flatpaks=($(printf "%s\n" "${FLATPAK_INSTALL[@]}" | sort -u))
            step_item "Configuring Flathub and installing Flatpaks (${#unique_flatpaks[@]} items)..."
            sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >> "$LOG_FILE" 2>&1 || true
            for fapp in "${unique_flatpaks[@]}"; do
                step_item "Installing flatpak: $fapp"
                sudo flatpak install -y --system flathub "$fapp" >> "$LOG_FILE" 2>&1 || true
            done
        fi

        step_ok "Application selection successfully deployed."
        return 0
    fi

    if [ "$INSTALL_MODE" = "minimal" ]; then
        step_ok "Optional applications skipped (minimal core stack)."
        return 0
    fi

    if [ "$INSTALL_MODE" = "full" ]; then
        if [ "$DISTRO" = "fedora" ] || [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "ubuntu" ] || [ "$DISTRO" = "alpine" ] || [ "$DISTRO" = "opensuse" ]; then
            step_item "Full stack requested for $DISTRO: deploying Flatpaks and available packages..."
            if [ -f "$DOTFILES_DIR/flatpaks.txt" ] && [ "$SKIP_FLATPAKS" = false ]; then
                sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >> "$LOG_FILE" 2>&1 || true
                local flatpaks=()
                while IFS= read -r fapp || [ -n "$fapp" ]; do
                    fapp=$(echo "$fapp" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
                    [ -z "$fapp" ] && continue
                    [[ "$fapp" =~ ^# ]] && continue
                    flatpaks+=("$fapp")
                done < "$DOTFILES_DIR/flatpaks.txt"
                local total_fp=${#flatpaks[@]}
                local fp_idx=0
                for fapp in "${flatpaks[@]}"; do
                    fp_idx=$((fp_idx + 1))
                    render_progress_bar "$fp_idx" "$total_fp" "Installing Flatpak: $fapp..."
                    sudo flatpak install -y --system flathub "$fapp" >> "$LOG_FILE" 2>&1 || true
                done
                [ "$total_fp" -gt 0 ] && [ -t 1 ] && printf "\n"
            fi
            step_ok "Full package stack successfully deployed."
            return 0
        fi

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
                rhythm_install_with_progress "${#FULL_PKGS[@]}" "Deploying full package stack (${#FULL_PKGS[@]} packages via yay)..." \
                    yay -S --needed --noconfirm "${FULL_PKGS[@]}" || step_warn "Some packages from packages.txt encountered errors during installation."
            fi
        fi

        if [ -f "$DOTFILES_DIR/flatpaks.txt" ] && [ "$SKIP_FLATPAKS" = false ]; then
            step_item "Configuring Flathub and deploying default Flatpaks..."
            sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >> "$LOG_FILE" 2>&1 || true
            local flatpaks=()
            while IFS= read -r fapp || [ -n "$fapp" ]; do
                fapp=$(echo "$fapp" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
                [ -z "$fapp" ] && continue
                [[ "$fapp" =~ ^# ]] && continue
                flatpaks+=("$fapp")
            done < "$DOTFILES_DIR/flatpaks.txt"
            local total_fp=${#flatpaks[@]}
            local fp_idx=0
            for fapp in "${flatpaks[@]}"; do
                fp_idx=$((fp_idx + 1))
                render_progress_bar "$fp_idx" "$total_fp" "Installing Flatpak: $fapp..."
                sudo flatpak install -y --system flathub "$fapp" >> "$LOG_FILE" 2>&1 || true
            done
            [ "$total_fp" -gt 0 ] && [ -t 1 ] && printf "\n"
        fi

        step_ok "Full package stack successfully deployed."
        return 0
    fi

    if [ ${#PACMAN_INSTALL[@]} -eq 0 ] && [ ${#FLATPAK_INSTALL[@]} -eq 0 ]; then
        step_ok "No optional applications selected."
        return 0
    fi

    if [ ${#PACMAN_INSTALL[@]} -gt 0 ]; then
        if [ "$DISTRO" = "fedora" ]; then
            step_item "Deploying application selections for Fedora..."
            sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >> "$LOG_FILE" 2>&1 || true
            local total_app=${#PACMAN_INSTALL[@]}
            local app_idx=0
            for app in "${PACMAN_INSTALL[@]}"; do
                app_idx=$((app_idx + 1))
                render_progress_bar "$app_idx" "$total_app" "Installing $app..."
                case "$app" in
                    *brave*) sudo flatpak install -y --system flathub com.brave.Browser >> "$LOG_FILE" 2>&1 || true ;;
                    *vesktop*|*discord*) sudo flatpak install -y --system flathub dev.vencord.Vesktop >> "$LOG_FILE" 2>&1 || true ;;
                    *code*) sudo flatpak install -y --system flathub com.visualstudio.code >> "$LOG_FILE" 2>&1 || sudo dnf install -y code >> "$LOG_FILE" 2>&1 || true ;;
                    *spotify*) sudo flatpak install -y --system flathub com.spotify.Client >> "$LOG_FILE" 2>&1 || true ;;
                    *obsidian*) sudo flatpak install -y --system flathub md.obsidian.Obsidian >> "$LOG_FILE" 2>&1 || true ;;
                    *steam*) sudo dnf install -y steam >> "$LOG_FILE" 2>&1 || true ;;
                    *) sudo dnf install -y --skip-broken "$app" >> "$LOG_FILE" 2>&1 || true ;;
                esac
            done
            [ "$total_app" -gt 0 ] && [ -t 1 ] && printf "\n"
        elif [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "ubuntu" ]; then
            step_item "Deploying application selections for $DISTRO..."
            sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >> "$LOG_FILE" 2>&1 || true
            local total_app=${#PACMAN_INSTALL[@]}
            local app_idx=0
            for app in "${PACMAN_INSTALL[@]}"; do
                app_idx=$((app_idx + 1))
                render_progress_bar "$app_idx" "$total_app" "Installing $app..."
                case "$app" in
                    *brave*)
                        # Setup official Brave browser repo for Debian/Ubuntu if requested
                        if ! command -v brave-browser >/dev/null 2>&1; then
                            sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg >> "$LOG_FILE" 2>&1 || true
                            sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources https://brave-browser-apt-release.s3.brave.com/brave-browser.sources >> "$LOG_FILE" 2>&1 || true
                            sudo apt-get update -y >> "$LOG_FILE" 2>&1 || true
                            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y brave-browser >> "$LOG_FILE" 2>&1 || sudo flatpak install -y --system flathub com.brave.Browser >> "$LOG_FILE" 2>&1 || true
                        fi
                        ;;
                    *vesktop*|*discord*) sudo flatpak install -y --system flathub dev.vencord.Vesktop >> "$LOG_FILE" 2>&1 || true ;;
                    *code*) sudo flatpak install -y --system flathub com.visualstudio.code >> "$LOG_FILE" 2>&1 || true ;;
                    *spotify*) sudo flatpak install -y --system flathub com.spotify.Client >> "$LOG_FILE" 2>&1 || true ;;
                    *obsidian*) sudo flatpak install -y --system flathub md.obsidian.Obsidian >> "$LOG_FILE" 2>&1 || true ;;
                    *steam*) sudo DEBIAN_FRONTEND=noninteractive apt-get install -y steam-installer >> "$LOG_FILE" 2>&1 || sudo DEBIAN_FRONTEND=noninteractive apt-get install -y steam >> "$LOG_FILE" 2>&1 || true ;;
                    *) sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$app" >> "$LOG_FILE" 2>&1 || true ;;
                esac
            done
            [ "$total_app" -gt 0 ] && [ -t 1 ] && printf "\n"
        elif [ "$DISTRO" = "alpine" ]; then
            step_item "Deploying application selections for Alpine..."
            sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >> "$LOG_FILE" 2>&1 || true
            local total_app=${#PACMAN_INSTALL[@]}
            local app_idx=0
            for app in "${PACMAN_INSTALL[@]}"; do
                app_idx=$((app_idx + 1))
                render_progress_bar "$app_idx" "$total_app" "Installing $app..."
                case "$app" in
                    *brave*) sudo flatpak install -y --system flathub com.brave.Browser >> "$LOG_FILE" 2>&1 || true ;;
                    *vesktop*|*discord*) sudo flatpak install -y --system flathub dev.vencord.Vesktop >> "$LOG_FILE" 2>&1 || true ;;
                    *code*) sudo flatpak install -y --system flathub com.visualstudio.code >> "$LOG_FILE" 2>&1 || true ;;
                    *spotify*) sudo flatpak install -y --system flathub com.spotify.Client >> "$LOG_FILE" 2>&1 || true ;;
                    *obsidian*) sudo flatpak install -y --system flathub md.obsidian.Obsidian >> "$LOG_FILE" 2>&1 || true ;;
                    *steam*) sudo flatpak install -y --system flathub com.valvesoftware.Steam >> "$LOG_FILE" 2>&1 || true ;;
                    *) sudo apk add --no-cache "$app" >> "$LOG_FILE" 2>&1 || true ;;
                esac
            done
            [ "$total_app" -gt 0 ] && [ -t 1 ] && printf "\n"
        elif [ "$DISTRO" = "opensuse" ]; then
            step_item "Deploying application selections for openSUSE..."
            sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >> "$LOG_FILE" 2>&1 || true
            local total_app=${#PACMAN_INSTALL[@]}
            local app_idx=0
            for app in "${PACMAN_INSTALL[@]}"; do
                app_idx=$((app_idx + 1))
                render_progress_bar "$app_idx" "$total_app" "Installing $app..."
                case "$app" in
                    *brave*) sudo flatpak install -y --system flathub com.brave.Browser >> "$LOG_FILE" 2>&1 || true ;;
                    *vesktop*|*discord*) sudo flatpak install -y --system flathub dev.vencord.Vesktop >> "$LOG_FILE" 2>&1 || true ;;
                    *code*) sudo flatpak install -y --system flathub com.visualstudio.code >> "$LOG_FILE" 2>&1 || true ;;
                    *spotify*) sudo flatpak install -y --system flathub com.spotify.Client >> "$LOG_FILE" 2>&1 || true ;;
                    *obsidian*) sudo flatpak install -y --system flathub md.obsidian.Obsidian >> "$LOG_FILE" 2>&1 || true ;;
                    *steam*) sudo zypper --non-interactive install --no-confirm steam >> "$LOG_FILE" 2>&1 || sudo flatpak install -y --system flathub com.valvesoftware.Steam >> "$LOG_FILE" 2>&1 || true ;;
                    *) sudo zypper --non-interactive install --no-confirm "$app" >> "$LOG_FILE" 2>&1 || true ;;
                esac
            done
            [ "$total_app" -gt 0 ] && [ -t 1 ] && printf "\n"
        else
            local unique_pkgs=($(printf "%s\n" "${PACMAN_INSTALL[@]}" | sort -u))
            PACMAN_INSTALL=("${unique_pkgs[@]}")
            rhythm_install_with_progress "${#PACMAN_INSTALL[@]}" "Installing selected applications via yay (${#PACMAN_INSTALL[@]} items)..." \
                yay -S --needed --noconfirm "${PACMAN_INSTALL[@]}" || step_warn "Some native packages could not be installed."
        fi
    fi

    if [ ${#FLATPAK_INSTALL[@]} -gt 0 ] && [ "$SKIP_FLATPAKS" = false ]; then
        step_item "Configuring Flathub and installing selected Flatpaks (${#FLATPAK_INSTALL[@]} items)..."
        sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >> "$LOG_FILE" 2>&1 || true
        local total_fp=${#FLATPAK_INSTALL[@]}
        local fp_idx=0
        for app in "${FLATPAK_INSTALL[@]}"; do
            fp_idx=$((fp_idx + 1))
            render_progress_bar "$fp_idx" "$total_fp" "Installing Flatpak: $app..."
            sudo flatpak install -y --system flathub "$app" >> "$LOG_FILE" 2>&1 || true
        done
        [ "$total_fp" -gt 0 ] && [ -t 1 ] && printf "\n"
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

    # Sembrar el fondo por defecto.
    #
    # El repo trae .config/hypr/wallpapers/default.jpg y el bucle de arriba ya
    # lo ha copiado a ~/.config/hypr/, pero NADA lo leia: default.jpg no tenia
    # ni una referencia en todo el repo. El unico wallpaper que se registraba
    # era el del tema de SDDM, y solo si el bloque de SDDM se ejecutaba entero
    # (install.sh lo triplemente condiciona). Si esa imagen no estaba, el cache
    # se quedaba vacio y el escritorio arrancaba en negro: sin fondo, y sin el
    # logo de Hyprland tampoco porque hyprland.lua pone disable_hyprland_logo.
    #
    # Se siembra aqui, ya en ~/.config, y no desde $DOTFILES_DIR, porque el
    # cache tiene que sobrevivir a que el checkout se mueva o se borre.
    #
    # No se pisa uno que ya haya: si el usuario tiene un fondo elegido, este
    # paso no toca nada.
    local DEFAULT_WP="$HOME/.config/hypr/wallpapers/default.jpg"
    # El cache cuenta como "no valido" si no existe O si lo que tiene dentro
    # tampoco. Un cache que apunta a una imagen borrada es el caso que mas
    #ciausaba el fondo negro de forma permanente.
    local CACHE_WP_VALID=false
    if [ -f "$HOME/.cache/current-wallpaper" ]; then
        local CACHED_WP
        CACHED_WP=$(cat "$HOME/.cache/current-wallpaper" 2>/dev/null || true)
        if [ -n "$CACHED_WP" ] && [ -f "$CACHED_WP" ]; then
            CACHE_WP_VALID=true
        else
            step_warn "Wallpaper cache points at a missing file; reseeding."
        fi
    fi
    if [ -f "$DEFAULT_WP" ] && [ "$CACHE_WP_VALID" != true ]; then
        mkdir -p "$HOME/.cache"
        echo "$DEFAULT_WP" > "$HOME/.cache/current-wallpaper"
        step_ok "Default wallpaper seeded."
    fi
    # Lo mismo con la biblioteca: wallpaper-random y wallpaper-selector fallan
    # con ~/Pictures/Wallpapers vacio, asi que el default se copia ahi tambien.
    mkdir -p "$HOME/Pictures/Wallpapers"
    if [ -f "$DEFAULT_WP" ] && ! compgen -G "$HOME/Pictures/Wallpapers/*" >/dev/null 2>&1; then
        cp -f "$DEFAULT_WP" "$HOME/Pictures/Wallpapers/default.jpg"
        step_ok "Default wallpaper added to the library."
    fi

    # Seed fallback colors for Hyprland and Hyprlock if wal has not run yet
    mkdir -p "$HOME/.cache/wal"
    if [ ! -f "$HOME/.cache/wal/colors-hyprland.conf" ]; then
        cat << 'WAL_EOF' > "$HOME/.cache/wal/colors-hyprland.conf"
$color0 = rgb(101012)
$color1 = rgb(546065)
$color2 = rgb(A45E4C)
$color3 = rgb(E59A78)
$color4 = rgb(5B7A84)
$color5 = rgb(6F8C94)
$color6 = rgb(9A9D9E)
$color7 = rgb(c2c8c9)
$color8 = rgb(878c8c)
$color9 = rgb(546065)
$color10 = rgb(A45E4C)
$color11 = rgb(E59A78)
$color12 = rgb(5B7A84)
$color13 = rgb(6F8C94)
$color14 = rgb(9A9D9E)
$color15 = rgb(c2c8c9)
$background = rgb(101012)
$foreground = rgb(c2c8c9)
$cursor = rgb(c2c8c9)
$wallpaper = default.jpg
WAL_EOF
    fi
    if [ ! -f "$HOME/.cache/wal/colors-hyprland-enhanced.conf" ]; then
        cp -f "$HOME/.cache/wal/colors-hyprland.conf" "$HOME/.cache/wal/colors-hyprland-enhanced.conf" 2>/dev/null || true
    fi

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
    # La ruta de ffmpeg para el selector de fondos de la Isla.
    #
    # El QML traia "/usr/bin/ffmpeg" escrito a fuego, que no es el sitio donde
    # lo deja el gestor de paquetes en todas las instalaciones y no existe en
    # absoluto en NixOS (ahi vive en el store). ffmpeg tampoco estaba en
    # packages.txt, con lo que la previsualizacion de .gif no podia funcionar.
    #
    # Resolverlo dentro del QML no es posible: Quickshell no expone una forma de
    # comprobar si un fichero existe. En el despliegue si se sabe, que es donde
    # se mira. Solo se escribe si el usuario no ha puesto la suya.
    step_item "Resolving ffmpeg for the island wallpaper selector..."
    local SETTINGS_QML="$HOME/.config/quickshell/wallpaper/settings.json"
    if command -v ffmpeg >/dev/null 2>&1 && [ -d "$(dirname "$SETTINGS_QML")" ]; then
        if [ -f "$SETTINGS_QML" ] && grep -q '"ffmpegPath"' "$SETTINGS_QML"; then
            step_ok "ffmpegPath already set by hand; left alone."
        elif command -v jq >/dev/null 2>&1; then
            local ffmpeg_real
            ffmpeg_real=$(command -v ffmpeg)
            local tmp_qml="$SETTINGS_QML.tmp.$$"
            if [ -f "$SETTINGS_QML" ]; then
                jq --arg f "$ffmpeg_real" '. + {ffmpegPath: $f}' "$SETTINGS_QML" > "$tmp_qml" 2>/dev/null \
                    && mv -f "$tmp_qml" "$SETTINGS_QML" \
                    || { rm -f "$tmp_qml"; step_warn "No se pudo escribir ffmpegPath en settings.json."; }
            else
                printf '{"ffmpegPath":"%s"}\n' "$ffmpeg_real" > "$tmp_qml" \
                    && mv -f "$tmp_qml" "$SETTINGS_QML" \
                    || { rm -f "$tmp_qml"; step_warn "No se pudo escribir ffmpegPath en settings.json."; }
            fi
            [ -f "$SETTINGS_QML" ] && grep -q "$ffmpeg_real" "$SETTINGS_QML" \
                && step_ok "ffmpegPath resolved to $ffmpeg_real."
        else
            step_warn "jq no disponible; ffmpegPath se quedaria en /usr/bin/ffmpeg."
        fi
    elif ! command -v ffmpeg >/dev/null 2>&1; then
        step_warn "ffmpeg no esta instalado; la Isla no podra previsualizar .gif."
    fi

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
        #
        # Esta limpieza se lleva por delante el default.jpg que step_dotfiles
        # acaba de dejar en la biblioteca, y como este paso va DESPUES, el
        # escritorio se quedaba sin wallpaper en cuanto se aceptaba el pack.
        # Se guardan aparte los fondos que el usuario hubiera puesto a mano:
        # esto se suppose "dejar solo FireWalls", no borrar lo suyo.
        local DEFAULT_WP_SEED="$HOME/.config/hypr/wallpapers/default.jpg"
        local KEPT_WALLS=""
        mkdir -p "$HOME/.cache"
        local saved_dir
        saved_dir=$(mktemp -d "$HOME/.cache/rhythm-keep-walls.XXXXXX" 2>/dev/null || true)
        if [ -n "$saved_dir" ]; then
            # Todo lo que no venga de un pack conocido se considera del usuario.
            # Los packs sedetectan por nombre, que es como los deja el paso de
            # descarga; lo demas se aparta.
            local f base
            for f in "$WALL_DIR"/*; do
                [ -e "$f" ] || continue
                base=$(basename "$f")
                case "$base" in
                    default.jpg) continue ;;
                esac
                if [ -n "$DEFAULT_WP_SEED" ] && cmp -s "$f" "$DEFAULT_WP_SEED" 2>/dev/null; then
                    continue
                fi
                mv -f "$f" "$saved_dir/" 2>/dev/null || true
            done
            KEPT_WALLS=$(find "$saved_dir" -maxdepth 1 -type f | wc -l)
        else
            KEPT_WALLS=0
        fi
        rm -rf "${WALL_DIR:?}/"* 2>/dev/null || true
        # El default se vuelve a poner DESPUES de la limpieza, siempre. Es el
        # unico fondo que hay garantizado tras una instalacion.
        if [ -f "$DEFAULT_WP_SEED" ]; then
            cp -f "$DEFAULT_WP_SEED" "$WALL_DIR/default.jpg"
        fi
        # Y los del usuario vuelven, para que la limpieza no les borre lo suyo.
        if [ -n "$saved_dir" ] && [ "${KEPT_WALLS:-0}" -gt 0 ] 2>/dev/null; then
            mv -f "$saved_dir"/* "$WALL_DIR/" 2>/dev/null || true
            step_item "Wallpapers previos del usuario conservados: $KEPT_WALLS"
        fi
        rm -rf "$saved_dir" 2>/dev/null || true
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

    # Ensure SDDM package is installed if enabled
    if [ "${ENABLE_SDDM:-true}" = true ] && ! command -v sddm >/dev/null 2>&1; then
        step_item "Installing SDDM display manager..."
        if [ "$DISTRO" = "fedora" ]; then
            sudo dnf install -y sddm >> "$LOG_FILE" 2>&1 || true
        elif [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "ubuntu" ]; then
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends sddm >> "$LOG_FILE" 2>&1 || true
        elif [ "$DISTRO" = "alpine" ]; then
            sudo apk add --no-cache sddm sddm-openrc >> "$LOG_FILE" 2>&1 || true
        elif [ "$DISTRO" = "opensuse" ]; then
            sudo zypper --non-interactive install --no-confirm sddm >> "$LOG_FILE" 2>&1 || true
        else
            yay -S --needed --noconfirm sddm >> "$LOG_FILE" 2>&1 || true
        fi
    fi

    # SDDM Astronaut Theme
    if [ "${ENABLE_SDDM:-true}" = true ] && [ -d "$DOTFILES_DIR/sddm/sddm-astronaut-theme" ]; then
        step_item "Deploying SDDM Astronaut theme..."
        sudo mkdir -p /usr/share/sddm/themes
        # `rm -rf` antes del `cp -r`, y no confiado en que el destino no exista.
        #
        # cp -r sobre un directorio YA existente no lo sustituye: copia el
        # origen DENTRO. En una reinstalacion, o tras haber instalado el tema a
        # mano, /usr/share/sddm/themes/sddm-astronaut-theme ya estaba, y el
        # resultado era
        #     /usr/share/sddm/themes/sddm-astronaut-theme/sddm-astronaut-theme/
        # con los Main.qml, metadata.desktop y Components/ de la version
        # VIEJA arriba y la nueva enterada dentro. El greeter sigue arrancando,
        # asi que no se ve como error: se ve como un tema que no cambia con las
        # actualizaciones. Medido aqui: el `cp -r` no fallaba nunca, solo
        # anidaba en silencio.
        #
        # Se borra solo lo del tema, nunca todo /usr/share/sddm/themes, que
        # puede tener otros greeters instalados.
        sudo rm -rf /usr/share/sddm/themes/sddm-astronaut-theme
        sudo cp -r "$DOTFILES_DIR/sddm/sddm-astronaut-theme" /usr/share/sddm/themes/
        # Comprobacion: si el `cp` volvio a anidar, el theme.conf que se escribe
        # abajo apuntaria a un directorio sin Main.qml de verdad y el login
        # caeria al tema por defecto de SDDM sin decir nada.
        if [ ! -f /usr/share/sddm/themes/sddm-astronaut-theme/Main.qml ]; then
            step_warn "El tema de SDDM ha quedado mal desplegado (falta Main.qml); revisa /usr/share/sddm/themes."
        else
            step_ok "SDDM theme files in place."
        fi
        
        sudo mkdir -p /etc/sddm.conf.d /etc/sddm
        printf "[Theme]\nCurrent=sddm-astronaut-theme\n" | sudo tee /etc/sddm.conf.d/theme.conf > /dev/null

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
        local deploy_bin="$HOME/.local/bin/rhythm-sddm-deploy"
        [ ! -x "$deploy_bin" ] && [ -x "$DOTFILES_DIR/.local/bin/rhythm-sddm-deploy" ] && deploy_bin="$DOTFILES_DIR/.local/bin/rhythm-sddm-deploy"
        if [ -x "$deploy_bin" ]; then
            if "$deploy_bin" "$DOTFILES_DIR"; then
                step_ok "SDDM greeter deployed (login on the internal panel only, cursor set)."
            else
                step_warn "El greeter de SDDM quedo a medias. Mira ~/.cache/rhythm-sddm-deploy.log"
            fi
        else
            step_warn "rhythm-sddm-deploy no esta disponible; el login se quedaria como este."
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

        # Pywal SDDM sync.
        #
        # ANTES se escribia aqui un hook en ~/.config/wal/hooks/sddm-sync.sh.
        # Pywal no tiene hooks: se comprobo contra su codigo (3.8.15) y no hay
        # ningun 'hook' ni 'postrun' en el paquete, y wal(1) solo documenta
        # TEMPLATES. Ese fichero no lo ejecutaba nadie, nunca. El arbol entero
        # de hooks del repo era inerte por el mismo motivo, y se ha borrado.
        #
        # Lo que si funciona es el paso 8 de modern-pywal-sync, que llama a
        # sddm-sync-wrapper directamente. Se avisa de que el sitio cambio, por
        # si alguien tiene el hook viejo por ahi de una instalacion anterior.

        # Initial color palette generation
        #
        # Este `wal` era el UNICO del installer, y solo se llegaba a el si el
        # tema de SDDM estaba presente. Toda la cadena de colores (waybar,
        # rofi, mako, GTK) cuelga de que corra al menos una vez, asi que su
        # ausencia hacia que nada tuviera tema. Ahora modern-pywal-sync tambien
        # lo ejecuta si falta, asi que esto es solo para tener una paleta ya
        # buena antes del primer arranque.
        #
        # Y el cache se escribe SOLO si no hay uno utilizable: antes se
        # sobreescribia siempre con una ruta DENTRO del clon del repo, que
        # puede moverse o borrarse. Con el clon fuera, el cache apuntaba al
        # vacio y el escritorio arrancaba en negro.
        local SDDM_WALLPAPER="$DOTFILES_DIR/sddm/sddm-astronaut-theme/Backgrounds/current_wallpaper.jpg"
        local CACHE_WP_FILE="$HOME/.cache/current-wallpaper"
        local CACHE_WP_NOW=""
        [ -f "$CACHE_WP_FILE" ] && CACHE_WP_NOW=$(cat "$CACHE_WP_FILE" 2>/dev/null || true)
        if [ -f "$SDDM_WALLPAPER" ]; then
            wal -i "$SDDM_WALLPAPER" -n -q >> "$LOG_FILE" 2>&1 || true
        fi
        mkdir -p "$HOME/.cache"
        if [ -z "$CACHE_WP_NOW" ] || [ ! -f "$CACHE_WP_NOW" ]; then
            # Sin cache, se prefiere el default que vive en ~/.config, que es
            # una ruta estable, y solo si no esta, el del clon.
            if [ -f "$HOME/.config/hypr/wallpapers/default.jpg" ]; then
                echo "$HOME/.config/hypr/wallpapers/default.jpg" > "$CACHE_WP_FILE"
                step_ok "Wallpaper cache seeded from the default."
            elif [ -f "$SDDM_WALLPAPER" ]; then
                echo "$SDDM_WALLPAPER" > "$CACHE_WP_FILE"
                step_warn "Wallpaper cache seeded from the checkout; move the repo if you want it to survive."
            fi
        else
            step_ok "Existing wallpaper kept: $(basename "$CACHE_WP_NOW")"
        fi

        # Neutralize Hyprland's internal default mascot wallpapers to eliminate startup flash
        if [ -d /usr/share/hypr ]; then
            local def_wp="$HOME/.config/hypr/wallpapers/default.jpg"
            [ ! -f "$def_wp" ] && [ -f "$DOTFILES_DIR/.config/hypr/wallpapers/default.jpg" ] && def_wp="$DOTFILES_DIR/.config/hypr/wallpapers/default.jpg"
            if [ -f "$def_wp" ]; then
                local tmp_wall_png="/tmp/rhythm-hypr-default.png"
                if command -v magick >/dev/null 2>&1; then
                    magick "$def_wp" "$tmp_wall_png" >> "$LOG_FILE" 2>&1 || true
                elif command -v convert >/dev/null 2>&1; then
                    convert "$def_wp" "$tmp_wall_png" >> "$LOG_FILE" 2>&1 || true
                elif command -v ffmpeg >/dev/null 2>&1; then
                    ffmpeg -y -i "$def_wp" "$tmp_wall_png" >> "$LOG_FILE" 2>&1 || true
                fi
                if [ -f "$tmp_wall_png" ]; then
                    for w in wall0.png wall1.png wall2.png; do
                        [ -f "/usr/share/hypr/$w" ] && sudo cp -f "$tmp_wall_png" "/usr/share/hypr/$w" >> "$LOG_FILE" 2>&1 || true
                    done
                    rm -f "$tmp_wall_png"
                fi
            fi
        fi

        # Preseed hyprpaper.conf with absolute wallpaper path for instant first start
        local seed_wp="$HOME/.config/hypr/wallpapers/default.jpg"
        [ -f "$HOME/.cache/current-wallpaper" ] && seed_wp=$(cat "$HOME/.cache/current-wallpaper" 2>/dev/null || echo "$seed_wp")
        if [ -f "$seed_wp" ]; then
            mkdir -p "$HOME/.config/hypr"
            printf "splash = false\nipc = on\npreload = %s\nwallpaper = ,%s\n" \
                "$seed_wp" "$seed_wp" > "$HOME/.config/hypr/hyprpaper.conf" 2>/dev/null || true
        fi
        step_ok "SDDM Astronaut theme configured."
    fi

    # Core system services
    step_item "Enabling NetworkManager and Bluetooth..."
    if command -v systemctl >/dev/null 2>&1; then
        sudo systemctl enable NetworkManager bluetooth >> "$LOG_FILE" 2>&1 || true
        sudo systemctl start NetworkManager bluetooth >> "$LOG_FILE" 2>&1 || true
    elif command -v rc-service >/dev/null 2>&1; then
        sudo rc-update add networkmanager default >> "$LOG_FILE" 2>&1 || true
        sudo rc-service networkmanager start >> "$LOG_FILE" 2>&1 || true
        sudo rc-update add bluetooth default >> "$LOG_FILE" 2>&1 || true
        sudo rc-service bluetooth start >> "$LOG_FILE" 2>&1 || true
        sudo rc-update add dbus default >> "$LOG_FILE" 2>&1 || true
        sudo rc-service dbus start >> "$LOG_FILE" 2>&1 || true
        sudo rc-update add seatd default >> "$LOG_FILE" 2>&1 || true
        sudo rc-service seatd start >> "$LOG_FILE" 2>&1 || true
        if rc-service -l 2>/dev/null | grep -q pipewire; then
            sudo rc-update add pipewire default >> "$LOG_FILE" 2>&1 || true
            sudo rc-service pipewire start >> "$LOG_FILE" 2>&1 || true
        fi
        for grp in seat video input audio; do
            if getent group "$grp" >/dev/null 2>&1; then
                sudo adduser "$USER" "$grp" >> "$LOG_FILE" 2>&1 || true
            fi
        done
    fi

    if [ "${ENABLE_SDDM:-true}" = true ]; then
        local other_dm
        other_dm=$(detect_existing_display_manager || true)
        if [ -n "$other_dm" ] && [ "$other_dm" != "sddm" ]; then
            step_item "Disabling $other_dm in favor of SDDM..."
            if command -v systemctl >/dev/null 2>&1; then
                sudo systemctl disable --now "$other_dm.service" >> "$LOG_FILE" 2>&1 || true
                sudo systemctl disable "$other_dm" >> "$LOG_FILE" 2>&1 || true
            elif command -v rc-service >/dev/null 2>&1; then
                sudo rc-service "$other_dm" stop >> "$LOG_FILE" 2>&1 || true
                sudo rc-update del "$other_dm" default >> "$LOG_FILE" 2>&1 || true
            fi
        fi

        # Disable all other common display managers to avoid conflicts with display-manager.service alias
        for dm in gdm gdm3 lightdm lxdm greetd ly cosmic-greeter slim; do
            if [ "$dm" != "sddm" ]; then
                if command -v systemctl >/dev/null 2>&1; then
                    sudo systemctl disable "$dm.service" >> "$LOG_FILE" 2>&1 || true
                elif command -v rc-service >/dev/null 2>&1; then
                    sudo rc-update del "$dm" default >> "$LOG_FILE" 2>&1 || true
                fi
            fi
        done

        # If display-manager.service symlink already exists and points to something else, remove or force it
        if [ -e /etc/systemd/system/display-manager.service ]; then
            local current_target
            current_target=$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)
            if [ -n "$current_target" ] && [[ "$current_target" != *"sddm"* ]]; then
                sudo rm -f /etc/systemd/system/display-manager.service >> "$LOG_FILE" 2>&1 || true
            fi
        fi

        # Debian default display manager file & debconf selections
        if command -v debconf-set-selections >/dev/null 2>&1; then
            echo "sddm shared/default-x-display-manager select sddm" | sudo debconf-set-selections 2>/dev/null || true
            echo "shared/default-x-display-manager select sddm" | sudo debconf-set-selections 2>/dev/null || true
        fi
        if [ -d /etc/X11 ] || [ -f /etc/X11/default-display-manager ]; then
            echo "/usr/bin/sddm" | sudo tee /etc/X11/default-display-manager >/dev/null 2>&1 || true
        fi

        # Ensure sddm user has access to video/render devices for Wayland greeter
        if id -u sddm >/dev/null 2>&1; then
            for grp in video render input; do
                getent group "$grp" >/dev/null 2>&1 && sudo usermod -aG "$grp" sddm 2>/dev/null || true
            done
            [ -d /var/lib/sddm ] && sudo chown -R sddm:sddm /var/lib/sddm 2>/dev/null || true
        fi

        # Ensure Hyprland desktop entry exists in wayland-sessions
        sudo mkdir -p /usr/share/wayland-sessions
        if [ ! -f /usr/share/wayland-sessions/hyprland.desktop ]; then
            cat << 'DESK_EOF' | sudo tee /usr/share/wayland-sessions/hyprland.desktop > /dev/null
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
DesktopNames=Hyprland
DESK_EOF
        fi

        # Preconfigure SDDM default session to Hyprland
        sudo mkdir -p /var/lib/sddm
        if [ ! -f /var/lib/sddm/state.conf ]; then
            printf "[Last]\nSession=hyprland.desktop\n" | sudo tee /var/lib/sddm/state.conf > /dev/null || true
            sudo chown -R sddm:sddm /var/lib/sddm 2>/dev/null || true
        fi

        step_item "Enabling SDDM display manager..."
        if command -v systemctl >/dev/null 2>&1; then
            if systemctl cat sddm.service >/dev/null 2>&1; then
                sudo systemctl enable --force sddm >> "$LOG_FILE" 2>&1 || sudo systemctl enable sddm >> "$LOG_FILE" 2>&1 || true
                sudo systemctl set-default graphical.target >> "$LOG_FILE" 2>&1 || true
                step_ok "SDDM enabled as default display manager."
            else
                step_warn "SDDM service unit not found on system."
            fi
        elif command -v rc-service >/dev/null 2>&1; then
            sudo rc-update add sddm default >> "$LOG_FILE" 2>&1 || true
            step_ok "SDDM enabled as default display manager via OpenRC."
        fi
    else
        step_ok "SDDM service activation skipped (existing display manager retained)."
    fi

    # PAM gnome-keyring unlock
    for pam_file in /etc/pam.d/login /etc/pam.d/sddm; do
        if [ -f "$pam_file" ] && ! grep -q "pam_gnome_keyring.so" "$pam_file"; then
            sudo sed -i '/^auth.*pam_unix/a auth       optional     pam_gnome_keyring.so' "$pam_file"
            sudo sed -i '/^session.*pam_unix/a session    optional     pam_gnome_keyring.so auto_start' "$pam_file"
        fi
    done

    # PAM hyprlock unlock
    if [ ! -f /etc/pam.d/hyprlock ]; then
        if [ -f /etc/pam.d/login ]; then
            printf "auth        include     login\n" | sudo tee /etc/pam.d/hyprlock >/dev/null || true
        elif [ -f /etc/pam.d/common-auth ]; then
            printf "auth        include     common-auth\n" | sudo tee /etc/pam.d/hyprlock >/dev/null || true
        fi
    fi

    # Pipewire audio sockets
    if command -v systemctl >/dev/null 2>&1; then
        step_item "Enabling Pipewire user audio services..."
        systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service >> "$LOG_FILE" 2>&1 || true
        systemctl --user enable --now pipewire.service >> "$LOG_FILE" 2>&1 || true
    fi

    # Add user to required groups (network for nmcli, lp for printing, optical for disc, seat for seatd)
    for grp in video input render wheel audio storage network lp optical seat; do
        if getent group "$grp" >/dev/null 2>&1; then
            if command -v usermod >/dev/null 2>&1; then
                sudo usermod -aG "$grp" "$USER" >> "$LOG_FILE" 2>&1 || true
            elif command -v adduser >/dev/null 2>&1; then
                sudo adduser "$USER" "$grp" >> "$LOG_FILE" 2>&1 || true
            fi
        fi
    done

    # Backlight permissions: configure udev rule with uaccess and ensure brightnessctl works immediately
    if [ "$IS_NIXOS" -eq 0 ] && [ -d /etc/udev/rules.d ]; then
        step_item "Configuring backlight hardware permissions..."
        cat << 'EOF' | sudo tee /etc/udev/rules.d/90-backlight.rules >/dev/null 2>&1 || true
# Give logged-in seat user read/write access to backlight and keyboard LEDs
ACTION=="add", SUBSYSTEM=="backlight", TAG+="uaccess", MODE="0664", GROUP="video"
ACTION=="add", SUBSYSTEM=="leds", KERNEL=="*kbd_backlight*", TAG+="uaccess", MODE="0664", GROUP="input"
EOF
        if command -v udevadm >/dev/null 2>&1; then
            sudo udevadm control --reload-rules >> "$LOG_FILE" 2>&1 || true
            sudo udevadm trigger --subsystem-match=backlight --subsystem-match=leds >> "$LOG_FILE" 2>&1 || true
        fi
    fi

    # Set SUID on brightnessctl as fail-safe across distros (Ubuntu, Debian, Alpine, openSUSE)
    _bctl="$(command -v brightnessctl 2>/dev/null || true)"
    if [ -n "$_bctl" ]; then
        sudo chmod u+s "$_bctl" >> "$LOG_FILE" 2>&1 || true
    fi

    # Battery charge limit permissions for Dynamic Island and laptops
    if [ "$IS_NIXOS" -eq 0 ]; then
        step_item "Configuring battery charge limit permissions..."
        sudo mkdir -p /etc/sudoers.d /usr/local/lib/rhythm
        local bat_limit_bin="$DOTFILES_DIR/.local/bin/battery-charge-limit"
        [ ! -f "$bat_limit_bin" ] && [ -f "$HOME/.local/bin/battery-charge-limit" ] && bat_limit_bin="$HOME/.local/bin/battery-charge-limit"
        if [ -f "$bat_limit_bin" ]; then
            sudo install -m 755 -o root -g root "$bat_limit_bin" /usr/local/lib/rhythm/battery-charge-limit 2>/dev/null || true
        fi
        cat << 'EOF' | sudo tee /etc/sudoers.d/rhythm-battery-limit > /dev/null 2>&1 || true
%wheel ALL=(root) NOPASSWD: /usr/local/lib/rhythm/battery-charge-limit
%sudo ALL=(root) NOPASSWD: /usr/local/lib/rhythm/battery-charge-limit
EOF
        echo "$USER ALL=(root) NOPASSWD: /usr/local/lib/rhythm/battery-charge-limit" | sudo tee -a /etc/sudoers.d/rhythm-battery-limit > /dev/null 2>&1 || true
        sudo chmod 440 /etc/sudoers.d/rhythm-battery-limit 2>/dev/null || true
    fi

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
            local pkg_label="pacman"
            [ "$DISTRO" = "fedora" ] && pkg_label="dnf"
            [ "$DISTRO" = "debian" ] && pkg_label="apt"
            [ "$DISTRO" = "ubuntu" ] && pkg_label="apt"
            [ "$DISTRO" = "alpine" ] && pkg_label="apk"
            [ "$DISTRO" = "opensuse" ] && pkg_label="zypper"
            if gum confirm "Would you also like to update system packages with $pkg_label?"; then
                bash "$DOTFILES_DIR/.local/bin/system-ota" update --system
            else
                bash "$DOTFILES_DIR/.local/bin/system-ota" update
            fi
        fi
    else
        step_dotfiles
    fi

    # Pywal, antes de modern-pywal-sync.
    #
    # ESTE PASO NO EXISTIA, y era la causa de que waybar y rofi salieran sin
    # tema. modern-pywal-sync se negaba a trabajar sin ~/.cache/wal/colors.sh,
    # ese cache solo lo crea `wal`, y `wal` no se ejecutaba en el camino de
    # update en absoluto: solo dentro del bloque de SDDM en la instalacion
    # completa. De modo que tras cualquier update en una maquina sin pywal
    # previo, los ficheros colors-pywal.css y colors-pywal.rasi no se creaban,
    # sus @import fallaban, y GTK y rofi descartan el tema ENTERO cuando un
    # import no se resuelve.
    #
    # Se hace aqui, y antes del sincronizador, para que sincronice una paleta de
    # verdad y no la de reserva.
    step_item "Calibrating the pywal palette from the current wallpaper..."
    local WAL_SRC=""
    if [ -f "$HOME/.cache/current-wallpaper" ]; then
        WAL_SRC=$(cat "$HOME/.cache/current-wallpaper" 2>/dev/null || true)
        [ -n "$WAL_SRC" ] && [ ! -f "$WAL_SRC" ] && WAL_SRC=""
    fi
    [ -z "$WAL_SRC" ] && [ -f "$HOME/.config/hypr/wallpapers/default.jpg" ] \
        && WAL_SRC="$HOME/.config/hypr/wallpapers/default.jpg"
    if command -v wal >/dev/null 2>&1 && [ -n "$WAL_SRC" ]; then
        wal -i "$WAL_SRC" -n -q >> "$LOG_FILE" 2>&1 \
            && step_ok "Pywal palette generated from $(basename "$WAL_SRC")." \
            || step_warn "wal fallo; se usara la paleta de reserva."
    else
        step_warn "Ni wal ni una imagen de la que sacar paleta; el sincronizador usara la reserva."
    fi

    if [ -x "$HOME/.local/bin/modern-pywal-sync" ]; then
        step_item "Syncing the palette to Waybar, Rofi, Mako and SDDM..."
        bash -c "$HOME/.local/bin/modern-pywal-sync >> '$LOG_FILE' 2>&1" \
            && step_ok "Colours synchronised." \
            || step_warn "modern-pywal-sync fallo; mira $LOG_FILE"
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
    if [ "$DISTRO" = "fedora" ]; then
        step_ok "Fedora Linux x86_64 verified."
        step_ok "DNF package manager & RPM Fusion repositories active."
        section "Package Toolchain & Repositories"
        step_ok "DNF COPRs (hyprland, quickshell, nwg-shell, sway-extras) verified."
    elif [ "$DISTRO" = "debian" ]; then
        step_ok "Debian Linux x86_64 (Trixie/Sid) verified."
        step_ok "APT package manager & Charm repositories active."
        section "Package Toolchain & Repositories"
        step_ok "Official Debian & Backports repositories verified."
    elif [ "$DISTRO" = "ubuntu" ]; then
        step_ok "Ubuntu Linux x86_64 verified."
        step_ok "APT package manager, Universe & Hyprland PPA repositories active."
        section "Package Toolchain & Repositories"
        step_ok "Official Ubuntu & Hyprland PPA repositories verified."
    else
        step_ok "Arch Linux x86_64 verified."
        step_ok "Parallel downloads & multilib repository active."
        section "AUR Helper & Build Toolchain"
        step_ok "yay aur helper ready."
    fi
    step_ok "Rust, cargo, and GTK4 layer-shell libraries ready."

    section "Core Packages & System Libraries"
    step_item "Simulating package dependency resolution..."
    for ((i=1; i<=10; i++)); do
        render_progress_bar "$((i*7))" 70 "Resolving packages ($((i*10))%)..."
        sleep 0.08
    done
    render_progress_bar 70 70 "Completed."
    [ -t 1 ] && printf "\n"
    step_ok "Compositor, Waybar, Quickshell, Rofi, Audio, Fonts resolved."

    section "Hardware Drivers & GPU Optimization"
    step_item "Simulating hardware auto-detection (NVIDIA/AMD/Intel)..."
    sleep 0.5
    if [ "$DISTRO" = "fedora" ]; then
        step_ok "NVIDIA Akmod, kernel-devel, DRM modesetting & dracut initramfs verified."
    elif [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "ubuntu" ]; then
        step_ok "NVIDIA DKMS, kernel headers, DRM modesetting & initramfs verified."
    else
        step_ok "Latest NVIDIA Open/DKMS drivers, kernel headers, DRM modesetting & pacman hook verified."
    fi

    section "Optional Software & Applications"
    step_item "Simulating interactive application menu..."
    sleep 0.4
    step_ok "Interactive multi-selection menu and universal fzf package search verified."

    section "Rust-Dock Component"
    rhythm_spin "Verifying rust-dock target binary..." -- sleep 0.8
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

    rhythm_spin "Calibrating Pywal color palette..." -- sleep 1.0

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
    rhythm_spin "Calibrating Pywal color scheme..." -- \
        bash -c "$HOME/.local/bin/modern-pywal-sync >> '$LOG_FILE' 2>&1 || true"
fi

# --- COMPLETION & REBOOT SCREEN ---
# Same helper the NixOS branch ends with, so both paths print the same screen
# and, more usefully, both say where the full log landed.
present_banner "Finished installing" "Installation complete."

if [ "$NO_REBOOT" = true ]; then
    gum style --foreground 7 --padding "0 0 1 $PADDING_LEFT" "Reboot skipped via flag."
elif [ "$AUTO_YES" = true ]; then
    if [ -n "$WAYLAND_DISPLAY" ] || [ -n "$DISPLAY" ]; then
        gum style --foreground 7 --padding "0 0 1 $PADDING_LEFT" "Rebooting into Hyprland..."
        rhythm_reboot
    elif [ "${ENABLE_SDDM:-true}" = true ] && { command -v systemctl >/dev/null 2>&1 && systemctl cat sddm.service >/dev/null 2>&1 || [ -x /etc/init.d/sddm ]; }; then
        if command -v systemctl >/dev/null 2>&1; then
            sudo systemctl start sddm || rhythm_reboot
        else
            sudo rc-service sddm start || rhythm_reboot
        fi
    else
        rhythm_reboot
    fi
elif [ -n "$WAYLAND_DISPLAY" ] || [ -n "$DISPLAY" ]; then
    gum style --foreground 7 --padding "0 0 1 $PADDING_LEFT" "You are running inside an active graphical session."
    gum style --foreground 7 --padding "0 0 1 $PADDING_LEFT" "Please reboot to apply all group permissions and start your desktop cleanly."
    if gum confirm "Reboot into Hyprland now?"; then
        rhythm_reboot
    fi
else
    if [ "${ENABLE_SDDM:-true}" = true ] && { command -v systemctl >/dev/null 2>&1 && systemctl cat sddm.service >/dev/null 2>&1 || [ -x /etc/init.d/sddm ]; }; then
        if gum confirm "Start SDDM login manager now?"; then
            if command -v systemctl >/dev/null 2>&1; then
                sudo systemctl start sddm || {
                    gum style --foreground 3 --padding "0 0 1 $PADDING_LEFT" "Could not start SDDM directly. Rebooting into desktop..."
                    rhythm_reboot
                }
            else
                sudo rc-service sddm start || {
                    gum style --foreground 3 --padding "0 0 1 $PADDING_LEFT" "Could not start SDDM directly. Rebooting into desktop..."
                    rhythm_reboot
                }
            fi
        elif gum confirm "Reboot into Hyprland now?"; then
            rhythm_reboot
        fi
    else
        if gum confirm "Reboot into Hyprland now?"; then
            rhythm_reboot
        fi
    fi
fi
