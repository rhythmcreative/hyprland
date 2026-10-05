# Machine scope: user, shell, groups, services, fonts, flatpak.
#
# Replaces the tail of install.sh: chsh, usermod groups, systemctl enables,
# cursor/icon gsettings defaults and the flatpak loop.
{ config, lib, pkgs, ... }:

let
  cfg = config.rhythm;
in
{
  config = lib.mkIf cfg.enable {
    users.users.${cfg.username} = {
      isNormalUser = true;
      shell = pkgs.zsh;
      extraGroups = [
        "video"
        "input"
        "render"
        "wheel"
        "audio"
        "storage"
        "networkmanager"
        "lp"
      ];
    };

    programs.zsh.enable = true;

    networking.networkmanager.enable = true;
    hardware.bluetooth.enable = true;
    services.blueman.enable = cfg.features.bluetooth;
    services.power-profiles-daemon.enable = true;

    # SSH on by default, like the Arch installer leaves it: remote access
    # and `gh`/`opencode` flows work out of the box. mkDefault so any
    # explicit `services.openssh.enable = false;` still wins.
    services.openssh.enable = lib.mkDefault true;

    services.flatpak.enable = cfg.features.flatpaks;

    fonts = {
      packages = with pkgs; [
        nerd-fonts.jetbrains-mono
        font-awesome
        noto-fonts
        noto-fonts-color-emoji
      ];
      fontconfig.enable = true;
    };
  };
}
