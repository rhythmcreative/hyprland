# Example NixOS host for the Rhythm Hyprland module.
#
# Copy this file to your own flake (or to /etc/nixos with the repo checked
# out) and adjust username, hostName, gpu and monitors.
#
# THERE IS NO `#asus` OUTPUT IN THIS FLAKE. The header used to tell you to run
#
#   sudo nixos-rebuild switch --flake /path/to/hyprland#asus
#
# and that command cannot work: flake.nix exports nixosModules, homeManagerModules,
# overlays, packages and homeConfigurations, and no nixosConfigurations at all,
# so there is no `asus` attribute to select. And the file imported
# ./hardware-configuration.nix, which does not exist in the repo, so even
# importing it by hand failed on a missing path.
#
# Both are fixed here: the modules come in BY PATH, so no `hyprland` input is
# needed, and hardware-configuration.nix is optional so the example evaluates
# as shipped.
#
# To actually use it, wrap it in your own flake:
#
#   outputs = { nixpkgs, home-manager, ... }: {
#     nixosConfigurations.mine = nixpkgs.lib.nixosSystem {
#       system = "x86_64-linux";
#       modules = [ ./hosts/asus/configuration.nix ];
#     };
#   };
#
#   sudo nixos-rebuild switch --flake .#mine
{ inputs, lib, ... }:

{
  imports = [
    # By path, not through inputs: see the header. modules/nixos does not read
    # `inputs` either, so an outer flake needs no special wiring for this file.
    ../../modules/nixos
    inputs.home-manager.nixosModules.home-manager
  ] ++ (
    # Optional, and only present after `nixos-generate-config` on a real
    # machine. Before that there is nothing to import, and importing it
    # unconditionally failed on the missing path -- which is one of the two
    # reasons this example never evaluated as shipped.
    #
    # An empty attrset is a valid no-op module, so the else branch is just that
    # rather than a null or a filtered list.
    if lib.pathExists ./hardware-configuration.nix
    then [ ./hardware-configuration.nix ]
    else [ ]
  );

  # The desktop's own packages come from this repo's overlay
  # (rhythmHelpers, rustDock, greeterMonitor). modules/options.nix defaults
  # them to pkgs.<name>, so without this the evaluation dies on
  # "attribute 'rhythmHelpers' missing" the moment those defaults are read.
  # This file did not have it: homes/rhythm/home.nix assumes the pkgs it is
  # given already carry the overlay, and nothing here supplied one.
  # `import`, not the bare path. ../../overlays is a DIRECTORY, and a path in
  # an overlay list is not an overlay:
  #   error: A definition for option `nixpkgs.overlays."..."' is not of type
  #          `nixpkgs overlay'.
  # flake.nix gets away with `overlays.default = import ./overlays;` because
  # the import happens there.
  nixpkgs.overlays = [ (import ../../overlays) ];

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
    # `inputs` is still passed through: home-manager.nixosModules needs it, and
    # a caller's flake will have it. Nothing in the desktop module requires it.
    extraSpecialArgs = { inherit inputs; };
    users.rhythm = import ../../homes/rhythm/home.nix;
  };

  # nixos-unstable moves fast; pin the release you tested with.
  system.stateVersion = "25.11";

  # The example names a user; without this NixOS refuses to evaluate
  # (no stateVersion/user mismatch aside, users."rhythm" would not exist).
  users.users.rhythm = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    # Password login is off by default and there is no password here either, so
    # an unconfigured example would lock you out on first boot.
    initialPassword = "rhythm";
  };
}