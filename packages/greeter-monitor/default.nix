# SDDM greeter wrapper: picks the login output, then starts Hyprland.
#
# Packages sddm/sddm-greeter-monitor with the Hyprland template beside it.
# The wrapper already honours RHYTHM_SDDM_PLANTILLA, so no patching is needed
# for the template path; Hyprland itself is started through the wrapped PATH.
# Verify on first boot with the lid closed that the login appears on the
# external output (the wrapper reads /sys/class/drm directly).
{ lib
, stdenv
, makeWrapper
, hyprland
, coreutils
, procps
, gawk
, gnugrep
, gnused
, jq
}:

stdenv.mkDerivation {
  pname = "rhythm-greeter-monitor";
  version = "0.24";
  src = ../../sddm;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin $out/share/rhythm
    cp "$src/sddm-greeter-monitor" "$out/bin/sddm-greeter-monitor"
    cp "$src/hyprland.lua" "$out/share/rhythm/hyprland.lua"
    chmod +x "$out/bin/sddm-greeter-monitor"
    # `start-hyprland` is an Arch-packaging helper that may not ship with
    # the nixpkgs Hyprland; SDDM already sets the Wayland session
    # environment for the greeter, so exec the compositor directly.
    substituteInPlace "$out/bin/sddm-greeter-monitor" \
      --replace 'exec start-hyprland -- --config' 'exec ${hyprland}/bin/Hyprland --config'
    # SDDM starts the greeter with a minimal PATH (/usr/bin does not exist
    # on NixOS), while the wrapper uses plain coreutils/pgrep/awk/grep/sed
    # throughout. Everything it shells out to goes on the wrapped PATH, or
    # the wrapper exits on the first `cat` and SDDM retries against a black
    # screen, which is exactly the failure this wrapper was written to avoid.
    wrapProgram "$out/bin/sddm-greeter-monitor" \
      --prefix PATH : '${lib.makeBinPath [ coreutils procps gawk gnugrep gnused jq ]}' \
      --set RHYTHM_SDDM_PLANTILLA "$out/share/rhythm/hyprland.lua"
  '';

  meta = {
    description = "SDDM greeter wrapper showing the login on the right output";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
