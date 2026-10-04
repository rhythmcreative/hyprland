# Package overlay shared by the NixOS module, the home-manager module and
# the flake outputs, so consumers never have to add it by hand.
final: prev: {
  rhythmHelpers = final.callPackage ../packages/helpers { };
  rustDock = final.callPackage ../packages/rust-dock { };
  greeterMonitor = final.callPackage ../packages/greeter-monitor { };
}
