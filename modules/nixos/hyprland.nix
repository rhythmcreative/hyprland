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

    # Everything the compositor and its scripts expect on PATH.
    # gum + fzf van aqui a proposito: install.sh, los helpers y los menus
    # los usan para mostrar mensajes. Sin gum en el sistema, `gum style`
    # no existe y los avisos se ven en plano o no se ven (en Arch siempre
    # esta porque el instalador lo pone con pacman).
    environment.systemPackages = with pkgs; [
      gum
      fzf
      git
      curl
      hypridle
      hyprlock
      hyprsunset
      hyprpicker
      awww
      mpvpaper
      mpv
      waybar
      quickshell
      rofi
      cliphist
      wl-clipboard
      grim
      slurp
      swappy
      wf-recorder
      libnotify
      socat
      brightnessctl
      pamixer
      playerctl
      inotify-tools
      psmisc
      jq
    ];
  };
}
