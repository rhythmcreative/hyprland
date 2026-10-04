# Example home-manager configuration for the Rhythm Hyprland desktop.
#
# Used standalone (`home-manager switch --flake ...#rhythm`) or from the
# NixOS host module (see hosts/asus). Values must match the system side.
{ inputs, ... }:

{
  imports = [
    inputs.hyprland.homeManagerModules.rhythm-hyprland
  ];

  home.username = "rhythm";
  home.homeDirectory = "/home/rhythm";
  home.stateVersion = "25.11";

  # NOTE: no nixpkgs.overlays here. This example runs with the flake's own
  # pkgs, which already carry the overlay (see flake.nix). If you consume the
  # module from your own flake with your own pkgs, add one line there:
  #   nixpkgs.overlays = [ inputs.hyprland.overlays.default ];

  rhythm = {
    enable = true;
    username = "rhythm";
    features = {
      flatpaks = true;
    };
    monitors.seedText = ''
      monitor=,preferred,auto,1
    '';
  };
}
