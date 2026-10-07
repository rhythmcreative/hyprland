# The ~/.local/bin helper scripts as a derivation.
#
# Home-manager symlinks these into ~/.local/bin file by file, so scripts
# calling each other through $HOME/.local/bin keep working. At build time a
# few hardcoded Arch paths are patched to store paths; everything else runs
# unchanged. Scripts that only make sense on Arch (pacman OTA, /usr deploy)
# are excluded here and documented in docs/nixos.md.
{ lib
, stdenv
, hyprlock
, bash
, python3
, python3Packages
, rnnoise-plugin ? null
, brightnessctl ? null
}:

let
  # Scripts replaced by Nix concepts; never deployed on NixOS.
  excluded = [
    "rust-dock" # packaged separately as rustDock (a committed Arch binary would not run: no /lib64 loader)
    "waybar_auto_hide" # precompiled Arch ELF binary; not used and fails on NixOS without /lib64 loader
    "ota-updater"
    "ota-snapshot" # Arch timeshift/snapper layout; NixOS generations cover rollbacks
    "rhythm-sddm-deploy" # embodied by modules/nixos/sddm.nix
    "enable-user-services" # embodied by systemd.user.services WantedBy
    "rhythm-materialize" # OTA deploy helper with no declarative counterpart
    "sddm-sync-wrapper" # live greeter recolouring needs a writable /usr/share (ADR-0004)
    "sddm-auto-sync-local"
    "sync-sddm-wallpaper"
    "sync-sddm-wallpaper-sudo"
    # Calls sddm-sync-wrapper, which the line above excludes, so it aborts with
    # "Script de sincronizacion no encontrado" on every wallpaper change.
    # Dead on NixOS by construction: the greeter palette is baked at build
    # time (ADR-0004).
    "sddm-wallpaper-watcher"
  ];
  excludedList = lib.concatStringsSep " " excluded;

  srcDir = ../../.local/bin;
  entries = builtins.readDir srcDir;
  scriptNames = builtins.filter
    (name: entries.${name} == "regular"
      && !(lib.elem name excluded)
      && !(lib.hasSuffix ".bak" name)
      && !(lib.hasSuffix ".pyc" name)
      && name != "__pycache__")
    (builtins.attrNames entries);

  # site-packages del modulo de dbus, resuelto en build time en vez de
  # escribir la version de Python a mano.
  # El path de site-packages del modulo de dbus se resuelve en el shell del
  # build, no en Nix: makeSearchPathOutput solo es correcto para Derivaciones
  # que exponen site-packages en share/, y esta lo expone en
  # lib/python3.14/site-packages. Con makeSearchPathOutput la ruta salia como
  # <pkg>/site-packages, sin el directorio de python, y el PYTHONPATH no
  # encontraba nada: el mismo "No module named dbus" por otra causa.
  #
  # El glob en el shell evita ademas atar esto a una version de Python.
