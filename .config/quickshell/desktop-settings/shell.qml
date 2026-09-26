import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import Quickshell
import Quickshell.Io

ShellRoot {
    id: appRoot

    // Dynamic pywal colors with robust fallbacks
    property color colBg: "#161722"
    property color colSurface: "#1e2130"
    property color colCard: "#25293d"
    property color colHover: "#2d324b"
    property color colAccent: "#7aa2f7"
    property color colFg: "#c0caf5"
    property color colMuted: "#7982a9"
    property color colBorder: Qt.rgba(colFg.r, colFg.g, colFg.b, 0.12)
    property color colSuccess: "#9ece6a"
    property color colDanger: "#f7768e"

    // Load pywal colors
    FileView {
        id: walColorFile
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        onLoaded: {
            try {
                const data = JSON.parse(text())
                if (data.special && data.special.background) {
                    appRoot.colBg = data.special.background
                }
                if (data.special && data.special.foreground) {
                    appRoot.colFg = data.special.foreground
                }
                if (data.colors && data.colors.color4) {
                    appRoot.colAccent = data.colors.color4
                }
                if (data.colors && data.colors.color0) {
                    appRoot.colSurface = Qt.lighter(data.colors.color0, 1.15)
                    appRoot.colCard = Qt.lighter(data.colors.color0, 1.3)
                    appRoot.colHover = Qt.lighter(data.colors.color0, 1.45)
                }
            } catch(e) {}
        }
    }

    IpcHandler {
        target: "settingsApp"
        function open(pageName: string): string {
            settingsWin.visible = true
            settingsWin.requestActivate()
            if (pageName && pageName.length > 0) {
                const map = {
                    "wifi": 0, "network": 0,
                    "bluetooth": 1, "bt": 1,
                    "audio": 2, "sound": 2,
                    "display": 3, "monitors": 3, "brightness": 3,
                    "appearance": 4, "theme": 4,
                    "wallpaper": 5, "wallpapers": 5,
                    "hyprland": 6, "compositor": 6,
                    "island": 7, "bar": 7,
                    "dock": 8,
                    "about": 9, "system": 9
                }
                const idx = map[pageName.toLowerCase()]
                if (idx !== undefined) {
                    settingsWin.selectedTab = idx
                }
            }
            return "opened"
        }
        function toggle(): string {
            settingsWin.visible = !settingsWin.visible
            if (settingsWin.visible) settingsWin.requestActivate()
            return settingsWin.visible ? "visible" : "hidden"
        }
        function close(): string {
            settingsWin.visible = false
            return "closed"
        }
    }

    Window {
        id: settingsWin
        title: "Desktop Settings"
        width: 1120
        height: 720
        minimumWidth: 920
        minimumHeight: 600
        visible: true
        color: "transparent"
        flags: Qt.Window | Qt.FramelessWindowHint

        property int selectedTab: 0
        property bool sidebarCollapsed: false

        // State Data
        property var sysInfo: ({})
        property var wifiData: ({ enabled: true, connected: false, ssid: "", signal: 0, ip: "", networks: [] })
        property var btData: ({ powered: true, discoverable: false, devices: [] })
        property var audioData: ({ sink_name: "", sink_vol: 50, sink_muted: false, source_name: "", source_vol: 50, source_muted: false })
        property var displayData: ({ monitors: [], brightness: 50 })
        property var wpData: ({ current: "", total: 0, wallpapers: [] })
        property var hyprData: ({ anim: true, blur: true, shadow: true, rounding: 10, gaps: 10, perf: false })
        property string wpFilter: ""

        // Process runners
        Process {
            id: sysInfoProc
            command: ["bash", "-c", "$HOME/.local/bin/desktop-settings-helper system-info"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try { settingsWin.sysInfo = JSON.parse(text.trim()) } catch(e) {}
                }
            }
        }

        Process {
            id: wifiProc
            command: ["bash", "-c", "$HOME/.local/bin/desktop-settings-helper wifi-status"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try { settingsWin.wifiData = JSON.parse(text.trim()) } catch(e) {}
                }
            }
        }

        Process {
            id: btProc
            command: ["bash", "-c", "$HOME/.local/bin/desktop-settings-helper bt-status"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try { settingsWin.btData = JSON.parse(text.trim()) } catch(e) {}
                }
            }
        }

        Process {
            id: audioProc
            command: ["bash", "-c", "$HOME/.local/bin/desktop-settings-helper audio-status"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try { settingsWin.audioData = JSON.parse(text.trim()) } catch(e) {}
                }
            }
        }

        Process {
            id: displayProc
            command: ["bash", "-c", "$HOME/.local/bin/desktop-settings-helper display-status"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try { settingsWin.displayData = JSON.parse(text.trim()) } catch(e) {}
                }
            }
        }

        Process {
            id: wpProc
            command: ["bash", "-c", "$HOME/.local/bin/desktop-settings-helper wallpapers 36 0"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try { settingsWin.wpData = JSON.parse(text.trim()) } catch(e) {}
                }
            }
        }

        Process {
            id: hyprProc
            command: ["bash", "-c", "$HOME/.local/bin/notch-hypr-helper status"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try { settingsWin.hyprData = JSON.parse(text.trim()) } catch(e) {}
                }
            }
        }

        function refreshActiveTab() {
            if (selectedTab === 0) wifiProc.running = true
            else if (selectedTab === 1) btProc.running = true
            else if (selectedTab === 2) audioProc.running = true
            else if (selectedTab === 3) displayProc.running = true
            else if (selectedTab === 4) walColorFile.reload()
            else if (selectedTab === 5) wpProc.running = true
            else if (selectedTab === 6) hyprProc.running = true
            else if (selectedTab === 9) sysInfoProc.running = true
        }

        function refreshAll() {
            wifiProc.running = true
            btProc.running = true
            audioProc.running = true
            displayProc.running = true
            wpProc.running = true
            hyprProc.running = true
            sysInfoProc.running = true
        }

        Component.onCompleted: {
            refreshAll()
        }

        onSelectedTabChanged: {
            refreshActiveTab()
        }

        // Window Container
        Rectangle {
            id: mainContainer
            anchors.fill: parent
            radius: 18
            color: appRoot.colBg
            border.color: appRoot.colBorder
            border.width: 1
            clip: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Custom Header / Titlebar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    color: appRoot.colSurface
                    border.color: appRoot.colBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12

                        // Window Drag Area
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            RowLayout {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                spacing: 10

                                Text {
                                    text: "󰒓"
                                    color: appRoot.colAccent
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 18
                                }

                                Text {
                                    text: "Desktop Settings"
                                    color: appRoot.colFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                }

                                Rectangle {
                                    width: 1
                                    height: 16
                                    color: appRoot.colBorder
                                }

                                Text {
                                    text: "Arch Linux | Hyprland"
                                    color: appRoot.colMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onPressed: settingsWin.startSystemMove()
                            }
                        }

                        // Refresh Button
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 8
                            color: refreshMouse.containsMouse ? appRoot.colHover : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "󰑐"
                                color: appRoot.colFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                            }
                            MouseArea {
                                id: refreshMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settingsWin.refreshAll()
                            }
                        }

                        // Close Button
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 8
                            color: closeMouse.containsMouse ? appRoot.colDanger : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                color: closeMouse.containsMouse ? "#ffffff" : appRoot.colFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                            }
                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settingsWin.visible = false
                            }
                        }
                    }
                }

                // Main Content Body (Sidebar + Page Stack)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    // Left Navigation Sidebar
                    Rectangle {
                        id: sidebar
                        Layout.fillHeight: true
                        Layout.preferredWidth: settingsWin.sidebarCollapsed ? 68 : 240
                        color: appRoot.colSurface
                        border.color: appRoot.colBorder
                        border.width: 1

                        Behavior on Layout.preferredWidth {
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            // Toggle Collapse Button
                            Rectangle {
                                Layout.fillWidth: true
                                height: 38
                                radius: 10
                                color: toggleCollapseMouse.containsMouse ? appRoot.colHover : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 12

                                    Text {
                                        text: settingsWin.sidebarCollapsed ? "󰅂" : "󰅁"
                                        color: appRoot.colAccent
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 16
                                    }

                                    Text {
                                        visible: !settingsWin.sidebarCollapsed
                                        text: "Navigation"
                                        color: appRoot.colMuted
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                        Layout.fillWidth: true
                                    }
                                }

                                MouseArea {
                                    id: toggleCollapseMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: settingsWin.sidebarCollapsed = !settingsWin.sidebarCollapsed
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: appRoot.colBorder
                            }

                            // Navigation Items List
                            ListView {
                                id: navList
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 4
                                clip: true

                                model: [
                                    { id: 0, label: "Network & Wi-Fi", icon: "󰤨" },
                                    { id: 1, label: "Bluetooth", icon: "󰂯" },
                                    { id: 2, label: "Sound & Audio", icon: "󰕾" },
                                    { id: 3, label: "Display & Brightness", icon: "󰍹" },
                                    { id: 4, label: "Appearance & Themes", icon: "󰏘" },
                                    { id: 5, label: "Wallpapers", icon: "󰸉" },
                                    { id: 6, label: "Hyprland Compositor", icon: "󰄛" },
                                    { id: 7, label: "Dynamic Island & Bar", icon: "󰐍" },
                                    { id: 8, label: "Rust Dock", icon: "󰀻" },
                                    { id: 9, label: "System & About", icon: "󰋼" }
                                ]

                                delegate: Rectangle {
                                    width: navList.width
                                    height: 42
                                    radius: 10
                                    color: settingsWin.selectedTab === modelData.id
                                           ? appRoot.colAccent
                                           : (itemMouse.containsMouse ? appRoot.colHover : "transparent")

                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 12
                                        spacing: 12

                                        Text {
                                            text: modelData.icon
                                            color: settingsWin.selectedTab === modelData.id ? appRoot.colBg : appRoot.colFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 17
                                        }

                                        Text {
                                            visible: !settingsWin.sidebarCollapsed
                                            text: modelData.label
                                            color: settingsWin.selectedTab === modelData.id ? appRoot.colBg : appRoot.colFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 12
                                            font.weight: settingsWin.selectedTab === modelData.id ? Font.Bold : Font.Normal
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        id: itemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: settingsWin.selectedTab = modelData.id
                                    }
                                }
                            }
                        }
                    }

                    // Content Area (Stack of Pages)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: appRoot.colBg

                        StackLayout {
                            anchors.fill: parent
                            anchors.margins: 24
                            currentIndex: settingsWin.selectedTab

                            // Page 0: Network & Wi-Fi
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                contentWidth: availableWidth
                                clip: true
                                ColumnLayout {
                                    width: settingsWin.width - (settingsWin.sidebarCollapsed ? 116 : 288)
                                    spacing: 16

                                    // Header
                                    RowLayout {
                                        Layout.fillWidth: true
                                        ColumnLayout {
                                            spacing: 4
                                            Text { text: "Network & Wi-Fi"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22; font.weight: Font.Bold }
                                            Text { text: "Manage Wi-Fi interfaces, connections, and access points"; color: appRoot.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
                                        }
                                        Item { Layout.fillWidth: true }
                                        // Wi-Fi Power Switch
                                        Rectangle {
                                            width: 100; height: 38; radius: 19
                                            color: settingsWin.wifiData.enabled ? appRoot.colAccent : appRoot.colSurface
                                            border.color: appRoot.colBorder; border.width: 1
                                            RowLayout {
                                                anchors.centerIn: parent; spacing: 8
                                                Text { text: settingsWin.wifiData.enabled ? "󰤨" : "󰤮"; color: settingsWin.wifiData.enabled ? appRoot.colBg : appRoot.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
                                                Text { text: settingsWin.wifiData.enabled ? "Enabled" : "Disabled"; color: settingsWin.wifiData.enabled ? appRoot.colBg : appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                                            }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/desktop-settings-helper wifi-toggle"])
                                                    wifiTimer.restart()
                                                }
                                            }
                                        }
                                    }

                                    // Active Connection Card
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 84
                                        radius: 14
                                        color: appRoot.colSurface
                                        border.color: appRoot.colBorder; border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 18
                                            spacing: 16

                                            Rectangle {
                                                width: 48; height: 48; radius: 24
                                                color: settingsWin.wifiData.connected ? appRoot.colAccent : appRoot.colCard
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: settingsWin.wifiData.connected ? "󰤨" : "󰤮"
                                                    color: settingsWin.wifiData.connected ? appRoot.colBg : appRoot.colMuted
                                                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true; spacing: 3
                                                Text {
                                                    text: settingsWin.wifiData.connected ? settingsWin.wifiData.ssid : "Not Connected"
                                                    color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15; font.weight: Font.Bold
                                                }
                                                Text {
                                                    text: settingsWin.wifiData.connected
                                                          ? ("IPv4: " + (settingsWin.wifiData.ip || "Obtaining...") + " | Signal: " + settingsWin.wifiData.signal + "%")
                                                          : "Select a wireless network below to connect"
                                                    color: appRoot.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                                                }
                                            }

                                            Rectangle {
                                                width: 90; height: 34; radius: 8
                                                color: appRoot.colCard
                                                border.color: appRoot.colBorder; border.width: 1
                                                Text { anchors.centerIn: parent; text: "󰑐 Rescan"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                                                MouseArea {
                                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        Quickshell.execDetached(["bash", "-c", "nmcli dev wifi rescan"])
                                                        wifiTimer.restart()
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Available Networks List Card
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 380
                                        radius: 14
                                        color: appRoot.colSurface
                                        border.color: appRoot.colBorder; border.width: 1

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 14
                                            spacing: 10

                                            Text {
                                                text: "Available Wireless Networks"
                                                color: appRoot.colFg
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 13
                                                font.weight: Font.Bold
                                            }

                                            ListView {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                clip: true
                                                spacing: 6
                                                model: settingsWin.wifiData.networks || []

                                                delegate: Rectangle {
                                                    width: parent ? parent.width : 0
                                                    height: 44
                                                    radius: 10
                                                    color: modelData.connected ? Qt.rgba(appRoot.colAccent.r, appRoot.colAccent.g, appRoot.colAccent.b, 0.15) : appRoot.colCard
                                                    border.color: modelData.connected ? appRoot.colAccent : appRoot.colBorder
                                                    border.width: 1

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.margins: 10
                                                        spacing: 12

                                                        Text {
                                                            text: modelData.signal > 75 ? "󰤨" : (modelData.signal > 40 ? "󰤥" : "󰤢")
                                                            color: modelData.connected ? appRoot.colAccent : appRoot.colFg
                                                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                                                        }

                                                        Text {
                                                            text: modelData.ssid
                                                            color: appRoot.colFg
                                                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.weight: Font.Bold
                                                            Layout.fillWidth: true
                                                            elide: Text.ElideRight
                                                        }

                                                        Rectangle {
                                                            width: 50; height: 22; radius: 6; color: appRoot.colSurface
                                                            Text { anchors.centerIn: parent; text: modelData.security || "WPA2"; color: appRoot.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                                                        }

                                                        Rectangle {
                                                            width: 80; height: 28; radius: 6
                                                            color: modelData.connected ? appRoot.colSuccess : appRoot.colAccent
                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: modelData.connected ? "Connected" : "Connect"
                                                                color: appRoot.colBg
                                                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold
                                                            }
                                                            MouseArea {
                                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                                onClicked: {
                                                                    if (!modelData.connected) {
                                                                        Quickshell.execDetached(["bash", "-c", "nmcli dev wifi connect '" + modelData.ssid + "'"])
                                                                        wifiTimer.restart()
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Page 1: Bluetooth
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                contentWidth: availableWidth
                                clip: true
                                ColumnLayout {
                                    width: settingsWin.width - (settingsWin.sidebarCollapsed ? 116 : 288)
                                    spacing: 16

                                    RowLayout {
                                        Layout.fillWidth: true
                                        ColumnLayout {
                                            spacing: 4
                                            Text { text: "Bluetooth"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22; font.weight: Font.Bold }
                                            Text { text: "Manage Bluetooth controllers, paired accessories, and devices"; color: appRoot.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
                                        }
                                        Item { Layout.fillWidth: true }
                                        Rectangle {
                                            width: 100; height: 38; radius: 19
                                            color: settingsWin.btData.powered ? appRoot.colAccent : appRoot.colSurface
                                            border.color: appRoot.colBorder; border.width: 1
                                            RowLayout {
                                                anchors.centerIn: parent; spacing: 8
                                                Text { text: settingsWin.btData.powered ? "󰂯" : "󰂲"; color: settingsWin.btData.powered ? appRoot.colBg : appRoot.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
                                                Text { text: settingsWin.btData.powered ? "Powered" : "Off"; color: settingsWin.btData.powered ? appRoot.colBg : appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                                            }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/desktop-settings-helper bt-toggle"])
                                                    btTimer.restart()
                                                }
                                            }
                                        }
                                    }

                                    // Paired Devices Card
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 380
                                        radius: 14
                                        color: appRoot.colSurface
                                        border.color: appRoot.colBorder; border.width: 1

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 14
                                            spacing: 10

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text { text: "Paired & Available Devices"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.weight: Font.Bold }
                                                Item { Layout.fillWidth: true }
                                                Rectangle {
                                                    width: 90; height: 28; radius: 6; color: appRoot.colCard; border.color: appRoot.colBorder; border.width: 1
                                                    Text { anchors.centerIn: parent; text: "󰂯 Scan"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold }
                                                    MouseArea {
                                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            Quickshell.execDetached(["bash", "-c", "bluetoothctl --timeout 5 scan on &"])
                                                            btTimer.restart()
                                                        }
                                                    }
                                                }
                                            }

                                            ListView {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                clip: true
                                                spacing: 6
                                                model: settingsWin.btData.devices || []

                                                delegate: Rectangle {
                                                    width: parent ? parent.width : 0
                                                    height: 48
                                                    radius: 10
                                                    color: appRoot.colCard
                                                    border.color: modelData.connected ? appRoot.colAccent : appRoot.colBorder
                                                    border.width: 1

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.margins: 10
                                                        spacing: 12

                                                        Text {
                                                            text: modelData.icon === "audio" ? "󰋋" : "󰂯"
                                                            color: modelData.connected ? appRoot.colAccent : appRoot.colMuted
                                                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18
                                                        }

                                                        ColumnLayout {
                                                            Layout.fillWidth: true; spacing: 2
                                                            Text { text: modelData.name || modelData.mac; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.weight: Font.Bold }
                                                            Text { text: modelData.mac; color: appRoot.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                                                        }

                                                        Rectangle {
                                                            width: 80; height: 28; radius: 6
                                                            color: modelData.connected ? appRoot.colSuccess : appRoot.colAccent
                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: modelData.connected ? "Connected" : "Connect"
                                                                color: appRoot.colBg
                                                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold
                                                            }
                                                            MouseArea {
                                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                                onClicked: {
                                                                    const cmd = modelData.connected ? "bt-disconnect" : "bt-connect"
                                                                    Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/desktop-settings-helper " + cmd + " " + modelData.mac])
                                                                    btTimer.restart()
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Page 2: Sound & Audio
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                contentWidth: availableWidth
                                clip: true
                                ColumnLayout {
                                    width: settingsWin.width - (settingsWin.sidebarCollapsed ? 116 : 288)
                                    spacing: 16

                                    ColumnLayout {
                                        spacing: 4
                                        Text { text: "Sound & Audio"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22; font.weight: Font.Bold }
                                        Text { text: "Control output sinks, microphone levels, and WirePlumber audio devices"; color: appRoot.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
                                    }

                                    // Output Sink Card
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 140
                                        radius: 14
                                        color: appRoot.colSurface
                                        border.color: appRoot.colBorder; border.width: 1

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 16
                                            spacing: 12

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text { text: "󰕾 Output Device"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.weight: Font.Bold }
                                                Item { Layout.fillWidth: true }
                                                Text { text: settingsWin.audioData.sink_name || "Analog Stereo"; color: appRoot.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 }
                                            }

                                            // Slider
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 14

                                                Rectangle {
                                                    width: 36; height: 36; radius: 18
                                                    color: settingsWin.audioData.sink_muted ? appRoot.colDanger : appRoot.colCard
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: settingsWin.audioData.sink_muted ? "󰝟" : (settingsWin.audioData.sink_vol > 50 ? "󰕾" : "󰖀")
                                                        color: settingsWin.audioData.sink_muted ? "#ffffff" : appRoot.colAccent
                                                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/desktop-settings-helper audio-toggle-mute sink"])
                                                            audioTimer.restart()
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    height: 12
                                                    radius: 6
                                                    color: appRoot.colCard

                                                    Rectangle {
                                                        width: parent.width * Math.min(1.0, Math.max(0.0, settingsWin.audioData.sink_vol / 100.0))
                                                        height: parent.height
                                                        radius: 6
                                                        color: settingsWin.audioData.sink_muted ? appRoot.colMuted : appRoot.colAccent
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: mouse => {
                                                            const p = Math.max(0, Math.min(1, mouse.x / width))
                                                            const vol = Math.round(p * 100)
                                                            settingsWin.audioData.sink_vol = vol
                                                            Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/desktop-settings-helper audio-set-vol sink " + vol])
                                                        }
                                                    }
                                                }

                                                Text {
                                                    text: settingsWin.audioData.sink_vol + "%"
                                                    color: appRoot.colFg
                                                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.weight: Font.Bold
                                                    Layout.preferredWidth: 45
                                                }
                                            }
                                        }
                                    }

                                    // Input Source Card
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 140
                                        radius: 14
                                        color: appRoot.colSurface
                                        border.color: appRoot.colBorder; border.width: 1

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 16
                                            spacing: 12

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text { text: "󰍬 Input Device (Microphone)"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.weight: Font.Bold }
                                                Item { Layout.fillWidth: true }
                                                Text { text: settingsWin.audioData.source_name || "Internal Mic"; color: appRoot.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 14

                                                Rectangle {
                                                    width: 36; height: 36; radius: 18
                                                    color: settingsWin.audioData.source_muted ? appRoot.colDanger : appRoot.colCard
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: settingsWin.audioData.source_muted ? "󰍭" : "󰍬"
                                                        color: settingsWin.audioData.source_muted ? "#ffffff" : appRoot.colAccent
                                                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/desktop-settings-helper audio-toggle-mute source"])
                                                            audioTimer.restart()
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    height: 12
                                                    radius: 6
                                                    color: appRoot.colCard

                                                    Rectangle {
                                                        width: parent.width * Math.min(1.0, Math.max(0.0, settingsWin.audioData.source_vol / 100.0))
                                                        height: parent.height
                                                        radius: 6
                                                        color: settingsWin.audioData.source_muted ? appRoot.colMuted : appRoot.colAccent
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: mouse => {
                                                            const p = Math.max(0, Math.min(1, mouse.x / width))
                                                            const vol = Math.round(p * 100)
                                                            settingsWin.audioData.source_vol = vol
                                                            Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/desktop-settings-helper audio-set-vol source " + vol])
                                                        }
                                                    }
                                                }

                                                Text {
                                                    text: settingsWin.audioData.source_vol + "%"
                                                    color: appRoot.colFg
                                                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.weight: Font.Bold
                                                    Layout.preferredWidth: 45
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Page 3: Display & Brightness
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                contentWidth: availableWidth
                                clip: true
                                ColumnLayout {
                                    width: settingsWin.width - (settingsWin.sidebarCollapsed ? 116 : 288)
                                    spacing: 16

                                    ColumnLayout {
                                        spacing: 4
                                        Text { text: "Display & Brightness"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22; font.weight: Font.Bold }
                                        Text { text: "Manage connected outputs, screen resolution, refresh rate, and backlight"; color: appRoot.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
                                    }

                                    // Brightness Slider Card
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 100
                                        radius: 14
                                        color: appRoot.colSurface
                                        border.color: appRoot.colBorder; border.width: 1

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 16
                                            spacing: 10

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text { text: "󰃠 Display Backlight"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.weight: Font.Bold }
                                                Item { Layout.fillWidth: true }
                                                Text { text: settingsWin.displayData.brightness + "%"; color: appRoot.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.weight: Font.Bold }
                                            }

                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 12
                                                radius: 6
                                                color: appRoot.colCard

                                                Rectangle {
                                                    width: parent.width * Math.min(1.0, Math.max(0.0, settingsWin.displayData.brightness / 100.0))
                                                    height: parent.height
                                                    radius: 6
                                                    color: appRoot.colAccent
                                                }

                                                MouseArea {
                                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: mouse => {
                                                        const p = Math.max(0.02, Math.min(1.0, mouse.x / width))
                                                        const val = Math.round(p * 100)
                                                        settingsWin.displayData.brightness = val
                                                        Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/desktop-settings-helper display-set-brightness " + val])
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Connected Monitors Card
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 220
                                        radius: 14
                                        color: appRoot.colSurface
                                        border.color: appRoot.colBorder; border.width: 1

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 16
                                            spacing: 10

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text { text: "Active Monitors"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.weight: Font.Bold }
                                                Item { Layout.fillWidth: true }
                                                Rectangle {
                                                    width: 110; height: 28; radius: 6; color: appRoot.colCard; border.color: appRoot.colBorder; border.width: 1
                                                    Text { anchors.centerIn: parent; text: "󰍹 nwg-displays"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold }
                                                    MouseArea {
                                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                        onClicked: Quickshell.execDetached(["nwg-displays"])
                                                    }
                                                }
                                            }

                                            ListView {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                clip: true
                                                spacing: 8
                                                model: settingsWin.displayData.monitors || []

                                                delegate: Rectangle {
                                                    width: parent ? parent.width : 0
                                                    height: 52
                                                    radius: 10
                                                    color: appRoot.colCard
                                                    border.color: modelData.focused ? appRoot.colAccent : appRoot.colBorder
                                                    border.width: 1

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.margins: 12
                                                        spacing: 14

                                                        Text { text: "󰍹"; color: appRoot.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20 }
                                                        ColumnLayout {
                                                            Layout.fillWidth: true; spacing: 2
                                                            Text { text: modelData.name + (modelData.model ? (" (" + modelData.model + ")") : ""); color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.weight: Font.Bold }
                                                            Text { text: modelData.width + "x" + modelData.height + " @ " + modelData.refresh + "Hz | Scale: " + modelData.scale; color: appRoot.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 }
                                                        }
                                                        Rectangle {
                                                            width: 60; height: 22; radius: 6; color: modelData.focused ? appRoot.colAccent : appRoot.colSurface
                                                            Text { anchors.centerIn: parent; text: modelData.focused ? "Primary" : "Active"; color: modelData.focused ? appRoot.colBg : appRoot.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; font.weight: Font.Bold }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Page 4: Appearance & Themes
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                contentWidth: availableWidth
                                clip: true
                                ColumnLayout {
                                    width: settingsWin.width - (settingsWin.sidebarCollapsed ? 116 : 288)
                                    spacing: 16

                                    ColumnLayout {
                                        spacing: 4
                                        Text { text: "Appearance & Themes"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22; font.weight: Font.Bold }
                                        Text { text: "Customize colors, dark/light themes, and Pywal desktop palettes"; color: appRoot.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
                                    }

                                    // Palette Overview Card
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 170
                                        radius: 14
                                        color: appRoot.colSurface
                                        border.color: appRoot.colBorder; border.width: 1

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 16
                                            spacing: 12

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text { text: "Active Pywal Color Swatches"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.weight: Font.Bold }
                                                Item { Layout.fillWidth: true }
                                                Rectangle {
                                                    width: 120; height: 30; radius: 6; color: appRoot.colAccent
                                                    Text { anchors.centerIn: parent; text: "󰑐 Sync Colors"; color: appRoot.colBg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                                                    MouseArea {
                                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/modern-pywal-sync"])
                                                            colorSyncTimer.restart()
                                                        }
                                                    }
                                                }
                                            }

                                            // Swatch Row
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8
                                                Repeater {
                                                    model: ["#1e2130", "#879DC2", "#9AAEC9", "#A8B9D2", "#C8B4C7", "#B2C3DA", "#B7CAE2", "#dde2ea", "#7aa2f7", "#9ece6a", "#f7768e"]
                                                    Rectangle {
                                                        Layout.fillWidth: true
                                                        height: 48
                                                        radius: 8
                                                        color: modelData
                                                        border.color: appRoot.colBorder; border.width: 1
                                                        Text { anchors.bottom: parent.bottom; anchors.bottomMargin: 4; anchors.horizontalCenter: parent.horizontalCenter; text: modelData; color: "#000000"; font.pixelSize: 8; opacity: 0.6 }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Page 5: Wallpapers
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                contentWidth: availableWidth
                                clip: true
                                ColumnLayout {
                                    width: settingsWin.width - (settingsWin.sidebarCollapsed ? 116 : 288)
                                    spacing: 16

                                    RowLayout {
                                        Layout.fillWidth: true
                                        ColumnLayout {
                                            spacing: 4
                                            Text { text: "Wallpapers"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22; font.weight: Font.Bold }
                                            Text { text: "Browse and instantly set wallpapers from ~/Pictures/Wallpapers (" + (settingsWin.wpData.total || 0) + " total)"; color: appRoot.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
                                        }
                                        Item { Layout.fillWidth: true }
                                        Rectangle {
                                            width: 130; height: 34; radius: 8; color: appRoot.colAccent
                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 6
                                                Text { text: "󰒝"; color: appRoot.colBg; font.family: "JetBrainsMono Nerd Font" }
                                                Text { text: "Random Wall"; color: appRoot.colBg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                                            }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    Quickshell.execDetached(["bash", "-c", "rand_wp=$(find ~/Pictures/Wallpapers -type f | shuf -n1); ~/.local/bin/setwall.sh \"$rand_wp\""])
                                                    wpTimer.restart()
                                                }
                                            }
                                        }
                                    }

                                    // Wallpaper Grid
                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 3
                                        rowSpacing: 14
                                        columnSpacing: 14

                                        Repeater {
                                            model: settingsWin.wpData.wallpapers || []

                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 140
                                                radius: 12
                                                color: appRoot.colSurface
                                                border.color: settingsWin.wpData.current === modelData ? appRoot.colAccent : appRoot.colBorder
                                                border.width: settingsWin.wpData.current === modelData ? 3 : 1
                                                clip: true

                                                Image {
                                                    anchors.fill: parent
                                                    source: "file://" + modelData
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                }

                                                Rectangle {
                                                    anchors.bottom: parent.bottom
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    height: 32
                                                    color: Qt.rgba(0, 0, 0, 0.7)

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.margins: 6
                                                        spacing: 6
                                                        Text {
                                                            text: modelData.split('/').pop()
                                                            color: "#ffffff"
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 9
                                                            Layout.fillWidth: true
                                                            elide: Text.ElideRight
                                                        }
                                                        Text {
                                                            visible: settingsWin.wpData.current === modelData
                                                            text: "󰄬 Active"
                                                            color: appRoot.colAccent
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 9
                                                            font.weight: Font.Bold
                                                        }
                                                    }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/setwall.sh '" + modelData + "'"])
                                                        settingsWin.wpData.current = modelData
                                                        wpTimer.restart()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Page 6: Hyprland Compositor
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                contentWidth: availableWidth
                                clip: true
                                ColumnLayout {
                                    width: settingsWin.width - (settingsWin.sidebarCollapsed ? 116 : 288)
                                    spacing: 16

                                    ColumnLayout {
                                        spacing: 4
                                        Text { text: "Hyprland Compositor"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22; font.weight: Font.Bold }
                                        Text { text: "Real-time compositor parameters, decoration effects, and tiling controls"; color: appRoot.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
                                    }

                                    // 4 Main Compositor Toggles
                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 2
                                        rowSpacing: 10
                                        columnSpacing: 10

                                        // Animations
                                        Rectangle {
                                            Layout.fillWidth: true; height: 60; radius: 12
                                            color: settingsWin.hyprData.anim ? appRoot.colAccent : appRoot.colSurface
                                            border.color: appRoot.colBorder; border.width: 1
                                            RowLayout {
                                                anchors.fill: parent; anchors.margins: 12; spacing: 12
                                                Text { text: "󰑮"; color: settingsWin.hyprData.anim ? appRoot.colBg : appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22 }
                                                ColumnLayout {
                                                    Layout.fillWidth: true; spacing: 2
                                                    Text { text: "Animations"; color: settingsWin.hyprData.anim ? appRoot.colBg : appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.weight: Font.Bold }
                                                    Text { text: settingsWin.hyprData.anim ? "Enabled" : "Disabled"; color: settingsWin.hyprData.anim ? Qt.rgba(appRoot.colBg.r, appRoot.colBg.g, appRoot.colBg.b, 0.8) : appRoot.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 }
                                                }
                                            }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    settingsWin.hyprData.anim = !settingsWin.hyprData.anim
                                                    Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/notch-hypr-helper set-anim " + settingsWin.hyprData.anim])
                                                }
                                            }
                                        }

                                        // Blur
                                        Rectangle {
                                            Layout.fillWidth: true; height: 60; radius: 12
                                            color: settingsWin.hyprData.blur ? appRoot.colAccent : appRoot.colSurface
                                            border.color: appRoot.colBorder; border.width: 1
                                            RowLayout {
                                                anchors.fill: parent; anchors.margins: 12; spacing: 12
                                                Text { text: "󰂵"; color: settingsWin.hyprData.blur ? appRoot.colBg : appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22 }
                                                ColumnLayout {
                                                    Layout.fillWidth: true; spacing: 2
                                                    Text { text: "Blur Effect"; color: settingsWin.hyprData.blur ? appRoot.colBg : appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.weight: Font.Bold }
                                                    Text { text: settingsWin.hyprData.blur ? "Enabled" : "Disabled"; color: settingsWin.hyprData.blur ? Qt.rgba(appRoot.colBg.r, appRoot.colBg.g, appRoot.colBg.b, 0.8) : appRoot.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 }
                                                }
                                            }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    settingsWin.hyprData.blur = !settingsWin.hyprData.blur
                                                    Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/notch-hypr-helper set-blur " + settingsWin.hyprData.blur])
                                                }
                                            }
                                        }

                                        // Shadows
                                        Rectangle {
                                            Layout.fillWidth: true; height: 60; radius: 12
                                            color: settingsWin.hyprData.shadow ? appRoot.colAccent : appRoot.colSurface
                                            border.color: appRoot.colBorder; border.width: 1
                                            RowLayout {
                                                anchors.fill: parent; anchors.margins: 12; spacing: 12
                                                Text { text: "󰞏"; color: settingsWin.hyprData.shadow ? appRoot.colBg : appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22 }
                                                ColumnLayout {
                                                    Layout.fillWidth: true; spacing: 2
                                                    Text { text: "Shadows"; color: settingsWin.hyprData.shadow ? appRoot.colBg : appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.weight: Font.Bold }
                                                    Text { text: settingsWin.hyprData.shadow ? "Enabled" : "Disabled"; color: settingsWin.hyprData.shadow ? Qt.rgba(appRoot.colBg.r, appRoot.colBg.g, appRoot.colBg.b, 0.8) : appRoot.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 }
                                                }
                                            }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    settingsWin.hyprData.shadow = !settingsWin.hyprData.shadow
                                                    Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/notch-hypr-helper set-shadow " + settingsWin.hyprData.shadow])
                                                }
                                            }
                                        }

                                        // Performance Mode
                                        Rectangle {
                                            Layout.fillWidth: true; height: 60; radius: 12
                                            color: settingsWin.hyprData.perf ? appRoot.colAccent : appRoot.colSurface
                                            border.color: appRoot.colBorder; border.width: 1
                                            RowLayout {
                                                anchors.fill: parent; anchors.margins: 12; spacing: 12
                                                Text { text: "󰓅"; color: settingsWin.hyprData.perf ? appRoot.colBg : appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22 }
                                                ColumnLayout {
                                                    Layout.fillWidth: true; spacing: 2
                                                    Text { text: "Performance"; color: settingsWin.hyprData.perf ? appRoot.colBg : appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.weight: Font.Bold }
                                                    Text { text: settingsWin.hyprData.perf ? "Max Performance" : "Balanced"; color: settingsWin.hyprData.perf ? Qt.rgba(appRoot.colBg.r, appRoot.colBg.g, appRoot.colBg.b, 0.8) : appRoot.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 }
                                                }
                                            }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    settingsWin.hyprData.perf = !settingsWin.hyprData.perf
                                                    Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/notch-hypr-helper toggle-perf"])
                                                    hyprTimer.restart()
                                                }
                                            }
                                        }
                                    }

                                    // Rounding & Gaps Controls
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 120
                                        radius: 14
                                        color: appRoot.colSurface
                                        border.color: appRoot.colBorder; border.width: 1

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 14
                                            spacing: 10

                                            // Rounding
                                            RowLayout {
                                                Layout.fillWidth: true; spacing: 10
                                                Text { text: "Rounding:"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.weight: Font.Bold; Layout.preferredWidth: 80 }
                                                Repeater {
                                                    model: [{ label: "Sharp (0px)", val: 0 }, { label: "Compact (6px)", val: 6 }, { label: "Normal (10px)", val: 10 }, { label: "Curved (16px)", val: 16 }]
                                                    Rectangle {
                                                        Layout.fillWidth: true; height: 32; radius: 8
                                                        color: settingsWin.hyprData.rounding === modelData.val ? appRoot.colAccent : appRoot.colCard
                                                        Text { anchors.centerIn: parent; text: modelData.label; color: settingsWin.hyprData.rounding === modelData.val ? appRoot.colBg : appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold }
                                                        MouseArea {
                                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                settingsWin.hyprData.rounding = modelData.val
                                                                Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/notch-hypr-helper set-rounding " + modelData.val])
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            // Gaps
                                            RowLayout {
                                                Layout.fillWidth: true; spacing: 10
                                                Text { text: "Gaps:"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.weight: Font.Bold; Layout.preferredWidth: 80 }
                                                Repeater {
                                                    model: [{ label: "0px", val: 0 }, { label: "6px", val: 6 }, { label: "10px", val: 10 }, { label: "16px", val: 16 }, { label: "24px", val: 24 }]
                                                    Rectangle {
                                                        Layout.fillWidth: true; height: 32; radius: 8
                                                        color: settingsWin.hyprData.gaps === modelData.val ? appRoot.colAccent : appRoot.colCard
                                                        Text { anchors.centerIn: parent; text: modelData.label; color: settingsWin.hyprData.gaps === modelData.val ? appRoot.colBg : appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold }
                                                        MouseArea {
                                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                settingsWin.hyprData.gaps = modelData.val
                                                                Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/notch-hypr-helper set-gaps " + modelData.val])
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Quick Hyprland Actions
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10

                                        Rectangle {
                                            Layout.fillWidth: true; height: 40; radius: 10; color: appRoot.colSurface; border.color: appRoot.colBorder; border.width: 1
                                            RowLayout {
                                                anchors.centerIn: parent; spacing: 6
                                                Text { text: "󰕰"; color: appRoot.colAccent; font.family: "JetBrainsMono Nerd Font" }
                                                Text { text: "Toggle Split Layout"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                                            }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/notch-hypr-helper toggle-split"]) }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true; height: 40; radius: 10; color: appRoot.colSurface; border.color: appRoot.colBorder; border.width: 1
                                            RowLayout {
                                                anchors.centerIn: parent; spacing: 6
                                                Text { text: "󰑐"; color: appRoot.colAccent; font.family: "JetBrainsMono Nerd Font" }
                                                Text { text: "Reload Hyprland"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                                            }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/notch-hypr-helper reload"]) }
                                        }
                                    }
                                }
                            }

                            // Page 7: Dynamic Island & Bar
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                contentWidth: availableWidth
                                clip: true
                                ColumnLayout {
                                    width: settingsWin.width - (settingsWin.sidebarCollapsed ? 116 : 288)
                                    spacing: 16

                                    ColumnLayout {
                                        spacing: 4
                                        Text { text: "Dynamic Island & Waybar"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22; font.weight: Font.Bold }
                                        Text { text: "Top notch overlay, media controls, and status bar orchestration"; color: appRoot.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
                                    }

                                    // Dynamic Island Controls Card
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 140
                                        radius: 14
                                        color: appRoot.colSurface
                                        border.color: appRoot.colBorder; border.width: 1

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 16
                                            spacing: 12

                                            Text { text: "Dynamic Island Controls"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.weight: Font.Bold }

                                            RowLayout {
                                                Layout.fillWidth: true; spacing: 10

                                                Rectangle {
                                                    Layout.fillWidth: true; height: 38; radius: 8; color: appRoot.colCard; border.color: appRoot.colBorder; border.width: 1
                                                    RowLayout {
                                                        anchors.centerIn: parent; spacing: 6
                                                        Text { text: "󰐍"; color: appRoot.colAccent; font.family: "JetBrainsMono Nerd Font" }
                                                        Text { text: "Open Island"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                        onClicked: Quickshell.execDetached(["bash", "-c", "WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1000 quickshell ipc -p ~/.config/quickshell/waybar-island/shell.qml call island openControl"])
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true; height: 38; radius: 8; color: appRoot.colCard; border.color: appRoot.colBorder; border.width: 1
                                                    RowLayout {
                                                        anchors.centerIn: parent; spacing: 6
                                                        Text { text: "󰅁"; color: appRoot.colAccent; font.family: "JetBrainsMono Nerd Font" }
                                                        Text { text: "Collapse Island"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                        onClicked: Quickshell.execDetached(["bash", "-c", "WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1000 quickshell ipc -p ~/.config/quickshell/waybar-island/shell.qml call island collapse"])
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true; height: 38; radius: 8; color: appRoot.colCard; border.color: appRoot.colBorder; border.width: 1
                                                    RowLayout {
                                                        anchors.centerIn: parent; spacing: 6
                                                        Text { text: "󰑐"; color: appRoot.colAccent; font.family: "JetBrainsMono Nerd Font" }
                                                        Text { text: "Restart Island"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                        onClicked: Quickshell.execDetached(["bash", "-c", "$HOME/.local/bin/quickshell-island &"])
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Waybar Card
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 100
                                        radius: 14
                                        color: appRoot.colSurface
                                        border.color: appRoot.colBorder; border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 16
                                            spacing: 14

                                            Text { text: "󰞅"; color: appRoot.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 24 }
                                            ColumnLayout {
                                                Layout.fillWidth: true; spacing: 2
                                                Text { text: "Waybar Status Bar"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.weight: Font.Bold }
                                                Text { text: "Reload or restart the top status bar process"; color: appRoot.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 }
                                            }
                                            Rectangle {
                                                width: 110; height: 36; radius: 8; color: appRoot.colAccent
                                                Text { anchors.centerIn: parent; text: "󰑐 Reload Bar"; color: appRoot.colBg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                                                MouseArea {
                                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: Quickshell.execDetached(["bash", "-c", "killall -SIGUSR2 waybar || waybar &"])
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Page 8: Rust Dock
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                contentWidth: availableWidth
                                clip: true
                                ColumnLayout {
                                    width: settingsWin.width - (settingsWin.sidebarCollapsed ? 116 : 288)
                                    spacing: 16

                                    ColumnLayout {
                                        spacing: 4
                                        Text { text: "Rust Dock"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22; font.weight: Font.Bold }
                                        Text { text: "Manage Wayland native rust-dock, visibility toggles, and border radius styling"; color: appRoot.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 140
                                        radius: 14
                                        color: appRoot.colSurface
                                        border.color: appRoot.colBorder; border.width: 1

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 16
                                            spacing: 12

                                            Text { text: "Dock Visibility & Process"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.weight: Font.Bold }

                                            RowLayout {
                                                Layout.fillWidth: true; spacing: 10

                                                Rectangle {
                                                    Layout.fillWidth: true; height: 38; radius: 8; color: appRoot.colCard; border.color: appRoot.colBorder; border.width: 1
                                                    RowLayout {
                                                        anchors.centerIn: parent; spacing: 6
                                                        Text { text: "󰘔"; color: appRoot.colAccent; font.family: "JetBrainsMono Nerd Font" }
                                                        Text { text: "Toggle Visibility (SIGUSR1)"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                        onClicked: Quickshell.execDetached(["bash", "-c", "pkill -SIGUSR1 rust-dock"])
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true; height: 38; radius: 8; color: appRoot.colCard; border.color: appRoot.colBorder; border.width: 1
                                                    RowLayout {
                                                        anchors.centerIn: parent; spacing: 6
                                                        Text { text: "󰑐"; color: appRoot.colAccent; font.family: "JetBrainsMono Nerd Font" }
                                                        Text { text: "Restart Dock"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                        onClicked: Quickshell.execDetached(["bash", "-c", "pkill -9 rust-dock; sleep 0.2; $HOME/.local/bin/rust-dock &"])
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Page 9: System & About
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                contentWidth: availableWidth
                                clip: true
                                ColumnLayout {
                                    width: settingsWin.width - (settingsWin.sidebarCollapsed ? 116 : 288)
                                    spacing: 16

                                    ColumnLayout {
                                        spacing: 4
                                        Text { text: "System & About"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22; font.weight: Font.Bold }
                                        Text { text: "Hardware configuration, operating system, and compositor specifications"; color: appRoot.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
                                    }

                                    // Hardware Specs Card
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 280
                                        radius: 14
                                        color: appRoot.colSurface
                                        border.color: appRoot.colBorder; border.width: 1

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 18
                                            spacing: 14

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text { text: "󰣇"; color: appRoot.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 28 }
                                                ColumnLayout {
                                                    spacing: 2
                                                    Text { text: settingsWin.sysInfo.os || "Arch Linux"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; font.weight: Font.Bold }
                                                    Text { text: "Kernel: " + (settingsWin.sysInfo.kernel || "") + " | Uptime: " + (settingsWin.sysInfo.uptime || ""); color: appRoot.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 }
                                                }
                                            }

                                            Rectangle { Layout.fillWidth: true; height: 1; color: appRoot.colBorder }

                                            GridLayout {
                                                Layout.fillWidth: true
                                                columns: 2
                                                rowSpacing: 10
                                                columnSpacing: 16

                                                ColumnLayout {
                                                    spacing: 2
                                                    Text { text: "󰻠 Processor (CPU)"; color: appRoot.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                                                    Text { text: settingsWin.sysInfo.cpu || "AMD Ryzen"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                                                }

                                                ColumnLayout {
                                                    spacing: 2
                                                    Text { text: "󰢮 Graphics (GPU)"; color: appRoot.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                                                    Text { text: settingsWin.sysInfo.gpu || "NVIDIA / AMD"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                                                }

                                                ColumnLayout {
                                                    spacing: 2
                                                    Text { text: "󰘚 Memory (RAM)"; color: appRoot.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                                                    Text { text: (settingsWin.sysInfo.ram_used || "") + " / " + (settingsWin.sysInfo.ram_total || "") + " (" + (settingsWin.sysInfo.ram_pct || 0) + "% in use)"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 }
                                                }

                                                ColumnLayout {
                                                    spacing: 2
                                                    Text { text: "󰄛 Compositor"; color: appRoot.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                                                    Text { text: settingsWin.sysInfo.hyprland || "Hyprland"; color: appRoot.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Auto Refresh Timers
        Timer { id: wifiTimer; interval: 1000; repeat: false; onTriggered: wifiProc.running = true }
        Timer { id: btTimer; interval: 1200; repeat: false; onTriggered: btProc.running = true }
        Timer { id: audioTimer; interval: 350; repeat: false; onTriggered: audioProc.running = true }
        Timer { id: hyprTimer; interval: 400; repeat: false; onTriggered: hyprProc.running = true }
        Timer { id: wpTimer; interval: 1500; repeat: false; onTriggered: wpProc.running = true }
        Timer { id: colorSyncTimer; interval: 2000; repeat: false; onTriggered: walColorFile.reload() }
    }
}
