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
      # Mismos grupos que el usermod de install.sh:2511, con dos
      # equivalencias propias de NixOS.
      #
      # `network` no existe como tal: NetworkManager declara aqui su grupo
      # `networkmanager`, que es el que da a nmcli y a los clientes de NM
      # acceso al demonio. Es el equivalente, no una omission.
      #
      # `optical` si falta y es real: sin el, Thunar no puede leer ni
      # escribir CDs/DVDs, que es justo para lo que instala
      # thunar-archive-plugin en Arch. Comprobado que `optical` es un grupo
      # valido de nixpkgs antes de declararlo.
      extraGroups = [
        "video"
        "input"
        "render"
        "wheel"
        "audio"
        "storage"
        "networkmanager"
        "lp"
        "optical"
      ];
    };

    programs.zsh.enable = true;

    # Rutas de los dos plugins de zsh que el .zshrc sourcea.
    #
    # El .zshrc del repo esta escrito para Arch, donde pacman deja los plugins
    # en /usr/share/zsh/plugins. En NixOS esa ruta no existe y el store es
    # de solo lectura, con lo que sin esto el shell abria sin resaltado de
    # sintaxis ni autosuggestiones: los dos `source` fallan en silencio porque
    # van con `[ -f ... ]`.
    #
    # Se exporta el fichero exacto, no el directorio, porque los dos plugins
    # no comparten layout en nixpkgs y porque el .zshrc solo necesita el
    # .zsh. sessionVariables y no environment.variables porque esto tiene que
    # existir en la sesion que arranca SDDM, no solo en una shell de login.
    environment.sessionVariables = {
      ZSH_AUTOSUGGESTIONS_SRC = "${pkgs.zsh-autosuggestions}/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh";
      ZSH_SYNTAX_HIGHLIGHTING_SRC = "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
    };

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

    # Thunar llega con gvfs y tumbler en Arch solo porque estan instalados en
    # el sistema base. En NixOS hay que pedirlos, y sin ellos el gestor de
    # archivos abre pero no monta los volumenes de red (gvfs), no crea la
    # papelera ni los montajes de disco (gvfsd-trash, gvfsd-fuse) y no genera
    # ninguna miniatura (tumbler). Los dos modulos existen y son no-op sin
    # esto, asi que declararlos es la diferencia entre un Thunar utilizable y
    # uno que solo muestra la carpeta.
    services.gvfs.enable = true;
    services.tumbler.enable = true;

    # SSH on by default, like the Arch installer leaves it: remote access
    # and `gh` flows work out of the box. mkDefault so any
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

    # Sudo sin contraseña por defecto para el grupo wheel (igual que en Arch,
    # /etc/sudoers.d/99-rhythmcreative), para que unidades de fondo como
    # rhythm-battery-limit.service puedan aplicar cambios sin bloquearse.
    security.sudo.wheelNeedsPassword = lib.mkDefault false;

    # Agente de autenticacion grafica de Polkit (Plasma 6).
    # Sin esto, cualquier aplicacion grafica que pida privilegios de root
    # (GParted, configuraciones de red, virt-manager o herramientas de disco)
    # falla en silencio al no encontrar agente en la sesion de Hyprland.
    systemd.user.services.polkit-kde-authentication-agent-1 = {
      description = "polkit-kde-authentication-agent-1";
      wantedBy = [ "graphical-session.target" "default.target" ];
      wants = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };

    fonts = {
      packages = with pkgs; [
        nerd-fonts.jetbrains-mono
        nerd-fonts.meslo-lg
        font-awesome
        inter
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
      ];
      fontconfig.enable = true;
    };
  };
}
