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
    # bluetoothd (el demonio) sigue activo con hardware.bluetooth.enable de
    # lo que se desactiva es el AGENTE GRAFICO.
    #
    # services.blueman.enable levanta blueman-applet y blueman-tray por
    # XDG autostart, y los dos aparecen en la bandeja de waybar encima del
    # icono de red de nm-applet. En la referencia del repo la derecha de la
    # barra tiene un solo icono de red, no tres. El menu de bluetooth sigue
    # funcionando por el modulo "bluetooth" de waybar y por
    # Super+B / F10, que llaman a blueman-manager bajo demanda.
    services.blueman.enable = false;
    services.power-profiles-daemon.enable = true;

    # SSH on by default, like the Arch installer leaves it: remote access
    # and `gh`/`opencode` flows work out of the box. mkDefault so any
    # explicit `services.openssh.enable = false;` still wins.
    services.openssh = {
      enable = lib.mkDefault true;
      # Stated instead of left to the sshd module's implicit side effect:
      # nixpkgs appends `services.openssh.ports` to
      # networking.firewall.allowedTCPPorts, so a firewall assembled anywhere
      # else in the machine's config can end up dropping 22 while sshd is
      # happily listening. From the other machine that is silent, not
      # "connection refused", and it reads exactly like a wrong IP.
      openFirewall = lib.mkDefault true;
    };

    # The reachability rule in the place the desktop's networking lives,
    # written against the port itself instead of the option shape: older
    # nixpkgs exposes services.openssh.port (an int), newer releases
    # services.openssh.ports (a list), and this works on both.
    #
    # A list option merges every definition, so 22 is appended to whatever
    # the machine already allows. A machine that really wants 22 closed
    # overrides the whole thing with mkForce; nothing listens on it anyway.
    networking.firewall.allowedTCPPorts = lib.mkDefault [ 22 ];

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
