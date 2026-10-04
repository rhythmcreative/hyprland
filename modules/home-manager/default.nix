# User scope of the Rhythm Hyprland desktop on NixOS.
{ ... }:

{
  imports = [
    ../options.nix
    ./dotfiles.nix
    ./helpers.nix
    ./services.nix
    ./themes.nix
    ./wallpaper.nix
  ];
}
