{
  description = "Rhythm Hyprland desktop: Arch installer plus a declarative NixOS and home-manager port";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      };
    in
    {
      overlays.default = final: prev: {
        rhythmHelpers = final.callPackage ./packages/helpers { };
        rustDock = final.callPackage ./packages/rust-dock { };
        greeterMonitor = final.callPackage ./packages/greeter-monitor { };
      };

      nixosModules.default = ./modules/nixos;
      nixosModules.rhythm-hyprland = ./modules/nixos;

      homeManagerModules.default = ./modules/home-manager;
      homeManagerModules.rhythm-hyprland = ./modules/home-manager;

      packages.${system} = {
        inherit (pkgs) rhythmHelpers rustDock greeterMonitor;
      };

      homeConfigurations.example = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs; };
        modules = [ ./homes/example/home.nix ];
      };
    };
}
