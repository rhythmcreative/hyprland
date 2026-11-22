import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: barWin
    property var modelData: null
    property string screenName: ""
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 40

    readonly property bool isScreenHidden: !!(islandRoot && barWin.screenName !== "" && islandRoot.hiddenScreens && islandRoot.hiddenScreens[barWin.screenName] === true)
    visible: {
        if (islandRoot) {
            if (islandRoot.enableQuickshellWaybar === false) return false
            if (islandRoot.islandVisible === false) return false
            if (isScreenHidden) return false
        }
        return true
    }
    exclusionMode: visible ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: visible ? 40 : 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "waybar"
    color: "transparent"
    property bool showTrayApps: false
    property var islandRoot: null

    // Live pywal colors directly from ~/.cache/wal/colors.json
    FileView {
        id: walFile
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: walFile.reload()
    }

    readonly property var walData: {
        try {
            return JSON.parse(walFile.text())
        } catch(e) {
            return null
        }
    }

    // Exact Pywal colors matching Waybar's @background, @foreground, @colorX
    readonly property color colBg: (walData && walData.special && walData.special.background) ? walData.special.background : "#0d1011"
    readonly property color colFg: (walData && walData.special && walData.special.foreground) ? walData.special.foreground : "#d6d7d4"
    readonly property color colAccent: (walData && walData.colors && walData.colors.color4) ? walData.colors.color4 : "#788786"
    readonly property color colMuted: (walData && walData.colors && walData.colors.color8) ? walData.colors.color8 : "#959694"
    readonly property color colCoral: (walData && walData.colors && walData.colors.color2) ? walData.colors.color2 : "#636D6D"
    readonly property color colCpu: (walData && walData.colors && walData.colors.color1) ? walData.colors.color1 : "#495253"
    readonly property color colRam: (walData && walData.colors && walData.colors.color5) ? walData.colors.color5 : "#78BAC9"
    readonly property color colCpuTemp: (walData && walData.colors && walData.colors.color3) ? walData.colors.color3 : "#A36256"
    readonly property color colGpuTemp: (walData && walData.colors && walData.colors.color2) ? walData.colors.color2 : "#636D6D"
    readonly property color colCava: (walData && walData.colors && walData.colors.color6) ? walData.colors.color6 : "#98A29F"
    readonly property color colLang: (walData && walData.colors && walData.colors.color5) ? walData.colors.color5 : "#78BAC9"
    readonly property color colAudio: (walData && walData.colors && walData.colors.color3) ? walData.colors.color3 : "#A36256"
    readonly property color colBacklight: (walData && walData.colors && walData.colors.color6) ? walData.colors.color6 : "#98A29F"
    readonly property color colBattery: (walData && walData.colors && walData.colors.color4) ? walData.colors.color4 : "#788786"

    // --- Dynamic Stats State ---
    property var rawWorkspaces: []
    property int activeWsId: 1
    property string activeKeymap: (islandRoot && islandRoot.kbLayout) ? islandRoot.kbLayout : "US"

    // System stats (shared from islandRoot: single collector for ALL monitors, 0 duplicate polling)
    readonly property int cpuPercent: islandRoot ? islandRoot.barCpuPercent : 5
    readonly property string cpuBar: islandRoot ? islandRoot.barCpuBar : "▁▁▁▁"
    readonly property string memStr: islandRoot ? islandRoot.barMemStr : "0.0G/0.0G"
    readonly property string cpuTempStr: islandRoot ? islandRoot.barCpuTempStr : "󰔏 --°C"
    readonly property string gpuTempStr: islandRoot ? islandRoot.barGpuTempStr : "󰔏 --°C"
    readonly property string cavaBars: islandRoot ? islandRoot.barCavaBars : "▁▁▁▁▁▁▁▁▁▁▁▁"

    // Bluetooth full state & icons
    readonly property int btConnectedCount: islandRoot ? islandRoot.barBtConnectedCount : 0
    readonly property bool btPowered: islandRoot ? islandRoot.barBtPowered : true
    readonly property string btType: islandRoot ? islandRoot.barBtType : "default"
    readonly property string btDeviceName: islandRoot ? islandRoot.barBtDeviceName : ""
    readonly property int btBattery: islandRoot ? islandRoot.barBtBattery : -1
    readonly property string btIcon: {
        if (!btPowered) return "󰂲" // Off / Disabled
        if (btConnectedCount === 0) return "󰂯" // On, un-connected
        if (btType === "audio") return "󰋋" // Headphones / Earbuds / Headset
        if (btType === "gamepad") return "󰊴" // Controller
        if (btType === "mouse") return "󰍽" // Mouse
        if (btType === "keyboard") return "󰌌" // Keyboard
        if (btType === "phone") return "󰏲" // Smartphone
        return "󰂱" // Default connected
    }

    // WiFi / Network full state & icons
    readonly property bool isEthernet: islandRoot ? islandRoot.barIsEthernet : false
    readonly property bool isWifiConnected: islandRoot ? islandRoot.barIsWifiConnected : true
    readonly property bool isWifiEnabled: islandRoot ? islandRoot.barIsWifiEnabled : true
    readonly property int wifiSignal: islandRoot ? islandRoot.barWifiSignal : 75
    readonly property string wifiSsid: islandRoot ? islandRoot.barWifiSsid : ""
    readonly property string netIcon: {
        if (isEthernet) return "󰈀"
        if (!isWifiEnabled) return "󰤪" // Radio disabled / airplane
        if (!isWifiConnected) return "󰤮" // Disconnected
        if (wifiSignal >= 75) return "󰤨" // Strongest
        if (wifiSignal >= 50) return "󰤥" // Good
        if (wifiSignal >= 25) return "󰤢" // Medium
        if (wifiSignal > 0) return "󰤟" // Weak
        return "󰤯" // Very weak / 0%
    }

    // Audio, Backlight, Battery
    readonly property int volPercent: islandRoot ? islandRoot.barVolPercent : 46
    readonly property bool volMuted: islandRoot ? islandRoot.barVolMuted : false
    readonly property bool isHeadphones: islandRoot ? islandRoot.barIsHeadphones : false
    readonly property int brightnessPercent: islandRoot ? islandRoot.barBrightnessPercent : 84
    readonly property bool hasBattery: islandRoot ? islandRoot.barHasBattery : true
    readonly property int batPercent: islandRoot ? islandRoot.barBatPercent : 100
    readonly property bool batCharging: islandRoot ? islandRoot.barBatCharging : false
    readonly property bool batPlugged: islandRoot ? islandRoot.barBatPlugged : false
    readonly property bool batDual: islandRoot ? islandRoot.barBatDual : false
    readonly property string batDetail: islandRoot ? islandRoot.barBatDetail : ""
    readonly property string batIcon: islandRoot ? islandRoot.barBatIcon : "󰁹"

    // Filter workspaces for current monitor
    readonly property var currentScreenWorkspaces: {
        const scrName = (barWin.screen && barWin.screen.name) ? barWin.screen.name : ""
        if (!scrName || rawWorkspaces.length === 0) return rawWorkspaces
        const filtered = rawWorkspaces.filter(w => w.monitor === scrName)
        return filtered.length > 0 ? filtered : rawWorkspaces
    }

    // Command runner with full environment
    function run(cmd) {
        const envInit = "export XDG_RUNTIME_DIR=\"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}\"; " +
                        "[ -z \"$WAYLAND_DISPLAY\" ] && export WAYLAND_DISPLAY=\"wayland-1\"; " +
                        "[ -z \"$HYPRLAND_INSTANCE_SIGNATURE\" ] && export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t \"$XDG_RUNTIME_DIR/hypr/\" 2>/dev/null | grep -v '\\.lock$' | head -n1); "
        Quickshell.execDetached(["bash", "-c", envInit + cmd])
    }

    // Dual Hyprland workspace switcher (Hyprland 0.55+ Lua API with <0.55 legacy fallback)
    function switchWorkspace(target) {
        const isNum = (typeof target === "number") || /^[0-9]+$/.test(String(target))
        const luaArg = isNum ? String(Number(target)) : ("'" + String(target).replace(/'/g, "") + "'")
        const rawTarget = String(target).replace(/'/g, "")
        const cmd =
            "out=$(hyprctl eval \"hl.dispatch(hl.dsp.focus({workspace=" + luaArg + "}))\" 2>&1 || true); " +
            "case \"$out\" in *error*|*unknown*|*'legacy parsers'*|'') hyprctl dispatch workspace '" + rawTarget + "' >/dev/null 2>&1 || true ;; esac"
        barWin.run(cmd)
    }

    function toggleSysMon() {
        const scrName = barWin.screenName || ((barWin.screen && barWin.screen.name) ? barWin.screen.name : "")
        if (barWin.islandRoot && typeof barWin.islandRoot.toggleSysMon === "function") {
            barWin.islandRoot.toggleSysMon(scrName)
        } else {
            barWin.run("quickshell ipc -p $HOME/.config/quickshell/waybar-island/shell.qml --any-display call island toggleSysMon '" + scrName + "'")
        }
    }

    // Event-driven workspace & keyboard layout refresh (instant response, low CPU)
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event ? String(event.name || "") : ""
            if (n === "workspace" || n === "workspacev2" || n === "focusedmon" ||
                n === "focusedmonv2" || n === "createworkspace" || n === "createworkspacev2" ||
                n === "destroyworkspace" || n === "destroyworkspacev2" ||
                n === "moveworkspace" || n === "moveworkspacev2" ||
                n === "activelayout" || n === "monitoradded" || n === "monitorremoved") {
                if (!wsProc.running) wsProc.running = true
                else wsRefreshPending = true
            }
        }
    }
    property bool wsRefreshPending: false

    // --- Timers & Processes ---
    // 1. Workspaces (Per-monitor active workspace) & Keymap
    Process {
        id: wsProc
        command: ["bash", "-c", "hyprctl -j monitors 2>/dev/null; echo '==='; hyprctl -j workspaces 2>/dev/null; echo '==='; $HOME/.local/bin/kb-layout 2>/dev/null || echo 'US'"]
        onExited: {
            if (barWin.wsRefreshPending) {
                barWin.wsRefreshPending = false
                wsProc.running = true
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parts = text.split("===")
                    if (parts.length >= 3) {
                        const mons = JSON.parse(parts[0].trim())
                        const ws = JSON.parse(parts[1].trim())
                        ws.sort((a, b) => a.id - b.id)
                        barWin.rawWorkspaces = ws

                        const scrName = barWin.screenName || ((barWin.screen && barWin.screen.name) ? barWin.screen.name : "")
                        const thisMon = mons.find(m => m.name === scrName)
                        if (thisMon && thisMon.activeWorkspace) {
                            barWin.activeWsId = thisMon.activeWorkspace.id
                        }

                        const km = parts[2].trim()
                        if (km.length > 0 && km !== "null") {
                            barWin.activeKeymap = km.toUpperCase()
                        } else if (barWin.islandRoot && barWin.islandRoot.kbLayout) {
                            barWin.activeKeymap = barWin.islandRoot.kbLayout
                        }
                    }
                } catch(e) {}
            }
        }
    }

    // Gentle fallback timer (Hyprland.onRawEvent already triggers wsProc immediately on events)
    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!wsProc.running) wsProc.running = true
    }

    // Main Bar Frame
    Item {
        anchors.fill: parent
        anchors.topMargin: 5
        anchors.bottomMargin: 5
        anchors.leftMargin: 7
        anchors.rightMargin: 7

        // ═════════════════════════════════════════════════════════════════════
        // LEFT MODULES: Workspaces, System Info Group, Cava
        // ═════════════════════════════════════════════════════════════════════
        RowLayout {
            id: leftCol
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // 1. Workspaces Capsule
            Rectangle {
                id: wsBox
                implicitHeight: 30
                implicitWidth: wsRow.implicitWidth + 8
                radius: 6
                color: barWin.colBg
                border.color: Qt.rgba(0, 0, 0, 0.45)
                border.width: 1

                RowLayout {
                    id: wsRow
                    anchors.centerIn: parent
                    spacing: 3

                    Repeater {
                        model: barWin.currentScreenWorkspaces.length > 0 ? barWin.currentScreenWorkspaces : [{ id: 1 }, { id: 2 }]

                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool isFocused: modelData.id === barWin.activeWsId
                            implicitWidth: Math.max(34, wsText.implicitWidth + 18)
                            implicitHeight: 26
                            radius: 5
                            color: isFocused ? Qt.rgba(barWin.colAccent.r, barWin.colAccent.g, barWin.colAccent.b, 0.25) : (wsMouse.containsMouse ? Qt.rgba(barWin.colMuted.r, barWin.colMuted.g, barWin.colMuted.b, 0.2) : "transparent")
                            Behavior on color { ColorAnimation { duration: 180 } }
                            border.color: isFocused ? Qt.rgba(barWin.colAccent.r, barWin.colAccent.g, barWin.colAccent.b, 0.45) : "transparent"
                            border.width: 1

                            Text {
                                id: wsText
                                anchors.centerIn: parent
                                text: modelData.id
                                color: isFocused ? barWin.colAccent : barWin.colFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: wsMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    barWin.activeWsId = modelData.id
                                    barWin.switchWorkspace(modelData.id)
                                    if (!wsProc.running) wsProc.running = true
                                }
                            }
                        }
                    }
                }

                WheelHandler {
                    onWheel: event => {
                        if (event.angleDelta.y > 0) {
                            barWin.activeWsId = Math.max(1, barWin.activeWsId - 1)
                            barWin.switchWorkspace("m-1")
                        } else if (event.angleDelta.y < 0) {
                            barWin.activeWsId = barWin.activeWsId + 1
                            barWin.switchWorkspace("m+1")
                        }
                        if (!wsProc.running) wsProc.running = true
                    }
                }
            }

            // 2. System Info Group (CPU, Memory, CPU Temp, GPU Temp)
            Rectangle {
                id: sysBox
                implicitHeight: 30
                implicitWidth: sysRow.implicitWidth
                radius: 6
                color: barWin.colBg
                border.color: Qt.rgba(0, 0, 0, 0.45)
                border.width: 1

                scale: (cpuMouse.pressed || memMouse.pressed || cpuTempMouse.pressed || gpuTempMouse.pressed) ? 0.93 : 1.0
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                RowLayout {
                    id: sysRow
                    anchors.centerIn: parent
                    spacing: 0

                    // CPU
                    Rectangle {
                        implicitHeight: 30
                        implicitWidth: cpuRow.implicitWidth + 24
                        radius: 6
                        color: cpuMouse.containsMouse ? Qt.rgba(barWin.colMuted.r, barWin.colMuted.g, barWin.colMuted.b, 0.22) : "transparent"
                        Behavior on color { ColorAnimation { duration: 180 } }

                        RowLayout {
                            id: cpuRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "󰍛"
                                color: barWin.colCpu
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                            }
                            Text {
                                text: barWin.cpuBar + " " + barWin.cpuPercent + "%"
                                color: barWin.colCpu
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            id: cpuMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) barWin.run("kitty -e htop")
                                else barWin.toggleSysMon()
                            }
                        }
                    }

                    // Divider (1px solid @color8)
                    Rectangle { implicitWidth: 1; implicitHeight: 30; color: barWin.colMuted; opacity: 0.35 }

                    // Memory
                    Rectangle {
                        implicitHeight: 30
                        implicitWidth: memRow.implicitWidth + 24
                        radius: 6
                        color: memMouse.containsMouse ? Qt.rgba(barWin.colMuted.r, barWin.colMuted.g, barWin.colMuted.b, 0.22) : "transparent"
                        Behavior on color { ColorAnimation { duration: 180 } }

                        RowLayout {
                            id: memRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "󰘚"
                                color: barWin.colRam
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                            }
                            Text {
                                text: barWin.memStr
                                color: barWin.colRam
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            id: memMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) barWin.run("kitty -e htop")
                                else barWin.toggleSysMon()
                            }
                        }
                    }

                    // Divider
                    Rectangle { implicitWidth: 1; implicitHeight: 30; color: barWin.colMuted; opacity: 0.35 }

                    // CPU Temp
                    Rectangle {
                        implicitHeight: 30
                        implicitWidth: cpuTempRow.implicitWidth + 24
                        radius: 6
                        color: cpuTempMouse.containsMouse ? Qt.rgba(barWin.colMuted.r, barWin.colMuted.g, barWin.colMuted.b, 0.22) : "transparent"
                        Behavior on color { ColorAnimation { duration: 180 } }

                        RowLayout {
                            id: cpuTempRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: barWin.cpuTempStr
                                color: barWin.colCpuTemp
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            id: cpuTempMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) barWin.run("kitty -e htop")
                                else barWin.toggleSysMon()
                            }
                        }
                    }

                    // Divider
                    Rectangle { implicitWidth: 1; implicitHeight: 30; color: barWin.colMuted; opacity: 0.35 }

                    // GPU Temp
                    Rectangle {
                        implicitHeight: 30
                        implicitWidth: gpuTempRow.implicitWidth + 24
                        radius: 6
                        color: gpuTempMouse.containsMouse ? Qt.rgba(barWin.colMuted.r, barWin.colMuted.g, barWin.colMuted.b, 0.22) : "transparent"
                        Behavior on color { ColorAnimation { duration: 180 } }

                        RowLayout {
                            id: gpuTempRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: barWin.gpuTempStr
                                color: barWin.colGpuTemp
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            id: gpuTempMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) barWin.run("kitty -e htop")
                                else barWin.toggleSysMon()
                            }
                        }
                    }
                }
            }

            // 3. Cava Visualizer Capsule
            Rectangle {
                implicitHeight: 30
                implicitWidth: cavaLbl.implicitWidth + 24
                radius: 6
                color: barWin.colBg
                border.color: Qt.rgba(0, 0, 0, 0.45)
                border.width: 1

                Text {
                    id: cavaLbl
                    anchors.centerIn: parent
                    text: barWin.cavaBars
                    color: barWin.colCava
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    font.bold: true
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // RIGHT MODULES: Language, Status Group (BT, WiFi, Tray, Audio, Bri, Bat)
        // ═════════════════════════════════════════════════════════════════════
        RowLayout {
            id: rightCol
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // 1. Language Capsule
            Rectangle {
                implicitHeight: 30
                implicitWidth: langContent.implicitWidth + 24
                radius: 6
                color: barWin.colBg
                border.color: Qt.rgba(0, 0, 0, 0.45)
                border.width: 1

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: langMouse.containsMouse ? Qt.rgba(barWin.colMuted.r, barWin.colMuted.g, barWin.colMuted.b, 0.22) : "transparent"
                    Behavior on color { ColorAnimation { duration: 180 } }
                }

                RowLayout {
                    id: langContent
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: "󰌌"
                        color: barWin.colLang
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }
                    Text {
                        text: barWin.activeKeymap
                        color: barWin.colLang
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                }

                MouseArea {
                    id: langMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: function(mouse) {
                        let scrName = (barWin.screen && barWin.screen.name) ? barWin.screen.name : ""
                        if (mouse.button === Qt.RightButton) {
                            barWin.run("$HOME/.local/bin/notch-language-helper switch 2>/dev/null || $HOME/.local/bin/toggle-keyboard-layout 2>/dev/null || hyprctl switchxkblayout all next")
                            if (!wsProc.running) wsProc.running = true
                        } else {
                            if (barWin.islandRoot && typeof barWin.islandRoot.toggleLanguage === "function") {
                                barWin.islandRoot.toggleLanguage(scrName)
                            } else {
                                barWin.run("quickshell ipc -p $HOME/.config/quickshell/waybar-island/shell.qml --any-display call island toggleLanguage '" + scrName + "' || quickshell ipc -p $HOME/.config/quickshell/waybar-island/shell.qml --any-display call island openLanguage '" + scrName + "'")
                            }
                        }
                    }
                }
            }

            // 2. Status Group Capsule (Bluetooth, WiFi, Tray Apps, Audio, Brightness, Battery)
            Rectangle {
                id: statusBox
                implicitHeight: 30
                implicitWidth: statusGroupRow.implicitWidth
                radius: 6
                color: barWin.colBg
                border.color: Qt.rgba(0, 0, 0, 0.45)
                border.width: 1

                RowLayout {
                    id: statusGroupRow
                    anchors.centerIn: parent
                    spacing: 0

                    // 2.1 Bluetooth (Dynamic State & Device Icon)
                    Rectangle {
                        implicitHeight: 30
                        implicitWidth: btRow.implicitWidth + 22
                        radius: 6
                        color: btMouse.containsMouse ? Qt.rgba(barWin.colMuted.r, barWin.colMuted.g, barWin.colMuted.b, 0.22) : "transparent"
                        Behavior on color { ColorAnimation { duration: 180 } }

                        RowLayout {
                            id: btRow
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: barWin.btIcon
                                color: !barWin.btPowered ? barWin.colMuted : (barWin.btConnectedCount > 0 ? barWin.colCava : barWin.colCoral)
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                            }
                            Text {
                                visible: barWin.btConnectedCount > 0
                                text: {
                                    if (barWin.btBattery >= 0) {
                                        return (barWin.btConnectedCount > 1 ? (barWin.btBattery + "% (" + barWin.btConnectedCount + ")") : (barWin.btBattery + "%"))
                                    }
                                    return barWin.btConnectedCount.toString()
                                }
                                color: barWin.colCava
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            id: btMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    barWin.run("blueman-manager")
                                } else {
                                    const scrName = (barWin.screen && barWin.screen.name) ? barWin.screen.name : ""
                                    if (barWin.islandRoot && typeof barWin.islandRoot.toggleBluetooth === "function") {
                                        barWin.islandRoot.toggleBluetooth(scrName)
                                    } else {
                                        barWin.run("quickshell ipc -p $HOME/.config/quickshell/waybar-island/shell.qml --any-display call island toggleBluetooth '" + scrName + "' || quickshell ipc -p $HOME/.config/quickshell/waybar-island/shell.qml --any-display call island openBluetooth '" + scrName + "'")
                                    }
                                }
                            }
                        }
                    }

                    // Divider
                    Rectangle { implicitWidth: 1; implicitHeight: 30; color: barWin.colMuted; opacity: 0.35 }

                    // 2.2 WiFi / Network (Dynamic Signal & State Icons)
                    Rectangle {
                        implicitHeight: 30
                        implicitWidth: 32
                        radius: 6
                        color: wifiMouse.containsMouse ? Qt.rgba(barWin.colMuted.r, barWin.colMuted.g, barWin.colMuted.b, 0.22) : "transparent"
                        Behavior on color { ColorAnimation { duration: 180 } }

                        Text {
                            anchors.centerIn: parent
                            text: barWin.netIcon
                            color: (!barWin.isWifiConnected && !barWin.isEthernet) ? barWin.colCpu : (barWin.isEthernet ? barWin.colRam : barWin.colFg)
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: wifiMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    barWin.run("nm-connection-editor")
                                } else {
                                    barWin.run("$HOME/.local/bin/rofi-wifi-menu 2>/dev/null || nm-connection-editor")
                                }
                            }
                        }
                    }

                    // 2.3 Other System Tray Apps (Disabled by default so background apps like Telegram don't clutter the bar)
                    Repeater {
                        model: barWin.showTrayApps ? SystemTray.items.values : []

                        delegate: Rectangle {
                            required property var modelData
                            // Skip nm-applet since WiFi is already rendered above
                            readonly property bool isNetworkApplet: (modelData && ((modelData.id && modelData.id.indexOf("nm-applet") !== -1) || (modelData.title && modelData.title.indexOf("Network") !== -1)))
                            readonly property bool isSymbolic: {
                                if (!modelData || !modelData.icon) return false
                                const ic = modelData.icon.toLowerCase()
                                return ic.indexOf("symbolic") !== -1 || ic.indexOf("-panel") !== -1 || ic.indexOf("status") !== -1 || ic.indexOf("telegram") !== -1
                            }
                            visible: barWin.showTrayApps && !isNetworkApplet
                            implicitWidth: visible ? 26 : 0
                            implicitHeight: 30
                            radius: 6
                            color: trayAppMouse.containsMouse ? Qt.rgba(barWin.colMuted.r, barWin.colMuted.g, barWin.colMuted.b, 0.22) : "transparent"
                            Behavior on color { ColorAnimation { duration: 180 } }

                            Image {
                                id: trayAppImg
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                sourceSize.width: 16
                                sourceSize.height: 16
                                source: (modelData && modelData.icon) ? modelData.icon : ""
                                fillMode: Image.PreserveAspectFit
                                visible: !isSymbolic
                            }

                            ColorOverlay {
                                anchors.fill: trayAppImg
                                source: trayAppImg
                                color: barWin.colFg
                                visible: isSymbolic
                            }

                            MouseArea {
                                id: trayAppMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        if (modelData && modelData.secondaryActivate) modelData.secondaryActivate()
                                        else if (modelData && modelData.activate) modelData.activate()
                                    } else {
                                        if (modelData && modelData.activate) modelData.activate()
                                    }
                                }
                            }
                        }
                    }

                    // Divider
                    Rectangle { implicitWidth: 1; implicitHeight: 30; color: barWin.colMuted; opacity: 0.35 }

                    // 2.4 Audio Volume (Headphones / Speaker / Mute)
                    Rectangle {
                        implicitHeight: 30
                        implicitWidth: volRow.implicitWidth + 24
                        radius: 6
                        color: volMouse.containsMouse ? Qt.rgba(barWin.colMuted.r, barWin.colMuted.g, barWin.colMuted.b, 0.22) : "transparent"
                        Behavior on color { ColorAnimation { duration: 180 } }

                        RowLayout {
                            id: volRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: barWin.volMuted ? "󰝟" : (barWin.isHeadphones ? "󰋋" : (barWin.volPercent > 50 ? "󰕾" : "󰕿"))
                                color: barWin.volMuted ? barWin.colMuted : barWin.colAudio
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                            }
                            Text {
                                text: barWin.volPercent + "%"
                                color: barWin.volMuted ? barWin.colMuted : barWin.colAudio
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            id: volMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    barWin.run("pavucontrol")
                                } else {
                                    if (barWin.islandRoot) barWin.islandRoot.barVolMuted = !barWin.volMuted
                                    barWin.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
                                    if (barWin.islandRoot) barWin.islandRoot.refreshBarFast()
                                }
                            }
                            onDoubleClicked: barWin.run("pavucontrol")
                        }

                        WheelHandler {
                            onWheel: event => {
                                if (event.angleDelta.y > 0) {
                                    if (barWin.islandRoot) {
                                        barWin.islandRoot.barVolPercent = Math.min(150, barWin.volPercent + 2)
                                        barWin.islandRoot.barVolMuted = false
                                    }
                                    barWin.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 2%+")
                                } else if (event.angleDelta.y < 0) {
                                    if (barWin.islandRoot) barWin.islandRoot.barVolPercent = Math.max(0, barWin.volPercent - 2)
                                    barWin.run("wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-")
                                }
                                if (barWin.islandRoot) barWin.islandRoot.refreshBarFast()
                            }
                        }
                    }

                    // Divider
                    Rectangle { implicitWidth: 1; implicitHeight: 30; color: barWin.colMuted; opacity: 0.35 }

                    // 2.5 Backlight / Brightness
                    Rectangle {
                        implicitHeight: 30
                        implicitWidth: briRow.implicitWidth + 24
                        radius: 6
                        color: briMouse.containsMouse ? Qt.rgba(barWin.colMuted.r, barWin.colMuted.g, barWin.colMuted.b, 0.22) : "transparent"
                        Behavior on color { ColorAnimation { duration: 180 } }

                        RowLayout {
                            id: briRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: barWin.brightnessPercent > 60 ? "󰃠" : (barWin.brightnessPercent > 25 ? "󰃟" : "󰃞")
                                color: barWin.colBacklight
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                            }
                            Text {
                                text: barWin.brightnessPercent + "%"
                                color: barWin.colBacklight
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            id: briMouse
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        WheelHandler {
                            onWheel: event => {
                                if (event.angleDelta.y > 0) {
                                    if (barWin.islandRoot) barWin.islandRoot.barBrightnessPercent = Math.min(100, barWin.brightnessPercent + 2)
                                    barWin.run("brightnessctl set 2%+")
                                } else if (event.angleDelta.y < 0) {
                                    if (barWin.islandRoot) barWin.islandRoot.barBrightnessPercent = Math.max(1, barWin.brightnessPercent - 2)
                                    barWin.run("brightnessctl set 2%-")
                                }
                                if (barWin.islandRoot) barWin.islandRoot.refreshBarFast()
                            }
                        }
                    }

                    // Divider
                    Rectangle { implicitWidth: 1; implicitHeight: 30; color: barWin.colMuted; opacity: 0.35 }

                    // 2.6 Battery / Desktop Power
                    Rectangle {
                        implicitHeight: 30
                        implicitWidth: batRow.implicitWidth + 24
                        radius: 6
                        color: batMouse.containsMouse ? Qt.rgba(barWin.colMuted.r, barWin.colMuted.g, barWin.colMuted.b, 0.22) : "transparent"
                        Behavior on color { ColorAnimation { duration: 180 } }

                        RowLayout {
                            id: batRow
                            anchors.centerIn: parent
                            spacing: barWin.hasBattery ? 6 : 0
                            Text {
                                text: !barWin.hasBattery ? "󰚥" : barWin.batIcon
                                color: !barWin.hasBattery ? barWin.colBattery : ((barWin.batCharging || barWin.batPlugged) ? barWin.colRam : (barWin.batPercent <= 15 ? barWin.colCpu : barWin.colBattery))
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                            }
                            Text {
                                visible: barWin.hasBattery
                                text: (barWin.batDual && barWin.batDetail) ? barWin.batDetail : (barWin.batPercent + "%")
                                color: (barWin.batCharging || barWin.batPlugged) ? barWin.colRam : (barWin.batPercent <= 15 ? barWin.colCpu : barWin.colBattery)
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: barWin.batDual ? 11 : 13
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            id: batMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const scrName = (barWin.screen && barWin.screen.name) ? barWin.screen.name : ""
                                barWin.run("quickshell ipc -p $HOME/.config/quickshell/waybar-island/shell.qml --any-display call island toggleBattery '" + scrName + "' || quickshell ipc -p $HOME/.config/quickshell/waybar-island/shell.qml --any-display call island toggleSysMon '" + scrName + "' || true")
                            }
                        }
                    }
                }
            }
        }
    }
}
