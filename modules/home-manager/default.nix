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

  # NOTE: this module does not add the package overlay itself: with
  # useGlobalPkgs the system nixpkgs (which already has it through the NixOS
  # module) wins, and setting nixpkgs.* here would fight it. Standalone
  # home-manager users add one line (see homes/rhythm/home.nix):
  #   nixpkgs.overlays = [ inputs.hyprland.overlays.default ];
}
