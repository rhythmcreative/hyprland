# Config directories, deployed declaratively instead of copied by install.sh.
#
# Two deliberate exceptions:
# - .config/systemd is NOT deployed: home-manager generates the user units
#   from services.nix, and stray unit files with the same names would
#   collide with the generated ones.
# - .config/hypr/monitors.conf is NOT deployed: nwg-displays owns that file
#   and the repo does not ship it. It is seeded once when missing, then left
#   alone, mirroring the saved_monitors dance in install.sh.
{ config, lib, ... }:

let
  cfg = config.rhythm;
in
{
  config = lib.mkIf cfg.enable {
    xdg.configFile."Kvantum" = { source = ../../.config/Kvantum; recursive = true; };
    xdg.configFile."gtk-3.0" = { source = ../../.config/gtk-3.0; recursive = true; };
    xdg.configFile."hypr" = { source = ../../.config/hypr; recursive = true; };
    xdg.configFile."kitty" = { source = ../../.config/kitty; recursive = true; };
    xdg.configFile."mako" = { source = ../../.config/mako; recursive = true; };
    xdg.configFile."quickshell" = { source = ../../.config/quickshell; recursive = true; };
    xdg.configFile."rhythm" = { source = ../../.config/rhythm; recursive = true; };
    xdg.configFile."rofi" = { source = ../../.config/rofi; recursive = true; };
    xdg.configFile."rust-dock" = { source = ../../.config/rust-dock; recursive = true; };
    xdg.configFile."wal" = { source = ../../.config/wal; recursive = true; };
    xdg.configFile."waybar" = { source = ../../.config/waybar; recursive = true; };

    home.file.".zshrc".source = ../../zsh/.zshrc;

    home.activation.seedMonitorsConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      target="${config.home.homeDirectory}/.config/hypr/monitors.conf"
      if [ ! -e "$target" ]; then
        mkdir -p "$(dirname "$target")"
        printf '%s\n' ${lib.escapeShellArg cfg.monitors.seedText} > "$target"
      fi
    '';
  };
}
