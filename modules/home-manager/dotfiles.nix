# Config directories, deployed declaratively instead of copied by install.sh.
#
# Two deliberate exceptions:
# - .config/systemd is NOT deployed: home-manager generates the user units
#   from services.nix, and stray unit files with the same names would
#   collide with the generated ones.
# - .config/hypr/monitors.conf is NOT deployed: nwg-displays owns that file
#   and the repo does not ship it. It is seeded once when missing, then left
#   alone, mirroring the saved_monitors dance in install.sh.
{ config, lib, ... }:

let
  cfg = config.rhythm;
in
{
  config = lib.mkIf cfg.enable {
    # hypr y waybar entran por una derivacion (packages/patched-dotfiles) en
    # vez de straight desde el repo, porque son los dos unicos que llevan
    # scripts de shell que se ejecutan de verdad, y en NixOS no hay
    # /bin/bash ni /usr/bin/env: sus shebangs no resuelven y el proceso muere
    # con "bad interpreter" antes de hacer nada. waybar no arrancaba al iniciar
    # sesion por esto (hyprland.lua llama a launch.sh, y launch.sh nunca
    # llegaba ni a escribir su log). La derivacion aplica patchShebangs, que es
    # lo mismo que ya hace packages/helpers para ~/.local/bin.
    xdg.configFile."Kvantum" = { source = ../../.config/Kvantum; recursive = true; };
    xdg.configFile."gtk-3.0" = { source = cfg.packageSet.patchedGtk3; recursive = true; };
    xdg.configFile."hypr" = { source = cfg.packageSet.patchedHypr; recursive = true; };
    xdg.configFile."kitty" = { source = ../../.config/kitty; recursive = true; };
    xdg.configFile."mako" = { source = ../../.config/mako; recursive = true; };
    xdg.configFile."quickshell" = { source = cfg.packageSet.patchedQuickshell; recursive = true; };
    xdg.configFile."rhythm" = { source = ../../.config/rhythm; recursive = true; };
    xdg.configFile."rofi" = { source = ../../.config/rofi; recursive = true; };
    xdg.configFile."rust-dock" = { source = ../../.config/rust-dock; recursive = true; };
    xdg.configFile."wal" = { source = cfg.packageSet.patchedWal; recursive = true; };
    xdg.configFile."waybar" = { source = cfg.packageSet.patchedWaybar; recursive = true; };

    home.file.".zshrc".source = ../../zsh/.zshrc;

    home.activation.seedMonitorsConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      (
        target="${config.home.homeDirectory}/.config/hypr/monitors.conf"
        if [ ! -e "$target" ]; then
          mkdir -p "$(dirname "$target")"
          printf '%s\n' ${lib.escapeShellArg cfg.monitors.seedText} > "$target"
        fi
      ) || true
    '';

    # The same wallpaper seeding install.sh does on Arch, which had no
    # counterpart here.
    #
    # The repo ships .config/hypr/wallpapers/default.jpg and the configFile
    # above deploys it, but NOTHING recorded it as the wallpaper to use:
    # ~/.cache/current-wallpaper is the file load-last-wallpaper-fast reads,
    # and on NixOS nothing ever wrote it. With no cache, no pywal wallpaper and
    # no /usr/share/sddm (the NixOS greeter lives in the store, so that branch
    # cannot match either) the chain had nothing to paint. And hyprland.lua
    # disables both force_default_wallpaper and the logo, so Hyprland paints
    # nothing of its own: the session came up on a flat black background.
    #
    # load-last-wallpaper-fast now falls back to default.jpg, so this is belt
    # and braces, and it is what makes ~/.cache/current-wallpaper point at a
    # stable path instead of being repopulated by the fallback on every login.
    #
    # It does not overwrite a wallpaper the user has already chosen, and it
    # repairs a cache pointing at a file that no longer exists -- which was the
    # case that black-screened every boot.
    home.activation.seedWallpaper = lib.hm.dag.entryAfter ([ "writeBoundary" ] ++ lib.optional (cfg.wallpaper.mode != "none") "fetchWallpapers") ''
      (
        home="${config.home.homeDirectory}"
        default_wp="$home/.config/hypr/wallpapers/default.jpg"
        cache="$home/.cache/current-wallpaper"
        mkdir -p "$home/.cache" "$home/Pictures/Wallpapers"

        seed=0
        if [ -f "$cache" ]; then
          cached="$(cat "$cache" 2>/dev/null || true)"
          if [ -z "$cached" ] || [ ! -f "$cached" ]; then
            # Points at something that is gone: that is a stale cache, not a
            # wallpaper the user chose.
            seed=1
          fi
        else
          seed=1
        fi

        if [ "$seed" = 1 ] && [ -f "$default_wp" ]; then
          printf '%s\n' "$default_wp" > "$cache"
        fi

        # wallpaper-random and wallpaper-selector fail on an empty library, so
        # the default goes there too when nothing is present.
        if [ -f "$default_wp" ] && [ -z "$(ls -A "$home/Pictures/Wallpapers" 2>/dev/null || true)" ]; then
          cp -f "$default_wp" "$home/Pictures/Wallpapers/default.jpg" 2>/dev/null || true
        fi
      ) || true
    '';

    # La ruta de ffmpeg que usa el selector de la Isla.
    #
    # El QML tenia "/usr/bin/ffmpeg" escrito a fuego. Eso no existe en NixOS,
    # donde el binario vive en el store, y en Arch depende de como lo haya
    # instalado el gestor de paquetes. Intentado resolverlo dentro del QML,
    # pero Quickshell no expone forma de comprobar si un fichero existe, y el
    # intento que funcionaba en Arch se rompio en NixOS.
    #
    # Aqui si se sabe: el despliegue es quien conoce el PATH real. Se escribe
    # en settings.json, que es lo que el QML lee, y solo si el usuario no ha
    # configurado otra a mano.
    home.activation.resolveFfmpeg = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      (
        home="${config.home.homeDirectory}"
        settings="$home/.config/quickshell/wallpaper/settings.json"
        ffmpeg=""
        if command -v ffmpeg >/dev/null 2>&1; then
          ffmpeg="$(command -v ffmpeg)"
        fi
        if [ -n "$ffmpeg" ] && [ -w "$(dirname "$settings")" ]; then
          if [ -f "$settings" ] && grep -q '"ffmpegPath"' "$settings" 2>/dev/null; then
            :
          else
            tmp="$settings.ffmpeg.$$"
            if command -v jq >/dev/null 2>&1; then
              if [ -f "$settings" ]; then
                jq --arg f "$ffmpeg" '. + {ffmpegPath: $f}' "$settings" > "$tmp" 2>/dev/null \
                  && mv -f "$tmp" "$settings" 2>/dev/null \
                  || rm -f "$tmp" 2>/dev/null
              else
                printf '{"ffmpegPath":"%s"}\n' "$ffmpeg" > "$tmp" 2>/dev/null \
                  && mv -f "$tmp" "$settings" 2>/dev/null \
                  || rm -f "$tmp" 2>/dev/null
              fi
            fi
          fi
        elif [ -z "$ffmpeg" ]; then
          echo "AVISO: ffmpeg no esta en el PATH; la Isla no podra previsualizar .gif"
        fi
      ) || true
    '';

  };
}
