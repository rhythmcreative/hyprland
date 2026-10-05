#!/usr/bin/env bash
# Aplica los cambios de ambito NixOS que requieren root.
#
# Hazlo con:  sudo ./fix-nixos.sh
#
# Que hace y por que:
#
# 1. /etc/nixos/flake.nix apunta a "github:rhythmcreative/hyprland". Un input
#    github: es un rev CONGELADO en flake.lock: nunca sigue el checkout local.
#    Aunque reconstruyas, el build leeria el codigo remoto y el overrideAttrs
#    de modules/nixos/sddm.nix (que inyecta theme.conf y el wallpaper en el
#    greeter) no se aplicaria. Por eso el tema no cambiaba.
#    Se pasa a path: para que lo editado sea lo que se despliega, igual que ya
#    se hizo en el flake de home-manager.
#
# 2. nixos-rebuild switch es lo que construye el paquete del tema con el
#    theme.conf dentro. Sin esto el sistema sigue con el paquete viejo.
#
# 3. El journal ha crecido a 3.9 GB por un bucle de servicios que ya no
#    existe, y journald llega a gastar el 35% de CPU escribiendo en el.
set -euo pipefail

FLAKE=/etc/nixos/flake.nix
REPO=/home/rhythmcreative/hyprland

echo "==> 1/4. Comprobando $FLAKE"
test -f "$FLAKE" || { echo "ERROR: no existe $FLAKE"; exit 1; }

if ! grep -q 'path:' "$FLAKE" || grep -q 'github:rhythmcreative/hyprland' "$FLAKE"; then
    echo "==> 2/4. Cambiando el input de hyprland a path:"
    echo "    antes:  $(grep -A2 'hyprland = {' "$FLAKE" | grep 'url' || echo '?')"
    cp -a "$FLAKE" "$FLAKE.bak-$(date +%Y%m%d-%H%M%S)"
    echo "    backup: $(ls -t "$FLAKE".bak-* | head -1)"

    sed -i "s|url = \"github:rhythmcreative/hyprland\"|url = \"path:$REPO\"|" "$FLAKE"

    echo "    ahora:  $(grep -A2 'hyprland = {' "$FLAKE" | grep 'url')"
else
    echo "==> 2/4. El input ya apunta a path:, no hace falta cambiarlo."
fi

echo "==> 3/4. Reconstruyendo el sistema (tarda varios minutos)"
nixos-rebuild switch --flake "$FLAKE" 2>&1 | tail -25

echo "==> 4/4. Purgando el journal"
journalctl --vacuum-size=200M 2>&1 | tail -2

cat <<'VERDE'

==> Listo.

Comprueba que el greeter ya lleva el tema:

  T=$(readlink -f /run/current-system/sw/share/sddm/themes/sddm-astronaut-theme)
  grep -i '^Background' "$T/theme.conf"
  ls -la "$T/Backgrounds/current_wallpaper.jpg"

Debe salir Background="Backgrounds/current_wallpaper.jpg" y el fichero de
imagen. Si no sale, el flake seguia apuntando a GitHub y hay que mirar el
backup que se ha dejado.

Para volver atras:  cp /etc/nixos/flake.nix.bak-* /etc/nixos/flake.nix
VERDE