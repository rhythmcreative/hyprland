# Compositor scope: Hyprland itself plus portals and plugins.
#
# Replaces the pacman install of hyprland/hypridle/hyprlock and the impure
# `hyprpm add/enable hyprbars/hyprexpo` step: plugins become pinned
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
      plugins = with pkgs.hyprlandPlugins; [
        hyprbars
        hyprexpo
      ];
    };

    # Portals come with programs.hyprland, but the GTK fallback backend
    # (file picker outside pure-Wayland apps) needs naming explicitly.
    xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

    # Everything the compositor and its scripts expect on PATH.
    environment.systemPackages = with pkgs; [
      hypridle
      hyprlock
      hyprsunset
      hyprpicker
      awww
      mpvpaper
      mpv
      waybar
      quickshell
      rofi-wayland
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
