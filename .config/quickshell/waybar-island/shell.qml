import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

ShellRoot {
    id: root

    property bool expanded: false
    property string activePlayerTitle: ""
    property string activePlayerArtist: ""
    property bool isPlaying: false
    property real volumeLevel: 0.5
    property real brightnessLevel: 0.5

    IpcHandler {
        target: "island"
        function toggle(): string {
            root.expanded = !root.expanded
            return root.expanded ? "expanded" : "collapsed"
        }
    }

    // Live pywal colors
    FileView {
        id: walFile
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
    }

    readonly property var walData: {
        try {
            return JSON.parse(walFile.text())
        } catch(e) {
            return null
        }
    }

    readonly property color colBg: walData?.special?.background ?? "#1e2130"
    readonly property color colFg: walData?.special?.foreground ?? "#dde2ea"
    readonly property color colAccent: walData?.colors?.color4 ?? "#C8B4C7"
    readonly property color colMuted: walData?.colors?.color8 ?? "#9a9ea3"
    readonly property color colSurface: Qt.rgba(colFg.r, colFg.g, colFg.b, 0.08)
    readonly property color colSurfaceHover: Qt.rgba(colFg.r, colFg.g, colFg.b, 0.16)
    readonly property color colBorder: Qt.rgba(colAccent.r, colAccent.g, colAccent.b, 0.25)

    // Current time
    property string timeStr: ""
    property string dateStr: ""

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const now = new Date()
            root.timeStr = Qt.formatTime(now, "HH:mm:ss")
            root.dateStr = Qt.formatDate(now, "dddd, d 'de' MMMM")
        }
    }

    // MPRIS tracking
    readonly property var players: Mpris.players.values
    readonly property var primaryPlayer: players.length > 0 ? players[0] : null

    onPrimaryPlayerChanged: updateMedia()

    Connections {
        target: root.primaryPlayer
        ignoreUnknownSignals: true
        function onPlaybackStateChanged() { root.updateMedia() }
        function onTrackTitleChanged() { root.updateMedia() }
        function onTrackArtistChanged() { root.updateMedia() }
    }

    function updateMedia() {
        if (root.primaryPlayer) {
            root.isPlaying = root.primaryPlayer.playbackState === MprisPlaybackState.Playing
            root.activePlayerTitle = root.primaryPlayer.trackTitle || ""
            root.activePlayerArtist = root.primaryPlayer.trackArtist || ""
        } else {
            root.isPlaying = false
            root.activePlayerTitle = ""
            root.activePlayerArtist = ""
        }
    }

    // Process helper to run quick commands
    function runCmd(cmd) {
        Quickshell.execDetached(["bash", "-c", cmd])
    }

    // Get live volume & brightness
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            // Read volume
            volProc.running = true
            // Read brightness
            briProc.running = true
        }
    }

    Process {
        id: volProc
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print $2}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const val = parseFloat(text.trim())
                if (!isNaN(val)) root.volumeLevel = Math.min(1.0, val)
            }
        }
    }

    Process {
        id: briProc
        command: ["bash", "-c", "brightnessctl -m | awk -F, '{print $4}' | tr -d '%'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const val = parseFloat(text.trim())
                if (!isNaN(val)) root.brightnessLevel = val / 100.0
            }
        }
    }

    // Main Dynamic Island Window
    PanelWindow {
        id: islandWin
        screen: Quickshell.screens[0]

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        implicitWidth: screen.width
        implicitHeight: screen.height
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        WlrLayershell.layer: root.expanded ? WlrLayer.Overlay : WlrLayer.Top
        WlrLayershell.keyboardFocus: root.expanded ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        mask: Region {
            item: capsule

            Region {
                item: root.expanded ? cazaClics : null
                intersection: Intersection.Combine
            }
        }

        // Dimmer background when expanded
        Rectangle {
            id: dimmer
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.35)
            opacity: root.expanded ? 1.0 : 0.0
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
        }

        // Background click catcher to close
        Item {
            id: cazaClics
            anchors.fill: parent
            enabled: root.expanded

            FocusScope {
                anchors.fill: parent
                focus: root.expanded
                Keys.onEscapePressed: root.expanded = false
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.expanded = false
            }
        }

        // Island container
        Rectangle {
            id: capsule
            anchors.top: parent.top
            anchors.topMargin: 5
            anchors.horizontalCenter: parent.horizontalCenter

            width: root.expanded ? 560 : (root.isPlaying && root.activePlayerTitle !== "" ? 280 : 210)
            height: root.expanded ? 400 : 30
            radius: root.expanded ? 14 : 6

            color: root.colBg
            border.color: root.colBorder
            border.width: 1
            clip: true

            Behavior on width {
                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
            }
            Behavior on height {
                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
            }
            Behavior on radius {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            // Subtle glow/shadow
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.color: Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.38)
                border.width: root.expanded ? 1.5 : 1
                opacity: 0.6
            }

            // ─────────────────────────────────────────────────────────────
            // COLLAPSED VIEW (Waybar-style integrated clock / media pill)
            // ─────────────────────────────────────────────────────────────
            Item {
                id: collapsedView
                anchors.fill: parent
                visible: opacity > 0
                opacity: root.expanded ? 0 : 1

                Behavior on opacity {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.expanded = !root.expanded

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: parent.containsMouse ? root.colSurfaceHover : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    // Media indicator if playing
                    RowLayout {
                        visible: root.isPlaying && root.activePlayerTitle !== ""
                        spacing: 6

                        Text {
                            text: "󰝚"
                            color: root.colAccent
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                        }

                        Text {
                            text: root.activePlayerTitle.length > 14 
                                ? root.activePlayerTitle.substring(0, 13) + "…" 
                                : root.activePlayerTitle
                            color: root.colFg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Layout.maximumWidth: 100
                        }

                        Rectangle {
                            width: 1
                            height: 12
                            color: root.colMuted
                            opacity: 0.4
                        }
                    }

                    // Clock (exact Waybar format and style)
                    Text {
                        text: root.timeStr
                        color: root.colAccent
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                    }

                    // Indicator icon
                    Text {
                        text: root.expanded ? "󰅃" : "󰅀"
                        color: root.colMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        opacity: 0.6
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }

            // ─────────────────────────────────────────────────────────────
            // EXPANDED VIEW (Dynamic Island Control Center)
            // ─────────────────────────────────────────────────────────────
            Item {
                id: expandedView
                anchors.fill: parent
                anchors.margins: 18
                visible: opacity > 0
                opacity: root.expanded ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 14

                    // 1. Header Row (Date, Pill notch, Power buttons)
                    RowLayout {
                        Layout.fillWidth: true

                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: root.dateStr
                                color: root.colFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }
                            Text {
                                text: root.timeStr
                                color: root.colAccent
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Notch close indicator
                        Rectangle {
                            width: 36
                            height: 4
                            radius: 2
                            color: root.colMuted
                            opacity: 0.5
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Item { Layout.fillWidth: true }

                        // Quick session buttons
                        RowLayout {
                            spacing: 8

                            Rectangle {
                                width: 30; height: 30; radius: 15
                                color: root.colSurface
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰌾"
                                    color: root.colFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.expanded = false; root.runCmd("hyprlock"); }
                                }
                            }

                            Rectangle {
                                width: 30; height: 30; radius: 15
                                color: root.colSurface
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰜉"
                                    color: root.colFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.expanded = false; root.runCmd("systemctl reboot"); }
                                }
                            }

                            Rectangle {
                                width: 30; height: 30; radius: 15
                                color: root.colSurface
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰐥"
                                    color: "#f38ba8"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.expanded = false; root.runCmd("systemctl poweroff"); }
                                }
                            }
                        }
                    }

                    // 2. Media Player Card
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 90
                        radius: 10
                        color: root.colSurface
                        border.color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.1)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 14

                            // Album art placeholder / icon
                            Rectangle {
                                width: 56; height: 56; radius: 8
                                color: Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.2)
                                Text {
                                    anchors.centerIn: parent
                                    text: root.isPlaying ? "󰝚" : "󰝛"
                                    color: root.colAccent
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 24
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: root.activePlayerTitle || "Nada en reproducción"
                                    color: root.colFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: root.activePlayerArtist || (root.primaryPlayer?.identity ?? "Reproductor multimedia")
                                    color: root.colMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            // Controls
                            RowLayout {
                                spacing: 10

                                Rectangle {
                                    width: 32; height: 32; radius: 16
                                    color: "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰒮"
                                        color: root.colFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 16
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.primaryPlayer?.previous() || root.runCmd("playerctl previous")
                                    }
                                }

                                Rectangle {
                                    width: 38; height: 38; radius: 19
                                    color: root.colAccent
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.isPlaying ? "󰏤" : "󰐊"
                                        color: root.colBg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 18
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.primaryPlayer?.playPause() || root.runCmd("playerctl play-pause")
                                    }
                                }

                                Rectangle {
                                    width: 32; height: 32; radius: 16
                                    color: "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰒭"
                                        color: root.colFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 16
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.primaryPlayer?.next() || root.runCmd("playerctl next")
                                    }
                                }
                            }
                        }
                    }

                    // 3. Quick Toggles Row (Wi-Fi, Bluetooth, Dark Mode, Mute)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        // Wi-Fi tile
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            radius: 8
                            color: root.colSurface

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8
                                Text {
                                    text: "󰤨"
                                    color: root.colAccent
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 16
                                }
                                ColumnLayout {
                                    spacing: 0
                                    Text {
                                        text: "Wi-Fi"
                                        color: root.colFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                    }
                                    Text {
                                        text: "Conectado"
                                        color: root.colMuted
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 9
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.runCmd("nm-connection-editor &")
                            }
                        }

                        // Bluetooth tile
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            radius: 8
                            color: root.colSurface

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8
                                Text {
                                    text: "󰂯"
                                    color: root.colAccent
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 16
                                }
                                ColumnLayout {
                                    spacing: 0
                                    Text {
                                        text: "Bluetooth"
                                        color: root.colFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                    }
                                    Text {
                                        text: "Activo"
                                        color: root.colMuted
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 9
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.runCmd("~/.local/bin/toggle-bluetooth")
                            }
                        }

                        // Wallpaper / pywal tile
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            radius: 8
                            color: root.colSurface

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8
                                Text {
                                    text: "󰔎"
                                    color: root.colAccent
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 16
                                }
                                ColumnLayout {
                                    spacing: 0
                                    Text {
                                        text: "Fondo"
                                        color: root.colFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                    }
                                    Text {
                                        text: "Cambiar"
                                        color: root.colMuted
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 9
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.expanded = false
                                    root.runCmd("~/.local/bin/wallpaper-selector")
                                }
                            }
                        }
                    }

                    // 4. Sliders (Volume & Brightness)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        // Volume Slider
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: root.volumeLevel === 0 ? "󰝟" : (root.volumeLevel < 0.5 ? "󰕿" : "󰕾")
                                color: root.colAccent
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 16
                                Layout.preferredWidth: 20
                            }

                            Rectangle {
                                id: volTrack
                                Layout.fillWidth: true
                                height: 18
                                radius: 9
                                color: root.colSurface

                                Rectangle {
                                    width: parent.width * root.volumeLevel
                                    height: parent.height
                                    radius: 9
                                    color: root.colAccent
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        const p = Math.max(0, Math.min(1, mouse.x / width))
                                        root.volumeLevel = p
                                        root.runCmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + Math.round(p * 100) + "%")
                                    }
                                }
                            }

                            Text {
                                text: Math.round(root.volumeLevel * 100) + "%"
                                color: root.colFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                Layout.preferredWidth: 35
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        // Brightness Slider
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: "󰃠"
                                color: root.colAccent
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 16
                                Layout.preferredWidth: 20
                            }

                            Rectangle {
                                id: briTrack
                                Layout.fillWidth: true
                                height: 18
                                radius: 9
                                color: root.colSurface

                                Rectangle {
                                    width: parent.width * root.brightnessLevel
                                    height: parent.height
                                    radius: 9
                                    color: root.colAccent
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        const p = Math.max(0.05, Math.min(1, mouse.x / width))
                                        root.brightnessLevel = p
                                        root.runCmd("brightnessctl set " + Math.round(p * 100) + "%")
                                    }
                                }
                            }

                            Text {
                                text: Math.round(root.brightnessLevel * 100) + "%"
                                color: root.colFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                Layout.preferredWidth: 35
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }
        }
    }
}
