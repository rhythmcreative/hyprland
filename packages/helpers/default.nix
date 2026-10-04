# The ~/.local/bin helper scripts as a derivation.
#
# Home-manager symlinks these into ~/.local/bin file by file, so scripts
# calling each other through $HOME/.local/bin keep working. At build time a
# few hardcoded Arch paths are patched to store paths; everything else runs
# unchanged. Scripts that only make sense on Arch (pacman OTA, /usr deploy)
# are excluded here and documented in docs/nixos.md.
{ lib
, stdenv
, hyprlock
, rustDock
}:

let
  # Scripts replaced by Nix concepts; never deployed on NixOS.
  excluded = [
    "rust-dock" # packaged separately as rustDock (a committed Arch binary would not run: no /lib64 loader)
    "system-ota" # updates come from `nix flake update` plus `nixos-rebuild switch` (ADR-0005)
    "ota-updater"
    "ota-snapshot" # Arch timeshift/snapper layout; NixOS generations cover rollbacks
    "rhythm-sddm-deploy" # embodied by modules/nixos/sddm.nix
    "enable-user-services" # embodied by systemd.user.services WantedBy
    "rhythm-materialize" # OTA deploy helper with no declarative counterpart
    "sddm-sync-wrapper" # live greeter recolouring needs a writable /usr/share (ADR-0004)
    "sddm-auto-sync-local"
    "sync-sddm-wallpaper"
    "sync-sddm-wallpaper-sudo"
  ];
  excludedList = lib.concatStringsSep " " excluded;
in
stdenv.mkDerivation {
  pname = "rhythm-helpers";
  version = "0.24";
  src = ../../.local/bin;

  installPhase = ''
    mkdir -p $out/bin
    for f in "$src"/*; do
      name="$(basename "$f")"
      case "$name" in
        __pycache__|*.pyc|*.bak) continue ;;
      esac
      case " ${excludedList} " in
        *" $name "*) continue ;;
      esac
      [ -f "$f" ] || continue
      cp "$f" "$out/bin/$name"
    done
    chmod +x "$out/bin"/*

    # Point the dock launcher at the packaged binary. The unit PATH already
    # covers bare tools (pkill, hyprctl, jq), so only FHS-absolute paths and
    # the classic binary location need patching.
    substituteInPlace "$out/bin/rust-dock-launcher" \
      --replace '$HOME/.local/bin/rust-dock' '${rustDock}/bin/rust-dock'

    # The locker probe checks FHS paths that do not exist on NixOS.
    substituteInPlace "$out/bin/powermenu-with-monitor-detection" \
      --replace '/usr/bin/hyprlock' '${hyprlock}/bin/hyprlock'
  '';

  meta = {
    description = "Helper scripts for the Rhythm Hyprland desktop";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
