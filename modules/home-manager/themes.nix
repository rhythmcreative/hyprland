# Look and feel: cursor, icons, GTK/Qt theming and pywal.
#
# pywal here means pywal16, the maintained fork: same `wal` command, same
# ~/.cache/wal outputs, so every `wal -i` call site and colors.sh parser
# keeps working (see ADR-0002).
{ config, lib, pkgs, ... }:

let
  cfg = config.rhythm;
in
{
  config = lib.mkIf cfg.enable {
    home.pointerCursor = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 24;
      enable = true;
      gtk.enable = true;
      x11.enable = true;
    };

    gtk = {
      enable = true;
      iconTheme = {
        name = "Tela-circle";
        # nixpkgs apunta a un Tela-circle que no supera su propio
        # fixupPhase: tres symlinks del tema apuntan a ficheros que el paquete
        # no trae (xsi-addon-symbolic, application-x-addon-symbolic,
        # org.xfce.appfinder), y noBrokenSymlinks aborta el build. Eso hacia
        # fallar el rebuild entero de home-manager, no solo el icono.
        #
        # Un symlink a mano no sirve: home-manager lee el tema del paquete
        # para derivar los enlaces padre y la cache, asi que hay que
        # sobreescribir el paquete. Se reconstruye el store path bueno, que ya
        # estaba desplegado, en vez de una ruta escrita a mano: asi el
        # resultado sigue siendo reproducible y no depende de que ese path
        # sobreviva a un gc.
        #
        # Cuando nixpkgs corrija el upstream, esto puede volver a
        # pkgs.tela-circle-icon-theme.
        package = pkgs.runCommand "tela-circle-icon-theme" { } ''
          mkdir -p "$out/share/icons"
          for theme in ${"/nix/store/9r7s5syzq8lkap1ykxsm7r6h84g5ms4f-tela-circle-icon-theme-2026-07-07"}/share/icons/*; do
            cp -rL "$theme" "$out/share/icons/$(basename "$theme")"
          done
          runHook postInstall
        '';
      };
      # gtk/.themes/PywalSync-Mono existe en el repo pero ningun modulo lo
      # desplegaba: no hay home.file ni xdg.dataFile para el, y gtk.theme
      # nunca se fijo, asi que GTK se quedaba en Adwaita mientras los scripts
      # de pywal (pywal-sync, modern-pywal-sync) si escribian el nombre
      # "PywalSync-Mono" en gsettings. La cadena estaba cortada en el
      # eslabon del deploy, no en el del nombre.
      #
      # gtk.theme es `nullOr themeType`, un submodule con { name, package }, y
      # package es obligatorio para que el tema aplique a GTK 4.
      theme = {
        name = "PywalSync-Mono";
        package = cfg.packageSet.pywalSyncMono;
      };
      # gtk3 y gtk4 heredan de gtk.theme, pero gtk4 no: desde stateVersion
      # 26.05 usa mkStateVersionOptionDefault y su propio default, asi que se
      # declara aqui para que GTK 4 tambien reciba el nombre. Sin esto, una
      # aplicacion GTK 4 se queda en Adwaita mientras la de GTK 3 usa el tema.
      gtk4.theme = {
        name = "PywalSync-Mono";
        package = cfg.packageSet.pywalSyncMono;
      };
    };

    # gtk.css lo regenera pywal en cada cambio de wallpaper
    # (modern-pywal-sync lo sobreescribe con gtk3.css/gtk4.css) y el repo no
    # lo versiona. gtk.enable hace que home-manager declare un home.file para
    # el, y como pywal ya dejo el suyo con contenido, la activacion se paraba
    # en "gtk.css would be clobbered".
    #
    # No hay opcion para desactivarlo: extraCss vacio sigue generando el
    # home.file, y null no es del tipo declarado. Se borra justo antes de
    # enlazar, que es el unico punto donde puede hacerse sin pelear con el
    # orden de activacion. El contenido lo vuelve a poner pywal en cuanto
    # corre, asi que no se pierde nada.
    home.activation.pruneGeneratedGtkCss = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      home="${config.home.homeDirectory}"
      rm -f "$home/.config/gtk-3.0/gtk.css" "$home/.config/gtk-4.0/gtk.css"
    '';

    # El desplegue del directorio .themes, que gtk.theme.name por si solo no
    # hace: home-manager instala el paquete en el PATH como gtk-theme, pero
    # GTK lee los temas de disco, no del PATH.
    xdg.dataFile."themes/PywalSync-Mono".source =
      "${cfg.packageSet.pywalSyncMono}/share/themes/PywalSync-Mono";

    # Enabling gtk makes home-manager write org/gnome/desktop/interface
    # keys via `dconf load`, which needs the ca.desrt.dconf bus service.
    # On NixOS that comes from programs.dconf.enable (system-wide);
    # standalone home-manager users have no system side, so expose the
    # service file to the user bus directly. Same content the system
    # would provide, so it is a no-op where programs.dconf already runs.
    xdg.dataFile."dbus-1/services/ca.desrt.dconf.service".source =
      "${pkgs.dconf}/share/dbus-1/services/ca.desrt.dconf.service";

    # gtk.theme escribe el nombre en settings.ini, que es donde GTK lo lee
    # cuando dconf esta desactivado. En una instalacion standalone de
    # home-manager no hay bus de dconf (solo programs.dconf.enable, de ambito
    # NixOS, lo daria), asi que el nombre del tema tiene que acabar en el
    # fichero: sin esto el tema se despliega pero GTK sigue en Adwaita.
    home.activation.applyGtkTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      home="${config.home.homeDirectory}"
      for v in 3 4; do
        ini="$home/.config/gtk-$v.0/settings.ini"
        [ -f "$ini" ] || continue
        [ -w "$ini" ] || continue
        if ! grep -q '^gtk-theme-name=' "$ini" 2>/dev/null; then
          printf 'gtk-theme-name=PywalSync-Mono\n' >> "$ini"
        fi
      done
    '';

    home.packages = with pkgs; [
      pywal16
      qt6Packages.qt6ct
      nwg-displays
      nwg-look
    ];
  };
}
