import QtQuick
import QtQuick.Layouts

Item {
    id: settingsMenu

    required property var rootState
    required property bool shown
    required property string dockPosition
    required property real anchorCenterX
    required property real anchorCenterY
    required property real dockEdgeOffset
    required property real screenWidth
    required property real screenHeight

    signal closeRequested()

    readonly property real menuW: 248
    readonly property real menuH: menuCol.implicitHeight + 16

    readonly property real targetX: {
        if (dockPosition === "left") return dockEdgeOffset
        if (dockPosition === "right") return screenWidth - dockEdgeOffset - menuW
        return Math.max(12, Math.min(screenWidth - menuW - 12, anchorCenterX - menuW / 2))
    }
    readonly property real targetY: {
        if (dockPosition === "top") return dockEdgeOffset
        if (dockPosition === "bottom") return screenHeight - dockEdgeOffset - menuH
        return Math.max(12, Math.min(screenHeight - menuH - 12, anchorCenterY - menuH / 2))
    }

    x: targetX
    y: targetY
    width: menuW
    height: menuH
    opacity: shown ? 1.0 : 0.0
    visible: opacity > 0.01

    Behavior on opacity { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Qt.rgba(settingsMenu.rootState.colBg.r, settingsMenu.rootState.colBg.g, settingsMenu.rootState.colBg.b, 0.96)
        border.width: 1
        border.color: Qt.rgba(settingsMenu.rootState.colAccent.r, settingsMenu.rootState.colAccent.g, settingsMenu.rootState.colAccent.b, 0.28)

        ColumnLayout {
            id: menuCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            spacing: 4

            // Header
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.topMargin: 2
                Layout.bottomMargin: 4
                spacing: 8

                Text {
                    text: "󰀻"
                    color: settingsMenu.rootState.colAccent
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                }

                Text {
                    Layout.fillWidth: true
                    text: settingsMenu.rootState.t("dock_settings_title", "Dock Settings")
                    color: settingsMenu.rootState.colFg
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                color: Qt.rgba(settingsMenu.rootState.colAccent.r, settingsMenu.rootState.colAccent.g, settingsMenu.rootState.colAccent.b, 0.18)
            }

            // Toggle: Auto-hide (SmartView)
            ToggleRow {
                rootState: settingsMenu.rootState
                glyph: "󰈉"
                label: settingsMenu.rootState.t("dock_autohide", "Auto-hide")
                checked: settingsMenu.rootState.cfgSmartView
                onToggled: settingsMenu.rootState.updateConfigOption("General", "SmartView", !settingsMenu.rootState.cfgSmartView ? "true" : "false")
            }

            // Toggle: Compact previews
            ToggleRow {
                rootState: settingsMenu.rootState
                glyph: "󰖲"
                label: settingsMenu.rootState.t("dock_compact_preview", "Compact previews")
                checked: settingsMenu.rootState.cfgCompactPreview
                onToggled: settingsMenu.rootState.updateConfigOption("General", "CompactPreview", !settingsMenu.rootState.cfgCompactPreview ? "true" : "false")
            }

            // Toggle: Show launcher button
            ToggleRow {
                rootState: settingsMenu.rootState
                glyph: "󰀻"
                label: settingsMenu.rootState.t("dock_show_launcher", "App launcher button")
                checked: !settingsMenu.rootState.cfgNoLauncher
                onToggled: settingsMenu.rootState.updateConfigOption("General", "NoLauncher", settingsMenu.rootState.cfgNoLauncher ? "false" : "true")
            }

            // Icon size selector
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.topMargin: 4
                spacing: 4

                Text {
                    text: settingsMenu.rootState.t("dock_icon_size", "Icon size")
                    color: settingsMenu.rootState.colMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: [
                            { label: "S (20)", val: 20 },
                            { label: "M (24)", val: 24 },
                            { label: "L (30)", val: 30 }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool selected: settingsMenu.rootState.cfgIconSize === modelData.val
                            Layout.fillWidth: true
                            Layout.preferredHeight: 26
                            radius: 7
                            color: selected
                                ? settingsMenu.rootState.colAccent
                                : (szArea.containsMouse ? settingsMenu.rootState.colSurfaceHover : settingsMenu.rootState.colSurface)
                            Behavior on color { ColorAnimation { duration: 110 } }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: selected ? settingsMenu.rootState.colBg : settingsMenu.rootState.colFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                font.weight: selected ? Font.Bold : Font.Medium
                            }

                            MouseArea {
                                id: szArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settingsMenu.rootState.updateConfigOption("General", "IconSize", String(modelData.val))
                            }
                        }
                    }
                }
            }

            // Position selector
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.topMargin: 4
                Layout.bottomMargin: 2
                spacing: 4

                Text {
                    text: settingsMenu.rootState.t("dock_position", "Position")
                    color: settingsMenu.rootState.colMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: [
                            { key: "bottom", glyph: "󰁅" },
                            { key: "top",    glyph: "󰁝" },
                            { key: "left",   glyph: "󰁍" },
                            { key: "right",  glyph: "󰁔" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool selected: settingsMenu.rootState.cfgPosition === modelData.key
                            Layout.fillWidth: true
                            Layout.preferredHeight: 26
                            radius: 7
                            color: selected
                                ? settingsMenu.rootState.colAccent
                                : (posArea.containsMouse ? settingsMenu.rootState.colSurfaceHover : settingsMenu.rootState.colSurface)
                            Behavior on color { ColorAnimation { duration: 110 } }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.glyph
                                color: selected ? settingsMenu.rootState.colBg : settingsMenu.rootState.colFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                id: posArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    settingsMenu.rootState.updateConfigOption("General", "Position", modelData.key)
                                    settingsMenu.closeRequested()
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                Layout.topMargin: 2
                color: Qt.rgba(settingsMenu.rootState.colAccent.r, settingsMenu.rootState.colAccent.g, settingsMenu.rootState.colAccent.b, 0.18)
            }

            // Hide dock action
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                radius: 8
                color: hideArea.containsMouse ? Qt.rgba(0.91, 0.30, 0.24, 0.18) : "transparent"
                Behavior on color { ColorAnimation { duration: 110 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        text: "󰈉"
                        color: "#e74c3c"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }

                    Text {
                        Layout.fillWidth: true
                        text: settingsMenu.rootState.t("dock_hide", "Hide dock")
                        color: "#e74c3c"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                }

                MouseArea {
                    id: hideArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        settingsMenu.closeRequested()
                        settingsMenu.rootState.setDockEnabledPersist(false)
                    }
                }
            }
        }
    }

    component ToggleRow: Rectangle {
        id: trow
        required property var rootState
        required property string glyph
        required property string label
        required property bool checked
        signal toggled()

        Layout.fillWidth: true
        Layout.preferredHeight: 32
        radius: 8
        color: rowArea.containsMouse ? trow.rootState.colSurfaceHover : "transparent"
        Behavior on color { ColorAnimation { duration: 110 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            Text {
                text: trow.glyph
                color: trow.checked ? trow.rootState.colAccent : trow.rootState.colMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
            }

            Text {
                Layout.fillWidth: true
                text: trow.label
                color: trow.rootState.colFg
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 16
                radius: 8
                color: trow.checked
                    ? trow.rootState.colAccent
                    : Qt.rgba(trow.rootState.colFg.r, trow.rootState.colFg.g, trow.rootState.colFg.b, 0.16)
                Behavior on color { ColorAnimation { duration: 140 } }

                Rectangle {
                    width: 12
                    height: 12
                    radius: 6
                    y: 2
                    x: trow.checked ? 16 : 2
                    color: trow.checked ? trow.rootState.colBg : trow.rootState.colFg
                    Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                }
            }
        }

        MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: trow.toggled()
        }
    }
}
