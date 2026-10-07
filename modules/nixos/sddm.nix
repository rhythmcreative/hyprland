# Login scope: SDDM on Wayland with the astronaut theme, login on the
# internal panel only.
#
# This is the declarative version of rhythm-sddm-deploy. On Arch that script
# writes the greeter wrapper to /usr/local/lib/rhythm, the Hyprland template
# to /usr/share/sddm and drop-ins to /etc/sddm.conf.d; here the same three
# pieces are store paths and module settings, so installer and updater cannot
# drift apart (see ADR-0004).
#
# Known limitation, and why this module postInstalls the theme: the greeter
# palette and background are baked in at build time. Live pywal recolouring is
# not possible on NixOS because the store is read-only (ADR-0004), so instead
# of dropping the feature, the build reads the same theme.conf the repo ships
# and copies it in, which the upstream package leaves out.
{ config, lib, pkgs, ... }:

let
  cfg = config.rhythm;

  # theme.conf lives in the repo's vendored theme, not in the upstream package:
  # sddm-astronaut installs Assets, Backgrounds, Components, Fonts, Main.qml,
  # Themes and metadata.desktop, but no theme.conf of its own, so the greeter
  # starts with no Background setting at all and paints its bundled
  # astronaut.png instead of the user's wallpaper. Arch gets the file because
  # install.sh copies the whole vendored directory into /usr/share; on NixOS
  # the equivalent has to be done in the build.
  vendoredTheme = ../../sddm/sddm-astronaut-theme;

  cursorName = "Bibata-Modern-Ice";

  # What the greeter does with CursorTheme is one call: the daemon reads the
  # name from sddm.conf and passes it over the socket, and sddm-greeter-qt6
  # hands it to QIcon::setThemeName(). Neither binary mentions FacesDir -- the
  # Wayland greeter has no such setting, it is an X11-era one for face icons.
  # So CursorTheme only works if Qt can resolve the name on its own, and Qt
  # looks in $XDG_DATA_DIRS/icons and $HOME/.icons.
  #
  # Neither exists for the greeter: its user is sddm with HOME=/var/lib/sddm,
  # its unit sets no XDG_DATA_DIRS, and /etc/environment -- which is what
  # pam_env.so in etc/pam.d/sddm-greeter reads -- is not generated here. Qt
  # therefore falls back to its compiled-in /usr/local/share:/usr/share, which
  # do not exist on NixOS, finds no cursor theme at all, and silently uses its
  # bundled arrow.
  #
  # Hence the two halves: the cursor has to be somewhere Qt scans, and the
  # greeter has to be told to scan it.
  cursorDataDir = "${pkgs.bibata-cursors}/share";

  # SDDM lists every session file in SessionDir, so the greeter's list is
  # whatever this directory holds. Built from the hyprland package's own file,
  # unmodified: the point is to drop hyprland-uwsm.desktop from the list, not
  # to alter how the remaining session starts.
  sessionDir = pkgs.runCommand "hyprland-wayland-sessions" { } ''
    mkdir -p "$out"

    if [ -f "${pkgs.hyprland}/share/wayland-sessions/hyprland.desktop" ]; then
      cp "${pkgs.hyprland}/share/wayland-sessions/hyprland.desktop" "$out/"
    else
      echo "AVISO: hyprland no trae hyprland.desktop" >&2
    fi
  '';

  # The wallpaper is a loose file inside another store path. A path written by
  # hand is not mounted into the build sandbox, so it is wrapped in its own
  # tiny derivation and declared as a build input; without that the copy in
  # postInstall cannot see it.
  wallpaperDrv = pkgs.runCommand "sddm-greeter-wallpaper" { } ''
    mkdir -p "$out"
    cp ${cfg.packageSet.patchedHypr}/wallpapers/default.jpg "$out/default.jpg"
  '';

  theme = pkgs.sddm-astronaut.override {
    embeddedTheme = "astronaut";
    themeConfig = {
      partialBlur = "true";
      dimBackground = "0.2";
    } // cfg.sddm.themeConfig;
  };
