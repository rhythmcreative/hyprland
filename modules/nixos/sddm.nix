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

  # SDDM's own FacesDir ships only .face.icon and root.face.icon, which are
  # X11 core-cursor aliases: this greeter is Wayland and Qt resolves cursor
  # themes as FacesDir/<name>/{cursor.theme,index.theme,cursors/}, so neither
  # of those files is ever loaded here. Only the theme goes in.
  #
  # pkgs.sddm is not referenced on purpose -- it is not a top-level attribute
  # in this nixpkgs, and reaching it through
  # config.services.displayManager.sddm.package instead would make the sddm
  # derivation depend on this directory while this directory depended on the
  # sddm derivation.
  cursorFaces = pkgs.runCommand "sddm-faces" { } ''
    mkdir -p "$out"

    if [ -d "${pkgs.bibata-cursors}/share/icons/${cursorName}" ]; then
      cp -r "${pkgs.bibata-cursors}/share/icons/${cursorName}" "$out/"
    else
      echo "AVISO: no hay cursor ${cursorName} para el greeter" >&2
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
  config = lib.mkIf cfg.enable {
    services.displayManager.sddm = {
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
      theme = "sddm-astronaut-theme";
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
    ];

    # Greeter cursor, matching the Bibata-Modern-Ice default on Arch.
    services.displayManager.sddm.settings.General.CursorTheme = cursorName;

    # CursorTheme is only a name: SDDM resolves it against FacesDir, and
    # nixpkgs points that at SDDM's own directory, which ships just the two
    # X core-cursor aliases (.face.icon, root.face.icon). Bibata-Modern-Ice is
    # not in there, so the name resolves to nothing and Qt falls back to its
    # default arrow with no warning -- a different cursor in the greeter than
    # the one the session uses. The cursor package is already in the closure
    # (home.pointerCursor pulls it in for the user), so this only has to point
    # FacesDir at a directory that has the theme in it.
    # FacesDir, not General: nixpkgs declares its default under [Theme], so
    # setting it in [General] writes a second FacesDir into the file instead
    # of replacing that one, and the later [Theme] line is the one SDDM uses.
    services.displayManager.sddm.settings.Theme.FacesDir = "${cursorFaces}";

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
