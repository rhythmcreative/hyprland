set -euo pipefail

# Habilita los servicios de usuario que esten en ~/.config/systemd/user y esten
#luencecidos para arrancar, sin lista fija.
#
# Por que hace falta: la migracion 003.enableba una lista escrita a mano de siete
# unidades, y como ya esta marcada como hecha en ~/.local/state/rhythm/migrations/
# no vuelve a correr nunca. Con eso, cualquier servicio nuevo que se anada al repo
# se despliega pero no se habilita: llega al disco, systemd lo ve con daemon-reload
# y nunca arranca. Es el mismo sintoma que los tres servicios que carryan meses
# enabled sin ejecutarse jamas, y es igual de silencioso.
#
# La regla es la del propio fichero: si una unidad tiene [Install] WantedBy=default.target
# se habilita. Asi no hay que mantener ninguna lista y anadir un servicio al repo
# basta.
#
# Las excluidas son units que se activan bajo demanda o a proposito:
#
#   rhythm-caffeine.service           la isla la enciende y la apaga con un
#                                     interruptor, y toggle-caffeine status la
#                                     arranca sola mientras el flag exista
#   rhythm-nightlight-schedule.service  solo debe correr si el usuario ha
#                                     activado un horario
#   blueman-applet.service            esta masked a proposito en esta maquina
#
# Este script solo habilita. No arranca nada: enabling no crea procesos, asi que
# un servicio recien anadido no aparecera hasta el siguiente inicio de sesion o
# hasta que se haga systemctl --user start <unidad>. Es lo que evita que un update
# te encienda de golpe la webcam o el dock por sorpresa.

EXCLUIDAS="rhythm-caffeine.service rhythm-nightlight-schedule.service blueman-applet.service pipewire-session-manager.service"
DIR="$HOME/.config/systemd/user"

if ! command -v systemctl >/dev/null 2>&1; then
    echo "004: systemctl no disponible, se salta."
    exit 0
fi

if [ ! -d "$DIR" ]; then
    echo "004: no existe $DIR, se salta."
    exit 0
fi

systemctl --user daemon-reload 2>/dev/null || true

habilitadas=0
saltadas=0

for unit in "$DIR"/*.service "$DIR"/*.timer; do
    [ -e "$unit" ] || continue
    name=$(basename "$unit")

    case " $EXCLUIDAS " in
        *" $name "*)
            saltadas=$((saltadas + 1))
            continue
            ;;
    esac

    # Solo si el propio fichero dice que debe arrancar. Los targets aceptados son
    # los que estan activos en una sesion real: default.target para servicios y
    # timers.target para timers. graphical-session.target queda fuera a proposito,
    # porque en Hyprland arrancado con SDDM no lo activa nadie y una unidad colgada
    # de el se queda sin arrancar sin decir nada.
    if ! grep -qE '^\s*WantedBy=.*(default\.target|timers\.target)' "$unit" 2>/dev/null; then
        continue
    fi

    # Si ya esta en el estado que queremos, no tocar nada: ademas se evita
    # remover un "enabled-runtime" que un unit Wants= grafiticamente puesto.
    case "$(systemctl --user is-enabled "$name" 2>/dev/null || echo unknown)" in
        enabled|enabled-runtime)
            continue
            ;;
    esac

    if systemctl --user enable "$name" >/dev/null 2>&1; then
        echo "004: habilitada $name."
        habilitadas=$((habilitadas + 1))
    else
        echo "004: no se pudo habilitar $name."
    fi
done

echo "004: $habilitadas habilitadas, $saltadas excluidas por diseno."
