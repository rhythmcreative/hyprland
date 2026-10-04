# Helper scripts in ~/.local/bin, symlinked from the rhythmHelpers package.
#
# The package already excludes Arch-only scripts (OTA, /usr deploy) and
# patches the remaining hardcoded paths, so every file linked here runs on
# NixOS. Scripts keep calling each other through ~/.local/bin, which is also
# added to the interactive PATH below.
{ config, lib, pkgs, ... }:

let
  cfg = config.rhythm;
  names = builtins.attrNames (builtins.readDir "${cfg.packageSet.helpers}/bin");
in
{
  config = lib.mkIf cfg.enable {
    home.file = lib.listToAttrs (map
      (name: {
        inherit name;
        value = {
          target = ".local/bin/${name}";
          source = "${cfg.packageSet.helpers}/bin/${name}";
        };
      })
      names);

    # The compiled dock under its classic name, for the launcher and any
    # residual $HOME/.local/bin/rust-dock reference.
    home.file = {
      ".local/bin/rust-dock" = lib.mkIf cfg.features.rustDock {
        source = "${cfg.packageSet.rustDock}/bin/rust-dock";
      };
    };

    home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];
  };
}
