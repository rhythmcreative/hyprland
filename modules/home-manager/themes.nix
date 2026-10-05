# Look and feel: cursor, icons, GTK/Qt theming and pywal.
#
# pywal here means pywal16, the maintained fork: same `wal` command, same
# ~/.cache/wal outputs, so every `wal -i` call site and colors.sh parser
# keeps working (see ADR-0002).
{ config, lib, pkgs, ... }:

let
  cfg = config.rhythm;
in
{
  config = lib.mkIf cfg.enable {
    home.pointerCursor = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 24;
      enable = true;
      gtk.enable = true;
      x11.enable = true;
    };

    gtk = {
      enable = true;
      iconTheme = {
        name = "Tela-circle";
        package = pkgs.tela-circle-icon-theme;
      };
    };

    # Enabling gtk makes home-manager write org/gnome/desktop/interface
    # keys via `dconf load`, which needs the ca.desrt.dconf bus service.
    # On NixOS that comes from programs.dconf.enable (system-wide);
    # standalone home-manager users have no system side, so expose the
    # service file to the user bus directly. Same content the system
    # would provide, so it is a no-op where programs.dconf already runs.
    xdg.dataFile."dbus-1/services/ca.desrt.dconf.service".source =
      "${pkgs.dconf}/share/dbus-1/services/ca.desrt.dconf.service";

    home.packages = with pkgs; [
      pywal16
      qt6Packages.qt6ct
      nwg-displays
      nwg-look
    ];
  };
}
