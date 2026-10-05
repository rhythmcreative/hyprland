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
      # postInstall is the last phase the derivation defines, so that is where
      # the copy has to live. It runs after upstream's own install, which is
      # what leaves Fonts/ and Assets/ read-only, hence the chmod.
      (theme.overrideAttrs (old: {
        nativeBuildInputs = lib.concatLists [
          (old.nativeBuildInputs or [ ])
          [ wallpaperDrv ]
        ];

        postInstall = (old.postInstall or "") + ''
          themeDir="$out/share/sddm/themes/sddm-astronaut-theme"

          chmod -R u+w "$themeDir" 2>/dev/null || true

          # The repo's theme.conf is the one that sets Background and the
          # layout; upstream ships none.
          if [ -f "${vendoredTheme}/theme.conf" ]; then
            cp "${vendoredTheme}/theme.conf" "$themeDir/theme.conf"
          fi

          # Fonts and Assets come from the vendored theme too, and the package
          # may carry older copies of both.
          for extra in Fonts Assets; do
            if [ -d "${vendoredTheme}/$extra" ]; then
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
              "$themeDir/theme.conf" 2>/dev/null || true
          fi
        '';
      }))
    ];

    # Greeter cursor, matching the Bibata-Modern-Ice default on Arch.
    services.displayManager.sddm.settings.General.CursorTheme = "Bibata-Modern-Ice";

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
