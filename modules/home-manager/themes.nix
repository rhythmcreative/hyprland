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
        # Upstream tela-circle-icon-theme has 3 dangling symlinks (xsi-addon-symbolic,
        # org.xfce.appfinder, application-x-addon-symbolic) that fail nixpkgs's
        # noBrokenSymlinks hook. We disable the check and prune broken symlinks in postInstall.
        package = (pkgs.tela-circle-icon-theme.override {
          allColorVariants = true;
        }).overrideAttrs (old: {
          dontCheckForBrokenSymlinks = true;
          postInstall = (old.postInstall or "") + ''
            find $out/share/icons -xtype l -delete 2>/dev/null || true
          '';
        });
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
      rm -f "$home/.config/gtk-3.0/gtk.css" "$home/.config/gtk-4.0/gtk.css" \
            "$home/.config/Kvantum/PywalAdapta/PywalAdapta.kvconfig" \
            "$home/.config/mako/config"
    '';

    # El desplegue del directorio .themes, que gtk.theme.name por si solo no
    # hace: home-manager instala el paquete en el PATH como gtk-theme, pero
    # GTK y nwg-look leen los temas de disco (.themes y share/themes), no del PATH.
    home.file.".themes/PywalSync-Mono".source =
      "${cfg.packageSet.pywalSyncMono}/share/themes/PywalSync-Mono";
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

      # Seed nwg-look gsettings cache so nwg-look widgets default to PywalSync-Mono
      nwg_dir="$home/.local/share/nwg-look"
      nwg_conf="$nwg_dir/gsettings"
      mkdir -p "$nwg_dir"
      if [ ! -f "$nwg_conf" ]; then
        cat <<EOF > "$nwg_conf"
# Generated by nwg-look, do not edit this file.
gtk-theme=PywalSync-Mono
icon-theme=Tela-circle
font-name=Adwaita Sans 11
cursor-theme=Bibata-Modern-Ice
cursor-size=24
toolbar-style=both-horiz
toolbar-icons-size=large
font-hinting=slight
font-antialiasing=grayscale
font-rgba-order=rgb
text-scaling-factor=1.0
color-scheme=prefer-dark
event-sounds=true
input-feedback-sounds=false
EOF
      elif ! grep -q '^gtk-theme=' "$nwg_conf" 2>/dev/null; then
        printf 'gtk-theme=PywalSync-Mono\n' >> "$nwg_conf"
      fi

      # Seed fallback pywal palette for Waybar, rust-dock, and Rofi if pywal has not run yet.
      # Without this, rust-dock falls back to default hardcoded Catppuccin Mocha colors,
      # and Rofi menus (such as SUPER+F hotkeys) fail to resolve @import "colors-pywal.rasi".
      wal_cache="$home/.cache/wal"
      mkdir -p "$wal_cache" "$home/.config/waybar" "$home/.config/rofi"
      if [ ! -f "$wal_cache/colors-waybar.css" ]; then
        cat <<'EOF' > "$wal_cache/colors-waybar.css"
@define-color background #101012;
@define-color foreground #c2c8c9;
@define-color cursor     #c2c8c9;
@define-color color0  #101012;
@define-color color1  #546065;
@define-color color2  #A45E4C;
@define-color color3  #E59A78;
@define-color color4  #5B7A84;
@define-color color5  #6F8C94;
@define-color color6  #9A9D9E;
@define-color color7  #c2c8c9;
@define-color color8  #878c8c;
@define-color color9  #546065;
@define-color color10 #A45E4C;
@define-color color11 #E59A78;
@define-color color12 #5B7A84;
@define-color color13 #6F8C94;
@define-color color14 #9A9D9E;
@define-color color15 #c2c8c9;
EOF
      fi

      if [ ! -e "$home/.config/waybar/colors-pywal.css" ]; then
        ln -sf "$wal_cache/colors-waybar.css" "$home/.config/waybar/colors-pywal.css"
      fi

      if [ ! -f "$home/.config/rofi/colors-pywal.rasi" ]; then
        cat <<'EOF' > "$home/.config/rofi/colors-pywal.rasi"
