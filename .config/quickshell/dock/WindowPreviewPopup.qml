import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

Item {
    id: popup

    required property var rootState
    required property bool shown
    required property var windowsModel  // ListModel of { address, className, title, workspaceId, minimized, active, urgent }
    required property string appIcon
    required property string appName
    required property string dockPosition
    required property bool isVertical
    required property bool compactPreview
    required property int radiusBase
    required property real anchorCenterX
    required property real anchorCenterY
    required property real dockEdgeOffset
    required property real screenWidth
    required property real screenHeight

    signal previewHoveredChanged(bool inside)
    signal windowActivated(string address)
    signal windowMinimizeToggled(string address)
    signal windowClosed(string address)

    readonly property int cardW: compactPreview ? 208 : 264
    readonly property int thumbH: compactPreview ? 112 : 154
    readonly property int headerH: 30
    readonly property int cardH: headerH + thumbH + 8
    readonly property int panelPad: 10
    readonly property int cardGap: 8

    readonly property int winCount: windowsModel ? windowsModel.count : 0
    readonly property real naturalW: isVertical
        ? (cardW + panelPad * 2)
        : (winCount * cardW + Math.max(0, winCount - 1) * cardGap + panelPad * 2)
    readonly property real naturalH: isVertical
        ? (winCount * cardH + Math.max(0, winCount - 1) * cardGap + panelPad * 2)
        : (cardH + panelPad * 2)

    readonly property real panelW: Math.min(naturalW, Math.max(cardW + panelPad * 2, screenWidth - 28))
    readonly property real panelH: Math.min(naturalH, Math.max(cardH + panelPad * 2, screenHeight - 28))

    readonly property real targetX: {
        if (dockPosition === "left") return dockEdgeOffset
        if (dockPosition === "right") return screenWidth - dockEdgeOffset - panelW
        return Math.max(14, Math.min(screenWidth - panelW - 14, anchorCenterX - panelW / 2))
    }
    readonly property real targetY: {
        if (dockPosition === "top") return dockEdgeOffset
        if (dockPosition === "bottom") return screenHeight - dockEdgeOffset - panelH
        return Math.max(14, Math.min(screenHeight - panelH - 14, anchorCenterY - panelH / 2))
    }

    readonly property real slideOffX: dockPosition === "left" ? -8 : (dockPosition === "right" ? 8 : 0)
    readonly property real slideOffY: dockPosition === "top" ? -8 : (dockPosition === "bottom" ? 8 : 0)

    x: targetX + (shown ? 0 : slideOffX)
    y: targetY + (shown ? 0 : slideOffY)
    width: panelW
    height: panelH
    opacity: shown && winCount > 0 ? 1.0 : 0.0
    visible: opacity > 0.01 && winCount > 0

    Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

    // Non-blocking HoverHandler tracks pointer across the whole preview panel & all cards/buttons
    HoverHandler {
        id: panelHover
        blocking: false
        onHoveredChanged: popup.previewHoveredChanged(hovered)
    }

    // Outer sleek matte container matching Waybar & Dynamic Island
    Rectangle {
        id: bgPanel
        anchors.fill: parent
        radius: Math.max(12, Math.min(16, popup.radiusBase + 2))
        color: Qt.rgba(popup.rootState.colBg.r, popup.rootState.colBg.g, popup.rootState.colBg.b, 0.95)
        border.width: 1
        border.color: Qt.rgba(popup.rootState.colAccent.r, popup.rootState.colAccent.g, popup.rootState.colAccent.b, 0.28)

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: parent.radius
            anchors.rightMargin: parent.radius
            anchors.topMargin: 1
            height: 1
            color: Qt.rgba(1, 1, 1, 0.06)
        }

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: popup.panelPad
            clip: true
            contentWidth: popup.isVertical ? width : cardsFlow.implicitWidth
            contentHeight: popup.isVertical ? cardsFlow.implicitHeight : height
            boundsBehavior: Flickable.StopAtBounds

            GridLayout {
                id: cardsFlow
                columns: popup.isVertical ? 1 : Math.max(1, popup.winCount)
                rows: popup.isVertical ? Math.max(1, popup.winCount) : 1
                columnSpacing: popup.cardGap
                rowSpacing: popup.cardGap

                Repeater {
                    model: popup.windowsModel

                    delegate: Rectangle {
                        id: card
                        required property string address
                        required property string className
                        required property string title
                        required property int workspaceId
                        required property bool minimized
                        required property bool active
                        required property bool urgent

                        Layout.preferredWidth: popup.cardW
                        Layout.preferredHeight: popup.cardH
                        radius: Math.max(10, popup.radiusBase)
                        color: cardHover.hovered
                            ? Qt.rgba(popup.rootState.colFg.r, popup.rootState.colFg.g, popup.rootState.colFg.b, 0.08)
                            : Qt.rgba(popup.rootState.colFg.r, popup.rootState.colFg.g, popup.rootState.colFg.b, 0.04)
                        border.width: 1.5
                        border.color: {
                            if (card.urgent) return popup.rootState.colUrgent
                            if (cardHover.hovered) return popup.rootState.colAccent
                            if (card.active) return Qt.rgba(popup.rootState.colAccent.r, popup.rootState.colAccent.g, popup.rootState.colAccent.b, 0.65)
                            return Qt.rgba(popup.rootState.colFg.r, popup.rootState.colFg.g, popup.rootState.colFg.b, 0.09)
                        }

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        HoverHandler { id: cardHover; blocking: false }

                        // Card click surface (left = focus/restore, middle = close)
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.MiddleButton) {
                                    popup.windowClosed(card.address)
                                } else {
                                    popup.windowActivated(card.address)
                                }
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 0
                            spacing: 0

                            // Header: icon + title + workspace pill + minimize + close
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: popup.headerH
                                Layout.leftMargin: 8
                                Layout.rightMargin: 6
                                spacing: 6

                                IconImage {
                                    Layout.preferredWidth: 14
                                    Layout.preferredHeight: 14
                                    implicitSize: 14
                                    mipmap: true
                                    asynchronous: true
                                    source: popup.rootState.resolveIconSource(popup.appIcon, card.className)
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: card.title || popup.appName || card.className
                                    color: popup.rootState.colFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    font.weight: card.active ? Font.DemiBold : Font.Medium
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                // Workspace or Minimized badge
                                Rectangle {
                                    visible: card.minimized || card.workspaceId > 0
                                    Layout.preferredHeight: 16
                                    Layout.preferredWidth: wsBadgeText.implicitWidth + 8
                                    radius: 4
                                    color: card.minimized
                                        ? Qt.rgba(0.90, 0.75, 0.48, 0.22)
                                        : Qt.rgba(popup.rootState.colAccent.r, popup.rootState.colAccent.g, popup.rootState.colAccent.b, 0.18)

                                    Text {
                                        id: wsBadgeText
                                        anchors.centerIn: parent
                                        text: card.minimized
                                            ? popup.rootState.t("dock_min_short", "MIN")
                                            : ("WS " + card.workspaceId)
                                        color: card.minimized ? "#e5c07b" : popup.rootState.colAccent
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 8
                                        font.weight: Font.Bold
                                    }
                                }

                                // Single-window Minimize / Restore button
                                Rectangle {
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                    radius: 5
                                    opacity: cardHover.hovered || minBtnArea.containsMouse ? 1.0 : 0.45
                                    color: minBtnArea.containsMouse
                                        ? Qt.rgba(popup.rootState.colFg.r, popup.rootState.colFg.g, popup.rootState.colFg.b, 0.18)
                                        : "transparent"
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Behavior on opacity { NumberAnimation { duration: 100 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: card.minimized ? "󰖯" : "󰖰"
                                        color: popup.rootState.colFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        id: minBtnArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: popup.windowMinimizeToggled(card.address)
                                    }
                                }

                                // Close button
                                Rectangle {
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                    radius: 5
                                    opacity: cardHover.hovered || closeBtnArea.containsMouse ? 1.0 : 0.55
                                    color: closeBtnArea.containsMouse ? "#e74c3c" : "transparent"
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Behavior on opacity { NumberAnimation { duration: 100 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "×"
                                        color: closeBtnArea.containsMouse ? "#ffffff" : popup.rootState.colFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                    }

                                    MouseArea {
                                        id: closeBtnArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: popup.windowClosed(card.address)
                                    }
                                }
                            }

                            // Live 60 FPS GPU thumbnail clipped to rounded corners
                            ClippingRectangle {
                                id: thumbClip
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.leftMargin: 6
                                Layout.rightMargin: 6
                                Layout.bottomMargin: 6
                                radius: Math.max(7, popup.radiusBase - 2)
                                color: Qt.rgba(0, 0, 0, 0.34)

                                ScreencopyView {
                                    id: liveThumb
                                    anchors.fill: parent
                                    captureSource: popup.shown ? popup.rootState.waylandForAddress(card.address) : null
                                    live: popup.shown && !card.minimized
                                    paintCursor: false
                                    constraintSize: Qt.size(
                                        Math.max(1, Math.round(thumbClip.width)),
                                        Math.max(1, Math.round(thumbClip.height))
                                    )
                                }

                                // Fallback placeholder when window is minimized or has no frame yet
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    visible: !liveThumb.hasContent

                                    IconImage {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 42
                                        height: 42
                                        implicitSize: 42
                                        mipmap: true
                                        opacity: 0.55
                                        source: popup.rootState.resolveIconSource(popup.appIcon, card.className)
                                    }

                                    Text {
                                        visible: card.minimized
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: popup.rootState.t("dock_minimized", "Minimized")
                                        color: popup.rootState.colMuted
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
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
