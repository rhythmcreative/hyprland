# Desktop programs for the user scope.
#
# install.sh deploys the desktop through standalone home-manager only (no
# sudo, no system rebuild), so the programs the session needs cannot come
# from environment.systemPackages the way they do on the NixOS side. They
# are the same list both scopes share (rhythm.desktopPackages in
# modules/options.nix): without this, SDDM would start a compositor with no
# bar, no launcher, no terminal and no screenshot tool, because every bind
# in hyprland.lua would resolve to nothing.
{ config, lib, pkgs, ... }:

let
  cfg = config.rhythm;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = cfg.desktopPackages ++ [ pkgs.adwaita-qt6 ];

    # Variables que el compositor tiene que encontrar al arrancar.
    #
    # Van por home.sessionVariables y no solo por environment.sessionVariables
    # (que usa el modulo de NixOS) porque esas dos se escriben en
    # /etc/environment, y NixOS solo instala `system-environment-generators`:
    # no hay `user-environment-generators`, asi que /etc/environment lo
    # heredan los servicios del SISTEMA y no los del USUARIO.
    #
    # Importa porque con withUWSM el compositor no lo arranca SDDM: lo arranca
    # UWSM como servicio de systemd --user. Al no recibir estas variables:
    #   - hyprland.lua hace os.getenv("RHYTHM_PLUGIN_HYPRBARS") -> nil y nunca
    #     llama a `hyprctl plugin load`, asi que el plugin no se carga.
    #   - kitty, que hereda del compositor, abre sin las rutas de los plugins
    #     de zsh y cae al valor por defecto (/usr/share/zsh/plugins), que en
    #     NixOS no existe: la shell sin resaltado ni autosuggestiones.
    #
    # home.sessionVariables escribe ~/.config/environment.d/10-home-manager.conf,
    # y systemd SI lee environment.d para el gestor de usuario. Ese es el
    # camino que llega de verdad a la sesion UWSM.
    #
    # Ojo al nombre de la opcion: es `systemd.user.sessionVariables`, no
    # `home.sessionVariables`. La segunda existe pero escribe otra cosa (los
    # valores por defecto de locale y poco mas); el fichero
    # environment.d/10-home-manager.conf lo genera el modulo systemd de
    # home-manager a partir de systemd.user.sessionVariables. Puesto en la
    # opcion equivocada el fichero salia con una sola linea y las tres
    # variables seguian sin llegar.
    systemd.user.sessionVariables = {
      RHYTHM_PLUGIN_HYPRBARS = "${pkgs.hyprlandPlugins.hyprbars}/lib/libhyprbars.so";
      ZSH_AUTOSUGGESTIONS_SRC = "${pkgs.zsh-autosuggestions}/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh";
      ZSH_SYNTAX_HIGHLIGHTING_SRC = "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";

      # Tematizacion de Qt en NixOS, donde los motores que hyprland.lua fija
      # por defecto no existen.
      #
      # hyprland.lua pone QT_QPA_PLATFORMTHEME=qt5ct y
      # QT_STYLE_OVERRIDE=kvantum, pensados para Arch. En nixpkgs no hay
      # qt5ct ni kvantum (comprobado en nixos-26.05 y en unstable), con lo que
      # Qt caia al estilo por defecto y las apps se veian distintas de GTK.
      #
      # El equivalente disponible es adwaita-qt6, que porta el tema Adwaita de
      # GTK a Qt: el plugin de estilo se llama `adwaita`
      # (lib/qt-6/plugins/styles/adwaita.so), y qt6ct, que hace de
      # platform theme para la fuente, la paleta y los iconos. Entre los dos
      # cubren lo que kvantum + qt5ct hacian en Arch.
      #
      # hyprland.lua solo fija estas dos si NO vienen ya del entorno (ver ahi
      # el `if not os.getenv`), asi que en Arch sigue mandando qt5ct+kvantum
      # y aqui mandan estos.
      QT_QPA_PLATFORMTHEME = "qt6ct";
      QT_STYLE_OVERRIDE = "adwaita";
    };
  };
}