in
stdenv.mkDerivation {
  pname = "rhythm-helpers";
  version = "0.24";
  src = ../../.local/bin;

  # patchShebangs resolves a shebang by looking the interpreter up with
  # `type -P` in the build PATH, and silently leaves the line alone when it
  # finds nothing. bash comes with stdenv, so the 71 shell scripts got fixed;
  # python3 did not, so the nine `#!/usr/bin/env python3` helpers (the island
  # sensors, bluetooth-pair-agent, pywal-tela-sync) shipped unrunnable even
  # though the argument was in scope. Both have to be named here.
  # The interpreter also has to be referenced from the output, or nothing
  # keeps its store path alive and a gc leaves the patched shebang dangling.
  #
  # python3Packages.dbus-python goes with it because bluetooth-pair-agent
  # imports dbus and exits 1 with "missing dependency: No module named 'dbus'"
  # without it. Merely listing it here is not enough: a native module lives in
  # site-packages, and python only finds it when the directory is on
  # PYTHONPATH, which the shebang alone does not set. Without this the BlueZ
  # pairing prompt never appeared, every RequestConfirmation was rejected with
  # nothing on screen, and Restart=always turned it into 439 restarts.
  nativeBuildInputs = [
      bash
      python3
      python3Packages.dbus-python
      python3Packages.pygobject3
      python3Packages.pycairo
    ];

  installPhase = ''
    mkdir -p $out/bin
    for f in "$src"/*; do
      name="$(basename "$f")"
      case "$name" in
        __pycache__|*.pyc|*.bak) continue ;;
      esac
      case " ${excludedList} " in
        *" $name "*) continue ;;
      esac
      [ -f "$f" ] || continue
      cp "$f" "$out/bin/$name"
    done
    chmod +x "$out/bin"/*

    # NixOS has neither /bin/bash nor /usr/bin/env, so every script that
    # declares either shebang lands in the store unrunnable: exec fails with
    # "bad interpreter" before the script's first line, which is why waybar
    # never came up at login and why `rhythm-doctor` reported green (its
    # delivery check is `[ -x ]`, and the exec bit is set regardless of
    # whether the interpreter exists).
    #
    # This is the same class of FHS-absolute path as the hyprlock probe
    # below, and gets the same treatment: resolved here at build time instead
    # of rewriting 71 files by hand, which ADR-0001 forbids anyway since the
    # modules reference .local/bin in place.
    #
    # Not switched to /bin/sh on purpose: most of these are bash scripts
    # ([[ ]], arrays, declare -A, mapfile, &>), so sh would fail later and
    # less legibly. This also picks up the `#!/usr/bin/env python3` ones
    # (bluetooth-pair-agent) by naming both interpreters.
    patchShebangs "$out/bin"/*

    # patchShebangs deja el shebang como "#! /nix/store/...", con un espacio
    # detrás del "#!". makeWrapper necesita reemplazar la primera línea, y con
    # el espacio no lo hace: se limita a crear un envoltorio que invoca el
    # original a través del intérprete equivocado, o directamente falla con
    # Permission denied al no poder reescribirlo. Normalizar aquí, quitando el
    # espacio.
    for script in "$out/bin"/*; do
      [ -f "$script" ] || continue
      # chmod +x de arriba deja los ficheros en 555, y makeWrapper necesita
      # escribir en ellos para montar el envoltorio: sin esto el build muere
      # con Permission denied justo en la primera llamada.
      chmod u+w "$script"
      first="$(head -n1 "$script")"
      # La comparación va con grep y no con un case sobre el shebang: dentro
      # de un string de Nix, "#!" abre un comentario y rompe el parseo.
      if printf '%s' "$first" | grep -q '^#! '; then
        interp="$(printf '%s' "$first" | sed 's/^#![[:space:]]*//')"
        tmp="$script.nb"
        { printf '#!%s\n' "$interp"; tail -n +2 "$script"; } > "$tmp"
        cat "$tmp" > "$script"
        rm -f "$tmp"
      fi
    done

    # El modulo de dbus va en PYTHONPATH, no solo en el PATH: es una extension
    # nativa que vive en site-packages, y python solo la encuentra si esa
    # carpeta esta en PYTHONPATH, cosa que el shebang no establece. Sin esto
    # bluetooth-pair-agent salia con status=1 y "missing dependency: No module
    # named 'dbus'", el prompt de emparejamiento no aparecia nunca y cada
    # RequestConfirmation se rechazaba sin nada en pantalla.
    #
    # Los scripts de python se envuelven a mano en vez de con makeWrapper ni
    # wrapProgram. Los dos reescriben el shebang del fichero original y aqui
    # eso rompe: wrapProgram lo deja en "bash -e", con lo que un script Python
    # pasa a correr bajo bash y falla con un error que no señala la causa; y
    # makeWrapper depende de detalles de permisos y nombres que hacen el build
    # fragil. Un envoltorio escrito aqui hace exactamente lo que hace falta y
    # no se comporta de forma distinta entre versiones de stdenv.
    #
    # El modulo de dbus va en PYTHONPATH y no solo en el PATH: es una extension
    # nativa que vive en site-packages, y python solo la encuentra si esa
    # carpeta esta en PYTHONPATH, cosa que el shebang no establece. Sin esto
    # bluetooth-pair-agent salia con status=1 y "missing dependency: No module
    # named 'dbus'", el prompt de emparejamiento nunca aparecia y cada
    # RequestConfirmation se rechazaba sin nada en pantalla, con 439 reinicios
    # del servicio.
    #
    # La ruta del modulo se resuelve en build time en vez de escribir
    # "python3.14": si nixpkgs cambia de version, una ruta fija dejaria el
    # PYTHONPATH apuntando a un directorio inexistente y el fallo seria el
    # mismo "No module named dbus" por otra causa.
    for py in bluetooth-pair-agent hypr-event-stream; do
      [ -f "$out/bin/$py" ] || continue
      mv "$out/bin/$py" "$out/bin/$py.real"
      # El heredoc se deja sin interpolar y las rutas se sustituyen con sed
      # despues: dentro de un string de Nix, una expansion de shell con
      # dollar y llaves se interpretaria como interpolacion.
      dbusSitePackages=""
      # Los tres modulos se resuelven de una vez. El agente importaba dbus y
      # luego gi, y cada uno aparecia como un "No module named" distinto segun
      # se fuera arreglando uno a uno. Las rutas se interpolan aqui y no en el
      # for: un nombre de atributo de Nix a secas no llega al shell.
      for extra in "${python3Packages.dbus-python}" \
                   "${python3Packages.pygobject3}" \
                   "${python3Packages.pycairo}"; do
        for candidate in "$extra"/lib/python*/site-packages; do
          if [ -d "$candidate" ]; then
            dbusSitePackages="$dbusSitePackages:$candidate"
          fi
        done
      done

      if [ -z "$dbusSitePackages" ]; then
        echo "AVISO: no se localizo site-packages de dbus-python" >&2
      else
        echo "PYTHONPATH de python: $dbusSitePackages" >&2
      fi

      cat > "$out/bin/$py" <<'EOF'
#!/bin/sh
# Generado en build time. Ver packages/helpers/default.nix.
export PYTHONPATH="@@DBUS@@:$PYTHONPATH"
export PATH="@@PYBINDIR@@:$PATH"
exec "@@PYTHON@@" "$(dirname "$(readlink -f "$0")")/@@NAME@@.real" "$@"
EOF
      sed -i \
        -e "s|@@DBUS@@|$dbusSitePackages|g" \
        -e "s|@@PYBINDIR@@|${python3}/bin|g" \
        -e "s|@@PYTHON@@|${python3}/bin/python3|g" \
        -e "s|@@NAME@@|$py|g" \
        "$out/bin/$py"
      chmod +x "$out/bin/$py"
    done

    # Point the dock launcher at the packaged binary. The unit PATH already
    # covers bare tools (pkill, hyprctl, jq), so only FHS-absolute paths need
    # patching. The launcher keeps pointing at $HOME/.local/bin/rust-dock on
    # purpose: home-manager links the packaged binary under that exact name,
    # so resolving it at runtime avoids a build-time edge on rustDock (whose
    # hash is filled in on first use) and keeps working if the user swaps the
    # binary by hand.

    # The locker probe checks FHS paths that do not exist on NixOS.
    substituteInPlace "$out/bin/powermenu-with-monitor-detection" \
      --replace '/usr/bin/hyprlock' '${hyprlock}/bin/hyprlock'

    if [ -f "$out/bin/toggle-noise-suppression" ] && [ -n "${if rnnoise-plugin != null then rnnoise-plugin else ""}" ]; then
      substituteInPlace "$out/bin/toggle-noise-suppression" \
        --replace '/usr/lib/ladspa' '${rnnoise-plugin}/lib/ladspa' \
        --replace 'plugin = "librnnoise_ladspa"' 'plugin = "${rnnoise-plugin}/lib/ladspa/librnnoise_ladspa.so"'
    fi

    if [ -f "$out/bin/keyboard-backlight" ] && [ -n "${if brightnessctl != null then brightnessctl else ""}" ]; then
      substituteInPlace "$out/bin/keyboard-backlight" \
        --replace 'echo "$new_brightness" | sudo tee "$BRIGHTNESS_FILE" > /dev/null' \
                  '${brightnessctl}/bin/brightnessctl -d asus::kbd_backlight set "$new_brightness" > /dev/null 2>&1 || echo "$new_brightness" | sudo tee "$BRIGHTNESS_FILE" > /dev/null'
    fi
  '';

  passthru = {
    inherit scriptNames;
  };

  meta = {
    description = "Helper scripts for the Rhythm Hyprland desktop";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