in
{
  config = lib.mkIf (cfg.enable && cfg.features.sddm) {
    services.displayManager = {
      defaultSession = "hyprland";
      sddm = {
        enable = true;
      wayland = {
        enable = true;
        # Weston is only the fallback selected for its dependencies: picking
        # it pulls qtwayland into the SDDM package, which the QML greeter
        # theme needs under any Wayland compositor. The actual command is
        # replaced below through settings, the module's designed override.
        compositor = "weston";
      };
      settings.Wayland.CompositorCommand = "${cfg.packageSet.greeterMonitor}/bin/sddm-greeter-monitor";

      # hyprland ships two session files -- hyprland.desktop, which execs
      # start-hyprland directly, and hyprland-uwsm.desktop, which goes through
      # `uwsm start` -- and SDDM lists every one it finds in SessionDir, so the
      # greeter offered both. SessionDir is narrowed to the plain one so the
      # list has a single entry.
      #
      # The consequence is deliberate and worth stating: with uwsom the
      # compositor is started by the systemd --user manager, which is what
      # reads ~/.config/environment.d and therefore what delivers
      # RHYTHM_PLUGIN_HYPRBARS and the zsh plugin paths (see
      # modules/home-manager/packages.nix). Started by SDDM's helper instead,
      # Hyprland is a child of that helper and inherits nothing from the user
      # manager, so hyprctl plugin load never runs and kitty falls back to
      # /usr/share/zsh/plugins, which does not exist here.
      settings.Wayland.SessionDir = "${sessionDir}";

      theme = "sddm-astronaut-theme";
    };
  };

    environment.systemPackages = [
      # overrideAttrs, not a plain override: the vendored theme.conf has to be
      # copied into the built package after upstream installs its own files.
      #
      # Without this the greeter has no theme.conf of the user's own. The QML
      # reads config.Background and its Background*Alignment properties from
      # there, so what is missing is exactly the wallpaper and layout the login
      # screen is supposed to show.
      #
      # installPhase, NOT postInstall. Upstream sddm-astronaut overrides
      # installPhase with its own string, and stdenv's runPhase evaluates the
      # env var in preference to the shell function
      # (`eval "${!curPhase:-$curPhase}"`), so that string replaces the
      # installPhase function entirely -- and the function is the only thing
      # that calls `runHook postInstall`. postInstall is a hook name, not a
      # phase: setting it here defined a variable nothing ever evaluated, so
      # every copy below was dead code and the greeter started with upstream's
      # bare theme (no theme.conf, no current_wallpaper.jpg, bundled
      # astronaut.png). Appending to installPhase runs after upstream's own
      # install, which is what leaves Fonts/ and Assets/ read-only, hence the
      # chmod.
      (theme.overrideAttrs (old: {
        nativeBuildInputs = lib.concatLists [
          (old.nativeBuildInputs or [ ])
          [ wallpaperDrv ]
        ];

        installPhase = (old.installPhase or "") + ''
          themeDir="$out/share/sddm/themes/sddm-astronaut-theme"

          chmod -R u+w "$themeDir" 2>/dev/null || true

          # Which file the greeter reads is NOT theme.conf. sddm-greeter
          # follows ConfigFile from metadata.desktop, and upstream v1.3
          # points that at Themes/<embeddedTheme>.conf. So writing the
          # user's config to theme.conf leaves the greeter on the bundled
          # astronaut.png -- the "no theme" login screen -- no matter how
          # correct theme.conf is. The name is therefore read back out of
          # the installed metadata instead of hardcoded: it differs per
          # source (the vendored theme names Themes/theme1.conf) and per
          # embeddedTheme, and the log line "Loading theme configuration
          # from ..." is the only thing that says which one won.
          confFile="$themeDir/theme.conf"
          confRel=$(sed -n 's/^ConfigFile=//p' "$themeDir/metadata.desktop" 2>/dev/null | head -n1 | tr -d '[:space:]')
          case "$confRel" in
            /*) confFile="$confRel" ;;
            ?*) confFile="$themeDir/$confRel" ;;
          esac

          # The repo's theme.conf is the one that sets Background and the
          # layout; upstream ships none.
          if [ -f "${vendoredTheme}/theme.conf" ]; then
            mkdir -p "$(dirname "$confFile")"
            cp "${vendoredTheme}/theme.conf" "$confFile"
          fi

          # Main.qml is the load-bearing one, and it is why this is not just a
          # matter of copying a config file. Upstream v1.3 opens with
          # `import QtMultimedia`, for its video backgrounds, and SDDM's QML
          # import path carries only SddmComponents -- qtmultimedia is not
          # there. The import fails, the engine logs "Fallback to embedded
          # theme" and paints SDDM's built-in grey login, ignoring this entire
          # directory: at which point theme.conf, the wallpaper and the layout
          # are all dead weight and the greeter looks unthemed no matter how
          # correct they are. The vendored Main.qml is v1.1 and has no such
          # import, which is also what Arch installs.
          if [ -f "${vendoredTheme}/Main.qml" ]; then
            cp "${vendoredTheme}/Main.qml" "$themeDir/Main.qml"
          fi

          # Fonts, Assets and Components come from the vendored theme too, and
          # the package may carry older copies. Components has to move with
          # Main.qml: v1.3 split VirtualKeyboardButton.qml out of
          # VirtualKeyboard.qml and dropped UserList.qml, so the two revisions
          # are only consistent as a pair.
          for extra in Fonts Assets Components; do
            if [ -d "${vendoredTheme}/$extra" ]; then
              mkdir -p "$themeDir/$extra"
              cp -r "${vendoredTheme}/$extra/." "$themeDir/$extra/"
            fi
          done

          # theme.conf points at Backgrounds/current_wallpaper.jpg. That file
          # is what the greeter draws, and it has to exist inside the package
          # or the login screen has no image to show. Baked in at build time
          # rather than synced live: the store is read-only (ADR-0004).
          if [ -f "${wallpaperDrv}/default.jpg" ]; then
            cp "${wallpaperDrv}/default.jpg" \
              "$themeDir/Backgrounds/current_wallpaper.jpg"
          else
            # Nothing to paint: keep the QML from asking for a file that is
            # not there, which reads as an empty grey login screen.
            echo "AVISO: sin wallpaper para el greeter" >&2
            sed -i 's|^Background=.*|Background="Backgrounds/astronaut.png"|' \
              "$confFile" 2>/dev/null || true
          fi
        '';
      }))
      # The greeter cursor, same package home.pointerCursor gives the user.
      # In the system profile it lands in /run/current-system/sw/share/icons,
      # which is one of the XDG_DATA_DIRS handed to the greeter below, so Qt
      # resolves CursorTheme from there instead of falling back to its bundled
      # arrow. Nothing new in the closure.
      pkgs.bibata-cursors
    ];

    # Greeter cursor, matching the Bibata-Modern-Ice default on Arch.
    services.displayManager.sddm.settings.General.CursorTheme = cursorName;

    # CursorTheme is only a name handed to QIcon::setThemeName() (see the note
    # on cursorDataDir), and that is not even what paints the pointer here:
    # Hyprland implements wp_cursor_shape_manager_v1, so a client asks the
    # compositor for a cursor shape by name and the compositor returns the
    # image from its own theme. The greeter is a Hyprland instance (see
    # sddm-greeter-monitor), so its pointer is drawn by Hyprland and
    # QIcon::setThemeName() has no bearing on it at all.
    #
    # What Hyprland reads is XCURSOR_THEME, with XCURSOR_PATH as the search
    # path -- the classic Xcursor lookup.
    #
    # Not set on display-manager.service: measured on a live greeter, that
    # environment never reaches the greeter's compositor. sddm opens a session
    # for user sddm, which starts a systemd --user manager, and that manager
    # is what populates the environment the greeter's Hyprland actually runs
    # with. A display-manager.service override is discarded there -- the
    # greeter came up with XCURSOR_THEME empty and XDG_DATA_DIRS rewritten to
    # the profile list, both of which had been set correctly on the unit.
    #
    # environment.sessionVariables is the option that works: it is the same
    # one nixpkgs itself uses for XCURSOR_PATH (config/xdg/icons.nix), and
    # XCURSOR_PATH demonstrably does reach the greeter's manager -- its value
    # there already ends in /run/current-system/sw/share/icons, where
    # bibata-cursors below puts the theme. So only the name was missing.
    environment.sessionVariables.XCURSOR_THEME = cursorName;

    # And only for Qt's own lookup, which needs the theme reachable through
    # XDG_DATA_DIRS. Hyprland does not read it, but the greeter's Qt client
    # still resolves icon themes that way, and /etc/environment is not
    # generated on this system so pam_env has nothing to supply.
    environment.sessionVariables.XDG_DATA_DIRS = [
      "/run/current-system/sw/share"
      cursorDataDir
      "/etc/xdg/share"
    ];

    # Kept in the system profile as well, so the theme lands in
    # /run/current-system/sw/share/icons/<name> rather than only in a path Qt
    # is told about. home.pointerCursor already pulls the same package in for
    # the user, so this adds nothing to the closure.

    # GNOME Keyring unlock at login, replacing the /etc/pam.d sed edits.
    # login uses the default ruleset, so the plain switch works there. sddm
    # ships custom rules (useDefaultRules=false), where enableGnomeKeyring
    # is silently ignored, so the keyring rule is appended by name instead.
    security.pam.services.login.enableGnomeKeyring = true;
    security.pam.services.sddm.rules = {
      auth.gnome_keyring = {
        control = "optional";
        modulePath = "${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so";
        order = 20000;
        settings.auto_start = true;
      };
      session.gnome_keyring = {
        control = "optional";
        modulePath = "${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so";
        order = 20000;
        settings.auto_start = true;
      };
    };
  };
}
