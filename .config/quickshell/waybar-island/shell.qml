import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications

ShellRoot {
    id: root

    property bool expanded: false
    property string activePlayerTitle: ""
    property string activePlayerArtist: ""
    property bool isPlaying: false
    property real volumeLevel: 0.5
    property real brightnessLevel: 0.5

    // Notification state
    property bool notifActive: false
    property string notifAppName: ""
    property string notifSummary: ""
    property string notifBody: ""
    property string notifIcon: ""
    property var currentNotification: null

    NotificationServer {
        id: notifServer
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true

        onNotification: function(n) {
            // Do Not Disturb: suppress banner toast, keep server-side history
            if (root.dndEnabled) {
                n.tracked = true
                return
            }
            n.tracked = true
            const app = (n.appName || "").toLowerCase()
            const summary = (n.summary || "").toLowerCase()
            const body = (n.body || "").toLowerCase()
            const full = `${app} ${summary} ${body}`

            // Filtrar y silenciar notificaciones repetitivas de cambio de wallpaper / pywal / sync
            const ignoredKeywords = [
                "pywal", "wallpaper", "sincroniz", "fondo", "sddm", "waybar",
                "oh my posh", "colores", "tema actualizado", "aplicando",
                "nm-applet", "p10k", "recargado", "reiniciado", "mako"
            ]
            const isSpam = ignoredKeywords.some(kw => full.includes(kw))
            if (isSpam) {
                n.dismiss()
                return
            }

            root.currentNotification = n
            root.notifAppName = n.appName || "System"
            root.notifSummary = n.summary || ""
            root.notifBody = n.body || ""
            root.notifIcon = n.appIcon || ""
            root.notifActive = true
            notifTimer.restart()
        }
    }

    Timer {
        id: notifTimer
        interval: 4500
        onTriggered: {
            root.notifActive = false
        }
    }

    property bool islandVisible: true
    property var hiddenScreens: ({})
    property int currentTab: 0 // 0 = Control & Sistema, 1 = Ajustes Hyprland
    property int controlSubView: 0 // 0 = Main, 1 = Wi-Fi, 2 = Bluetooth, 3 = Audio Output, 4 = System Update (OTA)

    // OTA System Update state
    property var otaData: ({
        status: "up_to_date",
        status_text: "System is up to date",
        has_updates: false,
        current_version: "v1.0.0",
        latest_version: "v1.0.0",
        dotfiles_branch: "main",
        dotfiles_behind: 0,
        dotfiles_ahead: 0,
        dotfiles_hash: "",
        remote_hash: "",
        pacman_updates: 0,
        pacman_list: [],
        kernel: "",
        last_checked: ""
    })
    property bool otaChecking: false
    property bool otaUpdating: false
    property string otaChangelogText: ""

    // Hyprland live state
    property bool hyprAnim: true
    property bool hyprBlur: true
    property bool hyprShadow: true
    property int hyprRounding: 10
    property int hyprGaps: 10
    property bool perfMode: false

    // Hardware / Connectivity state
    property string wifiSsid: "Wi-Fi"
    property bool wifiEnabled: true
    property bool btEnabled: false
    property string kbLayout: "US"
    property bool isMuted: false

    property var wifiList: []
    property var btDevices: []
    property var audioSinks: []
    property var audioApps: []
    property string activeSinkName: "Default Output"
    property bool nightLightEnabled: false
    property bool caffeineEnabled: false
    property bool powerSaverEnabled: false
    property bool dndEnabled: false
    property var recState: ({ recording: false, pid: 0, elapsed: 0, elapsed_str: "00:00", file: "" })
    property var privacyState: ({ mic: false, cam: false })
    property var sysStats: ({ cpu_pct: 0, ram_used: "0G", ram_total: "0G", ram_pct: 0, disk_used: "0G", disk_pct: 0 })
    property bool wifiScanning: false
    property bool btScanning: false
    property string selectedWifiSsid: ""
    property bool showUnnamedBtDevices: false
    readonly property var namedBtDevices: (root.btDevices || []).filter(d => d.has_name || d.paired || d.connected)
    readonly property var unnamedBtDevices: (root.btDevices || []).filter(d => !d.has_name && !d.paired && !d.connected)

    function refreshAllStates() {
        volProc.running = true
        briProc.running = true
        wifiProc.running = true
        btProc.running = true
        perfProc.running = true
        kbProc.running = true
        muteProc.running = true
        audioSinksProc.running = true
        audioAppsProc.running = true
        recStatusProc.running = true
        sysStatsProc.running = true
        nightLightCheckProc.running = true
        caffeineCheckProc.running = true
        powerSaveCheckProc.running = true
        dndCheckProc.running = true
        hyprStatusProc.running = true
        otaStatusProc.running = true
        if (root.controlSubView === 1) wifiListProc.running = true
        if (root.controlSubView === 2) btStatusProc.running = true
        if (root.controlSubView === 3) {
            audioSinksProc.running = true
            audioAppsProc.running = true
        }
        if (root.controlSubView === 4) {
            otaStatusProc.running = true
            otaChangelogProc.running = true
        }
    }

    onCurrentTabChanged: {
        if (root.controlSubView !== 4) root.controlSubView = 0
        if (root.currentTab === 1) hyprStatusProc.running = true
    }

    onExpandedChanged: {
        if (root.expanded) {
            if (root.controlSubView !== 4) root.controlSubView = 0
            root.refreshAllStates()
        } else {
            root.runCmd("$HOME/.local/bin/notch-bt-helper stop_scan")
        }
    }

    onControlSubViewChanged: {
        if (root.controlSubView === 2) {
            btStatusProc.running = true
            if (root.btEnabled) {
                root.runCmd("$HOME/.local/bin/notch-bt-helper scan")
            }
        } else {
            root.runCmd("$HOME/.local/bin/notch-bt-helper stop_scan")
        }
        if (root.controlSubView === 4) {
            otaStatusProc.running = true
            otaChangelogProc.running = true
        }
    }

    IpcHandler {
        target: "settings"
        function toggle(): string {
            root.expanded = !root.expanded
            if (root.expanded) {
                root.currentTab = 1
                root.controlSubView = 0
                root.refreshAllStates()
            }
            return root.expanded ? "expanded" : "collapsed"
        }
        function open(): string {
            root.expanded = true
            root.currentTab = 1
            root.controlSubView = 0
            root.refreshAllStates()
            return "expanded"
        }
        function open_wifi(): string {
            root.expanded = true
            root.currentTab = 0
            root.controlSubView = 1
            root.wifiScanning = true
            wifiListProc.running = true
            root.refreshAllStates()
            return "expanded"
        }
        function open_bt(): string {
            root.expanded = true
            root.currentTab = 0
            root.controlSubView = 2
            root.btScanning = true
            btStatusProc.running = true
            root.refreshAllStates()
            return "expanded"
        }
        function open_hypr(): string {
            root.expanded = true
            root.currentTab = 1
            root.controlSubView = 0
            root.refreshAllStates()
            return "expanded"
        }
        function open_audio(): string {
            root.expanded = true
            root.currentTab = 0
            root.controlSubView = 3
            audioSinksProc.running = true
            root.refreshAllStates()
            return "expanded"
        }
        function close(): string {
            root.expanded = false
            return "collapsed"
        }
    }

    IpcHandler {
        target: "island"
        function toggle(): string {
            root.expanded = !root.expanded
            if (root.expanded) {
                root.currentTab = 0
                root.controlSubView = 0
                root.refreshAllStates()
            }
            return root.expanded ? "expanded" : "collapsed"
        }
        function openWifi(): string {
            root.expanded = true
            root.currentTab = 0
            root.controlSubView = 1
            root.wifiScanning = true
            wifiListProc.running = true
            return "wifi"
        }
        function openBluetooth(): string {
            root.expanded = true
            root.currentTab = 0
            root.controlSubView = 2
            root.btScanning = true
            btStatusProc.running = true
            return "bluetooth"
        }
        function openAudio(): string {
            root.expanded = true
            root.currentTab = 0
            root.controlSubView = 3
            audioSinksProc.running = true
            return "audio"
        }
        function openControl(): string {
            root.expanded = true
            root.currentTab = 0
            root.controlSubView = 0
            root.refreshAllStates()
            return "control"
        }
        function openHyprland(): string {
            root.expanded = true
            root.currentTab = 1
            root.controlSubView = 0
            root.refreshAllStates()
            return "hyprland"
        }
        function openOta(): string {
            root.controlSubView = 4
            root.expanded = true
            otaStatusProc.running = true
            otaChangelogProc.running = true
            return "ota"
        }
        function collapse(): string {
            root.expanded = false
            return "collapsed"
        }
        function hide(screenName: string): string {
            root.expanded = false
            if (!screenName || screenName === "" || screenName === "all") {
                root.islandVisible = false
                root.hiddenScreens = {}
            } else {
                let hs = Object.assign({}, root.hiddenScreens)
                hs[screenName] = true
                root.hiddenScreens = hs
            }
            return "hidden"
        }
        function reveal(screenName: string): string {
            if (!screenName || screenName === "" || screenName === "all") {
                root.islandVisible = true
                root.hiddenScreens = {}
            } else {
                let hs = Object.assign({}, root.hiddenScreens)
                delete hs[screenName]
                root.hiddenScreens = hs
            }
            return "revealed"
        }
    }

    IpcHandler {
        target: "theme"
        function reload(): string {
            walFile.reload()
            root._walReloadCounter++
            return "reloaded"
        }
    }

    // Live pywal colors
    property int _walReloadCounter: 0

    FileView {
        id: walFile
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: {
            walFile.reload()
            root._walReloadCounter++
        }
        onTextChanged: {
            root._walReloadCounter++
        }
    }

    readonly property var walData: {
        const _dep = root._walReloadCounter
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

    // Current time & date exactly matching Waybar format: {:%H:%M:%S  -  %A, %d}
    property string timeStr: ""
    property string dayStr: ""
    property string clockStr: ""
    property string dateStr: ""

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const now = new Date()
            const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
            
            const dayName = days[now.getDay()]
            const dayNum = now.getDate()
            const monthName = months[now.getMonth()]
            
            const hours = String(now.getHours()).padStart(2, '0')
            const mins = String(now.getMinutes()).padStart(2, '0')
            const secs = String(now.getSeconds()).padStart(2, '0')

            root.timeStr = `${hours}:${mins}:${secs}`
            root.dayStr = `${dayName}, ${dayNum}`
            // Exact Waybar format: {:%H:%M:%S  -  %A, %d}
            root.clockStr = `${root.timeStr}  -  ${root.dayStr}`
            root.dateStr = `${dayName}, ${monthName} ${dayNum}`
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

    // Process helper to run quick commands with full environment
    function runCmd(cmd) {
        const envInit = "export XDG_RUNTIME_DIR=\"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}\"; " +
                        "[ -z \"$WAYLAND_DISPLAY\" ] && export WAYLAND_DISPLAY=\"wayland-1\"; " +
                        "[ -z \"$HYPRLAND_INSTANCE_SIGNATURE\" ] && export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t \"$XDG_RUNTIME_DIR/hypr/\" 2>/dev/null | grep -v '\\.lock$' | head -n1); "
        Quickshell.execDetached(["bash", "-c", envInit + cmd])
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
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim()
                root.isMuted = raw.includes("[MUTED]")
                const match = raw.match(/Volume:\s+([0-9.]+)/)
                if (match && match[1]) {
                    const val = parseFloat(match[1])
                    if (!isNaN(val)) root.volumeLevel = Math.min(1.0, val)
                }
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

    Process {
        id: wifiProc
        command: ["bash", "-c", "nmcli radio wifi && nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2 | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                root.wifiEnabled = (lines[0] || "").trim() === "enabled"
                const ssid = (lines[1] || "").trim()
                if (!root.wifiEnabled) {
                    root.wifiSsid = "Disabled"
                } else if (ssid.length > 0) {
                    root.wifiSsid = ssid
                } else {
                    root.wifiSsid = "Disconnected"
                }
            }
        }
    }

    Process {
        id: btProc
        command: ["bash", "-c", "bluetoothctl show 2>/dev/null | grep -i 'powered' | awk '{print $2}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.btEnabled = text.trim() === "yes"
            }
        }
    }

    Process {
        id: perfProc
        command: ["bash", "-c", "[ -f /tmp/hypr_performance_mode ] && echo 'perf' || echo 'normal'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.perfMode = text.trim() === "perf"
            }
        }
    }

    Process {
        id: kbProc
        command: ["bash", "-c", "hyprctl devices -j 2>/dev/null | jq -r '.keyboards[] | select(.main==true) | .active_keymap' 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const val = text.trim()
                root.kbLayout = val.length > 0 && val !== "null" ? val : "US"
            }
        }
    }

    Process {
        id: muteProc
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q 'MUTED' && echo true || echo false"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.isMuted = text.trim() === "true"
            }
        }
    }

    Process {
        id: wifiListProc
        command: ["bash", "-c", "$HOME/.local/bin/notch-wifi-helper list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiScanning = false
                try {
                    root.wifiList = JSON.parse(text.trim())
                } catch(e) {
                    root.wifiList = []
                }
            }
        }
    }

    Process {
        id: wifiRescanProc
        command: ["bash", "-c", "$HOME/.local/bin/notch-wifi-helper rescan"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiScanning = false
                try {
                    root.wifiList = JSON.parse(text.trim())
                } catch(e) {
                    root.wifiList = []
                }
            }
        }
    }

    Process {
        id: btStatusProc
        command: ["bash", "-c", "$HOME/.local/bin/notch-bt-helper status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim())
                    root.btEnabled = data.powered || false
                    root.btScanning = data.discovering || false
                    root.btDevices = data.devices || []
                } catch(e) {
                    root.btDevices = []
                }
            }
        }
    }

    Timer {
        id: btPollTimer
        interval: 1500
        repeat: true
        running: root.expanded && root.controlSubView === 2 && root.btEnabled
        onTriggered: {
            if (!btStatusProc.running) {
                btStatusProc.running = true
            }
        }
    }

    Timer {
        id: btDebounceSyncTimer
        interval: 350
        repeat: false
        onTriggered: {
            btStatusProc.running = true
            btProc.running = true
        }
    }

    Process {
        id: audioSinksProc
        command: ["bash", "-c", "$HOME/.local/bin/notch-audio-helper list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text.trim())
                    root.audioSinks = list
                    const active = list.find(s => s.active)
                    if (active) {
                        root.activeSinkName = active.name
                    }
                } catch(e) {
                    root.audioSinks = []
                }
            }
        }
    }

    Process {
        id: audioAppsProc
        command: ["bash", "-c", "$HOME/.local/bin/notch-audio-helper apps"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.audioApps = JSON.parse(text.trim())
                } catch(e) {
                    root.audioApps = []
                }
            }
        }
    }

    Process {
        id: recStatusProc
        command: ["bash", "-c", "$HOME/.local/bin/screen-recorder-helper status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.recState = JSON.parse(text.trim())
                } catch(e) {}
            }
        }
    }

    Timer {
        id: recPollTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            recStatusProc.running = true
        }
    }

    Process {
        id: privacyStatusProc
        command: ["bash", "-c", "$HOME/.local/bin/privacy-status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.privacyState = JSON.parse(text.trim())
                } catch(e) {}
            }
        }
    }

    Timer {
        id: privacyPollTimer
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            privacyStatusProc.running = true
        }
    }

    Process {
        id: sysStatsProc
        command: ["bash", "-c", "$HOME/.local/bin/notch-sys-stats"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.sysStats = JSON.parse(text.trim())
                } catch(e) {}
            }
        }
    }

    Process {
        id: nightLightCheckProc
        command: ["bash", "-c", "$HOME/.local/bin/toggle-nightlight status"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.nightLightEnabled = text.trim() === "on"
            }
        }
    }

    Process {
        id: caffeineCheckProc
        command: ["bash", "-c", "$HOME/.local/bin/toggle-caffeine status"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.caffeineEnabled = text.trim() === "on"
            }
        }
    }

    Process {
        id: dndCheckProc
        command: ["bash", "-c", "$HOME/.local/bin/toggle-dnd status"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.dndEnabled = text.trim() === "on"
            }
        }
    }

    Timer {
        id: togglesPollTimer
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            nightLightCheckProc.running = true
            caffeineCheckProc.running = true
            powerSaveCheckProc.running = true
            dndCheckProc.running = true
            }
    }

    Process {
        id: powerSaveCheckProc
        command: ["bash", "-c", "$HOME/.local/bin/toggle-powersave status"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.powerSaverEnabled = text.trim() === "on"
            }
        }
    }

    Process {
        id: hyprStatusProc
        command: ["bash", "-c", "$HOME/.local/bin/notch-hypr-helper status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim())
                    root.hyprAnim = data.anim
                    root.hyprBlur = data.blur
                    root.hyprShadow = data.shadow
                    root.hyprRounding = data.rounding
                    root.hyprGaps = data.gaps
                    root.perfMode = data.perf
                } catch(e) {}
            }
        }
    }

    Timer {
        id: hyprRefreshTimer
        interval: 350
        repeat: false
        onTriggered: hyprStatusProc.running = true
    }

    Process {
        id: otaStatusProc
        command: ["bash", "-c", "$HOME/.local/bin/system-ota status --json"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.otaChecking = false
                try {
                    const data = JSON.parse(text.trim())
                    root.otaData = data
                } catch(e) {}
            }
        }
    }

    Process {
        id: otaCheckProc
        command: ["bash", "-c", "$HOME/.local/bin/system-ota check --json"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.otaChecking = false
                try {
                    const data = JSON.parse(text.trim())
                    root.otaData = data
                } catch(e) {}
            }
        }
    }

    Process {
        id: otaChangelogProc
        command: ["bash", "-c", "$HOME/.local/bin/system-ota changelog"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.otaChangelogText = text.trim()
            }
        }
    }

    Process {
        id: otaUpdateProc
        command: ["bash", "-c", "$HOME/.local/bin/system-ota update"]
        onExited: {
            root.otaUpdating = false
            otaStatusProc.running = true
        }
    }

    Timer {
        id: statsTimer
        interval: 3000
        repeat: true
        running: root.expanded && root.currentTab === 0 && root.controlSubView === 0
        onTriggered: {
            sysStatsProc.running = true
        }
    }

    // Main Dynamic Island Windows (Multi-monitor support via Variants)
    Variants {
        id: islandVariants
        model: Quickshell.screens

        PanelWindow {
            id: islandWin
            required property var modelData
            screen: modelData
            visible: root.islandVisible && !root.hiddenScreens[modelData.name]

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

        aboveWindows: true
        WlrLayershell.layer: WlrLayer.Overlay
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

        // Dynamic Island container fused to top screen edge (Mac notch style)
        Item {
            id: capsule
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: 1.0

            readonly property real ala: 16
            width: root.expanded ? 660 : (root.notifActive ? 460 : (collapsedContent.width + capsule.ala * 2 + 36))
            height: root.expanded ? (root.controlSubView !== 0 ? 560 : (root.currentTab === 1 ? 580 : 700)) : (root.notifActive ? 56 : 36)

            Behavior on width {
                NumberAnimation {
                    id: capsuleWidthAnim
                    duration: 320
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                NumberAnimation {
                    id: capsuleHeightAnim
                    duration: 320
                    easing.type: Easing.OutCubic
                }
            }

            // Silueta con esquinas invertidas (alas) que funden con el borde superior de la pantalla
            SiluetaIsla {
                id: silueta
                anchors.fill: parent
                ala: capsule.ala
                cuerpoRadio: root.expanded ? 24 : (root.notifActive ? 16 : 12)
                relleno: root.colBg
                lado: "arriba"

                Behavior on cuerpoRadio {
                    NumberAnimation { duration: 200 }
                }
            }

            // Area de contenido (dentro del cuerpo de la isla, entre las alas)
            Item {
                id: contentArea
                anchors.fill: parent
                anchors.leftMargin: capsule.ala
                anchors.rightMargin: capsule.ala
                clip: true

            // ─────────────────────────────────────────────────────────────
            // COLLAPSED VIEW (Waybar-style integrated clock / media pill)
            // ─────────────────────────────────────────────────────────────
            Item {
                id: collapsedView
                anchors.fill: parent
                visible: opacity > 0
                opacity: (!root.expanded && !root.notifActive) ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.expanded = !root.expanded
                        if (root.expanded) {
                            root.controlSubView = 0
                            root.refreshAllStates()
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: parent.containsMouse ? root.colSurfaceHover : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                Row {
                    id: collapsedContent
                    anchors.centerIn: parent
                    spacing: 8

                    // Media indicator if playing
                    Row {
                        visible: root.isPlaying && root.activePlayerTitle !== ""
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: "󰝚"
                            color: root.colAccent
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
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
                            maximumLineCount: 1
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            width: 1
                            height: 12
                            color: root.colMuted
                            opacity: 0.4
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Privacy indicator in collapsed pill (mic green, camera orange)
                    Row {
                        visible: root.privacyState.mic || root.privacyState.cam
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: root.privacyState.cam ? "#FFA726" : "#66BB6A"
                            anchors.verticalCenter: parent.verticalCenter
                            SequentialAnimation on opacity {
                                running: root.privacyState.mic || root.privacyState.cam
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 600 }
                                NumberAnimation { to: 1.0; duration: 600 }
                            }
                        }

                        Text {
                            text: root.privacyState.cam ? "󰄀" : "󰍬"
                            color: root.privacyState.cam ? "#FFA726" : "#66BB6A"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            width: 1
                            height: 12
                            color: root.colMuted
                            opacity: 0.4
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Recording indicator in collapsed pill
                    Row {
                        visible: root.recState.recording
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: "#EF5350"
                            anchors.verticalCenter: parent.verticalCenter
                            SequentialAnimation on opacity {
                                running: root.recState.recording
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.2; duration: 500 }
                                NumberAnimation { to: 1.0; duration: 500 }
                            }
                        }

                        Text {
                            text: "REC " + (root.recState.elapsed_str || "00:00")
                            color: "#EF5350"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            width: 1
                            height: 12
                            color: root.colMuted
                            opacity: 0.4
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // DND indicator in collapsed pill
                    Row {
                        visible: root.dndEnabled
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: "#E57373"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "󰂛"
                            color: "#E57373"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            width: 1
                            height: 12
                            color: root.colMuted
                            opacity: 0.4
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Night Light indicator in collapsed pill
                    Row {
                        visible: root.nightLightEnabled
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: "#FFCA28"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "󰖔"
                            color: "#FFCA28"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            width: 1
                            height: 12
                            color: root.colMuted
                            opacity: 0.4
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Caffeine indicator in collapsed pill
                    Row {
                        visible: root.caffeineEnabled
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: "#D9A05B"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "󰅶"
                            color: "#D9A05B"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            width: 1
                            height: 12
                            color: root.colMuted
                            opacity: 0.4
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Clock (exact Waybar format: 17:04:12  -  Sábado, 26)
                    Text {
                        text: root.clockStr
                        color: root.colAccent
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Indicator icon
                    Text {
                        text: root.expanded ? "󰅃" : "󰅀"
                        color: root.colMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        opacity: 0.6
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // ─────────────────────────────────────────────────────────────
            // NOTIFICATION BANNER VIEW (Dynamic Island Banner)
            // ─────────────────────────────────────────────────────────────
            Item {
                id: notifView
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                visible: opacity > 0
                opacity: (!root.expanded && root.notifActive) ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.currentNotification) {
                            root.currentNotification.dismiss()
                        }
                        root.notifActive = false
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.topMargin: 2
                    anchors.bottomMargin: 4
                    spacing: 10

                    // Notification Icon Bubble
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.2)
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            anchors.centerIn: parent
                            text: "󰂚"
                            color: root.colAccent
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                        }
                    }

                    // Content Details
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: root.notifAppName.toUpperCase()
                                color: root.colAccent
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "ahora"
                                color: root.colMuted
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 9
                            }
                        }

                        Text {
                            text: root.notifSummary || "Notificación"
                            color: root.colFg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: root.notifBody !== ""
                            text: root.notifBody
                            color: root.colMuted
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                        }
                    }

                    // Dismiss X icon
                    Text {
                        text: "󰅖"
                        color: root.colMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        opacity: 0.7
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
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                anchors.topMargin: 32
                anchors.bottomMargin: 20
                visible: opacity > 0
                opacity: root.expanded ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 14

                    // ── 1. HEADER ROW (Date, Time, Notch grabber, Close/Lock/Power) ──
                    RowLayout {
                        Layout.fillWidth: true

                        ColumnLayout {
                            spacing: 1
                            Layout.preferredWidth: 150
                            Text {
                                text: root.dateStr
                                color: root.colFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }
                            Text {
                                text: root.timeStr
                                color: root.colAccent
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Notch close indicator / grabber
                        Rectangle {
                            width: 36
                            height: 4
                            radius: 2
                            color: root.colMuted
                            opacity: 0.5
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Item { Layout.fillWidth: true }

                        // Session & Close buttons
                        RowLayout {
                            spacing: 6
                            Layout.preferredWidth: 150
                            Layout.alignment: Qt.AlignRight

                            Rectangle {
                                width: 28; height: 28; radius: 14
                                color: root.colSurface
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰌾"
                                    color: root.colFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.expanded = false; root.runCmd("hyprlock"); }
                                }
                            }

                            Rectangle {
                                width: 28; height: 28; radius: 14
                                color: root.colSurface
                                Text {
                                    anchors.centerIn: parent
                                    text: "⏻"
                                    color: "#ff5555"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.expanded = false; root.runCmd("~/.local/bin/powermenu-with-monitor-detection"); }
                                }
                            }

                            Rectangle {
                                width: 28; height: 28; radius: 14
                                color: root.colSurface
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    color: root.colFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.expanded = false
                                }
                            }
                        }
                    }

                    // ── 2. SEGMENTED TABS (2 TABS: CONTROL & HYPRLAND) ──
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 12
                        visible: root.controlSubView === 0

                        // Tab 0: Control & Sistema
                        Rectangle {
                            width: 200
                            height: 34
                            radius: 17
                            color: root.currentTab === 0 ? root.colAccent : root.colSurface
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: "󰒓"
                                    color: root.currentTab === 0 ? root.colBg : root.colAccent
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                }
                                Text {
                                    text: "Control & System"
                                    color: root.currentTab === 0 ? root.colBg : root.colFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.currentTab = 0
                                    root.controlSubView = 0
                                }
                            }
                        }

                        // Tab 1: Hyprland Settings
                        Rectangle {
                            width: 200
                            height: 34
                            radius: 17
                            color: root.currentTab === 1 ? root.colAccent : root.colSurface
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: "󰣇"
                                    color: root.currentTab === 1 ? root.colBg : root.colAccent
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                }
                                Text {
                                    text: "Hyprland Settings"
                                    color: root.currentTab === 1 ? root.colBg : root.colFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.currentTab = 1
                                    root.controlSubView = 0
                                }
                            }
                        }
                    }

                    // ── 3. TAB 0: CONTROL & SISTEMA ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        visible: root.currentTab === 0 && root.controlSubView === 0

                        // Media Player Card
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 74
                            radius: 14
                            color: root.colSurface
                            border.color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 12

                                Rectangle {
                                    width: 48; height: 48; radius: 10
                                    color: Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.2)
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.isPlaying ? "󰝚" : "󰝛"
                                        color: root.colAccent
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 20
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        text: root.activePlayerTitle || "Nothing Playing"
                                        color: root.colFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: root.activePlayerArtist || (root.primaryPlayer?.identity ?? "Media")
                                        color: root.colMuted
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                RowLayout {
                                    spacing: 8
                                    Rectangle {
                                        width: 30; height: 30; radius: 15; color: "transparent"
                                        Text { anchors.centerIn: parent; text: "󰒮"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.primaryPlayer?.previous() || root.runCmd("playerctl previous") }
                                    }
                                    Rectangle {
                                        width: 34; height: 34; radius: 17; color: root.colAccent
                                        Text { anchors.centerIn: parent; text: root.isPlaying ? "󰏤" : "󰐊"; color: root.colBg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16 }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.primaryPlayer?.playPause() || root.runCmd("playerctl play-pause") }
                                    }
                                    Rectangle {
                                        width: 30; height: 30; radius: 15; color: "transparent"
                                        Text { anchors.centerIn: parent; text: "󰒭"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.primaryPlayer?.next() || root.runCmd("playerctl next") }
                                    }
                                }
                            }
                        }

                        // Quick Toggles Grid (Wi-Fi, Bluetooth, Rust-Dock, Wallpaper) - Material 3 Dual-Action Pills
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            rowSpacing: 10
                            columnSpacing: 10

                            // Wi-Fi Tile (Material 3 Split Pill)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                height: 54
                                radius: 16
                                color: root.wifiEnabled ? root.colAccent : root.colSurface
                                border.color: root.wifiEnabled ? root.colAccent : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 180 } }

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0

                                    // Main Left Action: Toggle Power
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 6
                                            spacing: 10

                                            // Icon container / badge
                                            Rectangle {
                                                width: 34; height: 34; radius: 17
                                                color: root.wifiEnabled ? Qt.rgba(0, 0, 0, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.wifiEnabled ? "󰖩" : "󰖪"
                                                    color: root.wifiEnabled ? root.colBg : root.colFg
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 17
                                                }
                                            }

                                            // Text Column
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1
                                                Text {
                                                    text: "Wi-Fi"
                                                    color: root.wifiEnabled ? root.colBg : root.colFg
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 11
                                                    font.weight: Font.Bold
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    text: root.wifiEnabled ? (root.wifiSsid || "Connected") : "Disabled"
                                                    color: root.wifiEnabled ? Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.8) : root.colMuted
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 9
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            onClicked: mouse => {
                                                if (mouse.button === Qt.RightButton) {
                                                    root.controlSubView = 1
                                                    root.wifiScanning = true
                                                    wifiListProc.running = true
                                                } else {
                                                    if (root.wifiEnabled) {
                                                        root.runCmd("nmcli radio wifi off")
                                                        root.wifiEnabled = false
                                                        root.wifiSsid = "Disabled"
                                                    } else {
                                                        root.runCmd("nmcli radio wifi on")
                                                        root.wifiEnabled = true
                                                        root.wifiSsid = "Connecting..."
                                                        wifiProc.running = true
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Subtle Vertical Separator
                                    Rectangle {
                                        width: 1
                                        height: 24
                                        Layout.alignment: Qt.AlignVCenter
                                        color: root.wifiEnabled ? Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.25) : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.12)
                                    }

                                    // Right Expand Action: Dedicated Chevron Button
                                    Rectangle {
                                        width: 38
                                        Layout.fillHeight: true
                                        color: wifiChevHover.containsMouse ? (root.wifiEnabled ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(255, 255, 255, 0.08)) : "transparent"
                                        radius: 16

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰅂"
                                            color: root.wifiEnabled ? root.colBg : root.colFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 14
                                        }

                                        MouseArea {
                                            id: wifiChevHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.controlSubView = 1
                                                root.wifiScanning = true
                                                wifiListProc.running = true
                                            }
                                        }
                                    }
                                }
                            }

                            // Bluetooth Tile (Material 3 Split Pill)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                height: 54
                                radius: 16
                                color: root.btEnabled ? root.colAccent : root.colSurface
                                border.color: root.btEnabled ? root.colAccent : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 180 } }

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0

                                    // Main Left Action: Toggle Power
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 6
                                            spacing: 10

                                            // Icon container / badge
                                            Rectangle {
                                                width: 34; height: 34; radius: 17
                                                color: root.btEnabled ? Qt.rgba(0, 0, 0, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.btEnabled ? "󰂯" : "󰂲"
                                                    color: root.btEnabled ? root.colBg : root.colFg
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 17
                                                }
                                            }

                                            // Text Column
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1
                                                Text {
                                                    text: "Bluetooth"
                                                    color: root.btEnabled ? root.colBg : root.colFg
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 11
                                                    font.weight: Font.Bold
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    text: root.btEnabled ? (root.btDevices.filter(d => d.connected).length > 0 ? root.btDevices.filter(d => d.connected)[0].name : "Enabled") : "Disabled"
                                                    color: root.btEnabled ? Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.8) : root.colMuted
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 9
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            onClicked: mouse => {
                                                if (mouse.button === Qt.RightButton) {
                                                    root.controlSubView = 2
                                                    btStatusProc.running = true
                                                } else {
                                                    const newState = !root.btEnabled
                                                    root.btEnabled = newState
                                                    if (newState) {
                                                        root.runCmd("$HOME/.local/bin/notch-bt-helper on")
                                                    } else {
                                                        root.runCmd("$HOME/.local/bin/notch-bt-helper off")
                                                    }
                                                    btDebounceSyncTimer.restart()
                                                }
                                            }
                                        }
                                    }

                                    // Subtle Vertical Separator
                                    Rectangle {
                                        width: 1
                                        height: 24
                                        Layout.alignment: Qt.AlignVCenter
                                        color: root.btEnabled ? Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.25) : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.12)
                                    }

                                    // Right Expand Action: Dedicated Chevron Button
                                    Rectangle {
                                        width: 38
                                        Layout.fillHeight: true
                                        color: btChevHover.containsMouse ? (root.btEnabled ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(255, 255, 255, 0.08)) : "transparent"
                                        radius: 16

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰅂"
                                            color: root.btEnabled ? root.colBg : root.colFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 14
                                        }

                                        MouseArea {
                                            id: btChevHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.controlSubView = 2
                                                root.btScanning = true
                                                btStatusProc.running = true
                                            }
                                        }
                                    }
                                }
                            }

                            // Audio Output Tile (Material 3 Split Pill)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                height: 54
                                radius: 16
                                color: root.isMuted ? root.colSurface : Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.15)
                                border.color: root.isMuted ? Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08) : root.colAccent
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 180 } }

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0

                                    // Main Left Action: Toggle Mute
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 6
                                            spacing: 10

                                            Rectangle {
                                                width: 34; height: 34; radius: 17
                                                color: root.isMuted ? root.colSurface : root.colAccent
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.isMuted ? "󰝟" : "󰓃"
                                                    color: root.isMuted ? "#ff5555" : root.colBg
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 17
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1
                                                Text {
                                                    text: "Audio Output"
                                                    color: root.colFg
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 11
                                                    font.weight: Font.Bold
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    text: root.isMuted ? "Muted" : root.activeSinkName
                                                    color: root.colMuted
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 9
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.isMuted = !root.isMuted
                                                root.runCmd("pamixer -t")
                                                muteProc.running = true
                                            }
                                        }
                                    }

                                    // Subtle Vertical Separator
                                    Rectangle {
                                        width: 1
                                        height: 24
                                        Layout.alignment: Qt.AlignVCenter
                                        color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.12)
                                    }

                                    // Right Expand Action: Dedicated Chevron Button to Audio Subview
                                    Rectangle {
                                        width: 38
                                        Layout.fillHeight: true
                                        color: audioChevHover.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : "transparent"
                                        radius: 16

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰅂"
                                            color: root.colFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 14
                                        }

                                        MouseArea {
                                            id: audioChevHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.controlSubView = 3
                                                audioSinksProc.running = true
                                            }
                                        }
                                    }
                                }
                            }

                            // Rust-Dock Tile (Material 3 Card)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                height: 54
                                radius: 16
                                color: dockHover.containsMouse ? root.colSurfaceHover : root.colSurface
                                border.color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Rectangle {
                                        width: 34; height: 34; radius: 17
                                        color: Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.15)
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰻂"
                                            color: root.colAccent
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 17
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: "Rust-Dock"
                                            color: root.colFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: "Toggle bottom dock"
                                            color: root.colMuted
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: dockHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.runCmd("~/.local/bin/rust-dock-toggle-all")
                                }
                            }

                            // Night Light Tile (Material 3 Card)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                height: 54
                                radius: 16
                                color: root.nightLightEnabled ? root.colAccent : (nightHover.containsMouse ? root.colSurfaceHover : root.colSurface)
                                border.color: root.nightLightEnabled ? root.colAccent : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 180 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Rectangle {
                                        width: 34; height: 34; radius: 17
                                        color: root.nightLightEnabled ? Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.25) : Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.15)
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰖔"
                                            color: root.nightLightEnabled ? root.colBg : root.colAccent
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 17
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: "Night Light"
                                            color: root.nightLightEnabled ? root.colBg : root.colFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: root.nightLightEnabled ? "4500K Active" : "Inactive"
                                            color: root.nightLightEnabled ? Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.8) : root.colMuted
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: nightHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.nightLightEnabled = !root.nightLightEnabled
                                        root.runCmd("~/.local/bin/toggle-nightlight")
                                    }
                                }
                            }

                            // Caffeine Tile (Material 3 Card)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                height: 54
                                radius: 16
                                color: root.caffeineEnabled ? root.colAccent : (caffeineHover.containsMouse ? root.colSurfaceHover : root.colSurface)
                                border.color: root.caffeineEnabled ? root.colAccent : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 180 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Rectangle {
                                        width: 34; height: 34; radius: 17
                                        color: root.caffeineEnabled ? Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.25) : Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.15)
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰅶"
                                            color: root.caffeineEnabled ? root.colBg : root.colAccent
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 17
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: "Caffeine"
                                            color: root.caffeineEnabled ? root.colBg : root.colFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: root.caffeineEnabled ? "Awake Mode" : "Normal Sleep"
                                            color: root.caffeineEnabled ? Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.8) : root.colMuted
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: caffeineHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.caffeineEnabled = !root.caffeineEnabled
                                        root.runCmd("~/.local/bin/toggle-caffeine")
                                    }
                                }
                            }

                            // Power Saver Tile (Material 3 Card)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                height: 54
                                radius: 16
                                color: root.powerSaverEnabled ? root.colAccent : (powerHover.containsMouse ? root.colSurfaceHover : root.colSurface)
                                border.color: root.powerSaverEnabled ? root.colAccent : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 180 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Rectangle {
                                        width: 34; height: 34; radius: 17
                                        color: root.powerSaverEnabled ? Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.25) : Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.15)
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰌪"
                                            color: root.powerSaverEnabled ? root.colBg : root.colAccent
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 17
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: "Power Saver"
                                            color: root.powerSaverEnabled ? root.colBg : root.colFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: root.powerSaverEnabled ? "Eco Active" : "Disabled"
                                            color: root.powerSaverEnabled ? Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.8) : root.colMuted
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: powerHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.powerSaverEnabled = !root.powerSaverEnabled
                                        root.runCmd("~/.local/bin/toggle-powersave")
                                    }
                                }
                            }

                            // Performance Tile (Material 3 Card)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                height: 54
                                radius: 16
                                color: root.perfMode ? root.colAccent : (perfHoverTab0.containsMouse ? root.colSurfaceHover : root.colSurface)
                                border.color: root.perfMode ? root.colAccent : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 180 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Rectangle {
                                        width: 34; height: 34; radius: 17
                                        color: root.perfMode ? Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.25) : Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.15)
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰓅"
                                            color: root.perfMode ? root.colBg : root.colAccent
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 17
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: "Performance"
                                            color: root.perfMode ? root.colBg : root.colFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: root.perfMode ? "Max Boost" : "Balanced"
                                            color: root.perfMode ? Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.8) : root.colMuted
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: perfHoverTab0
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.perfMode = !root.perfMode
                                        root.runCmd("$HOME/.local/bin/notch-hypr-helper toggle-perf")
                                        hyprRefreshTimer.restart()
                                    }
                                }
                            }
                            // Do Not Disturb Tile (Material 3 Card)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                height: 54
                                radius: 16
                                color: root.dndEnabled ? root.colAccent : (dndHover.containsMouse ? root.colSurfaceHover : root.colSurface)
                                border.color: root.dndEnabled ? root.colAccent : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 180 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Rectangle {
                                        width: 34; height: 34; radius: 17
                                        color: root.dndEnabled ? Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.25) : Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.15)
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰂛"
                                            color: root.dndEnabled ? root.colBg : root.colAccent
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 17
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: "Do Not Disturb"
                                            color: root.dndEnabled ? root.colBg : root.colFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: root.dndEnabled ? "Silenced" : "Sounds On"
                                            color: root.dndEnabled ? Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.8) : root.colMuted
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: dndHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.dndEnabled = !root.dndEnabled
                                        root.runCmd("~/.local/bin/toggle-dnd")
                                    }
                                }
                            }
                        }

                        // Sliders Card (Material 3 Pill Sliders: Volume & Brightness)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            // Volume Pill Slider
                            Rectangle {
                                id: volSliderTrack
                                Layout.fillWidth: true
                                height: 42
                                radius: 21
                                color: root.colSurface
                                border.color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                                border.width: 1
                                clip: true

                                // Progress Fill Bar
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: Math.max(parent.height, parent.width * (root.isMuted ? 0 : root.volumeLevel))
                                    radius: 21
                                    color: root.isMuted ? root.colMuted : root.colAccent
                                    visible: !root.isMuted && root.volumeLevel > 0
                                    Behavior on width {
                                        enabled: !volMouseArea.pressed && !capsuleWidthAnim.running && root.expanded
                                        NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 14
                                    spacing: 8

                                    // Inset Icon Button
                                    Text {
                                        text: root.isMuted ? "󰝟" : (root.volumeLevel > 0.5 ? "󰕾" : (root.volumeLevel > 0 ? "󰖀" : "󰕿"))
                                        color: root.isMuted ? "#ff5555" : (root.volumeLevel > 0 ? root.colBg : root.colAccent)
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 18
                                        font.weight: Font.Bold
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: "Volume"
                                        color: (!root.isMuted && root.volumeLevel > 0.85) ? root.colBg : root.colFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        opacity: (!root.isMuted && root.volumeLevel > 0.85) ? 0.9 : 0.7
                                        visible: !root.isMuted
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    Text {
                                        text: root.isMuted ? "Muted" : (Math.round(root.volumeLevel * 100) + "%")
                                        color: (!root.isMuted && root.volumeLevel > 0.85) ? root.colBg : (root.isMuted ? "#ff5555" : root.colFg)
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                }

                                MouseArea {
                                    id: volMouseArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        if (mouse.x < 36) {
                                            root.isMuted = !root.isMuted
                                            root.runCmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
                                        } else {
                                            const p = Math.max(0, Math.min(1, mouse.x / width))
                                            root.volumeLevel = p
                                            root.isMuted = false
                                            root.runCmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + Math.round(p * 100) + "%")
                                        }
                                    }
                                    onPositionChanged: mouse => {
                                        if (pressed) {
                                            const p = Math.max(0, Math.min(1, mouse.x / width))
                                            root.volumeLevel = p
                                            root.isMuted = false
                                            root.runCmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + Math.round(p * 100) + "%")
                                        }
                                    }
                                }
                            }

                            // Brightness Pill Slider
                            Rectangle {
                                id: brightSliderTrack
                                Layout.fillWidth: true
                                height: 42
                                radius: 21
                                color: root.colSurface
                                border.color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                                border.width: 1
                                clip: true

                                // Progress Fill Bar
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: Math.max(parent.height, parent.width * root.brightnessLevel)
                                    radius: 21
                                    color: root.colAccent
                                    Behavior on width {
                                        enabled: !brightMouseArea.pressed && !capsuleWidthAnim.running && root.expanded
                                        NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 14
                                    spacing: 8

                                    // Inset Icon Button
                                    Text {
                                        text: root.brightnessLevel > 0.6 ? "󰃠" : (root.brightnessLevel > 0.25 ? "󰃟" : "󰃞")
                                        color: root.colBg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 18
                                        font.weight: Font.Bold
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: "Brightness"
                                        color: root.brightnessLevel > 0.85 ? root.colBg : root.colFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        opacity: root.brightnessLevel > 0.85 ? 0.9 : 0.7
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    Text {
                                        text: Math.round(root.brightnessLevel * 100) + "%"
                                        color: root.brightnessLevel > 0.85 ? root.colBg : root.colFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                }

                                MouseArea {
                                    id: brightMouseArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        const p = Math.max(0.05, Math.min(1, mouse.x / width))
                                        root.brightnessLevel = p
                                        root.runCmd("brightnessctl set " + Math.round(p * 100) + "%")
                                    }
                                    onPositionChanged: mouse => {
                                        if (pressed) {
                                            const p = Math.max(0.05, Math.min(1, mouse.x / width))
                                            root.brightnessLevel = p
                                            root.runCmd("brightnessctl set " + Math.round(p * 100) + "%")
                                        }
                                    }
                                }
                            }
                        }

                        // Hardware Monitoring Card (Material 3 Segmented Stats)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 52
                            radius: 14
                            color: root.colSurface
                            border.color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 12

                                // CPU Stat
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    RowLayout {
                                        spacing: 6
                                        Text { text: "󰻠"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                                        Text { text: "CPU"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold }
                                        Item { Layout.fillWidth: true }
                                        Text { text: (root.sysStats?.cpu_pct ?? 0) + "%"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true; height: 4; radius: 2
                                        color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.1)
                                        Rectangle {
                                            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                            width: Math.max(0, Math.min(parent.width, parent.width * ((root.sysStats?.cpu_pct ?? 0) / 100.0)))
                                            radius: 2; color: root.colAccent
                                            Behavior on width { NumberAnimation { duration: 200 } }
                                        }
                                    }
                                }

                                // Separator
                                Rectangle { width: 1; height: 26; color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.1) }

                                // RAM Stat
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    RowLayout {
                                        spacing: 6
                                        Text { text: "󰍛"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                                        Text { text: "RAM " + (root.sysStats?.ram_used ?? ""); color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold; elide: Text.ElideRight }
                                        Item { Layout.fillWidth: true }
                                        Text { text: (root.sysStats?.ram_pct ?? 0) + "%"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true; height: 4; radius: 2
                                        color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.1)
                                        Rectangle {
                                            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                            width: Math.max(0, Math.min(parent.width, parent.width * ((root.sysStats?.ram_pct ?? 0) / 100.0)))
                                            radius: 2; color: root.colAccent
                                            Behavior on width { NumberAnimation { duration: 200 } }
                                        }
                                    }
                                }

                                // Separator
                                Rectangle { width: 1; height: 26; color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.1) }

                                // Disk Stat
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    RowLayout {
                                        spacing: 6
                                        Text { text: "󰋊"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                                        Text { text: "SSD " + (root.sysStats?.disk_used ?? ""); color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold; elide: Text.ElideRight }
                                        Item { Layout.fillWidth: true }
                                        Text { text: (root.sysStats?.disk_pct ?? 0) + "%"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true; height: 4; radius: 2
                                        color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.1)
                                        Rectangle {
                                            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                            width: Math.max(0, Math.min(parent.width, parent.width * ((root.sysStats?.disk_pct ?? 0) / 100.0)))
                                            radius: 2; color: root.colAccent
                                            Behavior on width { NumberAnimation { duration: 200 } }
                                        }
                                    }
                                }
                            }
                        }

                        // Bottom Action Chips (Material 3 Pills)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true; height: 36; radius: 18; color: root.colSurface
                                border.color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08); border.width: 1
                                RowLayout { anchors.centerIn: parent; spacing: 5
                                    Text { text: "󰈊"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                                    Text { text: "Picker"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.expanded = false; root.runCmd("hyprpicker -a"); } }
                            }

                            Rectangle {
                                Layout.fillWidth: true; height: 36; radius: 18; color: root.colSurface
                                border.color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08); border.width: 1
                                RowLayout { anchors.centerIn: parent; spacing: 5
                                    Text { text: "󰸉"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                                    Text { text: "Gallery"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.expanded = false; root.runCmd("~/.local/bin/wallpaper-gallery"); } }
                            }

                            Rectangle {
                                Layout.fillWidth: true; height: 36; radius: 18; color: root.colSurface
                                border.color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08); border.width: 1
                                RowLayout { anchors.centerIn: parent; spacing: 5
                                    Text { text: "󰑐"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                                    Text { text: "Random"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.runCmd("~/.local/bin/wallpaper-changer-with-waybar-sync") }
                            }

                            Rectangle {
                                Layout.fillWidth: true; height: 36; radius: 18
                                color: root.recState.recording ? Qt.rgba(239/255, 83/255, 80/255, 0.25) : root.colSurface
                                border.color: root.recState.recording ? "#EF5350" : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                                border.width: root.recState.recording ? 1.5 : 1
                                RowLayout { anchors.centerIn: parent; spacing: 5
                                    Text {
                                        text: root.recState.recording ? "󰓛" : "󰕧"
                                        color: root.recState.recording ? "#EF5350" : root.colAccent
                                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                                    }
                                    Text {
                                        text: root.recState.recording ? root.recState.elapsed_str : "Record"
                                        color: root.recState.recording ? "#EF5350" : root.colFg
                                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.runCmd("$HOME/.local/bin/screen-recorder-helper toggle")
                                        recStatusProc.running = true
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true; height: 36; radius: 18; color: root.colSurface
                                border.color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08); border.width: 1
                                RowLayout { anchors.centerIn: parent; spacing: 5
                                    Text { text: "󰌌"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                                    Text { text: root.kbLayout; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.runCmd("~/.local/bin/toggle-keyboard-layout"); kbProc.running = true; } }
                            }

                            Rectangle {
                                Layout.fillWidth: true; height: 36; radius: 18; color: root.colSurface
                                border.color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08); border.width: 1
                                RowLayout { anchors.centerIn: parent; spacing: 5
                                    Text { text: "󰈮"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                                    Text { text: "Tasks"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.expanded = false; root.runCmd("kitty -e htop"); } }
                            }
                        }
                    }

                    // ── 3. SUBSECCIÓN: REDES WI-FI (CONTROL) ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        visible: root.controlSubView === 1

                        // Sub-header with back button
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                width: 100
                                height: 32
                                radius: 16
                                color: root.colSurface
                                border.color: root.colBorder
                                border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        text: "󰁍"
                                        color: root.colAccent
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 14
                                    }
                                    Text {
                                        text: "Back"
                                        color: root.colFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.controlSubView = 0
                                }
                            }

                            Text {
                                text: "Available Wi-Fi Networks"
                                color: root.colFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                font.weight: Font.Bold
                            }

                            Item { Layout.fillWidth: true }
                        }

                        // Header card: Wi-Fi master switch & quick buttons
                        Rectangle {
                            Layout.fillWidth: true
                            height: 60
                            radius: 14
                            color: root.colSurface
                            border.color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12

                                Rectangle {
                                    width: 36; height: 36; radius: 18
                                    color: root.wifiEnabled ? root.colAccent : root.colSurface
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.wifiEnabled ? "󰖩" : "󰖪"
                                        color: root.wifiEnabled ? root.colBg : root.colFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 18
                                    }
                                }

                                ColumnLayout {
                                    spacing: 2
                                    Layout.fillWidth: true
                                    Text {
                                        text: "Wi-Fi"
                                        color: root.colFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                    }
                                    Text {
                                        text: root.wifiEnabled ? (root.wifiSsid !== "Disabled" && root.wifiSsid !== "Disconnected" ? ("Connected to: " + root.wifiSsid) : "Enabled") : "Disabled"
                                        color: root.colMuted
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                RowLayout {
                                    Layout.alignment: Qt.AlignRight
                                    spacing: 8

                                    // Rescan button
                                    Rectangle {
                                        width: 32; height: 32; radius: 16
                                        color: root.wifiScanning ? root.colAccent : Qt.rgba(255, 255, 255, 0.08)
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰑐"
                                            color: root.wifiScanning ? root.colBg : root.colFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 14
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.wifiScanning = true
                                                wifiRescanProc.running = true
                                            }
                                        }
                                    }

                                    // Advanced GUI button
                                    Rectangle {
                                        width: 32; height: 32; radius: 16
                                        color: Qt.rgba(255, 255, 255, 0.08)
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰒓"
                                            color: root.colFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 14
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.expanded = false
                                                root.runCmd("nm-connection-editor")
                                            }
                                        }
                                    }

                                    // Master Toggle Pill
                                    Rectangle {
                                        width: 68; height: 32; radius: 16
                                        color: root.wifiEnabled ? root.colAccent : root.colSurface
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: root.wifiEnabled ? "ON" : "OFF"
                                            color: root.wifiEnabled ? root.colBg : root.colFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.wifiEnabled) {
                                                    root.runCmd("nmcli radio wifi off")
                                                    root.wifiEnabled = false
                                                    root.wifiSsid = "Disabled"
                                                } else {
                                                    root.runCmd("nmcli radio wifi on")
                                                    root.wifiEnabled = true
                                                    root.wifiScanning = true
                                                    wifiListProc.running = true
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Inline Password card
                        Rectangle {
                            Layout.fillWidth: true
                            height: 48
                            radius: 12
                            color: Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.15)
                            border.color: root.colAccent
                            border.width: 1
                            visible: root.selectedWifiSsid !== ""

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                Text {
                                    text: "󰌾 " + root.selectedWifiSsid
                                    color: root.colFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    Layout.preferredWidth: 140
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 32
                                    radius: 8
                                    color: root.colBg
                                    TextInput {
                                        id: wifiPassInput
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        color: root.colFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        echoMode: TextInput.Password
                                        clip: true
                                        onAccepted: connectBtnArea.clicked(null)
                                    }
                                }

                                Rectangle {
                                    width: 76; height: 30; radius: 8
                                    color: root.colAccent
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Connect"
                                        color: root.colBg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                    }
                                    MouseArea {
                                        id: connectBtnArea
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            const pass = wifiPassInput.text
                                            root.runCmd("nmcli dev wifi connect '" + root.selectedWifiSsid + "' password '" + pass + "'")
                                            root.selectedWifiSsid = ""
                                            wifiPassInput.text = ""
                                            wifiListProc.running = true
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 30; height: 30; radius: 8
                                    color: root.colSurface
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰅖"
                                        color: root.colFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.selectedWifiSsid = ""
                                            wifiPassInput.text = ""
                                        }
                                    }
                                }
                            }
                        }

                        // Available Networks List
                        Flickable {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.selectedWifiSsid !== "" ? 300 : 355
                            contentWidth: width
                            contentHeight: wifiNetColumn.implicitHeight
                            clip: true

                            ColumnLayout {
                                id: wifiNetColumn
                                width: parent.width
                                spacing: 6

                                Repeater {
                                    model: root.wifiList
                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        height: 44
                                        radius: 12
                                        color: modelData.connected ? Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.18) : root.colSurface
                                        border.color: modelData.connected ? root.colAccent : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.05)
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 10

                                            Text {
                                                text: modelData.signal >= 75 ? "󰤨" : (modelData.signal >= 50 ? "󰤥" : (modelData.signal >= 25 ? "󰤢" : "󰤟"))
                                                color: modelData.connected ? root.colAccent : root.colFg
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 16
                                            }

                                            ColumnLayout {
                                                spacing: 0
                                                Layout.fillWidth: true
                                                Text {
                                                    text: modelData.ssid
                                                    color: root.colFg
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 11
                                                    font.weight: modelData.connected ? Font.Bold : Font.Normal
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    text: modelData.signal + "%  •  " + modelData.security
                                                    color: root.colMuted
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 9
                                                }
                                            }

                                            Rectangle {
                                                height: 26
                                                width: modelData.connected ? 95 : 72
                                                radius: 8
                                                color: modelData.connected ? Qt.rgba(255, 85, 85, 0.2) : root.colAccent
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.connected ? "Disconnect" : "Connect"
                                                    color: modelData.connected ? "#ff5555" : root.colBg
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (modelData.connected) {
                                                            root.runCmd("~/.local/bin/notch-wifi-helper disconnect")
                                                            wifiListProc.running = true
                                                        } else {
                                                            if (modelData.security === "Open" || modelData.security === "Abierta" || modelData.security === "--") {
                                                                root.runCmd("nmcli dev wifi connect '" + modelData.ssid + "'")
                                                                wifiListProc.running = true
                                                            } else {
                                                                root.selectedWifiSsid = modelData.ssid
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: root.wifiList.length === 0
                                    text: root.wifiScanning ? "Scanning nearby Wi-Fi networks..." : "No Wi-Fi networks found. Click Scan."
                                    color: root.colMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.topMargin: 20
                                }
                            }
                        }
                    }

                    // ── 4. SUBSECCIÓN: BLUETOOTH (CONTROL) ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        visible: root.controlSubView === 2

                        // Sub-header with back button
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                width: 100
                                height: 32
                                radius: 16
                                color: root.colSurface
                                border.color: root.colBorder
                                border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        text: "󰁍"
                                        color: root.colAccent
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 14
                                    }
                                    Text {
                                        text: "Back"
                                        color: root.colFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.controlSubView = 0
                                }
                            }

                            Text {
                                text: "Bluetooth Devices"
                                color: root.colFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                font.weight: Font.Bold
                            }

                            Item { Layout.fillWidth: true }
                        }

                        // Header card: Bluetooth master switch & quick buttons
                        Rectangle {
                            Layout.fillWidth: true
                            height: 60
                            radius: 14
                            color: root.colSurface
                            border.color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12

                                Rectangle {
                                    width: 36; height: 36; radius: 18
                                    color: root.btEnabled ? root.colAccent : root.colSurface
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.btEnabled ? "󰂯" : "󰂲"
                                        color: root.btEnabled ? root.colBg : root.colFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 18
                                    }
                                }

                                ColumnLayout {
                                    spacing: 2
                                    Text {
                                        text: "Bluetooth"
                                        color: root.colFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                    }
                                    Text {
                                        text: !root.btEnabled ? "Disabled" : (root.btScanning ? "Scanning nearby..." : (root.namedBtDevices.length > 0 ? root.namedBtDevices.length + " devices available" : "Ready to pair"))
                                        color: root.colMuted
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                RowLayout {
                                    Layout.alignment: Qt.AlignRight
                                    spacing: 8

                                    // Rescan / Scan toggle button
                                    Rectangle {
                                        width: 32; height: 32; radius: 16
                                        color: root.btScanning ? root.colAccent : Qt.rgba(255, 255, 255, 0.08)
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰑐"
                                            color: root.btScanning ? root.colBg : root.colFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 14
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.btScanning) {
                                                    root.runCmd("$HOME/.local/bin/notch-bt-helper stop_scan")
                                                    root.btScanning = false
                                                } else {
                                                    root.btScanning = true
                                                    root.runCmd("$HOME/.local/bin/notch-bt-helper scan")
                                                    btPollTimer.restart()
                                                }
                                            }
                                        }
                                    }

                                    // Advanced GUI button
                                    Rectangle {
                                        width: 32; height: 32; radius: 16
                                        color: Qt.rgba(255, 255, 255, 0.08)
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰒓"
                                            color: root.colFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 14
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.expanded = false
                                                root.runCmd("blueman-manager")
                                            }
                                        }
                                    }

                                    // Master Toggle Pill
                                    Rectangle {
                                        width: 68; height: 32; radius: 16
                                        color: root.btEnabled ? root.colAccent : root.colSurface
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: root.btEnabled ? "ON" : "OFF"
                                            color: root.btEnabled ? root.colBg : root.colFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                const newState = !root.btEnabled
                                                root.btEnabled = newState
                                                if (newState) {
                                                    root.runCmd("$HOME/.local/bin/notch-bt-helper on")
                                                    root.runCmd("$HOME/.local/bin/notch-bt-helper scan")
                                                } else {
                                                    root.runCmd("$HOME/.local/bin/notch-bt-helper off")
                                                    root.runCmd("$HOME/.local/bin/notch-bt-helper stop_scan")
                                                }
                                                btDebounceSyncTimer.restart()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Disabled state placeholder
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 30
                            spacing: 10
                            Layout.alignment: Qt.AlignHCenter
                            visible: !root.btEnabled

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 56; height: 56; radius: 28
                                color: root.colSurface
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰂲"
                                    color: root.colMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 26
                                }
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Bluetooth is Disabled"
                                color: root.colFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                font.weight: Font.Bold
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Turn on Bluetooth to discover and connect nearby devices"
                                color: root.colMuted
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                            }
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 6
                                width: 160; height: 32; radius: 16
                                color: root.colAccent
                                Text {
                                    anchors.centerIn: parent
                                    text: "Turn On Bluetooth"
                                    color: root.colBg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.btEnabled = true
                                        root.runCmd("$HOME/.local/bin/notch-bt-helper on")
                                        root.runCmd("$HOME/.local/bin/notch-bt-helper scan")
                                        btDebounceSyncTimer.restart()
                                    }
                                }
                            }
                        }

                        // Enabled: Devices List
                        Flickable {
                            visible: root.btEnabled
                            Layout.fillWidth: true
                            Layout.topMargin: 8
                            Layout.preferredHeight: 350
                            contentWidth: width
                            contentHeight: btDevColumn.implicitHeight + 20
                            clip: true

                            ColumnLayout {
                                id: btDevColumn
                                width: parent.width
                                spacing: 6

                                // Scanning banner
                                Rectangle {
                                    visible: root.btScanning
                                    Layout.fillWidth: true
                                    height: 28
                                    radius: 8
                                    color: Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.12)
                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text {
                                            text: "󰑐"
                                            color: root.colAccent
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                        }
                                        Text {
                                            text: "Scanning nearby Bluetooth devices..."
                                            color: root.colAccent
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                        }
                                    }
                                }

                                // Empty state when no named devices
                                Text {
                                    visible: root.namedBtDevices.length === 0 && !root.btScanning
                                    text: "No paired or named devices found. Click Scan above."
                                    color: root.colMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.topMargin: 20
                                }

                                // 1. Named / Paired / Connected Devices
                                Repeater {
                                    model: root.namedBtDevices
                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        height: 48
                                        radius: 12
                                        color: modelData.connected ? Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.18) : root.colSurface
                                        border.color: modelData.connected ? root.colAccent : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.05)
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 10

                                            Text {
                                                text: {
                                                    const t = (modelData.icon || "").toLowerCase()
                                                    const n = (modelData.name || "").toLowerCase()
                                                    if (t.indexOf("audio") >= 0 || t.indexOf("headset") >= 0 || t.indexOf("headphone") >= 0 || n.indexOf("wh-") >= 0 || n.indexOf("airpods") >= 0 || n.indexOf("buds") >= 0) return "󰋋"
                                                    if (t.indexOf("speaker") >= 0 || n.indexOf("speaker") >= 0 || n.indexOf("flip") >= 0 || n.indexOf("charge") >= 0 || n.indexOf("jbl") >= 0) return "󰓃"
                                                    if (t.indexOf("keyboard") >= 0 || n.indexOf("key") >= 0) return "󰌌"
                                                    if (t.indexOf("mouse") >= 0 || n.indexOf("mouse") >= 0) return "󰍽"
                                                    if (t.indexOf("phone") >= 0 || n.indexOf("iphone") >= 0 || n.indexOf("galaxy") >= 0) return "󰄡"
                                                    if (t.indexOf("gamepad") >= 0 || n.indexOf("controller") >= 0 || n.indexOf("dualsense") >= 0 || n.indexOf("xbox") >= 0) return "󰊴"
                                                    if (t.indexOf("computer") >= 0 || n.indexOf("mac") >= 0 || n.indexOf("pc") >= 0) return "󰌢"
                                                    return "󰂯"
                                                }
                                                color: modelData.connected ? root.colAccent : root.colFg
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 18
                                            }

                                            ColumnLayout {
                                                spacing: 0
                                                Layout.fillWidth: true
                                                Text {
                                                    text: modelData.name || modelData.mac
                                                    color: root.colFg
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 11
                                                    font.weight: modelData.connected ? Font.Bold : Font.Normal
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    text: modelData.mac + (modelData.connected ? "  •  Connected" : (modelData.paired ? "  •  Paired" : (modelData.rssi ? "  •  " + modelData.rssi + " dBm" : "  •  Available")))
                                                    color: modelData.connected ? root.colAccent : root.colMuted
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 9
                                                }
                                            }

                                            // Connect / Disconnect / Pair Button
                                            Rectangle {
                                                height: 26
                                                width: modelData.connected ? 95 : (modelData.paired ? 72 : 90)
                                                radius: 8
                                                color: modelData.connected ? Qt.rgba(255, 85, 85, 0.2) : root.colAccent
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.connected ? "Disconnect" : (modelData.paired ? "Connect" : "Pair & Link")
                                                    color: modelData.connected ? "#ff5555" : root.colBg
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (modelData.connected) {
                                                             root.runCmd("$HOME/.local/bin/notch-bt-helper disconnect " + modelData.mac)
                                                        } else {
                                                             root.runCmd("$HOME/.local/bin/notch-bt-helper connect " + modelData.mac)
                                                        }
                                                        btDebounceSyncTimer.restart()
                                                    }
                                                }
                                            }

                                            // Remove / Unpair Button (only for paired or connected)
                                            Rectangle {
                                                visible: modelData.paired || modelData.connected
                                                width: 26; height: 26; radius: 8
                                                color: Qt.rgba(255, 255, 255, 0.06)
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰆴"
                                                    color: root.colMuted
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 11
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        root.runCmd("$HOME/.local/bin/notch-bt-helper remove " + modelData.mac)
                                                        btDebounceSyncTimer.restart()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // 2. Collapsible Unnamed Devices Section
                                Rectangle {
                                    visible: root.unnamedBtDevices.length > 0
                                    Layout.fillWidth: true
                                    Layout.topMargin: 4
                                    height: 32
                                    radius: 8
                                    color: Qt.rgba(255, 255, 255, 0.04)

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 6
                                        Text {
                                            text: root.showUnnamedBtDevices ? "󰅀" : "󰅂"
                                            color: root.colMuted
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 12
                                        }
                                        Text {
                                            text: (root.showUnnamedBtDevices ? "Hide " : "Show ") + root.unnamedBtDevices.length + " unnamed devices (beacons)"
                                            color: root.colMuted
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                            Layout.fillWidth: true
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.showUnnamedBtDevices = !root.showUnnamedBtDevices
                                    }
                                }

                                Repeater {
                                    model: root.showUnnamedBtDevices ? root.unnamedBtDevices : []
                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        height: 42
                                        radius: 10
                                        color: Qt.rgba(255, 255, 255, 0.03)
                                        border.color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.04)
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 8

                                            Text {
                                                text: "󰂯"
                                                color: root.colMuted
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 14
                                            }

                                            ColumnLayout {
                                                spacing: 0
                                                Layout.fillWidth: true
                                                Text {
                                                    text: "Unnamed Device"
                                                    color: root.colMuted
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                }
                                                Text {
                                                    text: modelData.mac + (modelData.rssi ? "  •  " + modelData.rssi + " dBm" : "")
                                                    color: Qt.rgba(root.colMuted.r, root.colMuted.g, root.colMuted.b, 0.6)
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 8
                                                }
                                            }

                                            Rectangle {
                                                height: 24
                                                width: 60
                                                radius: 6
                                                color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.1)
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Pair"
                                                    color: root.colFg
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 9
                                                    font.weight: Font.Bold
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        root.runCmd("$HOME/.local/bin/notch-bt-helper connect " + modelData.mac)
                                                        btDebounceSyncTimer.restart()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── 4. SUBSECCIÓN: DISPOSITIVOS DE AUDIO (CONTROL) ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        visible: root.controlSubView === 3

                        // Sub-header with back button
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                width: 100
                                height: 32
                                radius: 16
                                color: root.colSurface
                                border.color: root.colBorder
                                border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        text: "󰁍"
                                        color: root.colAccent
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 14
                                    }
                                    Text {
                                        text: "Back"
                                        color: root.colFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.controlSubView = 0
                                }
                            }

                            Text {
                                text: "Audio Output Devices"
                                color: root.colFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                font.weight: Font.Bold
                            }

                            Item { Layout.fillWidth: true }

                            // Refresh button
                            Rectangle {
                                width: 32; height: 32; radius: 16
                                color: Qt.rgba(255, 255, 255, 0.08)
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰑐"
                                    color: root.colFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: audioSinksProc.running = true
                                }
                            }

                            // Pavucontrol GUI button
                            Rectangle {
                                width: 32; height: 32; radius: 16
                                color: Qt.rgba(255, 255, 255, 0.08)
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒓"
                                    color: root.colFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.expanded = false
                                        root.runCmd("pavucontrol")
                                    }
                                }
                            }
                        }

                        // Sinks List
                        Flickable {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 380
                            contentWidth: width
                            contentHeight: audioSinksColumn.implicitHeight
                            clip: true

                            ColumnLayout {
                                id: audioSinksColumn
                                width: parent.width
                                spacing: 8

                                Repeater {
                                    model: root.audioSinks
                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        height: 54
                                        radius: 14
                                        color: modelData.active ? Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.18) : (sinkHover.containsMouse ? root.colSurfaceHover : root.colSurface)
                                        border.color: modelData.active ? root.colAccent : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                                        border.width: 1
                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 12

                                            Rectangle {
                                                width: 34; height: 34; radius: 17
                                                color: modelData.active ? root.colAccent : Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.15)
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.active ? "󰓃" : "󰕾"
                                                    color: modelData.active ? root.colBg : root.colAccent
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 16
                                                }
                                            }

                                            ColumnLayout {
                                                spacing: 2
                                                Layout.fillWidth: true
                                                Text {
                                                    text: modelData.name || ("Sink #" + modelData.id)
                                                    color: root.colFg
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 11
                                                    font.weight: modelData.active ? Font.Bold : Font.Normal
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    text: "ID: " + modelData.id + "  •  Volume: " + modelData.volume + "%"
                                                    color: root.colMuted
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 9
                                                }
                                            }

                                            Rectangle {
                                                width: modelData.active ? 72 : 80
                                                height: 30
                                                radius: 15
                                                color: modelData.active ? root.colAccent : Qt.rgba(255, 255, 255, 0.08)

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.active ? "󰄬 Active" : "Select"
                                                    color: modelData.active ? root.colBg : root.colFg
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: sinkHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.runCmd("~/.local/bin/notch-audio-helper set " + modelData.id)
                                                root.activeSinkName = modelData.name
                                                audioSinksProc.running = true
                                                volProc.running = true
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: root.audioSinks.length === 0
                                    text: "No audio output devices detected."
                                    color: root.colMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.topMargin: 20
                                }

                                // ── Application Volume Mixer ──
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 10
                                    Text {
                                        text: "Application Volume Mixer"
                                        color: root.colFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: root.audioApps.length + " active app(s)"
                                        color: root.colMuted
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 9
                                    }
                                }

                                Repeater {
                                    model: root.audioApps
                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        height: 56
                                        radius: 12
                                        color: root.colSurface
                                        border.color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                                        border.width: 1

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 6

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                Text {
                                                    text: modelData.icon || "󰓃"
                                                    color: root.colAccent
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 14
                                                }

                                                Text {
                                                    text: modelData.name || ("App #" + modelData.id)
                                                    color: root.colFg
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }

                                                Text {
                                                    text: (modelData.muted ? "Muted" : (modelData.volume + "%"))
                                                    color: modelData.muted ? "#EF5350" : root.colAccent
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                }

                                                Rectangle {
                                                    width: 24; height: 24; radius: 12
                                                    color: modelData.muted ? Qt.rgba(239/255, 83/255, 80/255, 0.2) : Qt.rgba(255, 255, 255, 0.08)
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData.muted ? "󰝟" : "󰕾"
                                                        color: modelData.muted ? "#EF5350" : root.colFg
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 11
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            root.runCmd("$HOME/.local/bin/notch-audio-helper toggle-app-mute " + modelData.id)
                                                            audioAppsProc.running = true
                                                        }
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                id: appSliderTrack
                                                Layout.fillWidth: true
                                                height: 8
                                                radius: 4
                                                color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.1)

                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.top: parent.top
                                                    anchors.bottom: parent.bottom
                                                    width: Math.max(0, Math.min(parent.width, parent.width * ((modelData.volume || 0) / 100.0)))
                                                    radius: 4
                                                    color: modelData.muted ? root.colMuted : root.colAccent
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onPositionChanged: mouse => {
                                                        if (pressed) {
                                                            let pct = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                                                            root.runCmd("$HOME/.local/bin/notch-audio-helper set-app-vol " + modelData.id + " " + pct)
                                                            modelData.volume = pct
                                                        }
                                                    }
                                                    onClicked: mouse => {
                                                        let pct = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                                                        root.runCmd("$HOME/.local/bin/notch-audio-helper set-app-vol " + modelData.id + " " + pct)
                                                        audioAppsProc.running = true
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: root.audioApps.length === 0
                                    text: "No active application audio streams."
                                    color: root.colMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.topMargin: 4
                                    Layout.bottomMargin: 8
                                }
                            }
                        }
                    }

                    // ── 5. TAB 1: AJUSTES HYPRLAND ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        visible: root.currentTab === 1 && root.controlSubView === 0

                        // Subtitle
                        Text {
                            text: "Real-time Hyprland Compositor Settings"
                            color: root.colMuted
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            Layout.alignment: Qt.AlignHCenter
                        }

                        // 4 Hyprland Toggles (2x2 Grid)
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            rowSpacing: 8
                            columnSpacing: 8

                            // Animaciones
                            Rectangle {
                                Layout.fillWidth: true
                                height: 54
                                radius: 14
                                color: root.hyprAnim ? root.colAccent : root.colSurface
                                Behavior on color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10
                                    Text { text: "󰑮"; color: root.hyprAnim ? root.colBg : root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20 }
                                    ColumnLayout {
                                        spacing: 1
                                        Text { text: "Animations"; color: root.hyprAnim ? root.colBg : root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.weight: Font.Bold }
                                        Text { text: root.hyprAnim ? "Enabled" : "Disabled"; color: root.hyprAnim ? Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.8) : root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.hyprAnim = !root.hyprAnim
                                        root.runCmd("$HOME/.local/bin/notch-hypr-helper set-anim " + root.hyprAnim)
                                    }
                                }
                            }

                            // Desenfoque Blur
                            Rectangle {
                                Layout.fillWidth: true
                                height: 54
                                radius: 14
                                color: root.hyprBlur ? root.colAccent : root.colSurface
                                Behavior on color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10
                                    Text { text: "󰂵"; color: root.hyprBlur ? root.colBg : root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20 }
                                    ColumnLayout {
                                        spacing: 1
                                        Text { text: "Blur Effect"; color: root.hyprBlur ? root.colBg : root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.weight: Font.Bold }
                                        Text { text: root.hyprBlur ? "Enabled" : "Disabled"; color: root.hyprBlur ? Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.8) : root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.hyprBlur = !root.hyprBlur
                                        root.runCmd("$HOME/.local/bin/notch-hypr-helper set-blur " + root.hyprBlur)
                                    }
                                }
                            }

                            // Sombras
                            Rectangle {
                                Layout.fillWidth: true
                                height: 54
                                radius: 14
                                color: root.hyprShadow ? root.colAccent : root.colSurface
                                Behavior on color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10
                                    Text { text: "󰞏"; color: root.hyprShadow ? root.colBg : root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20 }
                                    ColumnLayout {
                                        spacing: 1
                                        Text { text: "Shadows"; color: root.hyprShadow ? root.colBg : root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.weight: Font.Bold }
                                        Text { text: root.hyprShadow ? "Enabled" : "Disabled"; color: root.hyprShadow ? Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.8) : root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.hyprShadow = !root.hyprShadow
                                        root.runCmd("$HOME/.local/bin/notch-hypr-helper set-shadow " + root.hyprShadow)
                                    }
                                }
                            }

                            // Rendimiento
                            Rectangle {
                                Layout.fillWidth: true
                                height: 54
                                radius: 14
                                color: root.perfMode ? root.colAccent : root.colSurface
                                Behavior on color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10
                                    Text { text: "󰓅"; color: root.perfMode ? root.colBg : root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20 }
                                    ColumnLayout {
                                        spacing: 1
                                        Text { text: "Performance"; color: root.perfMode ? root.colBg : root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.weight: Font.Bold }
                                        Text { text: root.perfMode ? "Max Performance" : "Balanced"; color: root.perfMode ? Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.8) : root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.perfMode = !root.perfMode
                                        root.runCmd("$HOME/.local/bin/notch-hypr-helper toggle-perf")
                                        hyprRefreshTimer.restart()
                                    }
                                }
                            }

                            // Modo Ahorro de Energía
                            Rectangle {
                                Layout.fillWidth: true
                                height: 54
                                radius: 14
                                color: root.powerSaverEnabled ? root.colAccent : root.colSurface
                                Behavior on color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10
                                    Text { text: "󰌪"; color: root.powerSaverEnabled ? root.colBg : root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20 }
                                    ColumnLayout {
                                        spacing: 1
                                        Text { text: "Power Saver"; color: root.powerSaverEnabled ? root.colBg : root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.weight: Font.Bold }
                                        Text { text: root.powerSaverEnabled ? "Eco Active" : "Disabled"; color: root.powerSaverEnabled ? Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.8) : root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.powerSaverEnabled = !root.powerSaverEnabled
                                        root.runCmd("~/.local/bin/toggle-powersave")
                                    }
                                }
                            }

                            // Config Pantallas
                            Rectangle {
                                Layout.fillWidth: true
                                height: 54
                                radius: 14
                                color: monitorsHover.containsMouse ? root.colSurfaceHover : root.colSurface
                                Behavior on color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10
                                    Text { text: "󰍹"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20 }
                                    ColumnLayout {
                                        spacing: 1
                                        Text { text: "Monitors"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.weight: Font.Bold }
                                        Text { text: "Display Manager"; color: root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                                    }
                                }
                                MouseArea {
                                    id: monitorsHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.runCmd("$HOME/.local/bin/notch-hypr-helper monitors")
                                }
                            }
                        }

                        // Card de Estilo y Ventanas (Redondeo y Gaps)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 96
                            radius: 14
                            color: root.colSurface
                            border.color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                                // Presets de Redondeo (Rounding)
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "Rounding:"
                                        color: root.colFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        Layout.preferredWidth: 80
                                    }

                                    Repeater {
                                        model: [
                                            { label: "Sharp (0px)", val: 0 },
                                            { label: "Normal (10px)", val: 10 },
                                            { label: "Curved (16px)", val: 16 }
                                        ]
                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 30
                                            radius: 8
                                            color: root.hyprRounding === modelData.val ? root.colAccent : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.label
                                                color: root.hyprRounding === modelData.val ? root.colBg : root.colFg
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.hyprRounding = modelData.val
                                                    root.runCmd("$HOME/.local/bin/notch-hypr-helper set-rounding " + modelData.val)
                                                }
                                            }
                                        }
                                    }
                                }

                                // Presets de Gaps (Espaciado)
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "Gaps:"
                                        color: root.colFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        Layout.preferredWidth: 80
                                    }

                                    Repeater {
                                        model: [
                                            { label: "0px", val: 0 },
                                            { label: "6px", val: 6 },
                                            { label: "10px", val: 10 },
                                            { label: "16px", val: 16 }
                                        ]
                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 30
                                            radius: 8
                                            color: root.hyprGaps === modelData.val ? root.colAccent : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.label
                                                color: root.hyprGaps === modelData.val ? root.colBg : root.colFg
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.hyprGaps = modelData.val
                                                    root.runCmd("$HOME/.local/bin/notch-hypr-helper set-gaps " + modelData.val)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Android-Style System Update (OTA) Card
                        Rectangle {
                            Layout.fillWidth: true
                            height: 56
                            radius: 14
                            color: otaCardHover.containsMouse ? root.colSurfaceHover : root.colSurface
                            border.color: root.otaData.has_updates ? root.colAccent : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                            border.width: root.otaData.has_updates ? 1.5 : 1
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 12

                                // Android OTA Icon Badge
                                Rectangle {
                                    width: 36; height: 36; radius: 18
                                    color: root.otaData.has_updates ? root.colAccent : Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.15)
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰚰"
                                        color: root.otaData.has_updates ? root.colBg : root.colAccent
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 18
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    RowLayout {
                                        spacing: 6
                                        Text {
                                            text: "System Update (OTA)"
                                            color: root.colFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                        }
                                        Rectangle {
                                            visible: root.otaData.has_updates
                                            width: 82; height: 18; radius: 9
                                            color: root.colAccent
                                            Text {
                                                anchors.centerIn: parent
                                                text: "New Update"
                                                color: root.colBg
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 9
                                                font.weight: Font.Bold
                                            }
                                        }
                                    }
                                    Text {
                                        text: root.otaData.has_updates ? root.otaData.status_text : ("Rhythm Hyprland " + (root.otaData.current_version || "v1.0.0") + " · Up to date")
                                        color: root.otaData.has_updates ? root.colAccent : root.colMuted
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                // Chevron
                                Text {
                                    text: "󰅂"
                                    color: root.colMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                }
                            }

                            MouseArea {
                                id: otaCardHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.controlSubView = 4
                                    otaStatusProc.running = true
                                    otaChangelogProc.running = true
                                }
                            }
                        }

                        // Herramientas Hyprland
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                Layout.fillWidth: true; height: 36; radius: 10; color: root.colSurface
                                RowLayout { anchors.centerIn: parent; spacing: 6
                                    Text { text: "󰍹"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                                    Text { text: "Monitors"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.expanded = false; root.runCmd("$HOME/.local/bin/notch-hypr-helper monitors"); } }
                            }

                            Rectangle {
                                Layout.fillWidth: true; height: 36; radius: 10; color: root.colSurface
                                RowLayout { anchors.centerIn: parent; spacing: 6
                                    Text { text: "󰕰"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                                    Text { text: "Split Layout"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.runCmd("$HOME/.local/bin/notch-hypr-helper toggle-split") }
                            }

                            Rectangle {
                                Layout.fillWidth: true; height: 36; radius: 10; color: root.colSurface
                                RowLayout { anchors.centerIn: parent; spacing: 6
                                    Text { text: "󰑐"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                                    Text { text: "Reload"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.runCmd("$HOME/.local/bin/notch-hypr-helper reload"); hyprRefreshTimer.restart(); } }
                            }
                        }
                    }

                    // ── 6. SUBSECCIÓN: SYSTEM UPDATE (OTA - ANDROID STYLE) ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        visible: root.controlSubView === 4

                        // Sub-header with back button
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                width: 100; height: 32; radius: 16
                                color: root.colSurface
                                border.color: root.colBorder; border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent; spacing: 6
                                    Text { text: "󰁍"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 }
                                    Text { text: "Back"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                                }

                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.controlSubView = 0
                                }
                            }

                            Text {
                                text: "System Update"
                                color: root.colFg; font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13; font.weight: Font.Bold
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 32; height: 32; radius: 16
                                color: Qt.rgba(255, 255, 255, 0.08)
                                Text {
                                    anchors.centerIn: parent; text: "󰑐"
                                    color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                                    RotationAnimation on rotation {
                                        running: root.otaChecking; loops: Animation.Infinite
                                        from: 0; to: 360; duration: 800
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (!root.otaChecking) { root.otaChecking = true; otaCheckProc.running = true } }
                                }
                            }

                            Rectangle {
                                width: 32; height: 32; radius: 16
                                color: Qt.rgba(255, 255, 255, 0.08)
                                Text { anchors.centerIn: parent; text: "󰓓"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.expanded = false; root.runCmd("kitty -e system-ota gui") }
                                }
                            }
                        }

                        // Android 15 Status Hero Card
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 118
                            radius: 16
                            color: root.colSurface
                            border.color: root.otaData.has_updates ? root.colAccent : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                            border.width: 1

                            ColumnLayout {
                                anchors.centerIn: parent; spacing: 6

                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 48; height: 48; radius: 24
                                    color: root.otaData.has_updates ? Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.2) : Qt.rgba(76/255, 175/255, 80/255, 0.2)
                                    border.color: root.otaData.has_updates ? root.colAccent : "#4CAF50"
                                    border.width: 2

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.otaData.has_updates ? "󰚰" : "󰄬"
                                        color: root.otaData.has_updates ? root.colAccent : "#4CAF50"
                                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22
                                    }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: root.otaData.has_updates ? "System Update Available" : "System is Up to Date"
                                    color: root.colFg; font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13; font.weight: Font.Bold
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: root.otaData.has_updates ? root.otaData.status_text : ("Rhythm Hyprland " + (root.otaData.current_version || "v1.0.0") + " · Last checked: " + (root.otaData.last_checked || "Recently"))
                                    color: root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10
                                }
                            }
                        }

                        // System Release & Specs Grid
                        GridLayout {
                            Layout.fillWidth: true; columns: 2; rowSpacing: 6; columnSpacing: 6

                            Rectangle {
                                Layout.fillWidth: true; height: 42; radius: 10; color: root.colSurface
                                RowLayout { anchors.fill: parent; anchors.margins: 8; spacing: 8
                                    Text { text: "󰓅"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
                                    ColumnLayout { spacing: 1
                                        Text { text: "Current Version"; color: root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                                        Text { text: (root.otaData.current_version || "v1.0.0") + " (" + (root.otaData.dotfiles_hash || "git") + ")"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold; elide: Text.ElideRight; Layout.fillWidth: true }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true; height: 42; radius: 10; color: root.colSurface
                                RowLayout { anchors.fill: parent; anchors.margins: 8; spacing: 8
                                    Text { text: "󰑐"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
                                    ColumnLayout { spacing: 1
                                        Text { text: "Target Release"; color: root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                                        Text { text: (root.otaData.latest_version && root.otaData.latest_version !== root.otaData.current_version) ? (root.otaData.latest_version + " (New)") : (root.otaData.current_version + " (Latest)"); color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold; elide: Text.ElideRight; Layout.fillWidth: true }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true; height: 42; radius: 10; color: root.colSurface
                                RowLayout { anchors.fill: parent; anchors.margins: 8; spacing: 8
                                    Text { text: "󰌽"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
                                    ColumnLayout { spacing: 1
                                        Text { text: "Linux Kernel"; color: root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                                        Text { text: root.otaData.kernel || "Arch Linux"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold; elide: Text.ElideRight; Layout.fillWidth: true }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true; height: 42; radius: 10; color: root.colSurface
                                RowLayout { anchors.fill: parent; anchors.margins: 8; spacing: 8
                                    Text { text: "󰘬"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
                                    ColumnLayout { spacing: 1
                                        Text { text: "Release Channel"; color: root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                                        Text { text: (root.otaData.dotfiles_branch || "main") + " · " + (root.otaData.has_updates ? (root.otaData.dotfiles_behind + " behind") : "Up to date"); color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold; elide: Text.ElideRight; Layout.fillWidth: true }
                                    }
                                }
                            }
                        }

                        // Changelog Preview Card
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 110
                            radius: 12; color: root.colSurface; clip: true
                            border.color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08); border.width: 1

                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 10; spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Changelog & History"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                                    Item { Layout.fillWidth: true }
                                    Text { text: root.otaData.current_version || "Current"; color: root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                                }

                                Flickable {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    contentWidth: width; contentHeight: changelogDisplayText.implicitHeight; clip: true

                                    Text {
                                        id: changelogDisplayText
                                        width: parent.width
                                        text: root.otaChangelogText || "Loading changelog..."
                                        color: root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; wrapMode: Text.Wrap
                                    }
                                }
                            }
                        }

                        // OTA Action Footer
                        RowLayout {
                            Layout.fillWidth: true; spacing: 10

                            Rectangle {
                                Layout.fillWidth: true; height: 40; radius: 20
                                color: checkOtaHover.containsMouse ? root.colSurfaceHover : root.colSurface
                                border.color: root.colBorder; border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent; spacing: 8
                                    Text {
                                        text: "󰑐"; color: root.colAccent
                                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                                        RotationAnimation on rotation {
                                            running: root.otaChecking; loops: Animation.Infinite; from: 0; to: 360; duration: 800
                                        }
                                    }
                                    Text {
                                        text: root.otaChecking ? "Checking..." : "Check for update"
                                        color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold
                                    }
                                }

                                MouseArea {
                                    id: checkOtaHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (!root.otaChecking) { root.otaChecking = true; otaCheckProc.running = true } }
                                }
                            }

                            Rectangle {
                                visible: root.otaData.has_updates || root.otaUpdating
                                Layout.fillWidth: true; height: 40; radius: 20
                                color: root.otaUpdating ? Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.6) : root.colAccent
                                Behavior on color { ColorAnimation { duration: 200 } }

                                RowLayout {
                                    anchors.centerIn: parent; spacing: 8
                                    Text {
                                        text: root.otaUpdating ? "󱑑" : "󰀚"
                                        color: root.colBg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15
                                    }
                                    Text {
                                        text: root.otaUpdating ? "Installing..." : "Download & Install"
                                        color: root.colBg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    enabled: !root.otaUpdating
                                    onClicked: { root.otaUpdating = true; otaUpdateProc.running = true }
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
