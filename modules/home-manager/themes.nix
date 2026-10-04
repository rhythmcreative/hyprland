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

    home.packages = with pkgs; [
      pywal16
      qt6ct
      nwg-displays
      nwg-look
    ];
  };
}
