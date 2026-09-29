#!/usr/bin/env bash
# Migration 003: enable persistent user services if their units are deployed.
#
# Antes llevaba su propia lista de unidades, y ya no: esa lista se dividia de la
# del instalador y de la del actualizador, que es justo el fallo que hizo que
# servicios como waybar-island no arrancaran hasta que se corrigio a mano. La
# lista ahora vive en un solo sitio, enable-user-services, que decide mirando el
# WantedBy de cada unidad. Este script solo lo llama, y si todavia no esta (un
# repo antiguo, o alguien que borro el helper) no se rompe la migracion.
set -euo pipefail
if [ -x "$HOME/.local/bin/enable-user-services" ]; then
    "$HOME/.local/bin/enable-user-services"
    echo "003: servicios de usuario habilitados por enable-user-services."
else
    echo "003: enable-user-services no esta, se omite."
fi
