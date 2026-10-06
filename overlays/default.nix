# Package overlay shared by the NixOS module, the home-manager module and
# the flake outputs, so consumers never have to add it by hand.
final: prev: {
  rhythmHelpers = final.callPackage ../packages/helpers { };
  rustDock = final.callPackage ../packages/rust-dock { };
  greeterMonitor = final.callPackage ../packages/greeter-monitor { };
  pywalSyncMono = final.callPackage ../packages/pywal-sync-mono { };

  # Prebuilt Tela Circle icon theme with all color variants included.
  # Avoids compiling 400k+ files and symlinks locally, installing in seconds.
  tela-circle-icon-theme = final.stdenvNoCC.mkDerivation {
    pname = "tela-circle-icon-theme";
    version = "2026-07-07-all";
    src = final.fetchzip {
      url = "https://github.com/rhythmcreative/hyprland/releases/download/v0.25/tela-circle-icon-theme-all.tar.gz";
      hash = "sha256-zACGW9Amy00NwWHVwQ+Eu2FnE9E4+xfFzEDvaiXXBJI=";
      stripRoot = false;
    };
    propagatedBuildInputs = [
      final.adwaita-icon-theme
      final.kdePackages.breeze-icons
      final.hicolor-icon-theme
    ];
    dontDropIconThemeCache = true;
    dontWrapQtApps = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/icons"
      cp -a . "$out/share/icons/"
      runHook postInstall
    '';
  };

  # Config trees that carry shell scripts, wrapped so their shebangs get
  # patched at build time. See packages/patched-dotfiles for why this is
  # needed and why it is not done with sed on the deployed copies.
  patchedWaybar = final.callPackage ../packages/patched-dotfiles {
    name = "rhythm-waybar-config";
    src = ../.config/waybar;
  };
  patchedHypr = final.callPackage ../packages/patched-dotfiles {
    name = "rhythm-hypr-config";
    src = ../.config/hypr;
  };
  # These three also carry shell scripts: the pywal hooks under wal/ run on
  # every theme change, hyprwall/ backs the island's wallpaper picker, and
  # gtk-3.0/ has the nm-applet css loader. Deployed verbatim they kept
  # `#!/bin/bash`, which does not exist here.
  patchedWal = final.callPackage ../packages/patched-dotfiles {
    name = "rhythm-wal-config";
    src = ../.config/wal;
  };
  patchedQuickshell = final.callPackage ../packages/patched-dotfiles {
    name = "rhythm-quickshell-config";
    src = ../.config/quickshell;
  };
  patchedGtk3 = final.callPackage ../packages/patched-dotfiles {
    name = "rhythm-gtk3-config";
    src = ../.config/gtk-3.0;
  };
}
