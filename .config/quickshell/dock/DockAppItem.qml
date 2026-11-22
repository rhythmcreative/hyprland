import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: item

    required property var rootState
    required property var appData
    required property int slotIndex
    required property int hoveredSlotIndex
    required property bool isVertical
    required property string dockPosition
    required property int iconSize
    required property int buttonRadius
    required property bool isDraggingAny
    required property bool isDraggedSelf
    required property bool isDropTarget

    signal hoveredChangedItem(bool inside, Item sourceItem)
    signal leftClicked(Item sourceItem)
    signal middleClicked()
    signal rightClicked(Item sourceItem)
    signal wheelScrolled(int delta)
    signal dragStarted(int pinnedIdx, real pointerCoord, var appData)
    signal dragMoved(real pointerCoord)
    signal dragFinished()

    // Classic rust-dock geometry: 58x54px slots around 24px icons (66px pitch, 66px dock height)
    readonly property real hoverDist: (hoveredSlotIndex >= 0 && !isDraggingAny)
        ? Math.abs(slotIndex - hoveredSlotIndex)
        : 99

    readonly property real targetScale: {
        if (isDraggedSelf) return 0.90
        if (hoverDist === 0) return 1.08
        return 1.0
    }
    readonly property real targetLift: {
        if (isDraggedSelf) return 0
        if (hoverDist === 0) return 1.5
        return 0
    }
    readonly property real extraSpread: 0

    // Exact rust-dock slot proportions (58x54 for iconSize=24)
    readonly property int basePrimary: iconSize + 34
    readonly property int baseCross: iconSize + 30

    width: isVertical ? baseCross : basePrimary
    height: isVertical ? basePrimary : baseCross

    Behavior on width {
        SpringAnimation { spring: 5.4; damping: 0.52; mass: 0.50 }
    }
    Behavior on height {
        SpringAnimation { spring: 5.4; damping: 0.52; mass: 0.50 }
    }

    property real bounceOffset: 0

    function triggerBounce() {
        bounceAnim.restart()
    }

    SequentialAnimation {
        id: bounceAnim
        NumberAnimation {
            target: item
            property: "bounceOffset"
            to: 8
            duration: 110
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: item
            property: "bounceOffset"
            to: 0
            duration: 240
            easing.type: Easing.OutBounce
        }
    }

    readonly property real totalLift: targetLift + bounceOffset
    readonly property real shiftX: dockPosition === "left" ? totalLift : (dockPosition === "right" ? -totalLift : 0)
    readonly property real shiftY: dockPosition === "top" ? totalLift : (dockPosition === "bottom" ? -totalLift : 0)

    // Drop insertion indicator bar when reordering pinned items
    Rectangle {
        visible: item.isDropTarget && !item.isDraggedSelf
        z: 10
        color: item.rootState.colAccent
        radius: 1.5
        width: item.isVertical ? parent.width - 10 : 2.5
        height: item.isVertical ? 2.5 : parent.height - 10
        anchors.horizontalCenter: item.isVertical ? parent.horizontalCenter : undefined
        anchors.verticalCenter: item.isVertical ? undefined : parent.verticalCenter
        anchors.left: item.isVertical ? undefined : parent.left
        anchors.leftMargin: item.isVertical ? 0 : -6
        anchors.top: item.isVertical ? parent.top : undefined
        anchors.topMargin: item.isVertical ? -6 : 0
    }

    Item {
        id: tile
        anchors.fill: parent
        opacity: item.isDraggedSelf ? 0.30 : (item.appData.allMinimized ? 0.48 : 1.0)
        Behavior on opacity { NumberAnimation { duration: 140 } }

        // Classic rust-dock hover & drop-target pill (calm dark surface, no loud active box)
        Rectangle {
            anchors.centerIn: parent
            width: item.basePrimary
            height: item.baseCross
            radius: Math.max(4, item.buttonRadius)
            color: {
                if (item.isDropTarget && !item.isDraggedSelf)
                    return Qt.rgba(item.rootState.colAccentAlt.r, item.rootState.colAccentAlt.g, item.rootState.colAccentAlt.b, 0.28)
                if (mouseArea.containsMouse && !item.isDraggingAny)
                    return Qt.rgba(item.rootState.colColor1.r, item.rootState.colColor1.g, item.rootState.colColor1.b, 0.28)
                return "transparent"
            }
            border.width: item.isDropTarget || item.appData.urgent ? 1 : 0
            border.color: item.appData.urgent
                ? item.rootState.colUrgent
                : Qt.rgba(item.rootState.colAccentAlt.r, item.rootState.colAccentAlt.g, item.rootState.colAccentAlt.b, 0.70)
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }
        }

        // Urgent pulse
        Rectangle {
            anchors.centerIn: parent
            width: item.basePrimary
            height: item.baseCross
            radius: Math.max(4, item.buttonRadius)
            color: Qt.rgba(item.rootState.colUrgent.r, item.rootState.colUrgent.g, item.rootState.colUrgent.b, 0.22)
            visible: item.appData.urgent
            SequentialAnimation on opacity {
                running: item.appData.urgent
                loops: Animation.Infinite
                NumberAnimation { from: 0.25; to: 0.90; duration: 650; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.90; to: 0.25; duration: 650; easing.type: Easing.InOutSine }
            }
        }

        // Clean centered app icon matching original rust-dock vertical alignment
        Item {
            id: iconContainer
            width: item.iconSize
            height: item.iconSize
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: item.shiftX + (item.dockPosition === "left" ? 5 : (item.dockPosition === "right" ? -5 : 0))
            anchors.verticalCenterOffset: item.shiftY + (item.dockPosition === "bottom" ? -5 : (item.dockPosition === "top" ? 5 : 0))
            scale: mouseArea.pressed && !mouseArea.dragMovedFar ? 0.92 : item.targetScale

            Behavior on scale {
                SpringAnimation { spring: 5.5; damping: 0.46; mass: 0.50 }
            }
            Behavior on anchors.horizontalCenterOffset {
                SpringAnimation { spring: 5.5; damping: 0.48; mass: 0.50 }
            }
            Behavior on anchors.verticalCenterOffset {
                SpringAnimation { spring: 5.5; damping: 0.48; mass: 0.50 }
            }

            IconImage {
                id: iconImg
                anchors.fill: parent
                implicitSize: item.iconSize
                mipmap: true
                asynchronous: true
                source: item.rootState.resolveIconSource(item.appData.icon, item.appData.id)
                visible: status === Image.Ready
            }

            Rectangle {
                anchors.fill: parent
                radius: Math.round(item.iconSize * 0.26)
                visible: iconImg.status !== Image.Ready
                color: Qt.rgba(item.rootState.colAccent.r, item.rootState.colAccent.g, item.rootState.colAccent.b, 0.25)
                border.width: 1
                border.color: Qt.rgba(item.rootState.colAccent.r, item.rootState.colAccent.g, item.rootState.colAccent.b, 0.45)

                Text {
                    anchors.centerIn: parent
                    text: (item.appData.name || item.appData.id || "?").charAt(0).toUpperCase()
                    color: item.rootState.colFg
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Math.max(10, Math.round(item.iconSize * 0.48))
                    font.weight: Font.Bold
                }
            }
        }

        // Classic rust-dock small circular dot(s) right below the icon
        Item {
            id: indicatorBox
            visible: item.appData.instances > 0
            width: item.isVertical ? 4 : Math.min(parent.width - 8, indRow.implicitWidth)
            height: item.isVertical ? Math.min(parent.height - 8, indCol.implicitHeight) : 4
            anchors.horizontalCenter: item.isVertical ? undefined : parent.horizontalCenter
            anchors.verticalCenter: item.isVertical ? parent.verticalCenter : undefined
            anchors.bottom: item.dockPosition === "bottom" ? parent.bottom : undefined
            anchors.bottomMargin: item.dockPosition === "bottom" ? 12 : 0
            anchors.top: item.dockPosition === "top" ? parent.top : undefined
            anchors.topMargin: item.dockPosition === "top" ? 12 : 0
            anchors.left: item.dockPosition === "left" ? parent.left : undefined
            anchors.leftMargin: item.dockPosition === "left" ? 12 : 0
            anchors.right: item.dockPosition === "right" ? parent.right : undefined
            anchors.rightMargin: item.dockPosition === "right" ? 12 : 0

            readonly property color indColor: {
                if (item.appData.urgent) return item.rootState.colUrgent
                if (item.appData.allMinimized) return item.rootState.colMuted
                if (item.appData.active) return item.rootState.colFg
                return Qt.rgba(item.rootState.colFg.r, item.rootState.colFg.g, item.rootState.colFg.b, 0.85)
            }
            readonly property int dotCount: Math.min(item.appData.instances, 3)

            Row {
                id: indRow
                visible: !item.isVertical
                anchors.centerIn: parent
                spacing: 3

                Repeater {
                    model: indicatorBox.dotCount
                    Rectangle {
                        width: 3
                        height: 3
                        radius: 1.5
                        color: indicatorBox.indColor
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }
                }
            }

            Column {
                id: indCol
                visible: item.isVertical
                anchors.centerIn: parent
                spacing: 3

                Repeater {
                    model: indicatorBox.dotCount
                    Rectangle {
                        width: 3
                        height: 3
                        radius: 1.5
                        color: indicatorBox.indColor
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: dragMovedFar ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        property real pressStartCoord: 0
        property bool dragMovedFar: false

        onContainsMouseChanged: {
            if (!item.isDraggingAny) {
                item.hoveredChangedItem(containsMouse, item)
            }
        }

        onPressed: function(mouse) {
            dragMovedFar = false
            if (mouse.button === Qt.LeftButton && item.appData.pinned) {
                const pt = item.mapToItem(item.parent, mouse.x, mouse.y)
                pressStartCoord = item.isVertical ? pt.y : pt.x
            }
        }

        onPositionChanged: function(mouse) {
            if (!(mouse.buttons & Qt.LeftButton) || !item.appData.pinned) return
            const pt = item.mapToItem(item.parent, mouse.x, mouse.y)
            const cur = item.isVertical ? pt.y : pt.x
            if (!dragMovedFar && Math.abs(cur - pressStartCoord) > 8) {
                dragMovedFar = true
                item.dragStarted(item.slotIndex, cur, item.appData)
            } else if (dragMovedFar) {
                item.dragMoved(cur)
            }
        }

        onReleased: function(mouse) {
            if (dragMovedFar) {
                dragMovedFar = false
                item.dragFinished()
                return
            }
            if (mouse.button === Qt.LeftButton) {
                if (item.appData.instances === 0) item.triggerBounce()
                item.leftClicked(item)
            } else if (mouse.button === Qt.MiddleButton) {
                item.triggerBounce()
                item.middleClicked()
            } else if (mouse.button === Qt.RightButton) {
                item.rightClicked(item)
            }
        }

        onCanceled: {
            if (dragMovedFar) {
                dragMovedFar = false
                item.dragFinished()
            }
        }

        onWheel: function(wheel) {
            if (item.appData.instances > 1) {
                item.wheelScrolled(wheel.angleDelta.y)
                wheel.accepted = true
            }
        }
    }
}
