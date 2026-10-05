# Package overlay shared by the NixOS module, the home-manager module and
# the flake outputs, so consumers never have to add it by hand.
final: prev: {
  rhythmHelpers = final.callPackage ../packages/helpers { };
  rustDock = final.callPackage ../packages/rust-dock { };
  greeterMonitor = final.callPackage ../packages/greeter-monitor { };

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
  tela-circle-icon-theme = prev.tela-circle-icon-theme.overrideAttrs (old: {
    postInstall = ''
      ${old.postInstall or ""}
      # Read every symlink in the shell and only fork rm for the dead ones:
      # jdupes has turned most of the ~400k files into links by now, so a
      # find -exec test per link would fork once per file.
      find "$out" -type l -print0 |
        while IFS= read -r -d "" link; do
          [ -e "$link" ] || rm -f "$link"
        done
    '';
  });
}
