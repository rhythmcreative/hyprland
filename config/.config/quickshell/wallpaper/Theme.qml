pragma Singleton
import QtQuick
import Quickshell.Io
import Qt.labs.platform

QtObject {
    id: root
    property bool loaded: false

    property color background: "#B2111718"
    property color background90: "#E6111718"
    property color border: "#D99E60"
    property color accent: "#B27A8364"
    property color text: "#edd1bf"

    Behavior on background {
        ColorAnimation {
            duration: root.loaded ? 800 : 0
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
        }
    }
    Behavior on background90 {
        ColorAnimation {
            duration: root.loaded ? 800 : 0
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
        }
    }
    Behavior on border {
        ColorAnimation {
            duration: root.loaded ? 800 : 0
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
        }
    }
    Behavior on accent {
        ColorAnimation {
            duration: root.loaded ? 800 : 0
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
        }
    }
    Behavior on text {
        ColorAnimation {
            duration: root.loaded ? 800 : 0
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
        }
    }

    property string walColorsPath: String(StandardPaths.writableLocation(StandardPaths.HomeLocation)).replace(/^file:\/\//, "") + "/.cache/wal/colors.json"

    property var _watcher: FileView {
        id: walFile
        path: root.walColorsPath
        blockLoading: true
        onLoaded: {
            try {
                let json = JSON.parse(text().trim());
                root.background = "#B2" + json.colors.color0.replace("#", "");
                root.background90 = "#E6" + json.colors.color0.replace("#", "");
                root.border = json.colors.color12;
                root.accent = "#B2" + json.colors.color1.replace("#", "");
                root.text = json.special.foreground;
                root.loaded = true;
            } catch (e) {}
        }
    }

    property var _timer: Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: walFile.reload()
        Component.onCompleted: walFile.reload()
    }
}
