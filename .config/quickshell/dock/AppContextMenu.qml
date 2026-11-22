import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Item {
    id: menu

    required property var rootState
    required property bool shown
    required property var appData
    required property string dockPosition
    required property real anchorCenterX
    required property real anchorCenterY
    required property real dockEdgeOffset
    required property real screenWidth
    required property real screenHeight

    signal closeRequested()
    signal newWindowRequested(var appData)
    signal desktopActionRequested(var actionObj)
    signal pinToggled(var appData)
    signal minimizeAllRequested(var appData)
    signal restoreAllRequested(var appData)
    signal closeAllRequested(var appData)

    readonly property var desktopActions: {
        if (!appData) return []
        const entry = appData.desktopEntry || menu.rootState.desktopEntryFor(appData.id)
        if (!entry || !entry.actions)
            return []
        const raw = entry.actions
        let out = []
        for (let i = 0; i < raw.length && out.length < 4; ++i) {
            const act = raw[i]
            if (act && act.name && act.name.length > 0) {
                out.push(act)
            }
        }
        return out
    }

    readonly property int instances: appData ? (appData.instances || 0) : 0
    readonly property int minimizedCount: appData ? (appData.minimizedCount || 0) : 0
    readonly property int activeCount: Math.max(0, instances - minimizedCount)
    readonly property bool isPinned: appData ? !!appData.pinned : false

    readonly property real menuW: 226
    readonly property real menuH: menuCol.implicitHeight + 14

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

    readonly property real slideOffX: dockPosition === "left" ? -8 : (dockPosition === "right" ? 8 : 0)
    readonly property real slideOffY: dockPosition === "top" ? -8 : (dockPosition === "bottom" ? 8 : 0)

    x: targetX + (shown ? 0 : slideOffX)
    y: targetY + (shown ? 0 : slideOffY)
    width: menuW
    height: menuH
    opacity: shown && appData ? 1.0 : 0.0
    visible: opacity > 0.01 && appData !== null

    Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Qt.rgba(menu.rootState.colBg.r, menu.rootState.colBg.g, menu.rootState.colBg.b, 0.96)
        border.width: 1
        border.color: Qt.rgba(menu.rootState.colAccent.r, menu.rootState.colAccent.g, menu.rootState.colAccent.b, 0.28)

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.topMargin: 1
            height: 1
            color: Qt.rgba(1, 1, 1, 0.06)
        }

        ColumnLayout {
            id: menuCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 7
            spacing: 2

            // Header row: icon + app name + open count badge
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.topMargin: 4
                Layout.bottomMargin: 5
                spacing: 9

                IconImage {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    implicitSize: 18
                    mipmap: true
                    source: menu.appData
                        ? menu.rootState.resolveIconSource(menu.appData.icon, menu.appData.id)
                        : ""
                }

                Text {
                    Layout.fillWidth: true
                    text: menu.appData ? (menu.appData.name || menu.appData.id) : ""
                    color: menu.rootState.colFg
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Rectangle {
                    visible: menu.instances > 0
                    Layout.preferredHeight: 18
                    Layout.preferredWidth: Math.max(20, countTxt.implicitWidth + 10)
                    radius: 9
                    color: Qt.rgba(menu.rootState.colAccent.r, menu.rootState.colAccent.g, menu.rootState.colAccent.b, 0.22)

                    Text {
                        id: countTxt
                        anchors.centerIn: parent
                        text: String(menu.instances)
                        color: menu.rootState.colAccent
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                Layout.topMargin: 2
                Layout.bottomMargin: 3
                color: Qt.rgba(menu.rootState.colAccent.r, menu.rootState.colAccent.g, menu.rootState.colAccent.b, 0.18)
            }

            // New window
            MenuEntryButton {
                rootState: menu.rootState
                glyph: "󰐕"
                label: menu.rootState.t("dock_new_window", "New window")
                onTriggered: {
                    menu.newWindowRequested(menu.appData)
                    menu.closeRequested()
                }
            }

            // Native .desktop actions (e.g. Private Window, Preferences, etc.)
            Repeater {
                model: menu.desktopActions
                delegate: MenuEntryButton {
                    required property var modelData
                    rootState: menu.rootState
                    glyph: "󰅂"
                    label: modelData.name
                    onTriggered: {
                        menu.desktopActionRequested(modelData)
                        menu.closeRequested()
                    }
                }
            }

            // Pin / Unpin
            MenuEntryButton {
                rootState: menu.rootState
                glyph: menu.isPinned ? "󰐄" : "󰐃"
                label: menu.isPinned
                    ? menu.rootState.t("dock_unpin", "Unpin from dock")
                    : menu.rootState.t("dock_pin", "Pin to dock")
                onTriggered: {
                    menu.pinToggled(menu.appData)
                    menu.closeRequested()
                }
            }

            // Separator before window controls
            Rectangle {
                visible: menu.instances > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                Layout.topMargin: 3
                Layout.bottomMargin: 3
                color: Qt.rgba(menu.rootState.colAccent.r, menu.rootState.colAccent.g, menu.rootState.colAccent.b, 0.18)
            }

            // Minimize all
            MenuEntryButton {
                visible: menu.activeCount > 0
                rootState: menu.rootState
                glyph: "󰖰"
                label: menu.rootState.t("dock_minimize_all", "Minimize all")
                onTriggered: {
                    menu.minimizeAllRequested(menu.appData)
                    menu.closeRequested()
                }
            }

            // Restore all
            MenuEntryButton {
                visible: menu.minimizedCount > 0
                rootState: menu.rootState
                glyph: "󰖯"
                label: menu.rootState.t("dock_restore_all", "Restore all")
                onTriggered: {
                    menu.restoreAllRequested(menu.appData)
                    menu.closeRequested()
                }
            }

            // Close all windows
            MenuEntryButton {
                visible: menu.instances > 0
                rootState: menu.rootState
                glyph: "󰅖"
                label: menu.rootState.t("dock_close_all", "Close all windows")
                danger: true
                onTriggered: {
                    menu.closeAllRequested(menu.appData)
                    menu.closeRequested()
                }
            }
        }
    }

    component MenuEntryButton: Rectangle {
        id: btn
        required property var rootState
        required property string glyph
        required property string label
        property bool danger: false
        signal triggered()

        Layout.fillWidth: true
        Layout.preferredHeight: 32
        radius: 8
        color: {
            if (!btnArea.containsMouse) return "transparent"
            return btn.danger
                ? Qt.rgba(0.91, 0.30, 0.24, 0.18)
                : Qt.rgba(btn.rootState.colAccent.r, btn.rootState.colAccent.g, btn.rootState.colAccent.b, 0.22)
        }
        Behavior on color { ColorAnimation { duration: 110 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            Text {
                text: btn.glyph
                color: btn.danger ? "#e74c3c" : Qt.rgba(btn.rootState.colFg.r, btn.rootState.colFg.g, btn.rootState.colFg.b, 0.78)
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
            }

            Text {
                Layout.fillWidth: true
                text: btn.label
                color: btn.danger ? "#e74c3c" : btn.rootState.colFg
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.triggered()
        }
    }
}
