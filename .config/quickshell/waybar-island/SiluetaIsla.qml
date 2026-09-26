// Silueta de Dynamic Island con esquinas invertidas (alas) fundidas con el borde de la pantalla

import QtQuick
import QtQuick.Shapes

Shape {
    id: silueta

    // Cuanto muerde cada esquina invertida hacia dentro (radio de union con el borde)
    property real ala: 16

    // El redondeo de las esquinas del fondo
    property real cuerpoRadio: 16

    property color relleno: "#1e2130"

    property string lado: "arriba" // arriba, abajo, izquierda, derecha
    property bool reflejada: false

    readonly property string _lado: reflejada ? "abajo" : lado
    readonly property bool _vertical: _lado === "izquierda" || _lado === "derecha"

    readonly property real _largo: _vertical ? height : width
    readonly property real _hondo: _vertical ? width : height

    antialiasing: true
    layer.enabled: true
    layer.samples: 8
    layer.smooth: true

    ShapePath {
        id: trazo

        fillColor: silueta.relleno
        strokeWidth: 0
        strokeColor: "transparent"

        readonly property real w: silueta._largo
        readonly property real h: silueta._hondo
        readonly property real g: Math.max(0, Math.min(silueta.ala, trazo.h / 2, trazo.w / 6))
        readonly property real r: Math.max(0, Math.min(silueta.cuerpoRadio, trazo.h / 2, trazo.w / 3 - trazo.g))

        function px(u, v) {
            if (silueta._lado === "izquierda") return v
            if (silueta._lado === "derecha") return trazo.h - v
            return u
        }
        function py(u, v) {
            if (silueta._vertical) return u
            return silueta._lado === "abajo" ? trazo.h - v : v
        }

        readonly property bool inv: silueta._lado === "abajo" || silueta._lado === "izquierda"
        readonly property int haciaDentro: inv ? PathArc.Counterclockwise : PathArc.Clockwise
        readonly property int haciaFuera: inv ? PathArc.Clockwise : PathArc.Counterclockwise

        startX: trazo.px(0, 0)
        startY: trazo.py(0, 0)

        // Esquina invertida del principio (ala izquierda)
        PathArc {
            x: trazo.px(trazo.g, trazo.g)
            y: trazo.py(trazo.g, trazo.g)
            radiusX: trazo.g
            radiusY: trazo.g
            direction: trazo.haciaDentro
        }

        PathLine {
            x: trazo.px(trazo.g, trazo.h - trazo.r)
            y: trazo.py(trazo.g, trazo.h - trazo.r)
        }

        // Esquina inferior izquierda del fondo
        PathArc {
            x: trazo.px(trazo.g + trazo.r, trazo.h)
            y: trazo.py(trazo.g + trazo.r, trazo.h)
            radiusX: trazo.r
            radiusY: trazo.r
            direction: trazo.haciaFuera
        }

        PathLine {
            x: trazo.px(trazo.w - trazo.g - trazo.r, trazo.h)
            y: trazo.py(trazo.w - trazo.g - trazo.r, trazo.h)
        }

        // Esquina inferior derecha del fondo
        PathArc {
            x: trazo.px(trazo.w - trazo.g, trazo.h - trazo.r)
            y: trazo.py(trazo.w - trazo.g, trazo.h - trazo.r)
            radiusX: trazo.r
            radiusY: trazo.r
            direction: trazo.haciaFuera
        }

        PathLine {
            x: trazo.px(trazo.w - trazo.g, trazo.g)
            y: trazo.py(trazo.w - trazo.g, trazo.g)
        }

        // Esquina invertida del final (ala derecha)
        PathArc {
            x: trazo.px(trazo.w, 0)
            y: trazo.py(trazo.w, 0)
            radiusX: trazo.g
            radiusY: trazo.g
            direction: trazo.haciaDentro
        }

        PathLine {
            x: trazo.px(0, 0)
            y: trazo.py(0, 0)
        }
    }
}
