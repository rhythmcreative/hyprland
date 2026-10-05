# Shared options for the Rhythm Hyprland desktop.
#
# Both the NixOS module (system scope: users, services, SDDM, hardware) and
# the home-manager module (user scope: dotfiles, helpers, user units) read
# these, so one set of values drives both sides. See docs/adr for why each
# default looks the way it does.
{ lib, pkgs, ... }:

{
  options.rhythm = {
    enable = lib.mkEnableOption "the Rhythm Hyprland desktop";

    username = lib.mkOption {
      type = lib.types.str;
      description = "User the desktop is configured for.";
    };

    gpu = lib.mkOption {
      type = lib.types.enum [ "auto" "nvidia" "amd" "intel" ];
      default = "auto";
      description = ''
        GPU stack to configure. "auto" only enables generic modesetting and
        firmware; the vendor stacks need an explicit value because NixOS
        resolves drivers at build time and cannot probe PCI IDs the way
        install.sh does with lspci. NVIDIA also needs allowUnfree, so it is
        never pulled in silently.
      '';
    };

    # Programs the desktop invokes at runtime. Declared here, next to the
    # options both scopes read, because the two scopes install them through
    # different mechanisms: the NixOS module as environment.systemPackages
    # (so they survive a login without a user session), the home-manager
    # module as home.packages. install.sh deploys home-manager alone (see
    # modules/home-manager/packages.nix), so a list that only lived in the
    # NixOS module left a session with a compositor and nothing to run.
    desktopPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        # Compositor companions and the session itself.
        hypridle
        hyprlock
        hyprsunset
        hyprpicker
        # Bar, menu, notifications and the dynamic island.
        waybar
        quickshell
        rofi
        libnotify
        # Terminal and file manager: hyprland.lua binds both by name.
        kitty
        thunar
        # Screenshots, clipboard and screen sharing.
        grim
        slurp
        swappy
        cliphist
        wl-clipboard
        wf-recorder
        # Media and wallpaper.
        mpv
        mpvpaper
        awww
        # Hardware and power control used by the helper scripts.
        brightnessctl
        pamixer
        playerctl
        # Small utilities the scripts and binds reach for.
        socat
        jq
        inotify-tools
        psmisc
        # Installer visuals and menus: helpers and install.sh show messages
        # through gum (choose/confirm/style) with plain-text fallback. On Arch
        # pacman always provides it; on NixOS it must be installed, otherwise
        # the styled prompts silently degrade and look like missing output.
        gum
        fzf
      ];
      description = ''
        Programs the desktop needs on PATH. Installed as
        environment.systemPackages by the NixOS module and as home.packages
        by the home-manager module, so a standalone install gets the same
        working desktop as a system-wide one.
      '';
    };

    monitors.seedText = lib.mkOption {
      type = lib.types.lines;
      default = "monitor=,preferred,auto,1";
      description = ''
        Initial content of ~/.config/hypr/monitors.conf, written only when
        the file does not exist yet. nwg-displays owns the file afterwards;
        later rebuilds never overwrite it.
      '';
    };

    wallpaper.mode = lib.mkOption {
      type = lib.types.enum [ "none" "random" "all" ];
      default = "random";
      description = ''
        Wallpaper pack download behaviour, mirroring install.sh --wallpapers.
        Fetching stays imperative (an activation script); Nix never puts
        850 MB of wallpapers in the store.
      '';
    };

    features = {
      island = lib.mkEnableOption "the quickshell dynamic island" // { default = true; };
      wallpaperWatcher = lib.mkEnableOption "the wallpaper monitor watcher" // { default = true; };
      rustDock = lib.mkEnableOption "rust-dock and its monitor watcher" // { default = true; };
      bluetooth = lib.mkEnableOption "the BlueZ pairing agent in the island" // { default = true; };
      powerProfile = lib.mkEnableOption "the automatic power profile daemon" // { default = true; };
      privacyShield = lib.mkEnableOption "the camera and microphone privacy shield" // { default = true; };
      nightlight = lib.mkEnableOption "night light temperature scheduling" // { default = true; };
      caffeine = lib.mkEnableOption "the on-demand caffeine inhibitor" // { default = true; };
      # Off on purpose: on NixOS, updates arrive through
      # `nix flake update` plus `nixos-rebuild switch`, not through the
      # Arch pacman-based checker (see ADR-0005).
      otaCheck = lib.mkEnableOption "the background OTA update checker" // { default = false; };
      flatpaks = lib.mkEnableOption "flatpak support with the repo app list" // { default = false; };
    };

    packageSet = {
      helpers = lib.mkOption {
        type = lib.types.package;
        default = pkgs.rhythmHelpers;
        description = "Derivation with the ~/.local/bin helper scripts.";
      };
      rustDock = lib.mkOption {
        type = lib.types.package;
        default = pkgs.rustDock;
        description = "Packaged rust-dock binary (replaces the cargo build).";
      };
      greeterMonitor = lib.mkOption {
        type = lib.types.package;
        default = pkgs.greeterMonitor;
        description = "SDDM greeter wrapper deciding which output shows the login.";
      };
    };

    sddm.themeConfig = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        Extra themeConfig values for the sddm-astronaut theme (static,
        baked in at build time). Live pywal recolouring of the greeter is
        not supported on NixOS: the store is read-only (see ADR-0004).
      '';
    };
  };
}
