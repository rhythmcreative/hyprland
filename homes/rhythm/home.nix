# Example home-manager configuration for the Rhythm Hyprland desktop.
#
# Used standalone (`home-manager switch --flake .#rhythm`) or from a NixOS
# host module (see hosts/asus). Values must match the system side.
{ ... }:

{
  # The module is imported BY PATH, not through `inputs.hyprland`.
  #
  # It used to be `inputs.hyprland.homeManagerModules.rhythm-hyprland`, which
  # only resolves if the consumer's flake happens to have an input called
  # `hyprland`. The one in THIS repo does not: flake.nix declares just nixpkgs
  # and home-manager. So homeConfigurations.rhythm in flake.nix -- the thing the
  # header tells you to run -- died on
  #     error: attribute 'hyprland' missing
  # and `nix flake show` listed homeConfigurations as "unknown".
  #
  # A path import needs no input at all, and works identically from this flake,
  # from a copied host config and from someone else's flake. Nothing in
  # modules/home-manager reads `inputs` (only a comment mentions it), so there
  # is nothing given up by dropping it.
  imports = [
    ../../modules/home-manager
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
