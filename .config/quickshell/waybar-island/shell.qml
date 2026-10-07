import QtQuick
import QtQuick.Controls
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

    // One Quickshell process owns one PanelWindow per monitor. Keep UI state on
    // each PanelWindow, and use this registry only to route external IPC calls.
    property var islandPanels: ({})

    function registerIslandPanel(screenName, panel) {
        let panels = Object.assign({}, root.islandPanels)
        panels[screenName] = panel
        root.islandPanels = panels
    }

    function unregisterIslandPanel(screenName) {
        let panels = Object.assign({}, root.islandPanels)
        delete panels[screenName]
        root.islandPanels = panels
    }

    function panelForScreen(screenName) {
        if (screenName && screenName !== "all")
            return root.islandPanels[screenName] || null
        let names = Object.keys(root.islandPanels)
        return names.length ? root.islandPanels[names[0]] : null
    }

    function setPanelState(screenName, expandedValue, tabValue, subViewValue) {
        let panel = root.panelForScreen(screenName)
        if (!panel) return null
        if (expandedValue === true) {
            // El ipc hide marca la pantalla en hiddenScreens, y el binding de
            // visible de la ventana la apaga entera. Sin quitarlo de ahi, volver
            // a expandir la ventana no dibuja NADA: el estado era correcto y aun
            // asi no se veia. Pasaba con 7 scripts que llaman a hide (menu wifi,
            // menu bluetooth, launcher, powermenu, wallpaper, atajos), y hacia
            // que SUPER+V, es decir open-clipboard, solo abriera la primera vez.
            root.islandVisible = true
            if (screenName && screenName !== "all") {
                let hs = Object.assign({}, root.hiddenScreens)
                delete hs[screenName]
                root.hiddenScreens = hs
            }
        }
        if (expandedValue !== undefined) panel.expanded = expandedValue
        if (tabValue !== undefined) panel.currentTab = tabValue
        if (subViewValue !== undefined) panel.controlSubView = subViewValue
        return panel
    }

    function anyPanelExpanded() {
        return Object.keys(root.islandPanels).some(name => root.islandPanels[name].expanded)
    }

    function anyPanelSubView(subView) {
        return Object.keys(root.islandPanels).some(name =>
            root.islandPanels[name].expanded && root.islandPanels[name].controlSubView === subView)
    }

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
    property var notifHistory: []
    property int notifUnread: 0

    function notifTime() {
        var d = new Date()
        return ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2)
    }
    // ── Apps silenciadas ──
    function notifMuted(app) {
        let a = (app || "").toLowerCase().trim()
        if (a === "") return false
        return root.mutedApps.some(m => (m || "").toLowerCase() === a)
    }


    function notifToggleMute(app) {
        let a = (app || "").toLowerCase().trim()
        if (a === "") return
        let lista = root.mutedApps.slice()
        let i = lista.findIndex(m => (m || "").toLowerCase() === a)
        if (i >= 0) lista.splice(i, 1)
        else lista.push(a)
        root.mutedApps = lista
        if (i < 0) {
            root.notifHistory = root.notifHistory.filter(n => (n.app || "").toLowerCase() !== a)
        }
        root.notifMuteSave(lista)
    }

    // Guardar la lista. Un app por linea en un fichero de texto plano, no JSON:
    // el JSON exige escapar comillas dentro de la cadena del shell, y los nombres
    // vienen de las notificaciones, o sea que no son datos de los que uno pueda
    // fiarse. Aqui se sanean a [a-z0-9._ -] antes de escribir, asi que el
    // comando no puede salir de los argumentos.
    function notifMuteSave(lista) {
        let limpio = []
        for (let m of lista) {
            let n = (m || "").toLowerCase().replace(/[^a-z0-9._ -]/g, "").trim()
            if (n !== "") limpio.push(n)
        }
        // Cada nombre va entrecomillado: sin comillas, printf '%s\n' battery saver
        // imprime DOS lineas y una app que se llama "Battery Saver" acaba guardada
        // como dos apps distintas: battery y saver.
        let cmd = "mkdir -p $HOME/.config/rhythm && : > $HOME/.config/rhythm/muted-apps.txt"
        for (let n of limpio) cmd += " && printf '%s\\n' '" + n.replace(/'/g, "'\\''") + "' >> $HOME/.config/rhythm/muted-apps.txt"
        root.runCmd(cmd)
    }

    // Apps que ya han hablado alguna vez, mas las silenciadas: asi se puede
    // silenciar una app sin tener que esperar a que notifique otra vez.
    function notifKnownApps() {
        let seen = {}
        for (let n of root.notifHistory) seen[(n.app || "System").toLowerCase()] = n.app || "System"
        for (let m of root.mutedApps) seen[(m || "").toLowerCase()] = m
        return Object.keys(seen).sort()
    }

    // Cargar la lista al arrancar la isla. Un app por linea.
    Process {
        id: muteLoadProc
        running: true
        command: ["bash", "-c", "cat $HOME/.config/rhythm/muted-apps.txt 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lista = []
                for (let linea of text.split("\n")) {
                    let n = linea.trim()
                    if (n !== "") lista.push(n)
                }
                root.mutedApps = lista
            }
        }
    }

    function notifPush(app, summary, body) {
        var h = [{app: app || "System", summary: summary || "", body: body || "", time: root.notifTime()}].concat(root.notifHistory)
        root.notifHistory = h.slice(0, 30)
        root.notifUnread = Math.min(99, root.notifUnread + 1)
    }
    function notifOpenCenter(screenName) {
        if (root.currentNotification) root.currentNotification.dismiss()
        root.currentNotification = null
        root.notifActive = false
        root.notifUnread = 0
        // A pending pairing request has a short lifetime: show it instead of
        // the notification list, otherwise the request is only visible through
        // a notification that leads somewhere else.
        if (root.pairRequest.active && root.pairRequest.state === "pending") {
            root.setPanelState(screenName, true, 0, 6)
            return
        }
        root.setPanelState(screenName, true, 2, 0)
        root.refreshAllStates()
    }
    function notifClear() {
        root.notifHistory = []
        root.notifUnread = 0
    }

    NotificationServer {
        id: notifServer
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true

        onNotification: function(n) {
            // App silenciada: se descarta aqui y no se guarda ni se avisa. Va antes
            // que el filtro de palabras clave y que el DND, porque es una decision
            // del usuario sobre esa app concreta y no sobre el estado global.
            if (root.notifMuted(n.appName)) {
                n.dismiss()
                return
            }

            // Do Not Disturb: suppress banner toast, keep server-side history
            if (root.dndEnabled) {
                n.tracked = true
                root.notifPush(n.appName, n.summary, n.body)
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

            root.notifPush(n.appName, n.summary, n.body)
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

    // Monitores con una ventana a pantalla completa, y por tanto con la isla
    // escondida. La isla vive en la capa Overlay, que Hyprland dibuja POR ENCIMA
    // de las ventanas en pantalla completa, asi que sin esto se ve encima del
    // video. El dock no sufre lo mismo porque usa la capa top.
    // Lo escribe island-fullscreens, que solo cuenta ventanas visibles y mapeadas
    // para no esconder la isla por un fullscreen de otro espacio de trabajo.
    property var fullscreenScreens: ({})

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
    property var clipList: []
    property int clipCount: 0
    property int clipCopiedId: -1
    property string clipToast: ""

    // Resultado del ultimo cambio de limite de carga: sale debajo de los botones
    // de la tarjeta y se borra solo a los 4 s.
    property string battLimitMsg: ""
    property bool isMuted: false

    property var wifiList: []
    property string wifiConnectScreen: ""
    property string wifiConnectSsid: ""
    property string wifiConnectPassword: ""
    property bool wifiConnectRunning: false
    property bool wifiConnectPromptOnError: false

    function startWifiConnect(screenName, ssid, password, promptOnError) {
        let panel = root.panelForScreen(screenName)
        if (!panel) return
        if (root.wifiConnectRunning) {
            panel.wifiConnectState = "error"
            panel.wifiConnectMessage = "Another Wi-Fi connection is already in progress."
            return
        }
        root.wifiConnectScreen = screenName
        root.wifiConnectSsid = ssid
        root.wifiConnectPassword = password || ""
        root.wifiConnectPromptOnError = promptOnError === true
        if (root.wifiConnectPromptOnError) {
            panel.clearWifiPassword()
            panel.selectedWifiSsid = ""
        }
        panel.wifiConnectState = "connecting"
        panel.wifiConnectMessage = "Connecting to " + ssid + "…"
        root.wifiConnectRunning = true
        wifiConnectProc.running = true
    }
    property var btDevices: []
    property var audioSinks: []
    property var audioApps: []
    property string activeSinkName: "Default Output"
    property bool nightLightEnabled: false
    property int nightLightTemperature: 4500
    property int nightLightGamma: 100
    property bool nightLightScheduleEnabled: false
    property string nightLightScheduleStart: ""
    property string nightLightScheduleEnd: ""
    property bool caffeineEnabled: false
    property bool powerSaverEnabled: false
    property bool dndEnabled: false
    property bool dockEnabled: true
    // Active BlueZ pairing request. BlueZ asks the registered agent, never the
    // notification server, so bluetooth-pair-agent forwards it here.
    property var pairRequest: ({ active: false, id: "", kind: "", name: "", device: "", passkey: "", hint: "", state: "pending", pin: "" })

    function showPairingRequest(screenName, requestId, payload) {
        let data
        try {
            data = JSON.parse(payload)
        } catch (e) {
            return "invalid"
        }
        // Only one request can be answered at a time: close the previous one so
        // BlueZ is not left waiting for a reply that will never come.
        if (root.pairRequest.active && root.pairRequest.state === "pending" && root.pairRequest.id !== requestId) {
            root.runCmd("$HOME/.local/bin/bluetooth-pair-agent respond " + root.pairRequest.id + " reject")
        }
        root.pairRequest = {
            active: true,
            id: requestId,
            kind: data.kind || "confirm",
            name: data.name || data.device || "Bluetooth device",
            device: data.device || "",
            passkey: data.passkey || "",
            hint: data.hint || "",
            state: "pending",
            pin: ""
        }
        let panel = root.setPanelState(screenName, true, 0, 6)
        if (!panel) {
            // Unknown or missing monitor: open it everywhere so the request is
            // never invisible.
            Object.keys(root.islandPanels).forEach(name => {
                root.islandPanels[name].expanded = true
                root.islandPanels[name].currentTab = 0
                root.islandPanels[name].controlSubView = 6
            })
        }
        return "pairing"
    }

    function answerPairing(action) {
        if (!root.pairRequest.active || root.pairRequest.state !== "pending") return
        let cmd = "$HOME/.local/bin/bluetooth-pair-agent respond " + root.pairRequest.id + " " + action
        if (action === "accept" && root.pairRequest.kind === "pin" && root.pairRequest.pin.length > 0) {
            cmd += " '" + root.pairRequest.pin + "'"
        }
        root.runCmd(cmd)
        root.pairRequest = Object.assign({}, root.pairRequest, { state: action === "accept" ? "accepted" : "rejected" })
        pairRequestResetTimer.restart()
    }
    property var recState: ({ recording: false, pid: 0, elapsed: 0, elapsed_str: "00:00", file: "" })
    property var privacyState: ({ mic: false, cam: false })
    property var sysStats: ({ cpu_pct: 0, ram_used: "0G", ram_total: "0G", ram_pct: 0, disk_used: "0G", disk_pct: 0 })

    // Baterias. battery-info devuelve count 0 y devices vacio si esta maquina no
    // tiene ninguna, y la seccion se oculta con visible en vez de con un texto de
    // "sin baterias": en un escritorio fijo no tiene que aparecer nada.
    property var batt: null

    // Apps silenciadas: sus notificaciones se descartan al llegar, sin banner ni
    // entrada en el historial. Un app por linea en muted-apps.txt.
    property var mutedApps: []
    property bool wifiScanning: false
    property bool btScanning: false
    property bool showUnnamedBtDevices: false
    readonly property var namedBtDevices: (root.btDevices || []).filter(d => d.has_name || d.paired || d.connected)
    readonly property var unnamedBtDevices: (root.btDevices || []).filter(d => !d.has_name && !d.paired && !d.connected)

    function refreshAllStates() {
        volProc.running = true
        briProc.running = true
        wifiProc.running = true
        btStatusProc.running = true
        perfProc.running = true
        battProc.running = true
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
        clipCountProc.running = true
        hyprStatusProc.running = true
        clipListProc.running = true
        otaStatusProc.running = true
        otaChangelogProc.running = true
    }

    IpcHandler {
        target: "settings"
        function toggle(screenName: string): string {
            let panel = root.panelForScreen(screenName)
            if (!panel) return "unavailable"
            // Pasa por setPanelState y no por panel.expanded a pelo, para que
            // expandir quite la marca de hiddenScreens que deja el ipc hide.
            let abrir = !panel.expanded
            root.setPanelState(screenName, abrir, abrir ? 1 : undefined, abrir ? 0 : undefined)
            if (abrir) root.refreshAllStates()
            return abrir ? "expanded" : "collapsed"
        }
        function open(screenName: string): string {
            let panel = root.setPanelState(screenName, true, 1, 0)
            if (!panel) return "unavailable"
            root.refreshAllStates()
            return "expanded"
        }
        function open_wifi(screenName: string): string {
            let panel = root.setPanelState(screenName, true, 0, 1)
            if (!panel) return "unavailable"
            root.wifiScanning = true
            wifiListProc.running = true
            root.refreshAllStates()
            return "expanded"
        }
        function open_bt(screenName: string): string {
            let panel = root.setPanelState(screenName, true, 0, 2)
            if (!panel) return "unavailable"
            root.btScanning = true
            btStatusProc.running = true
            root.refreshAllStates()
            return "expanded"
        }
        function open_hypr(screenName: string): string {
            let panel = root.setPanelState(screenName, true, 1, 0)
            if (!panel) return "unavailable"
            root.refreshAllStates()
            return "expanded"
        }
        function open_audio(screenName: string): string {
            let panel = root.setPanelState(screenName, true, 0, 3)
            if (!panel) return "unavailable"
            audioSinksProc.running = true
            audioAppsProc.running = true
            root.refreshAllStates()
            return "expanded"
        }
        function close(screenName: string): string {
            let panel = root.setPanelState(screenName, false)
            return panel ? "collapsed" : "unavailable"
        }
    }

    IpcHandler {
        target: "island"
        function toggle(screenName: string): string {
            let panel = root.panelForScreen(screenName)
            if (!panel) return "unavailable"
            panel.expanded = !panel.expanded
            if (panel.expanded) {
                panel.currentTab = 0
                // Abrir la isla con una solicitud pendiente debe llevar al
                // aviso de emparejamiento, no a la vista de control.
                panel.controlSubView = root.pairRequest.active ? 6 : 0
                root.refreshAllStates()
            }
            return panel.expanded ? "expanded" : "collapsed"
        }
        function openWifi(screenName: string): string {
            let panel = root.setPanelState(screenName, true, 0, 1)
            if (!panel) return "unavailable"
            root.wifiScanning = true
            wifiListProc.running = true
            return "wifi"
        }
        function openBluetooth(screenName: string): string {
            let panel = root.setPanelState(screenName, true, 0, 2)
            if (!panel) return "unavailable"
            root.btScanning = true
            btStatusProc.running = true
            return "bluetooth"
        }
        function openAudio(screenName: string): string {
            let panel = root.setPanelState(screenName, true, 0, 3)
            if (!panel) return "unavailable"
            audioSinksProc.running = true
            return "audio"
        }
        function openNightLight(screenName: string): string {
            let panel = root.setPanelState(screenName, true, 0, 5)
            if (!panel) return "unavailable"
            nightLightSettingsProc.running = true
            return "night-light"
        }
        function openControl(screenName: string): string {
            let panel = root.setPanelState(screenName, true, 0, 0)
            if (!panel) return "unavailable"
            root.refreshAllStates()
            return "control"
        }
        function showPairingRequest(screenName: string, requestId: string, payload: string): string {
            return root.showPairingRequest(screenName, requestId, payload)
        }
        function openHyprland(screenName: string): string {
            let panel = root.setPanelState(screenName, true, 1, 0)
            if (!panel) return "unavailable"
            root.refreshAllStates()
            return "hyprland"
        }
        // Estado real del panel de una pantalla. Para poder preguntar por que no se
        // ve la isla sin tener que adivinarlo por una captura.
        function state(screenName: string): string {
            let p = root.panelForScreen(screenName)
            if (!p) return "unavailable"
            return JSON.stringify({
                expanded: p.expanded,
                tab: p.currentTab,
                sub: p.controlSubView,
                hidden: root.hiddenScreens[screenName] === true,
                fullscreen: root.fullscreenScreens[screenName] === true,
                visible: p.visible
            })
        }
        function openBatteries(screenName: string): string {
            let panel = root.setPanelState(screenName, true, 1, 7)
            if (!panel) return "unavailable"
            battProc.running = true
            return "batteries"
        }
        function openOta(screenName: string): string {
            let current = root.panelForScreen(screenName)
            if (!current) return "unavailable"
            let panel = root.setPanelState(screenName, true, current.currentTab, 4)
            if (!panel) return "unavailable"
            otaStatusProc.running = true
            otaChangelogProc.running = true
            return "ota"
        }
        function openNotifications(screenName: string): string {
            root.notifOpenCenter(screenName)
            return "notifications"
        }
        function openClipboard(screenName: string): string {
            let panel = root.setPanelState(screenName, true, 3, 0)
            if (!panel) return "unavailable"
            clipListProc.running = true
            return "clipboard"
        }
        function collapse(screenName: string): string {
            let panel = root.setPanelState(screenName, false)
            return panel ? "collapsed" : "unavailable"
        }
        function hide(screenName: string): string {
            if (!screenName || screenName === "" || screenName === "all") {
                Object.keys(root.islandPanels).forEach(name => root.islandPanels[name].expanded = false)
                root.islandVisible = false
                root.hiddenScreens = {}
            } else {
                let panel = root.panelForScreen(screenName)
                if (panel) panel.expanded = false
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
        command: ["bash", "-c", "out=$(brightnessctl -c backlight -m 2>/dev/null | head -n1); [ -z \"$out\" ] && out=$(brightnessctl -m 2>/dev/null | head -n1); echo \"$out\" | awk -F, '{print $4}' | tr -d '%'"]
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

    //  `btProc` estaba aquí para preguntar solo "¿está encendido?", pero
    //  escribía root.btEnabled y eso ya lo hace btStatusProc, que además trae
    //  discovering y la lista de aparatos. Dos procesos escribiendo la misma
    //  propiedad, cada uno con su propio ritmo, es la forma de que el estado
    //  parpadee. Se queda uno solo: el que lo sabe todo.

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
        id: clipListProc
        command: ["bash", "-c", "$HOME/.local/bin/clipboard-list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.clipList = JSON.parse(text.trim())
                } catch(e) {
                    root.clipList = []
                }
            }
        }
    }

    Process {
        id: kbProc
        // kb-layout devuelve la abreviatura del layout ACTIVO segun lo que el
        // usuario configuro en input.kb_layout ("us,es" -> US / ES).
        //
        // Antes pedia active_keymap, que es el nombre del keymap de XKB:
        // "English (US)" frente a "Spanish". No es lo que el usuario escribe, y
        // como cambia de largo segun el idioma, el chip se redimensionaba en cada
        // cambio y parecia que se colapsaba al pulsarlo.
        command: ["bash", "-c", "$HOME/.local/bin/kb-layout"]
        stdout: StdioCollector {
            onStreamFinished: {
                const val = text.trim()
                root.kbLayout = val.length > 0 && val !== "null" ? val : "US"
            }

        }
    }

    // Sondea que monitores tienen algo a pantalla completa, para esconder la isla
    // mientras haya un video en pantalla completa. Un segundo basta: si se pierde
    // uno, la isla reaparece ese instante y se ve el parpadeo, pero con mas la
    // consulta se nota.
    Process {
        id: fullscreenProc
        command: ["bash", "-c", "$HOME/.local/bin/island-fullscreens"]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim()
                if (raw.length === 0) return
                try {
                    root.fullscreenScreens = JSON.parse(raw)
                } catch (e) {
                    root.fullscreenScreens = ({})
                }
            }
        }
    }

    Timer {
        id: fullscreenTimer
        interval: 1000
        repeat: true
        running: true
        onTriggered: fullscreenProc.running = true
        triggeredOnStart: true
    }

    Process {
        id: clipCountProc
        command: ["bash", "-c", "cliphist list 2>/dev/null | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text.trim(), 10)
                root.clipCount = isNaN(n) ? 0 : n
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
        id: wifiConnectProc
        command: [Quickshell.env("HOME") + "/.local/bin/notch-wifi-helper",
                  "connect", root.wifiConnectSsid, root.wifiConnectPassword]
        stdout: StdioCollector {
            onStreamFinished: {
                let result = null
                try { result = JSON.parse(text.trim()) } catch (e) {}
                const panel = root.panelForScreen(root.wifiConnectScreen)
                if (panel) {
                    if (result && result.status === "ok") {
                        panel.finishWifiConnection(root.wifiConnectSsid)
                    } else {
                        if (root.wifiConnectPromptOnError)
                            panel.selectedWifiSsid = root.wifiConnectSsid
                        panel.wifiConnectState = "error"
                        panel.wifiConnectMessage = result && result.message
                            ? "Connection failed: " + result.message
                            : "Connection failed. Check the password and try again."
                    }
                }
            }
        }
        onExited: {
            root.wifiConnectRunning = false
            root.wifiConnectPassword = ""
            root.wifiConnectPromptOnError = false
            wifiListProc.running = true
            wifiProc.running = true
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
        repeat: true
        //  El estado de bluetooth se mira SIEMPRE, no solo con la lista
        //  abierta. Antes esto solo corría con el subview de BT desplegado, así
        //  que al cerrar la isla la píldora se quedaba con el último
        //  `btDevices` que vio —congelado— mientras waybar, que va por D-Bus,
        //  seguía al día. Esa era la desincronización entre las dos barras.
        running: true
        //  Rápido donde se nota, tranquilo de fondo.
        interval: root.anyPanelSubView(2) ? 1500 : 3000
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

    // Aplicar el limite de carga de una bateria. battery-charge-limit escribe en el
    // charge_control_end_threshold y COMPRUEBA que el valor se quedo puesto: hay
    // controladores que lo ignoran en silencio, y sin comprobarlo la isla diria
    // que el limite esta puesto y no lo esta.
    Process {
        id: battLimitProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.battLimitMsg = text.trim()
                battLimitMsgTimer.restart()
                battProc.running = true
            }
        }
        onExited: (code) => {
            if (code !== 0 && root.battLimitMsg === "") {
                root.battLimitMsg = "Could not set the limit"
                battLimitMsgTimer.restart()
            }
        }
    }

    Timer {
        id: battLimitMsgTimer
        interval: 4000
        repeat: false
        onTriggered: root.battLimitMsg = ""
    }

    Process {
        id: battProc
        command: ["bash", "-c", "$HOME/.local/bin/battery-info"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.batt = JSON.parse(text.trim())
                } catch(e) {}
            }
        }
    }

    // Solo con la isla abierta: leer sysfs cada 10 s no cuesta (unos 5 ms), pero
    // tampoco tiene sentido pagarlo con la isla cerrada.
    //
    // OJO: aqui no se puede mirar islandWin. Las ventanas de la isla se crean una
    // por monitor dentro de una Repeater, asi que ese id no existe en este ambito
    // y el binding se quedaba en false para siempre: la seccion de baterias se
    // quedaba vacia para siempre y sin ningun error que lo dijera.
    Timer {
        id: battTimer
        interval: 10000
        repeat: true
        triggeredOnStart: true
        running: root.anyPanelExpanded()
        onTriggered: battProc.running = true
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
        id: nightLightSettingsProc
        command: [Quickshell.env("HOME") + "/.local/bin/toggle-nightlight", "settings"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const settings = JSON.parse(text.trim())
                    root.nightLightEnabled = settings.enabled === true
                    root.nightLightTemperature = Number(settings.temperature) || 4500
                    root.nightLightGamma = Number(settings.gamma) || 100
                    root.nightLightScheduleEnabled = settings.schedule_enabled === true
                    root.nightLightScheduleStart = settings.schedule_start || ""
                    root.nightLightScheduleEnd = settings.schedule_end || ""
                    Object.keys(root.islandPanels).forEach(name => {
                        const panel = root.islandPanels[name]
                        panel.nightScheduleStartText = root.nightLightScheduleStart
                        panel.nightScheduleEndText = root.nightLightScheduleEnd
                        panel.nightScheduleValidation = ""
                    })
                } catch (e) {}
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
            dockStatusProc.running = true
            }
    }

    Process {
        id: dockStatusProc
        command: ["bash", "-c", "$HOME/.local/bin/rust-dock-toggle-all status"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.dockEnabled = text.trim() === "on"
            }
        }
    }

    Timer {
        id: dockStatusRefreshTimer
        interval: 500
        repeat: false
        onTriggered: dockStatusProc.running = true
    }

    // Pairing request answered: keep the result visible for a moment, then let
    // the panels return to the regular control view.
    Timer {
        id: pairRequestResetTimer
        interval: 1800
        repeat: false
        onTriggered: {
            root.pairRequest = Object.assign({}, root.pairRequest, { active: false, state: "pending", pin: "" })
            Object.keys(root.islandPanels).forEach(name => {
                if (root.islandPanels[name].controlSubView === 6) root.islandPanels[name].controlSubView = 0
            })
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
        running: root.anyPanelExpanded()
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

            property bool expanded: false
            property int currentTab: 0
            property int controlSubView: 0
            property real tabFade: 1.0
            property string selectedWifiSsid: ""
            property string wifiConnectState: "idle"
            property string wifiConnectMessage: ""
            property bool wifiPasswordVisible: false
            property string nightScheduleStartText: ""
            property string nightScheduleEndText: ""
            property string nightScheduleValidation: ""
            function finishWifiConnection(ssid) {
                clearWifiPassword()
                selectedWifiSsid = ""
                wifiConnectState = "connected"
                wifiConnectMessage = "Connected to " + ssid + "."
                wifiConnectStatusTimer.restart()
            }
            function clearWifiPassword() {
                wifiPasswordVisible = false
                wifiPassInput.text = ""
            }
            Behavior on tabFade { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

            Component.onCompleted: root.registerIslandPanel(modelData.name, islandWin)
            Component.onDestruction: root.unregisterIslandPanel(modelData.name)

            onCurrentTabChanged: {
                if (islandWin.controlSubView !== 4 && !(root.pairRequest.active && islandWin.currentTab === 0)) islandWin.controlSubView = 0
                if (islandWin.currentTab === 1) hyprStatusProc.running = true
                islandWin.tabFade = 0.0
                tabFadeReset.restart()
            }
            onExpandedChanged: {
                if (islandWin.expanded) root.refreshAllStates()
                else if (!root.anyPanelExpanded()) root.runCmd("$HOME/.local/bin/notch-bt-helper stop_scan")
            }
            onControlSubViewChanged: {
                if (islandWin.controlSubView === 1) wifiListProc.running = true
                if (islandWin.controlSubView === 2) {
                    btStatusProc.running = true
                    if (root.btEnabled) root.runCmd("$HOME/.local/bin/notch-bt-helper scan")
                } else if (!Object.keys(root.islandPanels).some(name => root.islandPanels[name] !== islandWin && root.islandPanels[name].controlSubView === 2)) {
                    root.runCmd("$HOME/.local/bin/notch-bt-helper stop_scan")
                }
                if (islandWin.controlSubView === 3) {
                    audioSinksProc.running = true
                    audioAppsProc.running = true
                }
                if (islandWin.controlSubView === 4) {
                    otaStatusProc.running = true
                    otaChangelogProc.running = true
                }
                if (islandWin.controlSubView === 5) nightLightSettingsProc.running = true
            }

            Timer { id: tabFadeReset; interval: 40; repeat: false; onTriggered: islandWin.tabFade = 1.0 }
            Timer {
                id: nightTemperatureApplyTimer
                interval: 180
                repeat: false
                onTriggered: root.runCmd("~/.local/bin/toggle-nightlight temperature " + root.nightLightTemperature)
            }
            Timer {
                id: nightGammaApplyTimer
                interval: 180
                repeat: false
                onTriggered: root.runCmd("~/.local/bin/toggle-nightlight gamma " + root.nightLightGamma)
            }
            Timer {
                id: nightLightSettingsRefreshTimer
                interval: 500
                repeat: false
                onTriggered: nightLightSettingsProc.running = true
            }
            Timer {
                id: wifiConnectStatusTimer
                interval: 4000
                repeat: false
                onTriggered: {
                    if (islandWin.wifiConnectState === "connected") {
                        islandWin.wifiConnectState = "idle"
                        islandWin.wifiConnectMessage = ""
                    }
                }
            }
            Timer { id: hoverCollapseGrace; interval: 500; repeat: false; onTriggered: { if (islandWin.expanded && !root.notifActive) islandWin.expanded = false } }
            Timer { id: hoverExpandTimer; interval: 150; repeat: false; onTriggered: { if (!islandWin.expanded && !root.notifActive) { islandWin.expanded = true; if (!root.pairRequest.active) islandWin.controlSubView = 0; root.refreshAllStates() } } }

            screen: modelData
            visible: root.islandVisible && !root.hiddenScreens[modelData.name] && !root.fullscreenScreens[modelData.name]

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
        // OnDemand keeps text inputs usable when focused without the expanded
        // island swallowing Hyprland's global Super shortcuts.
        WlrLayershell.keyboardFocus: islandWin.expanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        mask: Region {
            item: capsule

            Region {
                item: islandWin.expanded ? cazaClics : null
                intersection: Intersection.Combine
            }
        }

        // Dimmer background when expanded
        Rectangle {
            id: dimmer
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.35)
            opacity: islandWin.expanded ? 1.0 : 0.0
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
        }

        // Background click catcher to close
        Item {
            id: cazaClics
            anchors.fill: parent
            enabled: islandWin.expanded

            FocusScope {
                anchors.fill: parent
                focus: islandWin.expanded
                Keys.onEscapePressed: islandWin.expanded = false
            }

            MouseArea {
                anchors.fill: parent
                onClicked: islandWin.expanded = false
            }
        }

        // Dynamic Island container fused to top screen edge (Mac notch style)
        Item {
            id: capsule
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: 1.0

            HoverHandler {
                id: islandHover
                onHoveredChanged: {
                    if (islandHover.hovered) {
                        hoverCollapseGrace.stop()
                    } else if (islandWin.expanded && !root.notifActive) {
                        hoverCollapseGrace.restart()
                    }
                }
            }


            readonly property real ala: 16
            width: islandWin.expanded ? 660 : (root.notifActive ? 460 : (collapsedContent.width + capsule.ala * 2 + 36))
            height: islandWin.expanded ? Math.min(800, islandContentCol.implicitHeight + 52) : (root.notifActive ? 56 : 36)

            Behavior on width {
                NumberAnimation {
                    id: capsuleWidthAnim
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                NumberAnimation {
                    id: capsuleHeightAnim
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }

            // Silueta con esquinas invertidas (alas) que funden con el borde superior de la pantalla
            SiluetaIsla {
                id: silueta
                anchors.fill: parent
                ala: capsule.ala
                cuerpoRadio: islandWin.expanded ? 24 : (root.notifActive ? 16 : 12)
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
                opacity: (!islandWin.expanded && !root.notifActive) ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: hoverExpandTimer.restart()
                    onExited: hoverExpandTimer.stop()
                    onClicked: {
                        hoverExpandTimer.stop()
                        islandWin.expanded = !islandWin.expanded
                        if (islandWin.expanded) {
                            islandWin.controlSubView = 0
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

                    // Unread notifications badge (adaptive count)
                    // El contador de notificaciones va dentro de un MouseArea y no al
                    // reves por una razon concreta: antes el MouseArea era un hijo mas
                    // del Row, con anchors.fill: parent, y dentro de un Row eso no
                    // existe. Quickshell lo avisa —
                    //
                    //   Cannot specify left, right, horizontalCenter, fill or centerIn
                    //   anchors for items inside Row. Row will not function.
                    //
                    // — y el area pulsable se quedaba en cero: el contador se veia pero
                    // no se podia pulsar. En un Row el tamano de un hijo sale de
                    // implicitWidth e implicitHeight, nunca de un anclaje.
                    MouseArea {
                        visible: root.notifUnread > 0 && !islandWin.expanded && !root.notifActive
                        implicitWidth: badgeNotif.implicitWidth
                        implicitHeight: badgeNotif.implicitHeight
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.notifOpenCenter(islandWin.modelData.name)

                        Row {
                            id: badgeNotif
                            spacing: 4
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: "󰂚"
                                color: root.colAccent
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Rectangle {
                                height: 16
                                width: Math.max(16, notifCountLbl.implicitWidth + 10)
                                radius: 8
                                color: root.colAccent
                                Text {
                                    id: notifCountLbl
                                    anchors.centerIn: parent
                                    text: root.notifUnread > 9 ? "9+" : root.notifUnread
                                    color: root.colBg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                }
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
                    }


                    // Indicator icon
                    Text {
                        text: islandWin.expanded ? "󰅃" : "󰅀"
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
                opacity: (!islandWin.expanded && root.notifActive) ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.notifOpenCenter(islandWin.modelData.name)
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
                opacity: islandWin.expanded ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                ColumnLayout {
                    id: islandContentCol
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
                                    onClicked: { islandWin.expanded = false; root.runCmd("hyprlock"); }
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
                                    onClicked: { islandWin.expanded = false; root.runCmd("~/.local/bin/powermenu-with-monitor-detection"); }
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
                                    onClicked: islandWin.expanded = false
                                }
                            }
                        }
                    }

                    // ── 2. SEGMENTED TABS (CONTROL, HYPRLAND & ALERTS) ──
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 12
                        visible: islandWin.controlSubView === 0

                        // Tab 0: Control & Sistema
                        Rectangle {
                            // 4 x 136 + 3 x 12 = 580, dentro de los 584 de la columna.
                            // Con 140 eran 596 y Qt empujaba todo 12 px a la derecha.
                            width: 136
                            height: 34
                            radius: 17
                            color: islandWin.currentTab === 0 ? root.colAccent : root.colSurface
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: "󰒓"
                                    color: islandWin.currentTab === 0 ? root.colBg : root.colAccent
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                }
                                Text {
                                    text: "Control"
                                    color: islandWin.currentTab === 0 ? root.colBg : root.colFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    islandWin.currentTab = 0
                                    islandWin.controlSubView = 0
                                }
                            }
                        }

                        // Tab 1: Hyprland Settings
                        Rectangle {
                            // 4 x 136 + 3 x 12 = 580, dentro de los 584 de la columna.
                            // Con 140 eran 596 y Qt empujaba todo 12 px a la derecha.
                            width: 136
                            height: 34
                            radius: 17
                            color: islandWin.currentTab === 1 ? root.colAccent : root.colSurface
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: "󰣇"
                                    color: islandWin.currentTab === 1 ? root.colBg : root.colAccent
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                }
                                Text {
                                    text: "Hyprland"
                                    color: islandWin.currentTab === 1 ? root.colBg : root.colFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    islandWin.currentTab = 1
                                    islandWin.controlSubView = 0
                                }
                            }
                        }

                        // Tab 2: Alerts
                        Rectangle {
                            // 4 x 136 + 3 x 12 = 580, dentro de los 584 de la columna.
                            // Con 140 eran 596 y Qt empujaba todo 12 px a la derecha.
                            width: 136
                            height: 34
                            radius: 17
                            color: islandWin.currentTab === 2 ? root.colAccent : root.colSurface
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: "󰂚"
                                    color: islandWin.currentTab === 2 ? root.colBg : root.colAccent
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                }
                                Text {
                                    text: "Alerts"
                                    color: islandWin.currentTab === 2 ? root.colBg : root.colFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                }
                                Rectangle {
                                    visible: root.notifUnread > 0
                                    height: 18
                                    width: Math.max(18, tabPillCount.implicitWidth + 10)
                                    radius: 9
                                    color: islandWin.currentTab === 2 ? root.colBg : root.colAccent
                                    Text {
                                        id: tabPillCount
                                        anchors.centerIn: parent
                                        text: root.notifUnread > 9 ? "9+" : root.notifUnread
                                        color: islandWin.currentTab === 2 ? root.colAccent : root.colBg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    islandWin.currentTab = 2
                                    islandWin.controlSubView = 0
                                    root.notifUnread = 0
                                }
                            }
                        }

                        // Tab 3: Portapapeles (opcion aparte de Alertas, arriba)
                        Rectangle {
                            // 4 x 136 + 3 x 12 = 580, dentro de los 584 de la columna.
                            // Con 140 eran 596 y Qt empujaba todo 12 px a la derecha.
                            width: 136
                            height: 34
                            radius: 17
                            color: islandWin.currentTab === 3 ? root.colAccent : root.colSurface
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: "󰅍"
                                    color: islandWin.currentTab === 3 ? root.colBg : root.colAccent
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                }
                                Text {
                                    text: "Clipboard"
                                    color: islandWin.currentTab === 3 ? root.colBg : root.colFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    islandWin.currentTab = 3
                                    islandWin.controlSubView = 0
                                    clipListProc.running = true
                                }
                            }
                        }

                    }

                    // ── 3. TAB 0: CONTROL & SISTEMA ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        visible: islandWin.currentTab === 0 && islandWin.controlSubView === 0
                        opacity: islandWin.tabFade

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
                                                    islandWin.controlSubView = 1
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
                                                islandWin.controlSubView = 1
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
                                                    text: root.pairRequest.active ? "Pairing request pending" : (root.btEnabled ? (root.btDevices.filter(d => d.connected).length > 0 ? root.btDevices.filter(d => d.connected)[0].name : "Enabled") : "Disabled")
                                                    color: root.btEnabled ? Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.8) : root.colMuted
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 9
                                                    font.weight: root.pairRequest.active ? Font.Bold : Font.Normal
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
                                                    if (root.pairRequest.active) {
                                                        islandWin.controlSubView = 6
                                                    } else {
                                                        islandWin.controlSubView = 2
                                                        btStatusProc.running = true
                                                    }
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
                                                islandWin.controlSubView = 2
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
                                                islandWin.controlSubView = 3
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
                                color: root.dockEnabled ? root.colAccent : (dockHover.containsMouse ? root.colSurfaceHover : root.colSurface)
                                border.color: root.dockEnabled ? root.colAccent : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 180 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Rectangle {
                                        width: 34; height: 34; radius: 17
                                        color: root.dockEnabled ? Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.25) : Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.15)
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰻂"
                                            color: root.dockEnabled ? root.colBg : root.colAccent
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 17
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: "Rust-Dock"
                                            color: root.dockEnabled ? root.colBg : root.colFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: root.dockEnabled ? "Enabled · click to hide" : "Disabled · click to show"
                                            color: root.dockEnabled ? Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.8) : root.colMuted
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
                                    onClicked: {
                                        root.runCmd("~/.local/bin/rust-dock-toggle-all toggle")
                                        dockStatusRefreshTimer.restart()
                                    }
                                }
                            }

                            // Notifications Tile (opens center)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                height: 54
                                radius: 16
                                color: notifTileHover.containsMouse ? root.colSurfaceHover : root.colSurface
                                border.color: root.notifUnread > 0 ? root.colAccent : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                                border.width: root.notifUnread > 0 ? 1.5 : 1
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
                                            text: "󰂚"
                                            color: root.colAccent
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 17
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: "Notifications"
                                            color: root.colFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: root.notifUnread > 0 ? (root.notifUnread > 9 ? "9+ unread" : root.notifUnread + " unread") : "No unread"
                                            color: root.colMuted
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: notifTileHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.notifOpenCenter(islandWin.modelData.name)
                                }
                            }

                            // Night Light Tile: same split layout as Wi-Fi/Bluetooth.
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                height: 54
                                radius: 16
                                color: root.nightLightEnabled ? root.colAccent : (nightTileHover.containsMouse ? root.colSurfaceHover : root.colSurface)
                                border.color: root.nightLightEnabled ? root.colAccent : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 180 } }

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0

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
                                                    text: root.nightLightEnabled ? (root.nightLightTemperature + "K · " + root.nightLightGamma + "%") : (root.nightLightTemperature + "K · Inactive")
                                                    color: root.nightLightEnabled ? Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.8) : root.colMuted
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 9
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }
                                        MouseArea {
                                            id: nightTileHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                islandWin.controlSubView = 5
                                                nightLightSettingsProc.running = true
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: 1
                                        height: 24
                                        Layout.alignment: Qt.AlignVCenter
                                        color: root.nightLightEnabled ? Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.25) : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.12)
                                    }

                                    Rectangle {
                                        width: 38
                                        Layout.fillHeight: true
                                        radius: 16
                                        color: nightSettingsChevronHover.containsMouse ? (root.nightLightEnabled ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(255, 255, 255, 0.08)) : "transparent"
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰅂"
                                            color: root.nightLightEnabled ? root.colBg : root.colFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 14
                                        }
                                        MouseArea {
                                            id: nightSettingsChevronHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                islandWin.controlSubView = 5
                                                nightLightSettingsProc.running = true
                                            }
                                        }
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
                                        enabled: !volMouseArea.pressed && !capsuleWidthAnim.running && islandWin.expanded
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
                                        enabled: !brightMouseArea.pressed && !capsuleWidthAnim.running && islandWin.expanded
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
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { islandWin.expanded = false; root.runCmd("hyprpicker -a"); } }
                            }

                            Rectangle {
                                Layout.fillWidth: true; height: 36; radius: 18; color: root.colSurface
                                border.color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08); border.width: 1
                                RowLayout { anchors.centerIn: parent; spacing: 5
                                    Text { text: "󰸉"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                                    Text { text: "Gallery"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold }
                                }
                                // El "sleep 0.6" no es cosmetico. La isla pide foco de teclado
                                // (OnDemand) mientras esta expandida, y si rofi se abre en ese
                                // momento no lo consigue: se auto-selecciona la primera entrada y
                                // se cierra, sin que se vea nada. Medido: lanzado con setsid rofi
                                // devolvia "primero.webp" al instante; con medio segundo de espera se
                                // queda esperando al usuario.
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { islandWin.expanded = false; root.runCmd("sleep 0.6 && ~/.local/bin/wallpaper-gallery"); } }
                            }

                            Rectangle {
                                Layout.fillWidth: true; height: 36; radius: 18; color: root.colSurface
                                border.color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08); border.width: 1
                                RowLayout { anchors.centerIn: parent; spacing: 5
                                    Text { text: "󰑐"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                                    Text { text: "Random"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold }
                                }
                                // Este boton pone "Random" y un icono de barajado, pero llamaba a
                                // wallpaper-changer-with-waybar-sync, que abre un selector para elegir
                                // a mano. No es lo aleatorio, y por eso pulsarlo no hacia lo que el
                                // nombre promete. wallpaper-random es el que corresponde y ya
                                // funcionaba.
                                //
                                // Sin el "sleep 0.6" del boton de galeria: aqui no se abre ningun
                                // menu de rofi al que haya que robarle el foco.
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.runCmd("~/.local/bin/wallpaper-random") }
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
                                Layout.fillWidth: true
                                height: 36; radius: 18; color: root.colSurface
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
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { islandWin.expanded = false; root.runCmd("kitty -e htop"); } }
                            }
                        }

                    }

                    // ── 3. SUBSECCIÓN: REDES WI-FI (CONTROL) ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        visible: islandWin.controlSubView === 1

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
                                    onClicked: islandWin.controlSubView = 0
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
                                                islandWin.expanded = false
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

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            radius: 10
                            visible: islandWin.selectedWifiSsid === "" && islandWin.wifiConnectState !== "idle"
                            color: Qt.rgba(76/255, 175/255, 80/255, 0.18)
                            border.color: "#4caf50"
                            border.width: 1
                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                verticalAlignment: Text.AlignVCenter
                                text: islandWin.wifiConnectMessage
                                color: "#80d890"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }

                        // Inline Wi-Fi password card; errors stay here for retry.
                        Rectangle {
                            Layout.fillWidth: true
                            height: islandWin.wifiConnectState === "idle" ? 48 : 96
                            radius: 12
                            color: Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.15)
                            border.color: islandWin.wifiConnectState === "error" ? "#ef5350" : root.colAccent
                            border.width: 1
                            visible: islandWin.selectedWifiSsid !== ""

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 7

                                    Text {
                                        text: "󰌾 " + islandWin.selectedWifiSsid
                                        color: root.colFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        Layout.preferredWidth: 112
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 30
                                        radius: 8
                                        color: root.colBg
                                        TextInput {
                                            id: wifiPassInput
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            color: root.colFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                            echoMode: islandWin.wifiPasswordVisible ? TextInput.Normal : TextInput.Password
                                            enabled: islandWin.wifiConnectState !== "connecting" && islandWin.wifiConnectState !== "connected"
                                            selectByMouse: true
                                            clip: true
                                            onAccepted: connectBtnArea.clicked(null)
                                        }
                                    }

                                    Rectangle {
                                        width: 42; height: 30; radius: 8
                                        color: root.colSurface
                                        Text {
                                            anchors.centerIn: parent
                                            text: islandWin.wifiPasswordVisible ? "Hide" : "Show"
                                            color: root.colFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 8
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: islandWin.wifiConnectState !== "connecting" && islandWin.wifiConnectState !== "connected"
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: islandWin.wifiPasswordVisible = !islandWin.wifiPasswordVisible
                                        }
                                    }

                                    Rectangle {
                                        width: 76; height: 30; radius: 8
                                        color: islandWin.wifiConnectState === "connected" ? "#4caf50" : root.colAccent
                                        opacity: islandWin.wifiConnectState === "connecting" ? 0.65 : 1
                                        Text {
                                            anchors.centerIn: parent
                                            text: islandWin.wifiConnectState === "connecting" ? "Connecting" :
                                                  islandWin.wifiConnectState === "connected" ? "Connected" :
                                                  islandWin.wifiConnectState === "error" ? "Retry" : "Connect"
                                            color: root.colBg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 9
                                            font.weight: Font.Bold
                                        }
                                        MouseArea {
                                            id: connectBtnArea
                                            anchors.fill: parent
                                            enabled: islandWin.wifiConnectState !== "connecting" && islandWin.wifiConnectState !== "connected"
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                const pass = wifiPassInput.text
                                                if (pass.length === 0) {
                                                    islandWin.wifiConnectState = "error"
                                                    islandWin.wifiConnectMessage = "Enter the Wi-Fi password. Use Show to check it before connecting."
                                                    return
                                                }
                                                root.startWifiConnect(islandWin.modelData.name, islandWin.selectedWifiSsid, pass, false)
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: 28; height: 30; radius: 8
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
                                                islandWin.selectedWifiSsid = ""
                                                islandWin.wifiConnectState = "idle"
                                                islandWin.wifiConnectMessage = ""
                                                islandWin.wifiPasswordVisible = false
                                                wifiPassInput.text = ""
                                            }
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: islandWin.wifiConnectState !== "idle"
                                    text: islandWin.wifiConnectMessage
                                    color: islandWin.wifiConnectState === "error" ? "#ff7777" :
                                           islandWin.wifiConnectState === "connected" ? "#80d890" : root.colAccent
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 9
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        // Available Networks List
                        Flickable {
                            Layout.fillWidth: true
                            Layout.preferredHeight: islandWin.selectedWifiSsid !== "" ? 300 : 355
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
                                                    text: (modelData.saved ? "Saved  •  " : "") + modelData.signal + "%  •  " + modelData.security
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
                                                            if (modelData.saved) {
                                                                // Reuse NetworkManager's saved credentials; only show the password
                                                                // form if bringing the saved profile up fails.
                                                                root.startWifiConnect(islandWin.modelData.name, modelData.ssid, "", true)
                                                            } else if (modelData.security === "Open" || modelData.security === "Abierta" || modelData.security === "--") {
                                                                islandWin.selectedWifiSsid = ""
                                                                islandWin.wifiConnectState = "idle"
                                                                islandWin.wifiConnectMessage = ""
                                                                root.startWifiConnect(islandWin.modelData.name, modelData.ssid, "", false)
                                                            } else {
                                                                islandWin.selectedWifiSsid = modelData.ssid
                                                                islandWin.wifiConnectState = "idle"
                                                                islandWin.wifiConnectMessage = ""
                                                                islandWin.wifiPasswordVisible = false
                                                                wifiPassInput.text = ""
                                                                wifiPassInput.forceActiveFocus()
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
                        visible: islandWin.controlSubView === 2

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
                                    onClicked: islandWin.controlSubView = 0
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
                                                islandWin.expanded = false
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
                        visible: islandWin.controlSubView === 3

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
                                    onClicked: islandWin.controlSubView = 0
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
                                        islandWin.expanded = false
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
                        visible: islandWin.currentTab === 1 && islandWin.controlSubView === 0
                        opacity: islandWin.tabFade

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

                            // Batteries: como los otros cinco, una tarjeta mas de la cuadrícula. Abre el
                            // apartado con el detalle de cada pila. No se dibuja si esta maquina no tiene
                            // ninguna bateria.
                            Rectangle {
                            Layout.fillWidth: true
                            // Con Power Saver fuera de la cuadricula, la bateria se queda sola en su
                            // fila y ocupa las dos columnas.
                            Layout.columnSpan: 2
                            height: 54
                            radius: 14
                            visible: (root.batt?.count ?? 0) > 0
                            color: root.colSurface

                            RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10
                            Text { text: "󰁹"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20 }
                            ColumnLayout {
                            spacing: 1
                            Layout.fillWidth: true
                            Text { text: "Batteries"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.weight: Font.Bold }
                            Text {
                            // Los ciclos van aqui tambien, no solo en el detalle: es el dato que
                            // se mira de reojo. Con varias pilas se suman, como el porcentaje.
                            text: (root.batt?.count ?? 0) > 1
                            ? (root.batt.count) + " devices · " + (root.batt.total_pct ?? 0) + "% average · "
                              + ((root.batt?.total_cycles ?? 0) + " cycles")
                            : ((root.batt?.total_pct ?? 0) + "% · " + ((root.batt?.ac?.online) ? "Charging" : "On battery")
                              + " · " + ((root.batt?.total_cycles ?? 0) + " cycles"))
                            color: root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9
                            elide: Text.ElideRight; Layout.fillWidth: true
                            }
                            }

                            // Separador + chevron, igual que las demas tarjetas: el icono de
                            // carga sobraba aqui, el estado de red ya sale en el subtitulo.
                            Rectangle {
                                width: 1
                                height: 16
                                radius: 0.5
                                color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.15)
                            }

                            Text {
                                text: "󰅂"
                                color: root.colMuted
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                            }
                            }

                            MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                            islandWin.controlSubView = 7
                            battProc.running = true
                            }
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
                                    islandWin.controlSubView = 4
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

                    // ── SUBSECCIÓN: BATERIAS ──
                    // Un apartado entero dentro de la pestaña Hyprland: una tarjeta por bateria con
                    // sus datos y sus botones de limite. Se llega pulsando la tarjeta Batteries de
                    // la cuadrícula de arriba, y se vuelve con el boton Back.
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        visible: islandWin.currentTab === 1 && islandWin.controlSubView === 7
                        // 28 de cabecera + 116 por bateria + 8 de separacion + 44 del boton Back.
                        // Un Repeater no propaga el implicitHeight de sus delegates al layout padre,
                        // asi que el alto se declara aqui y no sale de calcularlo.
                        Layout.preferredHeight: (root.batt?.count ?? 0) > 0 ? (28 + root.batt.count * 116 + 8 + 44) : 0

                        // Cabecera: total de todas las pilas y estado del cargador
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text { text: "󰁹"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                            Text { text: "Batteries"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold }
                            Item { Layout.fillWidth: true }
                            Text {
                                visible: (root.batt?.count ?? 0) > 1
                                text: (root.batt?.total_pct ?? 0) + "% total"
                                color: root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9
                            }
                            Text {
                                text: (root.batt?.ac?.online) ? "Charging" : "On battery"
                                color: (root.batt?.ac?.online) ? root.colAccent : root.colMuted
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9
                            }
                        }

                        Repeater {
                        model: root.batt?.devices ?? []

                        delegate: Rectangle {
                        id: battCardDel
                        // El limite y el nombre de la bateria pasan por propiedades CON TIPO.
                        // Leer modelData desde el delegate de dentro no es fiable: con el limite
                        // ningun boton se resaltaba, y al pulsar el nombre daba undefined y el
                        // comando se lanzaba contra una bateria inexistente.
                        readonly property int umbral: (modelData && modelData.threshold !== null && modelData.threshold !== undefined) ? modelData.threshold : 100
                        readonly property string batName: (modelData && modelData.name) ? modelData.name : ""
                        Layout.fillWidth: true
                        // 116 px: lo que ocupa la tarjeta con los datos y los botones de limite
                        // DENTRO. Con menos, los botones se salian de la tarjeta.
                        height: 116
                        radius: 12
                        color: root.colSurface
                        border.color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.05)
                        border.width: 1

                        ColumnLayout {
                        id: battCard
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                        text: modelData.icon
                        color: root.colAccent
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        }
                        Text {
                        text: modelData.name + (modelData.model ? " · " + modelData.model : "")
                        color: root.colFg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        }
                        Text {
                        visible: modelData.remaining !== null && modelData.remaining !== undefined
                        text: modelData.remaining ?? ""
                        color: root.colMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
                        }
                        Text {
                        text: modelData.state
                        color: root.colMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
                        }
                        Text {
                        text: (modelData.capacity ?? 0) + "%"
                        color: root.colAccent
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        }
                        }

                        Rectangle {
                        Layout.fillWidth: true
                        height: 4
                        radius: 2
                        color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.1)
                        Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(0, Math.min(parent.width, parent.width * ((modelData.capacity ?? 0) / 100.0)))
                        radius: 2
                        color: (modelData.capacity ?? 100) <= 15 ? "#e05c5c" : ((modelData.capacity ?? 100) <= 30 ? "#e0a75c" : root.colAccent)
                        Behavior on width { NumberAnimation { duration: 200 } }
                        }
                        Rectangle {
                        visible: battCardDel.umbral < 100
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(0, Math.min(parent.width, parent.width * (battCardDel.umbral / 100.0)))
                        color: "transparent"
                        border.color: Qt.rgba(255, 255, 255, 0.35)
                        border.width: 1
                        radius: 2
                        }
                        }

                        Flow {
                        Layout.fillWidth: true
                        spacing: 10
                        Row {
                        spacing: 3
                        visible: (modelData.power_w !== null && modelData.power_w !== undefined)
                        Text { text: "Power"; color: root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                        Text { text: (modelData.power_w ?? 0) + " W"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                        }
                        Row {
                        spacing: 3
                        visible: (modelData.voltage !== null && modelData.voltage !== undefined)
                        Text { text: "Volt"; color: root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                        Text {
                            // Sin toFixed sale "17.580000000000002 V": con una sola
                            // bateria el voltaje ya viene redondeado de sysfs y no se
                            // nota, pero con varias se ve el error de coma flotante.
                            text: (modelData.voltage ?? 0).toFixed(2) + " V"
                            color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9
                        }
                        }
                        Row {
                        spacing: 3
                        visible: (modelData.health !== null && modelData.health !== undefined)
                        Text { text: "Health"; color: root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                        Text { text: (modelData.health ?? 0) + "%"; color: (modelData.health ?? 100) >= 90 ? root.colFg : "#e0a75c"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                        }
                        Row {
                        spacing: 3
                        visible: (modelData.energy_full !== null && modelData.energy_full !== undefined)
                        Text { text: "Full"; color: root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                        Text { text: (modelData.energy_full ?? 0) + " Wh"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                        }
                        Row {
                        spacing: 3
                        visible: (modelData.cycles !== null && modelData.cycles !== undefined)
                        Text { text: "Cycles"; color: root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                        Text { text: "" + (modelData.cycles ?? 0); color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                        }
                        Row {
                        spacing: 3
                        visible: (modelData.threshold !== null && modelData.threshold !== undefined)
                        Text { text: "Limit"; color: root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                        Text { text: (battCardDel.umbral) + "%"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                        }
                        }

                        // ── Limite de carga ──
                        // Un boton por valor, y cada uno escribe en el charge_control_end_threshold
                        // de SU bateria, no en el de al lado: el limite va por dispositivo. El valor
                        // puesto sale resaltado, y 100 es "sin limite" y se dice con palabras. Solo de
                        // 70 para arriba: por debajo el firmware de este portatil acepta el numero pero
                        // luego no lo respeta.
                        Row {
                        Layout.alignment: Qt.AlignRight
                        Layout.topMargin: 2
                        spacing: 6
                        Repeater {
                        model: [70, 80, 90, 100]
                        delegate: Rectangle {
                        id: limitBtn
                        readonly property int valor: modelData
                        readonly property bool puesto: valor === battCardDel.umbral
                        readonly property string texto: valor === 100 ? "Off" : valor + "%"
                        width: limitLabel.implicitWidth + 16
                        height: 22
                        radius: 11
                        color: puesto ? root.colAccent : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.06)
                        border.color: puesto ? root.colAccent : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                        id: limitLabel
                        anchors.centerIn: parent
                        text: limitBtn.texto
                        color: limitBtn.puesto ? root.colBg : root.colMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
                        font.weight: limitBtn.puesto ? Font.Bold : Font.Normal
                        }
                        MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                        battLimitProc.command = ["bash", "-c",
                        "$HOME/.local/bin/battery-charge-limit " + limitBtn.valor + " " + battCardDel.batName + " 2>&1"]
                        battLimitProc.running = true
                        }
                        }
                        }
                        }
                        }

                        Text {
                        Layout.fillWidth: true
                        visible: root.battLimitMsg !== ""
                        text: root.battLimitMsg
                        color: root.battLimitMsg.indexOf(battCardDel.batName + " ") === 0 ? root.colAccent : "#e05c5c"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 8
                        elide: Text.ElideRight
                        }
                        }
                        }
                        }

                        // Boton de vuelta a la vista principal, como en los demas subapartados
                        // (WiFi, Bluetooth, audio).
                        Rectangle {
                            Layout.preferredWidth: 96
                            height: 32
                            radius: 16
                            color: root.colSurface
                            border.color: root.colBorder
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                Text { text: "󰁍"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 }
                                Text { text: "Back"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { islandWin.controlSubView = 0 }
                            }
                        }
                    }

                    // ── TAB 2: ALERTS CENTER ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        visible: islandWin.currentTab === 2
                        opacity: islandWin.tabFade

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Text {
                                text: "Notifications"
                                color: root.colFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                font.weight: Font.Bold
                            }
                            Rectangle {
                                height: 20
                                width: Math.max(20, tabUnreadLbl.implicitWidth + 12)
                                radius: 10
                                color: root.notifUnread > 0 ? root.colAccent : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.12)
                                Text {
                                    id: tabUnreadLbl
                                    anchors.centerIn: parent
                                    text: root.notifUnread > 9 ? "9+" : root.notifUnread
                                    color: root.notifUnread > 0 ? root.colBg : root.colMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                height: 32
                                width: 96
                                radius: 16
                                color: root.colSurface
                                border.color: root.colBorder
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: "Clear all"
                                    color: root.colFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.notifClear()
                                }
                            }
                        }

                        Flickable {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(470, Math.max(140, tabNotifCol.implicitHeight))
                            contentWidth: width
                            contentHeight: tabNotifCol.implicitHeight
                            clip: true

                            ColumnLayout {
                                id: tabNotifCol
                                width: parent.width
                                spacing: 10

                                Repeater {
                                    model: root.notifHistory
                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: tabNotifCardCol.implicitHeight + 24
                                        radius: 12
                                        color: root.colSurface
                                        border.color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                                        border.width: 1

                                        ColumnLayout {
                                            id: tabNotifCardCol
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.margins: 12
                                            anchors.bottomMargin: 12
                                            spacing: 4

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6
                                                Text {
                                                    text: "󰂚"
                                                    color: root.colAccent
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 12
                                                }
                                                Text {
                                                    text: modelData.app
                                                    color: root.colAccent
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                }
                                                Text {
                                                    text: modelData.time
                                                    color: root.colMuted
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 9
                                                }
                                            }

                                            Text {
                                                visible: modelData.summary !== ""
                                                text: modelData.summary
                                                color: root.colFg
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                wrapMode: Text.Wrap
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                visible: modelData.body !== ""
                                                text: modelData.body
                                                color: root.colMuted
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 10
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 3
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: "Tap to open app"
                                                color: root.colMuted
                                                opacity: 0.6
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 8
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                islandWin.expanded = false
                                                root.runCmd("$HOME/.local/bin/open-notification-app '" + modelData.app + "'")
                                            }
                                        }
                                    }
                                }

                                // ── MUTED APPS ──
                                // Silenciar una app entera: sus notificaciones se
                                // descartan al llegar y ni aparecen aqui. La lista
                                // sale de las apps que ya han hablado mas las que
                                // estan silenciadas, para poder quitar el silencio
                                // sin esperar a que la app vuelva a notificar.
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    visible: root.notifKnownApps().length > 0

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Text {
                                            text: "󰖔"
                                            color: root.mutedApps.length > 0 ? "#e0a75c" : root.colMuted
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                        }
                                        Text {
                                            text: "Muted apps"
                                            color: root.colFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            visible: root.mutedApps.length > 0
                                            text: root.mutedApps.length + " active"
                                            color: root.colMuted
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 9
                                        }
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Repeater {
                                            model: root.notifKnownApps()

                                            delegate: Rectangle {
                                                readonly property bool muteOn: root.notifMuted(modelData)

                                                height: 26
                                                width: muteLabel.implicitWidth + 26
                                                radius: 13
                                                color: muteOn ? Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.22) : root.colSurface
                                                border.color: muteOn ? root.colAccent : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                                                border.width: 1
                                                Behavior on color { ColorAnimation { duration: 120 } }

                                                Text {
                                                    id: muteLabel
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 9
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: (parent.muteOn ? "󰖔 " : "󰂚 ") + modelData
                                                    color: parent.muteOn ? root.colFg : root.colMuted
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 9
                                                    elide: Text.ElideRight
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        // El nombre se copia ANTES de tocar nada: al
                                                        // silenciar, notifKnownApps() cambia y el
                                                        // delegate se reconstruye, y después modelData
                                                        // ya no vale.
                                                        let app = modelData
                                                        root.notifToggleMute(app)
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: root.mutedApps.length > 0
                                        text: "Notifications from muted apps are discarded before they reach the list."
                                        color: root.colMuted
                                        opacity: 0.65
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 8
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    visible: root.notifHistory.length === 0
                                    text: "No notifications yet."
                                    color: root.colMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.topMargin: 20
                                }
                            }
                        }
                    }



                    // ── TAB 3: PORTAPAPELES ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        visible: islandWin.currentTab === 3
                        opacity: islandWin.tabFade

                        // ── PORTAPAPELES: opcion aparte dentro de Alertas ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Text {
                                text: "Clipboard"
                                color: root.colFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                font.weight: Font.Bold
                            }
                            Rectangle {
                                height: 20
                                width: 34
                                radius: 10
                                color: root.clipList.length > 0 ? root.colAccent : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.12)
                                Text {
                                    anchors.centerIn: parent
                                    text: root.clipList.length > 9 ? "9+" : root.clipList.length
                                    color: root.clipList.length > 0 ? root.colBg : root.colMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                height: 32
                                width: 110
                                radius: 16
                                color: root.colSurface
                                border.color: root.colBorder
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: "Clear all"
                                    color: root.colFg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.runCmd("cliphist wipe"); clipListProc.running = true }
                                }
                            }
                        }