* {
    background:     #101012;
    background-alt: #101012;
    foreground:     #c2c8c9;
    foreground-alt: #878c8c;
    selected:       #546065;
    active:         #A45E4C;
    urgent:         #E59A78;
    color0:         #101012;
    color1:         #546065;
    color2:         #A45E4C;
    color3:         #E59A78;
    color4:         #5B7A84;
    color5:         #6F8C94;
    color6:         #9A9D9E;
    color7:         #c2c8c9;
    color8:         #878c8c;
    color9:         #546065;
    color10:        #A45E4C;
    color11:        #E59A78;
    color12:        #5B7A84;
    color13:        #6F8C94;
        color14:        #9A9D9E;
        color15:        #c2c8c9;
        background-trans:     #101012CC;
        background-alt-trans: #101012AA;
        selected-trans:       #546065DD;
    }
    EOF
          fi

          if [ ! -f "$wal_cache/colors-rofi.rasi" ] && [ -f "$home/.config/rofi/colors-pywal.rasi" ]; then
            cp -f "$home/.config/rofi/colors-pywal.rasi" "$wal_cache/colors-rofi.rasi"
          fi

          if [ ! -f "$wal_cache/colors-rofi-dark.rasi" ]; then
            cat <<'EOF' > "$wal_cache/colors-rofi-dark.rasi"
    * {
        active-background: #A45E4C;
        active-foreground: @foreground;
        normal-background: @background;
        normal-foreground: @foreground;
        urgent-background: #546065;
        urgent-foreground: @foreground;

        alternate-active-background: @background;
        alternate-active-foreground: @foreground;
        alternate-normal-background: @background;
        alternate-normal-foreground: @foreground;
        alternate-urgent-background: @background;
        alternate-urgent-foreground: @foreground;

        selected-active-background: #546065;
        selected-active-foreground: @foreground;
        selected-normal-background: #9A9D9E;
        selected-normal-foreground: @foreground;
        selected-urgent-background: #E59A78;
        selected-urgent-foreground: @foreground;

        background-color: @background;
        background: #101012;
        foreground: #c2c8c9;
        border-color: @background;
        spacing: 2;
    }

    #window {
        background-color: @background;
        border: 0;
        padding: 2.5ch;
    }

    #mainbox {
        border: 0;
        padding: 0;
    }

    #message {
        border: 2px 0px 0px;
        border-color: @border-color;
        padding: 1px;
    }

    #textbox {
        text-color: @foreground;
    }

    #listview {
        fixed-height: 0;
        border: 2px 0px 0px;
        border-color: @border-color;
        spacing: 2px;
        scrollbar: true;
        padding: 2px 0px 0px;
    }

    #element {
        border: 0;
        padding: 1px;
    }

    #element.normal.normal {
        background-color: @normal-background;
        text-color: @normal-foreground;
    }

    #element.normal.urgent {
        background-color: @urgent-background;
        text-color: @urgent-foreground;
    }

    #element.normal.active {
        background-color: @active-background;
        text-color: @active-foreground;
    }

    #element.selected.normal {
        background-color: @selected-normal-background;
        text-color: @selected-normal-foreground;
    }

    #element.selected.urgent {
        background-color: @selected-urgent-background;
        text-color: @selected-urgent-foreground;
    }

    #element.selected.active {
        background-color: @selected-active-background;
        text-color: @selected-active-foreground;
    }

    #element.alternate.normal {
        background-color: @alternate-normal-background;
        text-color: @alternate-normal-foreground;
    }

    #element.alternate.urgent {
        background-color: @alternate-urgent-background;
        text-color: @alternate-urgent-foreground;
    }

    #element.alternate.active {
        background-color: @alternate-active-background;
        text-color: @alternate-active-foreground;
    }
    EOF
          fi
        '';

    home.packages = with pkgs; [
      pywal16
      qt6Packages.qt6ct
      nwg-displays
      nwg-look
    ];
  };
}
