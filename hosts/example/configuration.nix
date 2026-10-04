# Example NixOS host consuming the Rhythm Hyprland module.
#
# Copy to your own flake (or to /etc/nixos with the repo checked out) and
# adjust username, gpu and monitors. Then:
#   sudo nixos-rebuild switch --flake /path/to/hyprland#example
{ inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    inputs.hyprland.nixosModules.rhythm-hyprland
    inputs.home-manager.nixosModules.home-manager
  ];

  networking.hostName = "rhythm-nixos";

  rhythm = {
    enable = true;
    username = "rhythm";
    # Set explicitly when the hardware is known: "nvidia", "amd", "intel".
    gpu = "auto";
    wallpaper.mode = "random";
    features = {
      flatpaks = true;
    };
    monitors.seedText = ''
      monitor=,preferred,auto,1
    '';
  };

  # Wire the home-manager module with the same values.
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    users.rhythm = import ../../homes/example/home.nix;
  };

  # nixos-unstable moves fast; pin the release you tested with.
  system.stateVersion = "25.11";
}
