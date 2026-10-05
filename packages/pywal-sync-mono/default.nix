# The gtk/.themes/PywalSync-Mono theme as a derivation.
#
# The theme lives in the repo and is valid (index.theme declares Name and
# GtkTheme = PywalSync-Mono, with gtk-3.0/ and gtk-4.0/ stylesheets), but no
# module deployed it: on NixOS the result was GTK stuck on Adwaita while the
# pywal scripts went on setting "PywalSync-Mono" through gsettings.
#
# Wrapping it as a package is what makes it deployable. GTK resolves themes by
# walking XDG data dirs on disk, so `home.packages` alone changes nothing; the
# caller symlinks this into ~/.local/share/themes from themes.nix.
#
# The copy is byte-for-byte, so single-sourcing under ADR-0001 holds: this
# references the repo's own gtk/ tree and does not duplicate it.
{ lib
, stdenv
}:

stdenv.mkDerivation {
  pname = "pywal-sync-mono";
  version = "1.0";

  src = ../../gtk/.themes/PywalSync-Mono;

  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/themes/PywalSync-Mono"
    cp -r . "$out/share/themes/PywalSync-Mono/"

    runHook postInstall
  '';

  meta = {
    description = "PywalSync-Mono GTK theme (dynamic colours for GTK 3 and 4)";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}