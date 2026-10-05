# Compositor scope: Hyprland itself plus portals and plugins.
#
# Replaces the pacman install of hyprland/hypridle/hyprlock and the impure
# `hyprpm add/enable hyprbars` step: plugins become pinned
# derivations instead (see ADR-0006). hyprexpo is deliberately absent:
# upstream removed it from the hyprland-plugins repo and ships no
# standalone source, so there is nothing reproducible to build.
# hyprlandPlugins derivations (see ADR-0006).
{ config, lib, pkgs, ... }:

let
  cfg = config.rhythm;
in
{
  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      withUWSM = true;
      xwayland.enable = true;
    };

    # Pinned compositor plugins (ADR-0006). There is no programs.hyprland
    # plugins option and home-manager has none either, so the shared
    # hyprland.lua loads them through hyprctl from this env var; unset on
    # Arch, where hyprpm owns plugin loading. It reaches the compositor
    # twice: the display-manager service environment covers the SDDM
    # session, and sessionVariables covers a TTY/UWSM start.
    systemd.services.display-manager.environment = {
      RHYTHM_PLUGIN_HYPRBARS = "${pkgs.hyprlandPlugins.hyprbars}/lib/libhyprbars.so";
    };
    environment.sessionVariables = {
      RHYTHM_PLUGIN_HYPRBARS = "${pkgs.hyprlandPlugins.hyprbars}/lib/libhyprbars.so";
    };

    # Portals come with programs.hyprland, but the GTK fallback backend
    # (file picker outside pure-Wayland apps) needs naming explicitly.
    xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

    # Everything the compositor and its scripts expect on PATH. The list
    # itself is shared with the home-manager scope (see
    # rhythm.desktopPackages in modules/options.nix) so both install paths
    # end up with the same working desktop.
    #
    # gum and fzf are appended here instead of living in desktopPackages:
    # install.sh puts gum in ~/.nix-profile, and home.packages + profile
    # would both ship share/zsh/site-functions/_gum, which aborts the whole
    # activation with a file-collision error. System packages never enter the
    # user profile, so this is the conflict-free place for them.
    environment.systemPackages = cfg.desktopPackages ++ (with pkgs; [
      gum
      fzf
      # Navegador por defecto. En Arch install.sh ofrece Brave Origin Nightly
      # como opcion AUR (brave-origin-nightly-bin); en nixpkgs ese nombre es
      # solo de Arch y el navegador se llama brave-origin... pero solo existe
      # a partir de nixos-unstable: en nixos-26.05, que es el canal que fija
      # install.sh para /etc/nixos, el atributo no esta y el build fallaria.
      # Se degrada a brave (estable) en lugar de romper el rebuild.
      (if pkgs ? brave-origin then pkgs.brave-origin else pkgs.brave)
    ]);

    # Navegador por defecto del sistema.
    #
    # La opcion es xdg.mime y su tipo es un attrs (nombre de aplicacion ->
    # lista de mimeTypes), no una lista. Escribe el
    # [Default Applications] del mimeapps.list que leen GTK y xdg-utils.
    #
    # nixpkgs ya no trae programs.brave: se fusiono con programs.chromium, que
    # solo gestiona politicas y noAssociations, asi que el navegador por
    # defecto se declara aqui y las politicas mas abajo.
    xdg.mime.defaultApplications = {
      "${(if pkgs ? brave-origin then pkgs.brave-origin else pkgs.brave).name}.desktop" = [
        "text/html"
        "application/xhtml+xml"
        "application/xml"
        "application/rdf+xml"
        "image/gif"
        "image/jpeg"
        "image/png"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ];
    };

    # Politicas de Chromium para Brave: sin esto Brave sale pidiendo clave de
    # API, sin sincronizacion y con las notificaciones de oferta activadas.
    programs.chromium = {
      enable = true;
      package = if pkgs ? brave-origin then pkgs.brave-origin else pkgs.brave;
    };
  };
}
