# Desktop programs for the user scope.
#
# install.sh deploys the desktop through standalone home-manager only (no
# sudo, no system rebuild), so the programs the session needs cannot come
# from environment.systemPackages the way they do on the NixOS side. They
# are the same list both scopes share (rhythm.desktopPackages in
# modules/options.nix): without this, SDDM would start a compositor with no
# bar, no launcher, no terminal and no screenshot tool, because every bind
# in hyprland.lua would resolve to nothing.
{ config, lib, ... }:

let
  cfg = config.rhythm;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = cfg.desktopPackages;
  };
}