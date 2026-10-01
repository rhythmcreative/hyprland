#!/bin/bash
# This script runs after wal finishes.
#
# pywal no falla nunca aqui: si algo falla, este guion se queda con el primer
# error y no aplica el resto. Por eso cada paso se comprueba.

# Update Mako configuration.
#
# Antes esto llamaba a ~/.config/mako/pywal-update.sh, un fichero que no existe
# en el repo ni en ninguna instalacion: en cada cambio de tema salia
# "No such file or directory". Mako ya se sincroniza por dos vias que si
# funcionan: done.d/mako-sync.sh y modern-pywal-sync.
[ -x "$HOME/.local/bin/sync-mako-pywal" ] && "$HOME/.local/bin/sync-mako-pywal"

# Update Waybar (if needed).
#
# Se usa pkill sin -f a proposito: los dos procesos de este equipo se llaman
# rust-dock, y `pkill -f dock` los mataria a los dos.
command -v pkill >/dev/null 2>&1 && pkill -SIGUSR1 waybar 2>/dev/null

# Update Qt5CT configuration
[ -f "$HOME/.config/wal/scripts/qt5ct-wal.sh" ] && "$HOME/.config/wal/scripts/qt5ct-wal.sh"

# Any other post-wal commands can go here