# System scope of the Rhythm Hyprland desktop on NixOS.
#
# Mirrors what install.sh does outside $HOME: user, groups, shell, core
# services, display manager, audio, hardware. User scope (dotfiles, helpers,
# user units) lives in modules/home-manager and reads the same rhythm.*
# options defined in modules/options.nix.
{ ... }:

{
  imports = [
    ../options.nix
    ./hyprland.nix
    ./sddm.nix
    ./audio.nix
    ./flatpak.nix
    ./hardware.nix
    ./system.nix
  ];
}
