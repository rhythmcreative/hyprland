# Login scope: SDDM on Wayland with the astronaut theme, login on the
# internal panel only.
#
# This is the declarative version of rhythm-sddm-deploy. On Arch that script
# writes the greeter wrapper to /usr/local/lib/rhythm, the Hyprland template
# to /usr/share/sddm and drop-ins to /etc/sddm.conf.d; here the same three
# pieces are store paths and module settings, so installer and updater cannot
# drift apart (see ADR-0004).
#
# Known limitation: the greeter palette is baked in at build time through
# themeConfig. Live pywal recolouring of the login screen is not supported
# on NixOS because the store is read-only.
{ config, lib, pkgs, ... }:

let
  cfg = config.rhythm;
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

    environment.systemPackages = [ theme ];

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