Flickable {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(470, Math.max(140, tabClipCol.implicitHeight))
                            contentWidth: width
                            contentHeight: tabClipCol.implicitHeight
                            clip: true

                            ColumnLayout {
                                id: tabClipCol
                                width: parent.width
                                spacing: 8
                        Repeater {
                            model: root.clipList
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                height: 48
                                radius: 12
                                color: modelData.id === root.clipCopiedId ? Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.25) : root.colSurface
                                border.color: modelData.id === root.clipCopiedId ? root.colAccent : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.05)
                                border.width: 1
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 12
                                    spacing: 12
                                    Item {
                                        width: 26; height: 26
                                        Layout.alignment: Qt.AlignVCenter
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 13
                                            visible: !modelData.image
                                            color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.08)
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰅍"
                                                color: root.colAccent
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 14
                                            }
                                        }
                                        Image {
                                            anchors.fill: parent
                                            visible: modelData.image
                                            source: modelData.image ? "file://" + modelData.thumb : ""
                                            fillMode: Image.PreserveAspectCrop
                                            smooth: true
                                            asynchronous: true
                                        }
                                    }
                                    ColumnLayout {
                                        spacing: 1
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        Text {
                                            text: modelData.title
                                            color: root.colFg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 13
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        // Al copiar, la propia fila lo dice: "Text copied" o
                                        // "Image pasted" en vez de su subtitulo, en color acento.
                                        Text {
                                            readonly property bool justCopied: modelData.id === root.clipCopiedId && root.clipToast !== ""
                                            text: justCopied ? root.clipToast : modelData.sub
                                            visible: justCopied || modelData.sub !== ""
                                            color: justCopied ? root.colAccent : root.colMuted
                                            font.weight: justCopied ? Font.Bold : Font.Normal
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.runCmd("cliphist decode " + modelData.id + " | wl-copy")
                                        root.clipCopiedId = modelData.id
                                        root.clipToast = modelData.image ? "Image pasted" : "Text copied"
                                        clipCopyTimer.restart()
                                        clipListProc.running = true
                                    }
                                }
                            }
                        }

                    Timer {
                            id: clipCopyTimer
                            interval: 1500
                            repeat: false
                            onTriggered: { root.clipCopiedId = -1; root.clipToast = "" }
                        }
                        Timer {
                            interval: 5000
                            repeat: true
                            running: islandWin.currentTab === 3
                            triggeredOnStart: true
                            onTriggered: clipListProc.running = true
                        }

                        Text {
                            visible: root.clipList.length === 0
                            text: "Empty: copy something first"
                            color: root.colMuted
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            Layout.alignment: Qt.AlignHCenter
                        }
                            }
                        }

                    }

                    // ── 5. SUBSECCIÓN: NIGHT LIGHT ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        visible: islandWin.controlSubView === 5

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
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: islandWin.controlSubView = 0 }
                            }
                            Text {
                                text: "Night Light"
                                color: root.colFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                font.weight: Font.Bold
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                width: 32; height: 32; radius: 16
                                color: Qt.rgba(255, 255, 255, 0.08)
                                Text { anchors.centerIn: parent; text: "󰑐"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: nightLightSettingsProc.running = true }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            radius: 14
                            color: root.colSurface
                            border.color: root.nightLightEnabled ? root.colAccent : root.colBorder
                            border.width: 1
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10
                                Rectangle {
                                    width: 38; height: 38; radius: 19
                                    color: root.nightLightEnabled ? Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.22) : root.colBg
                                    Text { anchors.centerIn: parent; text: "󰖔"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18 }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { text: root.nightLightEnabled ? "Enabled" : "Disabled"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.weight: Font.Bold }
                                    Text { text: root.nightLightEnabled ? "Blue-light filter is active" : "Blue-light filter is off"; color: root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                                }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    width: 68; height: 32; radius: 16
                                    color: root.nightLightEnabled ? root.colAccent : root.colSurface
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Text { anchors.centerIn: parent; text: root.nightLightEnabled ? "ON" : "OFF"; color: root.nightLightEnabled ? root.colBg : root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.nightLightEnabled = !root.nightLightEnabled
                                            root.runCmd("~/.local/bin/toggle-nightlight " + (root.nightLightEnabled ? "on" : "off"))
                                            nightLightSettingsRefreshTimer.restart()
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 132
                            radius: 14
                            color: root.colSurface
                            border.color: root.colBorder; border.width: 1
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 12; spacing: 7
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Color temperature"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                                    Item { Layout.fillWidth: true }
                                    Text { text: root.nightLightTemperature + " K"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                                }
                                Slider {
                                    id: nightTemperatureSlider
                                    Layout.fillWidth: true
                                    from: 1800; to: 6500; stepSize: 100
                                    value: root.nightLightTemperature
                                    onMoved: {
                                        root.nightLightTemperature = Math.round(value / 100) * 100
                                        nightTemperatureApplyTimer.restart()
                                    }
                                    background: Rectangle {
                                        x: nightTemperatureSlider.leftPadding
                                        y: nightTemperatureSlider.topPadding + nightTemperatureSlider.availableHeight / 2 - height / 2
                                        width: nightTemperatureSlider.availableWidth; height: 5; radius: 3
                                        color: root.colBg
                                        Rectangle { width: nightTemperatureSlider.visualPosition * parent.width; height: parent.height; radius: 3; color: root.colAccent }
                                    }
                                    handle: Rectangle {
                                        x: nightTemperatureSlider.leftPadding + nightTemperatureSlider.visualPosition * (nightTemperatureSlider.availableWidth - width)
                                        y: nightTemperatureSlider.topPadding + nightTemperatureSlider.availableHeight / 2 - height / 2
                                        width: 18; height: 18; radius: 9
                                        color: root.colAccent; border.color: root.colFg; border.width: 1
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 6
                                    Repeater {
                                        model: [
                                            { label: "Candle", value: 2200 },
                                            { label: "Warm", value: 3000 },
                                            { label: "Balanced", value: 4500 },
                                            { label: "Daylight", value: 6000 }
                                        ]
                                        delegate: Rectangle {
                                            required property var modelData
                                            Layout.fillWidth: true; height: 25; radius: 12
                                            color: root.nightLightTemperature === modelData.value ? root.colAccent : root.colBg
                                            Text { anchors.centerIn: parent; text: modelData.label; color: root.nightLightTemperature === modelData.value ? root.colBg : root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 8; font.weight: Font.Bold }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.nightLightTemperature = modelData.value
                                                    root.runCmd("~/.local/bin/toggle-nightlight temperature " + modelData.value)
                                                }
                                            }
                                        }
                                    }
                                }
                                Text { text: "Lower values are warmer; higher values look more neutral."; color: root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 8 }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 118
                            radius: 14
                            color: root.colSurface
                            border.color: root.colBorder; border.width: 1
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 12; spacing: 6
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Display gamma"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                                    Item { Layout.fillWidth: true }
                                    Text { text: root.nightLightGamma + "%"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                                }
                                Slider {
                                    id: nightGammaSlider
                                    Layout.fillWidth: true
                                    from: 20; to: 100; stepSize: 5
                                    value: root.nightLightGamma
                                    onMoved: {
                                        root.nightLightGamma = Math.round(value / 5) * 5
                                        nightGammaApplyTimer.restart()
                                    }
                                    background: Rectangle {
                                        x: nightGammaSlider.leftPadding
                                        y: nightGammaSlider.topPadding + nightGammaSlider.availableHeight / 2 - height / 2
                                        width: nightGammaSlider.availableWidth; height: 5; radius: 3
                                        color: root.colBg
                                        Rectangle { width: nightGammaSlider.visualPosition * parent.width; height: parent.height; radius: 3; color: root.colAccent }
                                    }
                                    handle: Rectangle {
                                        x: nightGammaSlider.leftPadding + nightGammaSlider.visualPosition * (nightGammaSlider.availableWidth - width)
                                        y: nightGammaSlider.topPadding + nightGammaSlider.availableHeight / 2 - height / 2
                                        width: 18; height: 18; radius: 9
                                        color: root.colAccent; border.color: root.colFg; border.width: 1
                                    }
                                }
                                Text { text: "Lower gamma dims the image; 100% is normal brightness."; color: root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 8 }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 170
                            radius: 14
                            color: root.colSurface
                            border.color: root.nightLightScheduleEnabled ? root.colAccent : root.colBorder
                            border.width: 1
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 7
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Automatic schedule"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold }
                                    Item { Layout.fillWidth: true }
                                    Text { text: root.nightLightScheduleEnabled ? "Enabled" : "Optional · Off"; color: root.nightLightScheduleEnabled ? root.colAccent : root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; font.weight: Font.Bold }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Text { text: "Start"; color: root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                                    TextField {
                                        id: nightScheduleStartInput
                                        Layout.fillWidth: true
                                        implicitHeight: 30
                                        maximumLength: 5
                                        placeholderText: "HH:MM"
                                        text: islandWin.nightScheduleStartText
                                        color: root.colFg
                                        placeholderTextColor: root.colMuted
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        horizontalAlignment: TextInput.AlignHCenter
                                        onTextEdited: islandWin.nightScheduleStartText = text
                                        background: Rectangle { radius: 8; color: root.colBg; border.color: root.colBorder; border.width: 1 }
                                    }
                                    Text { text: "End"; color: root.colMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                                    TextField {
                                        id: nightScheduleEndInput
                                        Layout.fillWidth: true
                                        implicitHeight: 30
                                        maximumLength: 5
                                        placeholderText: "HH:MM"
                                        text: islandWin.nightScheduleEndText
                                        color: root.colFg
                                        placeholderTextColor: root.colMuted
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        horizontalAlignment: TextInput.AlignHCenter
                                        onTextEdited: islandWin.nightScheduleEndText = text
                                        background: Rectangle { radius: 8; color: root.colBg; border.color: root.colBorder; border.width: 1 }
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: islandWin.nightScheduleValidation || "Off by default. Set both times (24-hour HH:MM) to enable."
                                    color: islandWin.nightScheduleValidation ? root.colAccent : root.colMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 8
                                    elide: Text.ElideRight
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 30; radius: 15
                                        color: root.colAccent
                                        Text {
                                            anchors.centerIn: parent
                                            text: root.nightLightScheduleEnabled ? "Update schedule" : "Enable schedule"
                                            color: root.colBg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 9
                                            font.weight: Font.Bold
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                const start = islandWin.nightScheduleStartText.trim()
                                                const end = islandWin.nightScheduleEndText.trim()
                                                const valid = /^([01][0-9]|2[0-3]):[0-5][0-9]$/
                                                if (!valid.test(start) || !valid.test(end) || start === end) {
                                                    islandWin.nightScheduleValidation = "Enter different valid start and end times."
                                                    return
                                                }
                                                root.nightLightScheduleStart = start
                                                root.nightLightScheduleEnd = end
                                                islandWin.nightScheduleValidation = "Schedule saved. Night Light follows this time window."
                                                root.runCmd("~/.local/bin/toggle-nightlight schedule on " + start + " " + end)
                                                nightLightSettingsRefreshTimer.restart()
                                            }
                                        }
                                    }
                                    Rectangle {
                                        width: 78; height: 30; radius: 15
                                        color: root.colBg
                                        border.color: root.colBorder; border.width: 1
                                        opacity: root.nightLightScheduleEnabled ? 1 : 0.45
                                        Text { anchors.centerIn: parent; text: "Disable"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; font.weight: Font.Bold }
                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: root.nightLightScheduleEnabled
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.nightLightScheduleEnabled = false
                                                islandWin.nightScheduleValidation = "Automatic schedule disabled."
                                                root.runCmd("~/.local/bin/toggle-nightlight schedule off")
                                                nightLightSettingsRefreshTimer.restart()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Rectangle {
                                Layout.fillWidth: true; height: 34; radius: 17
                                color: root.colSurface; border.color: root.colBorder; border.width: 1
                                Text { anchors.centerIn: parent; text: "Reset defaults · 4500 K · 100%"; color: root.colFg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.nightLightTemperature = 4500
                                        root.nightLightGamma = 100
                                        root.runCmd("~/.local/bin/toggle-nightlight reset")
                                    }
                                }
                            }
                        }
                    }
                    // ── SUBSECCIÓN: BLUETOOTH PAIRING REQUEST ──
                    // BlueZ entrega la solicitud al agente registrado, no al
                    // servidor de notificaciones: bluetooth-pair-agent la
                    // reenvia aqui para que la confirme el usuario.
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        visible: islandWin.controlSubView === 6

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
                                    onClicked: {
                                        if (root.pairRequest.active && root.pairRequest.state === "pending") root.answerPairing("reject")
                                        islandWin.controlSubView = 0
                                    }
                                }
                            }
                            Text {
                                text: "Pairing Request"
                                color: root.colFg; font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13; font.weight: Font.Bold
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                width: 68; height: 32; radius: 16
                                color: root.colSurface
                                border.color: root.colBorder; border.width: 1
                                visible: root.pairRequest.active
                                Text {
                                    anchors.centerIn: parent
                                    text: root.pairRequest.state === "pending" ? "Waiting" : (root.pairRequest.state === "accepted" ? "Done" : "Closed")
                                    color: root.pairRequest.state === "accepted" ? root.colAccent : root.colMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 9; font.weight: Font.Bold
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 232
                            radius: 14
                            color: root.colSurface
                            border.color: root.pairRequest.active ? root.colAccent : root.colBorder
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 180 } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    Rectangle {
                                        width: 38; height: 38; radius: 19
                                        color: Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.18)
                                        Text { anchors.centerIn: parent; text: "󰂯"; color: root.colAccent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18 }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: root.pairRequest.name
                                            color: root.colFg; font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 12; font.weight: Font.Bold
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: root.pairRequest.device
                                            color: root.colMuted; font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 1
                                    color: root.colBorder
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.pairRequest.kind === "pin" ? "Enter the PIN" : (root.pairRequest.kind === "authorize" ? "Authorization" : "Confirmation code")
                                    color: root.colMuted; font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 9; font.weight: Font.Bold
                                }

                                // Numeric comparison: the code is split in pairs
                                // so it can be read digit by digit.
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    visible: root.pairRequest.kind !== "pin" && root.pairRequest.passkey !== ""
                                    Repeater {
                                        model: {
                                            let digits = (root.pairRequest.passkey || "").split("")
                                            let grouped = []
                                            for (let i = 0; i < digits.length; i += 2) grouped.push(digits[i] + (digits[i + 1] || ""))
                                            return grouped
                                        }
                                        delegate: Rectangle {
                                            required property int index
                                            required property string modelData
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 40
                                            radius: 10
                                            color: root.colBg
                                            border.color: root.colBorder; border.width: 1
                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData
                                                color: root.colAccent; font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 18; font.weight: Font.Bold
                                            }
                                        }
                                    }
                                }

                                TextField {
                                    id: pairPinInput
                                    Layout.fillWidth: true
                                    visible: root.pairRequest.kind === "pin"
                                    implicitHeight: 34
                                    maximumLength: 8
                                    echoMode: TextInput.PasswordEchoOnEdit
                                    placeholderText: "PIN"
                                    text: root.pairRequest.pin
                                    color: root.colFg
                                    placeholderTextColor: root.colMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    horizontalAlignment: TextInput.AlignHCenter
                                    onTextEdited: root.pairRequest = Object.assign({}, root.pairRequest, { pin: text })
                                    background: Rectangle { radius: 10; color: root.colBg; border.color: root.colBorder; border.width: 1 }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.pairRequest.hint
                                    color: root.colMuted; font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 9
                                    wrapMode: Text.WordWrap
                                }

                                Item { Layout.fillWidth: true; Layout.preferredHeight: 1 }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 32; radius: 16
                                        color: root.colSurface
                                        border.color: root.colBorder; border.width: 1
                                        opacity: root.pairRequest.state === "pending" ? 1 : 0.45
                                        Text {
                                            anchors.centerIn: parent
                                            text: "Reject"
                                            color: root.colFg; font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10; font.weight: Font.Bold
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            enabled: root.pairRequest.state === "pending"
                                            onClicked: root.answerPairing("reject")
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 32; radius: 16
                                        color: root.colAccent
                                        opacity: root.pairRequest.state === "pending"
                                                && (root.pairRequest.kind !== "pin" || root.pairRequest.pin.length > 0) ? 1 : 0.45
                                        Text {
                                            anchors.centerIn: parent
                                            text: "Confirm"
                                            color: root.colBg; font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10; font.weight: Font.Bold
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            enabled: root.pairRequest.state === "pending"
                                                    && (root.pairRequest.kind !== "pin" || root.pairRequest.pin.length > 0)
                                            onClicked: root.answerPairing("accept")
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: !root.pairRequest.active
                            text: "No pending pairing request."
                            color: root.colMuted; font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                        }
                    }

                    // ── SUBSECCIÓN: SYSTEM UPDATE (OTA - ANDROID STYLE) ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        visible: islandWin.controlSubView === 4

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
                                    onClicked: islandWin.controlSubView = 0
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
                                    onClicked: { islandWin.expanded = false; root.runCmd("kitty -e system-ota gui") }
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
