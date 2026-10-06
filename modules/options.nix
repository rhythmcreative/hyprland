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
        # ffmpeg lo usa el selector de fondos de la Isla para las vistas
        # previas de los .gif. No estaba en ninguna de las dos listas, con lo
        # que la previsualizacion de animados no podia funcionar en ninguna
        # plataforma: ademas de faltar el paquete, la ruta que el QML tenia
        # escrita (/usr/bin/ffmpeg) no existe en NixOS, donde el binario vive
        # en el store.
        ffmpeg
        # Hardware and power control used by the helper scripts.
        brightnessctl
        pamixer
        playerctl
        # Small utilities the scripts and binds reach for.
        socat
        jq
        inotify-tools
        psmisc
        # gsettings viene en glib. Los scripts de pywal lo usan para activar
        # el tema GTK y el color-scheme, pero lo invocan tras un
        # `command -v`, asi que su ausencia no daba ningun error: elDesktop
        # se quedaba en el tema por defecto sin decir por que. Sin esto, el
        # despliegue del tema PywalSync-Mono no llegaba a aplicarse.
glib
        # bc, no por el powermenu en si sino por powermenu-with-monitor-detection:
        # escala las fuentes y los espaciados del tema de rofi con `48 * $scale
        # factor | bc` (6 llamadas). Sin bc cada variable queda vacia, el .rasi que
        # genera sale con `mainbox-spacing: px` sin numero, rofi lo rechaza con
        # "Failed to parse theme" y sale con codigo 1: el menu de Super+BackSpace
        # no llega ni a abrirse, y el log solo muestra "Opcion seleccionada:"
        # en vacio. El script nunca declaro la dependencia y en Arch bc viene en
        # el sistema base.
        bc
        # python3: nueve helpers de ~/.local/bin la usan (los sensores de la
        # Isla, bluetooth-pair-agent, pywal-tela-sync) y varios la invocan como
        # `python3 -c` en linea, no por shebang. Sin esto eran 730 fallos en
        # cinco minutos y el agente de emparejamiento Bluetooth reiniciaba 439
        # veces con status=127.
        python3
        # pulseaudio aporta pactl, que usa volume-dynamic para las teclas de
        # volumen (F11/F12 y el mute). PipeWire no lo trae, asi que sin esto
        # esas teclas no hacian nada.
        pulseaudio
        # hyprpicker lo invoca el atajo de selector de color e identify (de
        # imagemagick) lo usa el backend de fondos para detectar .webp
        # animados, que si no se tratan como estaticos.
        imagemagick
        # --- Shell -------------------------------------------------------
        # El .zshrc del repo sourcea los dos plugins de abajo y arranca
        # starship. En Arch pacman los deja en /usr/share/zsh/plugins y starship
        # esta en el PATH, asi que los tres existen. En NixOS no hay
        # /usr/share: sin declararlos el shell abria limpio pero SIN
        # resaltado de sintaxis, SIN autosuggestiones y SIN el prompt de
        # starship, que es justo lo que hace util el .zshrc.
        #
        # Las rutas exactas de los dos .zsh las exporta modules/nixos/system.nix
        # en sessionVariables, que es lo que .zshrc lee
        # (ZSH_AUTOSUGGESTIONS_SRC / ZSH_SYNTAX_HIGHLIGHTING_SRC).
        zsh-autosuggestions
        zsh-syntax-highlighting
        starship
        # --- Thunar: operaciones de fichero -------------------------------
        # Sin esto Thunar abria pero no podia hacer casi nada con los
        # archivos: sin file-roller no descomprime nada, sin gvfs no aparecen
        # los volumenes de red, y sin tumbler no hay miniaturas. En Arch los
        # cuatro vienen del gestor de archivos, que aqui no hay.
        file-roller
        gvfs
        tumbler
        thunar-archive-plugin
        thunar-volman
        # ffmpegthumbnailer genera las miniaturas de video, que tumbler no
        # sabe hacer por si mismo.
        ffmpegthumbnailer
        # --- Utilidades ---------------------------------------------------
        # lsof lo usan privacy-shield-daemon y privacy-status para detectar la
        # camara abierta por un descriptor de fichero. Hay un respaldo con
        # fuser, pero en Arch es lsof y el comportamiento debe coincidir.
        lsof
        xdg-user-dirs
        htop
        btop
        fastfetch
        # v4l-utils aporta v4l2-utility, con el que se enumera y ajusta la
        # camara.
        v4l-utils
        # gnome-keyring aporta gnome-keyring-daemon, que hyprland.lua lanza en
        # el autostart con
        #     gnome-keyring-daemon --start --components=secrets &
        # El modulo NixOS lo declaraba solo para el modulo PAM (sddm.nix), que
        # es el cierre del servicio y no el PATH del usuario: con
        # enableGnomeKeyring el llavero se desbloquea al iniciar sesion, pero el
        # daemon no llegaba a existir y por eso las aplicaciones no recordaban
        # ninguna contrasena. En Arch el paquete ya estaba en el sistema, que
        # es por lo que nadie noto que era una dependencia.
        gnome-keyring
        # brave-origin es el navegador por defecto. En Arch install.sh lo ofrece como
        # la opcion AUR brave-origin-nightly-bin; el sufijo -bin es de Arch y
        # en nixpkgs el mismo navegador es brave-origin. Ese atributo solo
        # existe a partir de nixos-unstable, asi que en el canal estable se
        # degrada a brave en vez de romper el rebuild.
        (if pkgs ? brave-origin then pkgs.brave-origin else pkgs.brave)
        # cava es el visualizador de audio que dibuja la barra del_custom/cava en
        # modules-left. Sin el binario, cava.sh devuelve vacio y el modulo no
        # aparece: en la captura se veia la izquierda sin la barra de audio.
        cava
        # nm-applet, en nixpkgs como networkmanagerapplet (el paquete `networkmanager`
        # solo trae el daemon y las herramientas de linea de comandos).
        # hyprland.lua lo lanza con `nm-applet --indicator &` y el menu de wifi
        # de waybar lo abria, asi que sin esto ese bind no hacia nada.
        networkmanagerapplet
        gnome-network-displays
        # NOTE: gum and fzf are deliberately NOT here. This list becomes
        # home.packages, and the installer separately runs `nix profile
        # install nixpkgs#gum` into ~/.nix-profile. Both would provide
        # share/zsh/site-functions/_gum, and two packages owning the same
        # file in one profile aborts the whole home-manager activation
        # ("An existing package already provides the following file").
        # The NixOS module adds them to environment.systemPackages instead,
        # which never enters the user profile.
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

    # Reduccion de ruido del microfono. En Arch se activa a mano con
    # toggle-noise-suppression, asi que por defecto va apagado tambien aqui: lo
    # contrario es una diferencia de comportamiento entre las dos plataformas.
    audio.denoising = lib.mkEnableOption
      "the RNNoise microphone filter chain in PipeWire" // { default = false; };

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
      # hyprbars draws a title bar on every window. Off means the shared
      # hyprland.lua never sees RHYTHM_PLUGIN_HYPRBARS and never runs
      # `hyprctl plugin load` on it, so no bar is drawn anywhere.
      hyprbars = lib.mkEnableOption "the hyprbars plugin, which adds title bars to windows" // {
        default = true;
      };
      asus = lib.mkEnableOption "ASUS ROG/TUF hardware integration (asusctl, supergfxctl, power curves)" // { default = false; };
      surface = lib.mkEnableOption "Microsoft Surface hardware integration (surface-control)" // { default = false; };
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
      pywalSyncMono = lib.mkOption {
        type = lib.types.package;
        default = pkgs.pywalSyncMono;
        description = ''
          The gtk/.themes/PywalSync-Mono GTK theme from the repo, wrapped so
          home-manager can deploy it. GTK reads themes from disk, so a plain
          checkout in the repo is not enough on its own.
        '';
      };
      patchedWaybar = lib.mkOption {
        type = lib.types.package;
        default = pkgs.patchedWaybar;
        description = ''
          .config/waybar with its shebangs resolved for NixOS. Deployed
          through xdg.configFile, so it gets no build step of its own.
        '';
      };
      patchedHypr = lib.mkOption {
        type = lib.types.package;
        default = pkgs.patchedHypr;
        description = ''
          .config/hypr with its shebangs resolved for NixOS, for the scripts
          under scripts/ that hyprland.lua and hyprlock.conf invoke.
        '';
      };
      patchedWal = lib.mkOption {
        type = lib.types.package;
        default = pkgs.patchedWal;
        description = ".config/wal with its shebangs resolved; these are pywal hooks.";
      };
      patchedQuickshell = lib.mkOption {
        type = lib.types.package;
        default = pkgs.patchedQuickshell;
        description = ''
          .config/quickshell with its shebangs resolved, for hyprwall/.
        '';
      };
      patchedGtk3 = lib.mkOption {
        type = lib.types.package;
        default = pkgs.patchedGtk3;
        description = ".config/gtk-3.0 with its shebangs resolved.";
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
