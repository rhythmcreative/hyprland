# Helper scripts in ~/.local/bin, symlinked from the rhythmHelpers package.
#
# The package already excludes Arch-only scripts (OTA, /usr deploy) and
# patches the remaining hardcoded paths, so every file linked here runs on
# NixOS. Scripts keep calling each other through ~/.local/bin, which is also
# added to the interactive PATH below.
{ config, lib, pkgs, ... }:

let
  cfg = config.rhythm;
  srcDir = ../../.local/bin;
  entries = builtins.readDir srcDir;
  excluded = [
    "rust-dock"
    "waybar_auto_hide"
    "ota-updater"
    "ota-snapshot"
    "rhythm-sddm-deploy"
    "enable-user-services"
    "rhythm-materialize"
    "sddm-sync-wrapper"
    "sddm-auto-sync-local"
    "sync-sddm-wallpaper"
    "sync-sddm-wallpaper-sudo"
    "sddm-wallpaper-watcher"
  ];
  fallbackNames = builtins.filter
    (name: entries.${name} == "regular"
      && !(lib.elem name excluded)
      && !(lib.hasSuffix ".bak" name)
      && !(lib.hasSuffix ".pyc" name)
      && name != "__pycache__")
    (builtins.attrNames entries);

  names = cfg.packageSet.helpers.scriptNames or fallbackNames;
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
      names)
    // lib.optionalAttrs cfg.features.rustDock {
      # The compiled dock under its classic name, for the launcher and any
      # residual $HOME/.local/bin/rust-dock reference.
      ".local/bin/rust-dock".source = "${cfg.packageSet.rustDock}/bin/rust-dock";
    };

    home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];
  };
}
