# Package overlay shared by the NixOS module, the home-manager module and
# the flake outputs, so consumers never have to add it by hand.
final: prev: {
  rhythmHelpers = final.callPackage ../packages/helpers { };
  rustDock = final.callPackage ../packages/rust-dock { };
  greeterMonitor = final.callPackage ../packages/greeter-monitor { };
  pywalSyncMono = final.callPackage ../packages/pywal-sync-mono { };

  # Upstream's Tela install.sh renames a handful of icons by pointing a second
  # name at an existing file, and it does it with absolute links into the theme
  # directory. Two of those targets are not in the 2026-07-07 release
  # (x-addon-symbolic.svg, edit-find.svg), so the store path ships three
  # dangling symlinks and stdenv's noBrokenSymlinks postFixup check refuses to
  # build the derivation. Nothing downstream survives that: home-manager-path
  # and home-manager-generation depend on the theme, so the whole desktop
  # activation fails.
  #
  # Deleting the dead links after install is the honest fix, not a bypass:
  # a dangling symlink renders no icon and the file it named is not in the
  # store anyway. dontCheckForBrokenSymlinks would build, but it leaves the
  # broken links in place, which is what the check exists to prevent, and
  # jdupes has already hardlinked the ~400k real files by then.
  tela-circle-icon-theme = (prev.tela-circle-icon-theme.override {
    allColorVariants = true;
  }).overrideAttrs (old: {
    postInstall = ''
      ${old.postInstall or ""}
      # Efficiently prune broken dangling symlinks using native C find without slow bash loops:
      find "$out" -xtype l -delete
    '';
  });

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
