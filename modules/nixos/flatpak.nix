# Flatpak apps from flatpaks.txt, installed once each.
#
# install.sh adds flathub and installs the list with flatpak install -y.
# Same thing here as a system activation script, guarded per app so later
# rebuilds are no-ops. Off unless rhythm.features.flatpaks is set.
{ config, lib, pkgs, ... }:

let
  cfg = config.rhythm;
  apps = lib.filter (a: a != "") (lib.splitString "\n" (builtins.readFile ../../flatpaks.txt));
  want = lib.concatMapStringsSep "\n" (app: ''
    if ! ${pkgs.flatpak}/bin/flatpak list --app --columns=application 2>/dev/null | ${pkgs.gnugrep}/bin/grep -qx '${app}'; then
      ${pkgs.flatpak}/bin/flatpak install -y --system flathub '${app}' || true
    fi
  '') apps;
in
{
  config = lib.mkIf (cfg.enable && cfg.features.flatpaks) {
    system.activationScripts.rhythmFlatpaks = lib.stringAfter [ "var" ] ''
      ${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo || true
      ${want}
    '';
  };
}
