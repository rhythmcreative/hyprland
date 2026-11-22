import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

Scope {
    id: screenScope

    required property var rootState
    required property var screenObj

    readonly property string screenName: screenObj ? screenObj.name : ""
    readonly property string dockPos: rootState.cfgPosition
    readonly property bool isVertical: dockPos === "left" || dockPos === "right"
    readonly property int hoverHeadroom: 20

    readonly property int baseMargin: rootState.cfgSystemGapUsed ? rootState.hyprGapsOut : rootState.cfgMargin
    readonly property int edgeMargin: {
        if (dockPos === "top") return rootState.cfgMarginTop + baseMargin
        if (dockPos === "left") return rootState.cfgMarginLeft + baseMargin
        if (dockPos === "right") return rootState.cfgMarginRight + baseMargin
        return rootState.cfgMarginBottom + baseMargin
    }

    // ── Stable In-Place ListModels (prevents delegate recreation & lost hover) ─
    ListModel { id: pinnedModel }
    ListModel { id: runningModel }
    ListModel { id: previewModel }

    readonly property int launcherSlotCount: rootState.cfgNoLauncher ? 0 : 1

    function syncAppListModel(listModel, newArr) {
        const target = Array.isArray(newArr) ? newArr : []
        // First check if exact sequence of pinKey/id matches for fast in-place property update
        let sameOrder = (listModel.count === target.length)
        if (sameOrder) {
            for (let i = 0; i < target.length; ++i) {
                if (listModel.get(i).pinKey !== target[i].pinKey || listModel.get(i).id !== target[i].id) {
                    sameOrder = false
                    break
                }
            }
        }
        if (sameOrder) {
            for (let i = 0; i < target.length; ++i) {
                const it = target[i]
                const cur = listModel.get(i)
                if (cur.name !== it.name) listModel.setProperty(i, "name", it.name)
                if (cur.icon !== (it.icon || "")) listModel.setProperty(i, "icon", it.icon || "")
                if (cur.exec !== (it.exec || "")) listModel.setProperty(i, "exec", it.exec || "")
                if (cur.pinned !== !!it.pinned) listModel.setProperty(i, "pinned", !!it.pinned)
                if (cur.instances !== it.instances) listModel.setProperty(i, "instances", it.instances)
                if (cur.minimizedCount !== it.minimizedCount) listModel.setProperty(i, "minimizedCount", it.minimizedCount)
                if (cur.allMinimized !== !!it.allMinimized) listModel.setProperty(i, "allMinimized", !!it.allMinimized)
                if (cur.active !== !!it.active) listModel.setProperty(i, "active", !!it.active)
                if (cur.urgent !== !!it.urgent) listModel.setProperty(i, "urgent", !!it.urgent)
            }
            return
        }

        // Keyed reconciliation: remove missing items, insert/move/update existing ones in place
        let keepKeys = {}
        for (let i = 0; i < target.length; ++i) keepKeys[target[i].pinKey] = true

        for (let i = listModel.count - 1; i >= 0; --i) {
            if (!keepKeys[listModel.get(i).pinKey]) {
                listModel.remove(i)
            }
        }

        for (let i = 0; i < target.length; ++i) {
            const it = target[i]
            const rowObj = {
                id: it.id || "",
                pinKey: it.pinKey || it.id || "",
                name: it.name || "",
                icon: it.icon || "",
                exec: it.exec || "",
                pinned: !!it.pinned,
                instances: it.instances || 0,
                minimizedCount: it.minimizedCount || 0,
                allMinimized: !!it.allMinimized,
                active: !!it.active,
                urgent: !!it.urgent
            }
            let existingIdx = -1
            for (let j = i; j < listModel.count; ++j) {
                if (listModel.get(j).pinKey === rowObj.pinKey) {
                    existingIdx = j
                    break
                }
            }
            if (existingIdx >= 0) {
                if (existingIdx !== i) listModel.move(existingIdx, i, 1)
                listModel.set(i, rowObj)
            } else {
                listModel.insert(i, rowObj)
            }
        }
    }

    function syncPreviewListModel() {
        if (!previewAppId) {
            if (previewModel.count > 0) previewModel.clear()
            return
        }
        const wins = rootState.windowsForApp(previewAppId, screenName)
        if (wins.length === 0) {
            if (previewModel.count > 0) previewModel.clear()
            if (previewOpen) {
                previewOpen = false
                previewAppId = ""
            }
            return
        }

        // Remove closed windows
        let liveSet = {}
        for (let i = 0; i < wins.length; ++i) liveSet[wins[i].address] = true
        for (let i = previewModel.count - 1; i >= 0; --i) {
            if (!liveSet[previewModel.get(i).address]) {
                previewModel.remove(i)
            }
        }

        // Update / insert in place so live ScreencopyView streams never reset!
        for (let i = 0; i < wins.length; ++i) {
            const w = wins[i]
            const row = {
                address: w.address || "",
                className: w.className || "",
                title: w.title || "",
                workspaceId: w.workspaceId || 0,
                minimized: !!w.minimized,
                active: !!w.active,
                urgent: !!w.urgent
            }
            let foundIdx = -1
            for (let j = 0; j < previewModel.count; ++j) {
                if (previewModel.get(j).address === row.address) {
                    foundIdx = j
                    break
                }
            }
            if (foundIdx >= 0) {
                if (foundIdx !== i) previewModel.move(foundIdx, i, 1)
                const cur = previewModel.get(i)
                if (cur.title !== row.title) previewModel.setProperty(i, "title", row.title)
                if (cur.workspaceId !== row.workspaceId) previewModel.setProperty(i, "workspaceId", row.workspaceId)
                if (cur.minimized !== row.minimized) previewModel.setProperty(i, "minimized", row.minimized)
                if (cur.active !== row.active) previewModel.setProperty(i, "active", row.active)
                if (cur.urgent !== row.urgent) previewModel.setProperty(i, "urgent", row.urgent)
            } else {
                previewModel.insert(i, row)
            }
        }
    }

    function syncAllModels() {
        const m = rootState.buildModelForScreen(screenName)
        syncAppListModel(pinnedModel, m.pinned)
        syncAppListModel(runningModel, m.running)
        if (previewAppId) syncPreviewListModel()
    }

    Connections {
        target: screenScope.rootState
        function onClientsRevisionChanged() { screenScope.syncAllModels() }
        function onPinnedIdsChanged() { screenScope.syncAllModels() }
        function onEffectivePinnedIdsChanged() { screenScope.syncAllModels() }
        function onCfgSortRunningAppsChanged() { screenScope.syncAllModels() }
    }

    Component.onCompleted: syncAllModels()

    // Visibility / SmartView / Fullscreen / External-hide logic
    readonly property bool externallyHidden: !!rootState.hiddenScreens[screenName]
    readonly property bool fullscreenActive: !!rootState.fullscreenScreens[screenName]
    readonly property bool globallyOff: !rootState.dockEnabled

    property bool smartRevealed: false
    property bool dockHovered: false
    property bool bridgeHovered: false
    property bool previewPanelHovered: false
    readonly property bool previewHovered: bridgeHovered || previewPanelHovered
    property bool edgeHovered: false

    readonly property bool anyPopupActive: previewOpen || contextMenuOpen || settingsMenuOpen

    readonly property bool dockShown: {
        if (globallyOff || externallyHidden || fullscreenActive)
            return false
        if (rootState.cfgSmartView)
            return smartRevealed || dockHovered || previewHovered || edgeHovered || anyPopupActive || dragActive
        return true
    }

    // Smart auto-hide delay timer
    Timer {
        id: smartHideTimer
        interval: Math.max(80, screenScope.rootState.cfgAutoHideDelay)
        repeat: false
        onTriggered: {
            if (!screenScope.dockHovered && !screenScope.previewHovered && !screenScope.edgeHovered && !screenScope.anyPopupActive && !screenScope.dragActive) {
                screenScope.smartRevealed = false
            }
        }
    }

    function touchSmartReveal() {
        if (!rootState.cfgSmartView) return
        smartHideTimer.stop()
        smartRevealed = true
    }

    function scheduleSmartHide() {
        if (!rootState.cfgSmartView) return
        if (!dockHovered && !previewHovered && !edgeHovered && !anyPopupActive && !dragActive) {
            smartHideTimer.restart()
        }
    }

    onDockShownChanged: {
        if (!dockShown) {
            dismissAllOverlays()
        }
    }

    // ── Hover, Tooltip, Preview, Context Menu & Quick Settings state ────────
    property int hoveredSlotIndex: -1
    property string hoveredAppId: ""
    property string hoveredAppName: ""
    property string hoveredAppIcon: ""
    property real hoveredAnchorX: 0
    property real hoveredAnchorY: 0

    property bool previewOpen: false
    property string previewAppId: ""
    property string previewAppName: ""
    property string previewAppIcon: ""
    property real previewAnchorX: 0
    property real previewAnchorY: 0

    onPreviewAppIdChanged: syncPreviewListModel()

    property bool contextMenuOpen: false
    property var contextMenuApp: null
    property real contextAnchorX: 0
    property real contextAnchorY: 0

    property bool settingsMenuOpen: false
    property real settingsAnchorX: 0
    property real settingsAnchorY: 0

    readonly property bool tooltipVisible: {
        if (previewOpen || contextMenuOpen || settingsMenuOpen || dragActive)
            return false
        if (hoveredSlotIndex < 0 || !hoveredAppName)
            return false
        if (hoveredAppId && rootState.windowsForApp(hoveredAppId, screenName).length > 0)
            return false
        return true
    }

    function dismissAllOverlays() {
        previewShowTimer.stop()
        previewHideTimer.stop()
        previewOpen = false
        previewAppId = ""
        bridgeHovered = false
        previewPanelHovered = false
        contextMenuOpen = false
        contextMenuApp = null
        settingsMenuOpen = false
        hoveredSlotIndex = -1
        hoveredAppId = ""
        hoveredAppName = ""
    }

    function measureItemCenter(sourceItem) {
        if (!sourceItem || !dockWin.contentItem) return { x: screenObj.width / 2, y: screenObj.height / 2 }
        const pt = sourceItem.mapToItem(dockWin.contentItem, sourceItem.width / 2, sourceItem.height / 2)
        let sx = pt.x
        let sy = pt.y
        if (dockPos === "bottom") {
            sy = screenObj.height - (dockWin.height - pt.y)
        } else if (dockPos === "right") {
            sx = screenObj.width - (dockWin.width - pt.x)
        }
        return { x: sx, y: sy }
    }

    Timer {
        id: previewShowTimer
        interval: Math.max(15, screenScope.rootState.cfgShowDelay)
        repeat: false
        onTriggered: {
            if (screenScope.contextMenuOpen || screenScope.settingsMenuOpen || screenScope.dragActive)
                return
            if (!screenScope.hoveredAppId) return
            const wins = screenScope.rootState.windowsForApp(screenScope.hoveredAppId, screenScope.screenName)
            if (wins.length === 0) {
                screenScope.previewOpen = false
                screenScope.previewAppId = ""
                return
            }
            screenScope.previewAppId = screenScope.hoveredAppId
            screenScope.previewAppName = screenScope.hoveredAppName
            screenScope.previewAppIcon = screenScope.hoveredAppIcon
            screenScope.previewAnchorX = screenScope.hoveredAnchorX
            screenScope.previewAnchorY = screenScope.hoveredAnchorY
            screenScope.syncPreviewListModel()
            screenScope.previewOpen = true
        }
    }

    Timer {
        id: previewHideTimer
        interval: Math.max(260, screenScope.rootState.cfgHideDelay)
        repeat: false
        onTriggered: {
            if (!screenScope.previewHovered && screenScope.hoveredSlotIndex < 0) {
                screenScope.previewOpen = false
                screenScope.previewAppId = ""
                screenScope.scheduleSmartHide()
            }
        }
    }

    function schedulePreviewHideIfNeeded() {
        if (!previewHovered && hoveredSlotIndex < 0) {
            previewHideTimer.restart()
        } else {
            previewHideTimer.stop()
        }
    }

    function handleAppHover(inside, slotIdx, appData, sourceItem) {
        if (inside) {
            previewHideTimer.stop()
            touchSmartReveal()
            const c = measureItemCenter(sourceItem)
            hoveredSlotIndex = slotIdx
            hoveredAppId = appData.id
            hoveredAppName = appData.name
            hoveredAppIcon = appData.icon || ""
            hoveredAnchorX = c.x
            hoveredAnchorY = c.y

            if (contextMenuOpen || settingsMenuOpen || dragActive) return

            const wins = rootState.windowsForApp(appData.id, screenName)
            if (wins.length > 0) {
                if (previewOpen && previewAppId === appData.id) {
                    previewAnchorX = c.x
                    previewAnchorY = c.y
                    return
                }
                previewShowTimer.interval = previewOpen
                    ? Math.max(15, rootState.cfgMoveDelay)
                    : Math.max(20, rootState.cfgShowDelay)
                previewShowTimer.restart()
            } else if (previewOpen) {
                previewShowTimer.stop()
                previewOpen = false
                previewAppId = ""
            }
        } else {
            if (hoveredSlotIndex === slotIdx) {
                hoveredSlotIndex = -1
                hoveredAppId = ""
                hoveredAppName = ""
            }
            previewShowTimer.stop()
            if (previewOpen) {
                schedulePreviewHideIfNeeded()
            }
        }
    }

    function copyAppPlain(m) {
        return {
            id: m.id,
            pinKey: m.pinKey,
            name: m.name,
            icon: m.icon,
            exec: m.exec,
            pinned: m.pinned,
            instances: m.instances,
            minimizedCount: m.minimizedCount,
            allMinimized: m.allMinimized,
            active: m.active,
            urgent: m.urgent
        }
    }

    function openContextMenu(appData, sourceItem) {
        previewShowTimer.stop()
        previewHideTimer.stop()
        previewOpen = false
        previewAppId = ""
        bridgeHovered = false
        previewPanelHovered = false
        settingsMenuOpen = false
        const c = measureItemCenter(sourceItem)
        contextAnchorX = c.x
        contextAnchorY = c.y
        contextMenuApp = copyAppPlain(appData)
        contextMenuOpen = true
    }

    function openSettingsMenu(clickX, clickY) {
        previewShowTimer.stop()
        previewHideTimer.stop()
        previewOpen = false
        previewAppId = ""
        bridgeHovered = false
        previewPanelHovered = false
        contextMenuOpen = false
        contextMenuApp = null
        let sx = clickX
        let sy = clickY
        if (dockPos === "bottom") sy = screenObj.height - (dockWin.height - clickY)
        else if (dockPos === "right") sx = screenObj.width - (dockWin.width - clickX)
        settingsAnchorX = sx
        settingsAnchorY = sy
        settingsMenuOpen = true
    }

    // ── Drag & Drop reorder state (pinned items) ────────────────────────────
    property bool dragActive: false
    property int dragFromPinnedIndex: -1
    property int dropTargetPinnedIndex: -1
    property real dragPointerCoord: 0
    property var dragAppData: null

    function startPinnedDrag(slotIdx, pointerCoord, appData) {
        const pinnedIdx = slotIdx - launcherSlotCount
        if (pinnedIdx < 0 || pinnedIdx >= pinnedModel.count) return
        dismissAllOverlays()
        dragActive = true
        dragFromPinnedIndex = pinnedIdx
        dropTargetPinnedIndex = pinnedIdx
        dragPointerCoord = pointerCoord
        dragAppData = copyAppPlain(appData)
    }

    function updatePinnedDrag(pointerCoord) {
        if (!dragActive || pinnedModel.count === 0) return
        dragPointerCoord = pointerCoord
        const step = (rootState.cfgIconSize + 34) + (rootState.cfgSpacing + 2)
        let target = Math.floor(pointerCoord / Math.max(1, step))
        target = Math.max(0, Math.min(pinnedModel.count - 1, target))
        dropTargetPinnedIndex = target
    }

    function finishPinnedDrag() {
        if (dragActive && dragFromPinnedIndex >= 0 && dropTargetPinnedIndex >= 0 && dragFromPinnedIndex !== dropTargetPinnedIndex) {
            const fromApp = pinnedModel.get(dragFromPinnedIndex)
            const toApp = pinnedModel.get(dropTargetPinnedIndex)
            if (fromApp && toApp) {
                rootState.reorderPinned(fromApp.pinKey, toApp.pinKey)
            }
        }
        dragActive = false
        dragFromPinnedIndex = -1
        dropTargetPinnedIndex = -1
        dragAppData = null
        scheduleSmartHide()
    }

    readonly property real capsuleEdgeThickness: isVertical ? dockCapsule.width : dockCapsule.height
    readonly property real dockEdgeOffset: edgeMargin + capsuleEdgeThickness + 8

    // ════════════════════════════════════════════════════════════════════════
    // WINDOW 1: Main Dock Edge Surface (handles ExclusiveZone + Input Mask)
    // ════════════════════════════════════════════════════════════════════════
    PanelWindow {
        id: dockWin
        screen: screenScope.screenObj
        color: "transparent"
        visible: true

        WlrLayershell.namespace: "rhythm-dock"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.layer: {
            if (screenScope.rootState.cfgSmartView && screenScope.dockShown)
                return WlrLayer.Overlay
            if (screenScope.rootState.cfgLayer === "overlay") return WlrLayer.Overlay
            if (screenScope.rootState.cfgLayer === "bottom") return WlrLayer.Bottom
            if (screenScope.rootState.cfgLayer === "background") return WlrLayer.Background
            return WlrLayer.Top
        }

        anchors {
            top: screenScope.dockPos === "top" || screenScope.isVertical
            bottom: screenScope.dockPos === "bottom" || screenScope.isVertical
            left: screenScope.dockPos === "left" || !screenScope.isVertical
            right: screenScope.dockPos === "right" || !screenScope.isVertical
        }

        implicitWidth: screenScope.isVertical
            ? Math.max(12, dockCapsule.width + screenScope.edgeMargin + screenScope.hoverHeadroom)
            : screenScope.screenObj.width
        implicitHeight: screenScope.isVertical
            ? screenScope.screenObj.height
            : Math.max(12, dockCapsule.height + screenScope.edgeMargin + screenScope.hoverHeadroom)

        readonly property bool wantsExclusive: screenScope.rootState.cfgExclusive
            && !screenScope.rootState.cfgSmartView
            && screenScope.dockShown
            && (pinnedModel.count > 0 || runningModel.count > 0 || !screenScope.rootState.cfgNoLauncher)

        exclusionMode: wantsExclusive ? ExclusionMode.Normal : ExclusionMode.Ignore
        WlrLayershell.exclusiveZone: wantsExclusive
            ? Math.max(0, Math.round(screenScope.capsuleEdgeThickness + screenScope.edgeMargin))
            : 0

        mask: Region {
            item: screenScope.dockShown ? dockCapsule : null
            Region {
                item: (screenScope.rootState.cfgSmartView && !screenScope.dockShown && !screenScope.globallyOff && !screenScope.externallyHidden && !screenScope.fullscreenActive)
                    ? edgeWakeStrip
                    : null
                intersection: Intersection.Combine
            }
        }

        // Invisible 4px wake strip at screen edge for SmartView auto-hide
        Item {
            id: edgeWakeStrip
            anchors.left: screenScope.dockPos === "right" ? undefined : parent.left
            anchors.right: screenScope.dockPos === "left" ? undefined : parent.right
            anchors.top: screenScope.dockPos === "bottom" ? undefined : parent.top
            anchors.bottom: screenScope.dockPos === "top" ? undefined : parent.bottom
            width: screenScope.isVertical ? 4 : parent.width
            height: screenScope.isVertical ? parent.height : 4

            HoverHandler {
                onHoveredChanged: {
                    screenScope.edgeHovered = hovered
                    if (hovered) screenScope.touchSmartReveal()
                    else screenScope.scheduleSmartHide()
                }
            }
        }

        readonly property real hiddenSlideDist: screenScope.capsuleEdgeThickness + screenScope.edgeMargin + 36
        property real slideOffset: screenScope.dockShown ? 0 : hiddenSlideDist
        Behavior on slideOffset {
            SpringAnimation { spring: 4.8; damping: 0.48; mass: 0.65 }
        }

        // Classic rust-dock capsule: exact 274x66px (4 apps), subtle color1 border, radius 10
        Rectangle {
            id: dockCapsule
            readonly property int padH: Math.max(4, screenScope.rootState.cfgPadding + 7)
            readonly property int padV: Math.max(4, screenScope.rootState.cfgPadding + 4)
            readonly property int slotSpacing: screenScope.rootState.cfgSpacing + 2

            width: screenScope.isVertical
                ? (contentBox.implicitWidth + padV * 2)
                : (screenScope.rootState.cfgFullScreen
                    ? Math.max(80, parent.width - 2 * screenScope.edgeMargin)
                    : (contentBox.implicitWidth + padH * 2))
            height: screenScope.isVertical
                ? (screenScope.rootState.cfgFullScreen
                    ? Math.max(80, parent.height - 2 * screenScope.edgeMargin)
                    : (contentBox.implicitHeight + padH * 2))
                : (contentBox.implicitHeight + padV * 2)

            anchors.horizontalCenter: screenScope.isVertical ? undefined : parent.horizontalCenter
            anchors.verticalCenter: screenScope.isVertical ? parent.verticalCenter : undefined
            anchors.bottom: screenScope.dockPos === "bottom" ? parent.bottom : undefined
            anchors.top: screenScope.dockPos === "top" ? parent.top : undefined
            anchors.left: screenScope.dockPos === "left" ? parent.left : undefined
            anchors.right: screenScope.dockPos === "right" ? parent.right : undefined

            anchors.bottomMargin: screenScope.dockPos === "bottom" ? (screenScope.edgeMargin - dockWin.slideOffset) : 0
            anchors.topMargin: screenScope.dockPos === "top" ? (screenScope.edgeMargin - dockWin.slideOffset) : 0
            anchors.leftMargin: screenScope.dockPos === "left" ? (screenScope.edgeMargin - dockWin.slideOffset) : 0
            anchors.rightMargin: screenScope.dockPos === "right" ? (screenScope.edgeMargin - dockWin.slideOffset) : 0

            opacity: screenScope.dockShown ? 1.0 : 0.0
            visible: opacity > 0.01 && (pinnedModel.count > 0 || runningModel.count > 0 || !screenScope.rootState.cfgNoLauncher)

            radius: Math.max(4, screenScope.rootState.cfgRadius)
            color: Qt.rgba(
                screenScope.rootState.colBg.r,
                screenScope.rootState.colBg.g,
                screenScope.rootState.colBg.b,
                screenScope.rootState.cfgOpacity
            )
            border.width: 1
            border.color: Qt.rgba(
                screenScope.rootState.colBg.r * 0.65 + screenScope.rootState.colColor1.r * 0.35,
                screenScope.rootState.colBg.g * 0.65 + screenScope.rootState.colColor1.g * 0.35,
                screenScope.rootState.colBg.b * 0.65 + screenScope.rootState.colColor1.b * 0.35,
                0.95
            )

            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 220 } }
            Behavior on border.color { ColorAnimation { duration: 220 } }

            // Right-click on dock background opens Dock Quick-Settings Menu
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: function(mouse) {
                    const pt = mapToItem(dockWin.contentItem, mouse.x, mouse.y)
                    screenScope.openSettingsMenu(pt.x, pt.y)
                }
            }

            HoverHandler {
                blocking: false
                onHoveredChanged: {
                    screenScope.dockHovered = hovered
                    if (hovered) {
                        screenScope.touchSmartReveal()
                    } else {
                        screenScope.hoveredSlotIndex = -1
                        screenScope.schedulePreviewHideIfNeeded()
                        screenScope.scheduleSmartHide()
                    }
                }
            }

            // Main Dock Content Flow (seamless single strip like original rust-dock)
            GridLayout {
                id: contentBox
                anchors.centerIn: parent
                columns: screenScope.isVertical ? 1 : 3
                rows: screenScope.isVertical ? 3 : 1
                columnSpacing: dockCapsule.slotSpacing
                rowSpacing: dockCapsule.slotSpacing

                // 1. Optional Launcher Button
                Rectangle {
                    id: launcherBtn
                    visible: !screenScope.rootState.cfgNoLauncher
                    Layout.preferredWidth: screenScope.rootState.cfgIconSize + 34
                    Layout.preferredHeight: screenScope.rootState.cfgIconSize + 30
                    radius: Math.max(4, screenScope.rootState.cfgRadius - 2)
                    color: launcherMouse.containsMouse
                        ? Qt.rgba(screenScope.rootState.colColor1.r, screenScope.rootState.colColor1.g, screenScope.rootState.colColor1.b, 0.28)
                        : "transparent"
                    border.width: 0
                    Behavior on color { ColorAnimation { duration: 130 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰀻"
                        color: launcherMouse.containsMouse ? screenScope.rootState.colAccent : screenScope.rootState.colFg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Math.round(screenScope.rootState.cfgIconSize * 0.78)
                        scale: launcherMouse.containsMouse ? 1.12 : 1.0
                        Behavior on scale { SpringAnimation { spring: 5.5; damping: 0.45; mass: 0.5 } }
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }

                    MouseArea {
                        id: launcherMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onContainsMouseChanged: {
                            if (containsMouse) {
                                screenScope.previewShowTimer.stop()
                                screenScope.previewOpen = false
                                screenScope.previewAppId = ""
                                const c = screenScope.measureItemCenter(launcherBtn)
                                screenScope.hoveredSlotIndex = 0
                                screenScope.hoveredAppId = ""
                                screenScope.hoveredAppName = screenScope.rootState.t("dock_launcher", "Applications")
                                screenScope.hoveredAnchorX = c.x
                                screenScope.hoveredAnchorY = c.y
                            } else if (screenScope.hoveredSlotIndex === 0) {
                                screenScope.hoveredSlotIndex = -1
                                screenScope.hoveredAppName = ""
                            }
                        }
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.RightButton) {
                                const pt = launcherBtn.mapToItem(dockWin.contentItem, mouse.x, mouse.y)
                                screenScope.openSettingsMenu(pt.x, pt.y)
                            } else {
                                screenScope.rootState.launchAppLauncher()
                            }
                        }
                    }
                }

                // 2. Pinned Apps Container
                Grid {
                    id: pinnedGrid
                    columns: screenScope.isVertical ? 1 : Math.max(1, pinnedModel.count)
                    rows: screenScope.isVertical ? Math.max(1, pinnedModel.count) : 1
                    spacing: dockCapsule.slotSpacing
                    visible: pinnedModel.count > 0

                    Repeater {
                        model: pinnedModel

                        delegate: DockAppItem {
                            required property var model
                            required property int index

                            rootState: screenScope.rootState
                            appData: model
                            slotIndex: screenScope.launcherSlotCount + index
                            hoveredSlotIndex: screenScope.hoveredSlotIndex
                            isVertical: screenScope.isVertical
                            dockPosition: screenScope.dockPos
                            iconSize: screenScope.rootState.cfgIconSize
                            buttonRadius: Math.max(4, screenScope.rootState.cfgRadius - 2)
                            isDraggingAny: screenScope.dragActive
                            isDraggedSelf: screenScope.dragActive && screenScope.dragFromPinnedIndex === index
                            isDropTarget: screenScope.dragActive && screenScope.dropTargetPinnedIndex === index

                            onHoveredChangedItem: function(inside, src) {
                                screenScope.handleAppHover(inside, slotIndex, model, src)
                            }
                            onLeftClicked: function(src) {
                                screenScope.rootState.focusOrLaunch(screenScope.copyAppPlain(model), screenScope.screenName)
                            }
                            onMiddleClicked: screenScope.rootState.launchApp(screenScope.copyAppPlain(model))
                            onRightClicked: function(src) {
                                screenScope.openContextMenu(model, src)
                            }
                            onWheelScrolled: function(delta) {
                                screenScope.rootState.cycleAppWindow(model.id, delta > 0 ? -1 : 1, screenScope.screenName)
                            }
                            onDragStarted: function(sIdx, coord, data) {
                                screenScope.startPinnedDrag(sIdx, coord, data)
                            }
                            onDragMoved: function(coord) {
                                screenScope.updatePinnedDrag(coord)
                            }
                            onDragFinished: screenScope.finishPinnedDrag()
                        }
                    }
                }

                // 3. Non-Pinned Running Apps Section (seamless flow like original rust-dock)
                Grid {
                    id: runningGrid
                    columns: screenScope.isVertical ? 1 : Math.max(1, runningModel.count)
                    rows: screenScope.isVertical ? Math.max(1, runningModel.count) : 1
                    spacing: dockCapsule.slotSpacing
                    visible: runningModel.count > 0

                    Repeater {
                        model: runningModel

                        delegate: DockAppItem {
                            required property var model
                            required property int index

                            rootState: screenScope.rootState
                            appData: model
                            slotIndex: screenScope.launcherSlotCount + pinnedModel.count + index
                            hoveredSlotIndex: screenScope.hoveredSlotIndex
                            isVertical: screenScope.isVertical
                            dockPosition: screenScope.dockPos
                            iconSize: screenScope.rootState.cfgIconSize
                            buttonRadius: Math.max(4, screenScope.rootState.cfgRadius - 2)
                            isDraggingAny: screenScope.dragActive
                            isDraggedSelf: false
                            isDropTarget: false

                            onHoveredChangedItem: function(inside, src) {
                                screenScope.handleAppHover(inside, slotIndex, model, src)
                            }
                            onLeftClicked: function(src) {
                                screenScope.rootState.focusOrLaunch(screenScope.copyAppPlain(model), screenScope.screenName)
                            }
                            onMiddleClicked: screenScope.rootState.launchApp(screenScope.copyAppPlain(model))
                            onRightClicked: function(src) {
                                screenScope.openContextMenu(model, src)
                            }
                            onWheelScrolled: function(delta) {
                                screenScope.rootState.cycleAppWindow(model.id, delta > 0 ? -1 : 1, screenScope.screenName)
                            }
                        }
                    }
                }
            }

            // Floating dragged icon ghost (outside Grid so it never creates an extra cell)
            Item {
                visible: screenScope.dragActive && screenScope.dragAppData !== null
                z: 100
                width: screenScope.rootState.cfgIconSize + 12
                height: screenScope.rootState.cfgIconSize + 12
                readonly property point pinnedOrigin: pinnedGrid.mapToItem(dockCapsule, 0, 0)
                x: screenScope.isVertical
                    ? (dockCapsule.width - width) / 2
                    : pinnedOrigin.x + Math.max(-6, Math.min(pinnedGrid.width - width + 6, screenScope.dragPointerCoord - width / 2))
                y: screenScope.isVertical
                    ? pinnedOrigin.y + Math.max(-6, Math.min(pinnedGrid.height - height + 6, screenScope.dragPointerCoord - height / 2))
                    : (dockCapsule.height - height) / 2 - 6

                Rectangle {
                    anchors.fill: parent
                    radius: Math.max(8, screenScope.rootState.cfgRadius)
                    color: Qt.rgba(screenScope.rootState.colBg.r, screenScope.rootState.colBg.g, screenScope.rootState.colBg.b, 0.94)
                    border.width: 1.5
                    border.color: screenScope.rootState.colAccent

                    IconImage {
                        anchors.centerIn: parent
                        width: screenScope.rootState.cfgIconSize
                        height: screenScope.rootState.cfgIconSize
                        implicitSize: screenScope.rootState.cfgIconSize
                        mipmap: true
                        source: screenScope.dragAppData
                            ? screenScope.rootState.resolveIconSource(screenScope.dragAppData.icon, screenScope.dragAppData.id)
                            : ""
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // WINDOW 2: Overlay Layer for Live Previews, Tooltips & Context Menus
    // ════════════════════════════════════════════════════════════════════════
    PanelWindow {
        id: overlayWin
        screen: screenScope.screenObj
        color: "transparent"
        visible: screenScope.previewOpen
            || screenScope.contextMenuOpen
            || screenScope.settingsMenuOpen
            || screenScope.tooltipVisible
            || previewPopup.opacity > 0.01
            || contextMenu.opacity > 0.01
            || settingsMenu.opacity > 0.01

        WlrLayershell.namespace: "rhythm-dock-overlay"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: (screenScope.contextMenuOpen || screenScope.settingsMenuOpen)
            ? WlrKeyboardFocus.OnDemand
            : WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Click anywhere outside or press Escape to dismiss menus cleanly
        HyprlandFocusGrab {
            active: screenScope.contextMenuOpen || screenScope.settingsMenuOpen
            windows: [overlayWin, dockWin]
            onCleared: {
                screenScope.contextMenuOpen = false
                screenScope.contextMenuApp = null
                screenScope.settingsMenuOpen = false
                screenScope.scheduleSmartHide()
            }
        }

        // Non-null root Region whenever a popup or menu is open
        mask: Region {
            item: {
                if (screenScope.contextMenuOpen || screenScope.settingsMenuOpen) return outsideCatcher
                if (screenScope.previewOpen) return previewPopup
                return null
            }

            Region {
                item: (screenScope.previewOpen && !screenScope.contextMenuOpen && !screenScope.settingsMenuOpen)
                    ? hoverBridge
                    : null
                intersection: Intersection.Combine
            }
        }

        // Fullscreen click catcher when a menu is open
        Item {
            id: outsideCatcher
            anchors.fill: parent
            visible: screenScope.contextMenuOpen || screenScope.settingsMenuOpen

            FocusScope {
                anchors.fill: parent
                focus: screenScope.contextMenuOpen || screenScope.settingsMenuOpen
                Keys.onEscapePressed: {
                    screenScope.contextMenuOpen = false
                    screenScope.contextMenuApp = null
                    screenScope.settingsMenuOpen = false
                    screenScope.scheduleSmartHide()
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: {
                    screenScope.contextMenuOpen = false
                    screenScope.contextMenuApp = null
                    screenScope.settingsMenuOpen = false
                    screenScope.scheduleSmartHide()
                }
            }
        }

        // Seamless hover bridge strictly spanning ONLY the 8px gap (never overlapping dock icons!)
        Item {
            id: hoverBridge
            visible: screenScope.previewOpen && !screenScope.contextMenuOpen && !screenScope.settingsMenuOpen
            x: {
                if (screenScope.dockPos === "left") return Math.max(0, previewPopup.targetX - 10)
                if (screenScope.dockPos === "right") return previewPopup.targetX + previewPopup.width - 2
                return previewPopup.targetX
            }
            y: {
                if (screenScope.dockPos === "top") return Math.max(0, previewPopup.targetY - 10)
                if (screenScope.dockPos === "bottom") return previewPopup.targetY + previewPopup.height - 2
                return previewPopup.targetY
            }
            width: screenScope.isVertical ? 12 : previewPopup.width
            height: screenScope.isVertical ? previewPopup.height : 12

            HoverHandler {
                blocking: false
                onHoveredChanged: {
                    screenScope.bridgeHovered = hovered
                    if (hovered) {
                        previewHideTimer.stop()
                        screenScope.touchSmartReveal()
                    } else {
                        screenScope.schedulePreviewHideIfNeeded()
                    }
                }
            }
        }

        // 1. Live GPU Window Preview Strip
        WindowPreviewPopup {
            id: previewPopup
            rootState: screenScope.rootState
            shown: screenScope.previewOpen && !screenScope.contextMenuOpen && !screenScope.settingsMenuOpen
            windowsModel: previewModel
            appIcon: screenScope.previewAppIcon
            appName: screenScope.previewAppName
            dockPosition: screenScope.dockPos
            isVertical: screenScope.isVertical
            compactPreview: screenScope.rootState.cfgCompactPreview
            radiusBase: screenScope.rootState.cfgRadius
            anchorCenterX: screenScope.previewAnchorX
            anchorCenterY: screenScope.previewAnchorY
            dockEdgeOffset: screenScope.dockEdgeOffset
            screenWidth: overlayWin.width
            screenHeight: overlayWin.height

            onPreviewHoveredChanged: function(inside) {
                screenScope.previewPanelHovered = inside
                if (inside) {
                    previewHideTimer.stop()
                    screenScope.touchSmartReveal()
                } else {
                    screenScope.schedulePreviewHideIfNeeded()
                }
            }
            onWindowActivated: function(addr) {
                const winObj = screenScope.rootState.windowByAddress(addr)
                screenScope.previewOpen = false
                screenScope.previewAppId = ""
                screenScope.bridgeHovered = false
                screenScope.previewPanelHovered = false
                if (winObj) screenScope.rootState.activateWindow(winObj)
            }
            onWindowMinimizeToggled: function(addr) {
                const winObj = screenScope.rootState.windowByAddress(addr)
                if (winObj) screenScope.rootState.toggleMinimizeWindow(winObj)
            }
            onWindowClosed: function(addr) {
                const winObj = screenScope.rootState.windowByAddress(addr)
                if (winObj) screenScope.rootState.closeWindow(winObj)
            }
        }

        // 2. Floating Pill Tooltip
        Rectangle {
            id: tooltipPill
            readonly property real padX: 10
            readonly property real padY: 5
            width: tooltipLabel.implicitWidth + padX * 2
            height: tooltipLabel.implicitHeight + padY * 2
            radius: 8

            readonly property real tx: {
                if (screenScope.dockPos === "left") return screenScope.dockEdgeOffset + 4
                if (screenScope.dockPos === "right") return overlayWin.width - screenScope.dockEdgeOffset - width - 4
                return Math.max(10, Math.min(overlayWin.width - width - 10, screenScope.hoveredAnchorX - width / 2))
            }
            readonly property real ty: {
                if (screenScope.dockPos === "top") return screenScope.dockEdgeOffset + 4
                if (screenScope.dockPos === "bottom") return overlayWin.height - screenScope.dockEdgeOffset - height - 4
                return Math.max(10, Math.min(overlayWin.height - height - 10, screenScope.hoveredAnchorY - height / 2))
            }

            x: tx
            y: ty
            opacity: screenScope.tooltipVisible ? 1.0 : 0.0
            visible: opacity > 0.01

            color: Qt.rgba(screenScope.rootState.colBg.r, screenScope.rootState.colBg.g, screenScope.rootState.colBg.b, 0.95)
            border.width: 1
            border.color: Qt.rgba(screenScope.rootState.colAccent.r, screenScope.rootState.colAccent.g, screenScope.rootState.colAccent.b, 0.28)

            Behavior on opacity { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            Behavior on x { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

            Text {
                id: tooltipLabel
                anchors.centerIn: parent
                text: screenScope.hoveredAppName
                color: screenScope.rootState.colFg
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }

        // 3. Right-Click App Context Menu
        AppContextMenu {
            id: contextMenu
            rootState: screenScope.rootState
            shown: screenScope.contextMenuOpen
            appData: screenScope.contextMenuApp
            dockPosition: screenScope.dockPos
            anchorCenterX: screenScope.contextAnchorX
            anchorCenterY: screenScope.contextAnchorY
            dockEdgeOffset: screenScope.dockEdgeOffset
            screenWidth: overlayWin.width
            screenHeight: overlayWin.height

            onCloseRequested: {
                screenScope.contextMenuOpen = false
                screenScope.contextMenuApp = null
                screenScope.scheduleSmartHide()
            }
            onNewWindowRequested: function(app) {
                screenScope.rootState.launchAppNewWindow(app)
            }
            onDesktopActionRequested: function(actObj) {
                if (actObj && typeof actObj.execute === "function") {
                    actObj.execute()
                }
            }
            onPinToggled: function(app) {
                if (app.pinned) screenScope.rootState.unpinApp(app.pinKey || app.id)
                else screenScope.rootState.pinApp(app.id)
            }
            onMinimizeAllRequested: function(app) {
                screenScope.rootState.minimizeAllForApp(app.id)
            }
            onRestoreAllRequested: function(app) {
                screenScope.rootState.restoreAllForApp(app.id)
            }
            onCloseAllRequested: function(app) {
                screenScope.rootState.closeAllForApp(app.id)
            }
        }

        // 4. Right-Click Dock Background Quick-Settings Menu
        DockSettingsMenu {
            id: settingsMenu
            rootState: screenScope.rootState
            shown: screenScope.settingsMenuOpen
            dockPosition: screenScope.dockPos
            anchorCenterX: screenScope.settingsAnchorX
            anchorCenterY: screenScope.settingsAnchorY
            dockEdgeOffset: screenScope.dockEdgeOffset
            screenWidth: overlayWin.width
            screenHeight: overlayWin.height

            onCloseRequested: {
                screenScope.settingsMenuOpen = false
                screenScope.scheduleSmartHide()
            }
        }
    }
}
