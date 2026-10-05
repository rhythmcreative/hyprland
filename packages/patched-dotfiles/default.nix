# A config directory deployed through home-manager, with its shebangs fixed.
#
# xdg.configFile links the source tree in verbatim, so unlike
# packages/helpers it gets no build step and no patchShebangs. On NixOS that
# left every script under .config unrunnable, because neither /bin/bash nor
# /usr/bin/env exists: exec fails with "bad interpreter" before the script's
# first line.
#
# The visible symptom was that waybar never came up at login.
# hyprland.lua runs ~/.config/waybar/launch.sh, the kernel cannot find the
# interpreter named in its shebang, and the process dies before it manages to
# write its own log -- which is why ~/.cache/waybar-launch.log did not exist.
# Every waybar module (cava, temperatures, weather, uptime) failed the same
# way and was reported as a stopped module.
#
# Wrapping the directory as a derivation is what lets the same build-time fix
# used for ~/.local/bin apply here. ADR-0001 requires the .config sources to
# stay single-sourced, so the tree is referenced where it lives and copied,
# never forked or rewritten in the repo.
{ lib
, stdenv
, bash
, python3
, src
, name ? "rhythm-dotfiles"
}:

stdenv.mkDerivation {
  pname = name;
  version = "1.0";

  inherit src;

  dontConfigure = true;

  # patchShebangs resolves `#!/usr/bin/env python3` only if a python
  # interpreter is in the build PATH; without this it left the env form in
  # place and the script still could not run on NixOS.
  nativeBuildInputs = [ bash python3 ];

  installPhase = ''
    runHook preInstall

    cp -r . "$out"
    chmod -R u+w "$out"

    # patch-shebangs.sh only visits files matching `find -type f -perm -0100`,
    # so anything without the exec bit is skipped in silence. The repo tracks
    # some of these without it (waybar-colors-sync.py is 644), and they were
    # therefore left with their original `#!/usr/bin/env python3`.
    find "$out" -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod u+x {} +

    # Same reasoning as packages/helpers: resolve the FHS-absolute
    # interpreter at build time instead of rewriting 48 files by hand. Naming
    # both interpreters also covers the `#!/usr/bin/env python3` scripts.
    patchShebangs "$out"

    runHook postInstall
  '';

  meta = {
    description = "Config directory with NixOS-compatible shebangs";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}