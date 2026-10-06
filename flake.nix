{
  description = "Rhythm Hyprland desktop: Arch installer plus a declarative NixOS and home-manager port";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      };
    in
    {
      overlays.default = import ./overlays;

      nixosModules.default = ./modules/nixos;
      nixosModules.rhythm-hyprland = ./modules/nixos;

      homeManagerModules.default = ./modules/home-manager;
      homeManagerModules.rhythm-hyprland = ./modules/home-manager;

      packages.${system} = {
        inherit (pkgs) rhythmHelpers rustDock greeterMonitor;
      };

      homeConfigurations.rhythm = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs; };
        modules = [ ./homes/rhythm/home.nix ];
      };

      nixosConfigurations.asus = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/asus/configuration.nix ];
      };
    };
}
