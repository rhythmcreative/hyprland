import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (homeDir + "/.config")
    readonly property string dataHome: Quickshell.env("XDG_DATA_HOME") || (homeDir + "/.local/share")
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"

    // ════════════════════════════════════════════════════════════════════════
    // 1. Live Pywal Colors (reactive, zero restart needed on wallpaper change)
    // ════════════════════════════════════════════════════════════════════════
    property int _walRev: 0

    FileView {
        id: walFile
        path: root.homeDir + "/.cache/wal/colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: walFile.reload()
        onLoaded: root._walRev++
    }

    readonly property var walData: {
        const _d = root._walRev
        try {
            const raw = walFile.text()
            return raw ? JSON.parse(raw) : null
        } catch (e) {
            return null
        }
    }

    readonly property color colBg: (walData && walData.special && walData.special.background) ? walData.special.background : "#1e1e2e"
    readonly property color colFg: (walData && walData.special && walData.special.foreground) ? walData.special.foreground : "#cdd6f4"
    readonly property color colColor1: (walData && walData.colors && walData.colors.color1) ? walData.colors.color1 : "#495253"
    readonly property color colAccent: (walData && walData.colors && walData.colors.color4) ? walData.colors.color4 : "#89b4fa"
    readonly property color colAccentAlt: (walData && walData.colors && walData.colors.color2) ? walData.colors.color2 : "#a6e3a1"
    readonly property color colUrgent: (walData && walData.colors && walData.colors.color1) ? walData.colors.color1 : "#f38ba8"
    readonly property color colMuted: (walData && walData.colors && walData.colors.color8) ? walData.colors.color8 : "#6c7086"
    readonly property color colSurface: Qt.rgba(colFg.r, colFg.g, colFg.b, 0.08)
    readonly property color colSurfaceHover: Qt.rgba(colFg.r, colFg.g, colFg.b, 0.16)

    // ════════════════════════════════════════════════════════════════════════
    // 2. Live Multi-Language i18n
    // ════════════════════════════════════════════════════════════════════════
    property string activeLang: "es"
    property var i18nCatalog: ({})

    readonly property var builtInI18n: ({
        es: {
            dock_new_window: "Nueva ventana",
            dock_pin: "Fijar en el dock",
            dock_unpin: "Desfijar del dock",
            dock_minimize_all: "Minimizar todas",
            dock_restore_all: "Restaurar todas",
            dock_close_all: "Cerrar todas las ventanas",
            dock_minimized: "Minimizada",
            dock_min_short: "MIN",
            dock_launcher: "Aplicaciones",
            dock_settings_title: "Ajustes del dock",
            dock_autohide: "Ocultar automáticamente",
            dock_compact_preview: "Vistas previas compactas",
            dock_show_launcher: "Botón de aplicaciones",
            dock_icon_size: "Tamaño de iconos",
            dock_position: "Posición",
            dock_hide: "Ocultar dock"
        },
        en: {
            dock_new_window: "New window",
            dock_pin: "Pin to dock",
            dock_unpin: "Unpin from dock",
            dock_minimize_all: "Minimize all",
            dock_restore_all: "Restore all",
            dock_close_all: "Close all windows",
            dock_minimized: "Minimized",
            dock_min_short: "MIN",
            dock_launcher: "Applications",
            dock_settings_title: "Dock Settings",
            dock_autohide: "Auto-hide",
            dock_compact_preview: "Compact previews",
            dock_show_launcher: "App launcher button",
            dock_icon_size: "Icon size",
            dock_position: "Position",
            dock_hide: "Hide dock"
        },
        fr: {
            dock_new_window: "Nouvelle fenêtre",
            dock_pin: "Épingler au dock",
            dock_unpin: "Détacher du dock",
            dock_minimize_all: "Tout réduire",
            dock_restore_all: "Tout restaurer",
            dock_close_all: "Fermer toutes les fenêtres",
            dock_minimized: "Réduite",
            dock_min_short: "RÉD",
            dock_launcher: "Applications",
            dock_settings_title: "Paramètres du dock",
            dock_autohide: "Masquage automatique",
            dock_compact_preview: "Aperçus compacts",
            dock_show_launcher: "Bouton d'applications",
            dock_icon_size: "Taille des icônes",
            dock_position: "Position",
            dock_hide: "Masquer le dock"
        },
        de: {
            dock_new_window: "Neues Fenster",
            dock_pin: "An Dock anheften",
            dock_unpin: "Vom Dock lösen",
            dock_minimize_all: "Alle minimieren",
            dock_restore_all: "Alle wiederherstellen",
            dock_close_all: "Alle Fenster schließen",
            dock_minimized: "Minimiert",
            dock_min_short: "MIN",
            dock_launcher: "Anwendungen",
            dock_settings_title: "Dock-Einstellungen",
            dock_autohide: "Automatisch ausblenden",
            dock_compact_preview: "Kompakte Vorschau",
            dock_show_launcher: "App-Starter-Symbol",
            dock_icon_size: "Symbolgröße",
            dock_position: "Position",
            dock_hide: "Dock ausblenden"
        },
        pt: {
            dock_new_window: "Nova janela",
            dock_pin: "Fixar no dock",
            dock_unpin: "Desafixar do dock",
            dock_minimize_all: "Minimizar todas",
            dock_restore_all: "Restaurar todas",
            dock_close_all: "Fechar todas as janelas",
            dock_minimized: "Minimizada",
            dock_min_short: "MIN",
            dock_launcher: "Aplicações",
            dock_settings_title: "Definições do dock",
            dock_autohide: "Ocultar automaticamente",
            dock_compact_preview: "Pré-visualizações compactas",
            dock_show_launcher: "Botão de aplicações",
            dock_icon_size: "Tamanho dos ícones",
            dock_position: "Posição",
            dock_hide: "Ocultar dock"
        }
    })

    FileView {
        id: langFile
        path: root.configHome + "/rhythm/language"
        watchChanges: true
        printErrors: false
        onFileChanged: langFile.reload()
        onLoaded: {
            const raw = (langFile.text() || "").trim()
            if (raw) root.activeLang = raw
            catalogFile.reload()
        }
    }

    FileView {
        id: catalogFile
        path: root.configHome + "/rhythm/i18n/" + root.activeLang + "/island.json"
        watchChanges: true
        printErrors: false
        onFileChanged: catalogFile.reload()
        onLoaded: {
            try {
                root.i18nCatalog = JSON.parse(catalogFile.text() || "{}")
            } catch (e) {
                root.i18nCatalog = ({})
            }
        }
    }

    function t(key, fallback) {
        if (i18nCatalog && i18nCatalog[key]) return i18nCatalog[key]
        const base = (activeLang || "en").split("-")[0].toLowerCase()
        if (builtInI18n[activeLang] && builtInI18n[activeLang][key]) return builtInI18n[activeLang][key]
        if (builtInI18n[base] && builtInI18n[base][key]) return builtInI18n[base][key]
        if (builtInI18n.en[key]) return builtInI18n.en[key]
        return fallback
    }

    // ════════════════════════════════════════════════════════════════════════
    // 3. Dock Configuration (~/.config/rust-dock/hypr-dock.conf)
    // ════════════════════════════════════════════════════════════════════════
    property string cfgPosition: "bottom"
    property int cfgIconSize: 24
    property int cfgPadding: 2
    property int cfgSpacing: 6
    property int cfgRadius: 10
    property real cfgOpacity: 0.95
    property bool cfgFullScreen: false
    property bool cfgExclusive: true
    property string cfgLayer: "top"
    property string cfgLauncherCommand: "rofi-themed -show drun"
    property bool cfgNoLauncher: true
    property bool cfgSmartView: false
    property int cfgAutoHideDelay: 250
    property bool cfgSystemGapUsed: false
    property int cfgMargin: 8
    property int cfgMarginTop: 0
    property int cfgMarginBottom: 0
    property int cfgMarginLeft: 0
    property int cfgMarginRight: 0
    property int cfgShowDelay: 40
    property int cfgHideDelay: 140
    property int cfgMoveDelay: 30
    property bool cfgCompactPreview: false
    property bool cfgSortRunningApps: false
    property var cfgIniPinnedFallback: []

    property string _rawConfText: ""

    FileView {
        id: confFile
        path: root.configHome + "/rust-dock/hypr-dock.conf"
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: confFile.reload()
        onLoaded: root.parseIniConfig(confFile.text() || "")
    }

    function parseBool(v, defVal) {
        if (v === undefined || v === null) return defVal
        const s = String(v).trim().toLowerCase()
        if (s === "true" || s === "1" || s === "yes" || s === "on") return true
        if (s === "false" || s === "0" || s === "no" || s === "off") return false
        return defVal
    }

    function parseIntClamp(v, defVal, lo, hi) {
        const n = parseInt(String(v).trim(), 10)
        if (isNaN(n)) return defVal
        return Math.max(lo, Math.min(hi, n))
    }

    function parseFloatClamp(v, defVal, lo, hi) {
        const n = parseFloat(String(v).trim())
        if (isNaN(n)) return defVal
        return Math.max(lo, Math.min(hi, n))
    }

    function parseIniConfig(text) {
        _rawConfText = text
        let sec = ""
        let ini = {}
        const lines = text.split(/\r?\n/)
        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i].trim()
            if (!line || line.startsWith("#") || line.startsWith(";")) continue
            if (line.startsWith("[") && line.endsWith("]")) {
                sec = line.slice(1, -1).trim()
                if (!ini[sec]) ini[sec] = {}
                continue
            }
            const eq = line.indexOf("=")
            if (eq > 0) {
                const k = line.slice(0, eq).trim()
                const val = line.slice(eq + 1).trim()
                if (!ini[sec]) ini[sec] = {}
                ini[sec][k] = val
            }
        }

        const g = ini["General"] || {}
        const pv = ini["General.preview"] || {}
        const th = ini["Theme"] || {}
        const pa = ini["PinnedApps"] || {}

        const pos = String(g["Position"] || "bottom").trim().toLowerCase()
        cfgPosition = (pos === "top" || pos === "bottom" || pos === "left" || pos === "right") ? pos : "bottom"
        const lyr = String(g["Layer"] || "top").trim().toLowerCase()
        cfgLayer = (lyr === "top" || lyr === "bottom" || lyr === "overlay" || lyr === "background") ? lyr : "top"

        cfgIconSize = parseIntClamp(g["IconSize"], 24, 16, 96)
        cfgPadding = parseIntClamp(g["Padding"], 2, 0, 48)
        cfgSpacing = parseIntClamp(th["Spacing"] !== undefined ? th["Spacing"] : g["Spacing"], 6, 0, 64)
        cfgRadius = parseIntClamp(g["Radius"], 10, 0, 40)
        cfgOpacity = parseFloatClamp(g["Opacity"], 0.95, 0.10, 1.0)
        cfgFullScreen = parseBool(g["FullScreen"], false)
        cfgExclusive = parseBool(g["Exclusive"], true)
        cfgSmartView = parseBool(g["SmartView"], false)
        cfgAutoHideDelay = parseIntClamp(g["AutoHideDelay"], 250, 50, 5000)
        cfgSystemGapUsed = parseBool(g["SystemGapUsed"], false)
        cfgMargin = parseIntClamp(g["Margin"], 8, 0, 200)
        cfgMarginTop = parseIntClamp(g["MarginTop"], 0, 0, 4000)
        cfgMarginBottom = parseIntClamp(g["MarginBottom"], 0, 0, 4000)
        cfgMarginLeft = parseIntClamp(g["MarginLeft"], 0, 0, 4000)
        cfgMarginRight = parseIntClamp(g["MarginRight"], 0, 0, 4000)
        cfgNoLauncher = parseBool(g["NoLauncher"], true)
        cfgLauncherCommand = (g["LauncherCommand"] && g["LauncherCommand"].length > 0)
            ? g["LauncherCommand"]
            : "rofi-themed -show drun"
        cfgCompactPreview = parseBool(pv["Compact"] !== undefined ? pv["Compact"] : g["CompactPreview"], false)
        cfgSortRunningApps = parseBool(g["SortRunningApps"], false)
        cfgShowDelay = parseIntClamp(pv["ShowDelay"], 40, 0, 3000)
        cfgHideDelay = parseIntClamp(pv["HideDelay"], 140, 20, 3000)
        cfgMoveDelay = parseIntClamp(pv["MoveDelay"], 30, 0, 2000)

        if (pa["Apps"]) {
            cfgIniPinnedFallback = pa["Apps"].split(",").map(s => s.trim()).filter(s => s.length > 0)
        }
    }

    function updateConfigOption(section, key, value) {
        let lines = (_rawConfText || "[General]\n").split(/\r?\n/)
        let inSec = false
        let foundSec = false
        let updated = false
        let insertIdx = -1

        for (let i = 0; i < lines.length; ++i) {
            const trimmed = lines[i].trim()
            if (trimmed.startsWith("[") && trimmed.endsWith("]")) {
                if (inSec && !updated) {
                    insertIdx = i
                }
                inSec = (trimmed.slice(1, -1).trim() === section)
                if (inSec) foundSec = true
                continue
            }
            if (inSec) {
                const eq = trimmed.indexOf("=")
                if (eq > 0 && trimmed.slice(0, eq).trim() === key) {
                    lines[i] = key + " = " + value
                    updated = true
                    break
                }
            }
        }

        if (!updated) {
            if (foundSec) {
                if (insertIdx >= 0) {
                    lines.splice(insertIdx, 0, key + " = " + value)
                } else {
                    lines.push(key + " = " + value)
                }
            } else {
                lines.push("", "[" + section + "]", key + " = " + value)
            }
        }

        const out = lines.join("\n").replace(/\n+$/, "\n")
        parseIniConfig(out)
        // Atomic write via temp file + mv so read-only symlinks (e.g. NixOS store links)
        // are cleanly replaced with a writable user config without EROFS/EACCES errors.
        Quickshell.execDetached(["bash", "-c",
            "cfg=\"$1\"; body=\"$2\"; dir=$(dirname \"$cfg\"); mkdir -p \"$dir\" && tmp=\"$dir/.hypr-dock.conf.tmp.$$\"; printf '%s' \"$body\" > \"$tmp\" && mv -f \"$tmp\" \"$cfg\"",
            "--", configHome + "/rust-dock/hypr-dock.conf", out
        ])
    }

    // ════════════════════════════════════════════════════════════════════════
    // 4. Persistent Enabled State (~/.config/rhythm/dock.conf) & External Hide
    // ════════════════════════════════════════════════════════════════════════
    property bool dockEnabled: true
    property var hiddenScreens: ({})
    property var fullscreenScreens: ({})

    FileView {
        id: enabledFile
        path: root.configHome + "/rhythm/dock.conf"
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: enabledFile.reload()
        onLoaded: {
            const txt = enabledFile.text() || ""
            const m = txt.match(/^enabled\s*=\s*(\S+)/m)
            if (m) {
                root.dockEnabled = (m[1].trim() !== "off")
            } else {
                root.dockEnabled = true
            }
        }
    }

    function setDockEnabledPersist(enable) {
        const val = enable ? "on" : "off"
        dockEnabled = !!enable
        if (enable) {
            hiddenScreens = ({})
        }
        const vis = enable ? "visible" : "hidden"
        Quickshell.execDetached(["bash", "-c",
            "mkdir -p \"$HOME/.config/rhythm\" && printf 'enabled=%s\\n' \"$1\" > \"$HOME/.config/rhythm/dock.conf.tmp.$$\" && mv -f \"$HOME/.config/rhythm/dock.conf.tmp.$$\" \"$HOME/.config/rhythm/dock.conf\" && printf '%s\\n' \"$2\" > \"${XDG_RUNTIME_DIR:-/tmp}/rust-dock-visible\" && printf '%s\\n' \"$2\" > /tmp/rust-dock-visible",
            "--", val, vis
        ])
    }

    // ════════════════════════════════════════════════════════════════════════
    // 5. Pinned Apps (~/.local/share/rust-dock/pinned)
    // ════════════════════════════════════════════════════════════════════════
    property var pinnedIds: []
    property bool _pinnedFileLoaded: false

    FileView {
        id: pinnedFile
        path: root.dataHome + "/rust-dock/pinned"
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: pinnedFile.reload()
        onLoaded: {
            root._pinnedFileLoaded = true
            const raw = pinnedFile.text() || ""
            const parsed = raw.split(/\r?\n/).map(s => s.trim()).filter(s => s.length > 0)
            root.pinnedIds = parsed
        }
    }

    readonly property var effectivePinnedIds: {
        if (_pinnedFileLoaded) return pinnedIds
        if (pinnedIds.length > 0) return pinnedIds
        return cfgIniPinnedFallback
    }

    function savePinnedIds(list) {
        pinnedIds = list.slice()
        _pinnedFileLoaded = true
        const body = list.join("\n") + (list.length > 0 ? "\n" : "")
        Quickshell.execDetached(["mkdir", "-p", dataHome + "/rust-dock"])
        pinnedFile.setText(body)
    }

    function pinApp(appId) {
        if (!appId) return
        const cur = effectivePinnedIds.slice()
        const lower = appId.toLowerCase()
        if (cur.some(x => x.toLowerCase() === lower)) return
        cur.push(appId)
        savePinnedIds(cur)
    }

    function unpinApp(appId) {
        if (!appId) return
        const lower = appId.toLowerCase()
        const cur = effectivePinnedIds.filter(x => x.toLowerCase() !== lower)
        savePinnedIds(cur)
    }

    function reorderPinned(draggedKey, targetKey) {
        if (!draggedKey || !targetKey || draggedKey === targetKey) return
        const cur = effectivePinnedIds.slice()
        const fromIdx = cur.indexOf(draggedKey)
        const toOrig = cur.indexOf(targetKey)
        if (fromIdx < 0 || toOrig < 0 || fromIdx === toOrig) return
        const item = cur.splice(fromIdx, 1)[0]
        const toNow = cur.indexOf(targetKey)
        const insertAt = (fromIdx < toOrig) ? (toNow + 1) : toNow
        cur.splice(Math.max(0, Math.min(cur.length, insertAt)), 0, item)
        savePinnedIds(cur)
    }

    // ════════════════════════════════════════════════════════════════════════
    // 6. Minimized Windows State ($XDG_RUNTIME_DIR/rust-dock-minimized.json)
    // ════════════════════════════════════════════════════════════════════════
    property var minimizedMap: ({})

    FileView {
        id: minimizedFile
        path: root.runtimeDir + "/rust-dock-minimized.json"
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: minimizedFile.reload()
        onLoaded: {
            try {
                const parsed = JSON.parse(minimizedFile.text() || "{}")
                if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
                    root.minimizedMap = parsed
                    root.clientsRevision++
                }
            } catch (e) {
                root.minimizedMap = ({})
            }
        }
    }

    function saveMinimizedMap() {
        minimizedFile.setText(JSON.stringify(minimizedMap))
        clientsRevision++
    }

    // ════════════════════════════════════════════════════════════════════════
    // 7. Hyprland Clients, Monitors, Active Window & Gaps (Zero-Latency IPC)
    // ════════════════════════════════════════════════════════════════════════
    property var hyprClients: []
    property var hyprMonitorsById: ({})
    property var hyprMonitorsByName: ({})
    property string activeWindowAddr: ""
    property string activeWindowClass: ""
    property int hyprGapsOut: 6
    property int clientsRevision: 0
    property string _lastSnapshotSig: ""

    // Per-app window cycling index
    property var _cycleIndexMap: ({})

    function normalizeAddr(addr) {
        if (!addr) return ""
        const s = String(addr).trim().toLowerCase()
        return s.startsWith("0x") ? s : ("0x" + s)
    }

    function waylandForAddress(addr) {
        const target = normalizeAddr(addr)
        if (!target || !Hyprland.toplevels) return null
        const list = Hyprland.toplevels.values
        for (let i = 0; i < list.length; ++i) {
            const t = list[i]
            if (!t) continue
            const rawAddr = (t.lastIpcObject && t.lastIpcObject.address) ? t.lastIpcObject.address : t.address
            if (normalizeAddr(rawAddr) === target) {
                return t.wayland || null
            }
        }
        return null
    }

    function buildWaylandLookup() {
        let map = {}
        const list = Hyprland.toplevels ? Hyprland.toplevels.values : []
        for (let i = 0; i < list.length; ++i) {
            const t = list[i]
            if (!t) continue
            const rawAddr = (t.lastIpcObject && t.lastIpcObject.address) ? t.lastIpcObject.address : t.address
            const addr = normalizeAddr(rawAddr)
            if (addr) {
                map[addr] = {
                    wayland: t.wayland || null,
                    urgent: !!t.urgent,
                    activated: !!t.activated
                }
            }
        }
        return map
    }

    // Single fast batched hyprctl query process (clients + monitors + activewindow; gaps fetched only on startup/reload)
    Process {
        id: stateQueryProc
        command: ["bash", "-c",
            "c=$(hyprctl clients -j 2>/dev/null || echo '[]'); " +
            "m=$(hyprctl monitors -j 2>/dev/null || echo '[]'); " +
            "a=$(hyprctl activewindow -j 2>/dev/null || echo '{}'); " +
            "printf '{\"clients\":%s,\"monitors\":%s,\"active\":%s}\\n' \"$c\" \"$m\" \"$a\""
        ]
        stdout: StdioCollector {
            onStreamFinished: root.applyHyprSnapshot(this.text)
        }
    }

    // Separate gaps_out query (runs only once at startup and on configreloaded)
    Process {
        id: gapsQueryProc
        command: ["bash", "-c", "hyprctl getoption general:gaps_out -j 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const g = JSON.parse(this.text.trim())
                    if (g) {
                        const gStr = g.css || g.custom || ""
                        if (gStr) {
                            const parts = String(gStr).trim().split(/\s+/)
                            const parsed = parseInt(parts[0], 10)
                            if (!isNaN(parsed) && parsed >= 0) root.hyprGapsOut = parsed
                        } else if (typeof g.int === "number" && g.int >= 0) {
                            root.hyprGapsOut = g.int
                        }
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        id: refreshDebounce
        interval: 35
        repeat: false
        onTriggered: {
            Hyprland.refreshToplevels()
            if (!stateQueryProc.running) {
                stateQueryProc.running = true
            }
        }
    }

    // Gentle safety reconcile every 15s (Hyprland.onRawEvent handles all real-time changes)
    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: {
            if (!stateQueryProc.running) {
                Hyprland.refreshToplevels()
                stateQueryProc.running = true
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const name = event ? event.name : ""
            if (name === "configreloaded") {
                if (!gapsQueryProc.running) gapsQueryProc.running = true
                refreshDebounce.restart()
                return
            }
            if (name === "openwindow" || name === "closewindow" ||
                name === "movewindow" || name === "movewindowv2" ||
                name === "activewindow" || name === "activewindowv2" ||
                name === "workspace" || name === "workspacev2" ||
                name === "focusedmon" || name === "focusedmonv2" ||
                name === "fullscreen" || name === "urgent" ||
                name === "windowtitle" || name === "windowtitlev2" ||
                name === "monitoradded" || name === "monitorremoved") {
                refreshDebounce.restart()
            }
        }
    }

    function applyHyprSnapshot(rawText) {
        if (!rawText || !rawText.trim()) return
        let snap = null
        try {
            snap = JSON.parse(rawText)
        } catch (e) {
            return
        }
        if (!snap) return

        // 1. Gaps
        if (snap.gaps) {
            const gStr = snap.gaps.css || snap.gaps.custom || ""
            if (gStr) {
                const first = parseInt(String(gStr).trim().split(/\s+/)[0], 10)
                if (!isNaN(first)) hyprGapsOut = Math.max(0, first)
            } else if (typeof snap.gaps.int === "number") {
                hyprGapsOut = Math.max(0, snap.gaps.int)
            }
        }

        // 2. Monitors
        let byId = {}
        let byName = {}
        let activeWsByMon = {}
        if (Array.isArray(snap.monitors)) {
            for (let i = 0; i < snap.monitors.length; ++i) {
                const m = snap.monitors[i]
                if (!m || !m.name) continue
                byId[m.id] = m
                byName[m.name] = m
                if (m.activeWorkspace) {
                    activeWsByMon[m.name] = m.activeWorkspace.id
                }
            }
        }
        hyprMonitorsById = byId
        hyprMonitorsByName = byName

        // 3. Active window
        const actAddr = normalizeAddr((snap.active && snap.active.address) ? snap.active.address : "")
        const actClass = String((snap.active && snap.active.class) ? snap.active.class : "").toLowerCase()
        activeWindowAddr = actAddr
        activeWindowClass = actClass

        // 4. Clients + Wayland handle join + Fullscreen detection + Minimized pruning
        const wlLookup = buildWaylandLookup()
        let clients = []
        let liveAddrs = {}
        let fsScreens = {}

        if (Array.isArray(snap.clients)) {
            for (let i = 0; i < snap.clients.length; ++i) {
                const c = snap.clients[i]
                if (!c || !c.address) continue
                const addr = normalizeAddr(c.address)
                liveAddrs[addr] = true

                const wsId = c.workspace ? (c.workspace.id || 0) : 0
                const wsName = c.workspace ? String(c.workspace.name || "") : ""
                const isMin = !!minimizedMap[addr] || wsName === "special:minimized"
                const wl = wlLookup[addr] || null
                const monObj = byId[c.monitor]
                const monName = monObj ? monObj.name : ""

                // Detect fullscreen window on monitor's active workspace
                if (!isMin && monName && c.fullscreen && c.fullscreen > 0 && activeWsByMon[monName] === wsId) {
                    fsScreens[monName] = true
                }

                clients.push({
                    address: addr,
                    className: String(c.class || ""),
                    classLower: String(c.class || "").toLowerCase(),
                    title: String(c.title || ""),
                    workspaceId: wsId,
                    workspaceName: wsName,
                    monitorId: typeof c.monitor === "number" ? c.monitor : -1,
                    monitorName: monName,
                    floating: !!c.floating,
                    at: Array.isArray(c.at) ? c.at : [0, 0],
                    size: Array.isArray(c.size) ? c.size : [0, 0],
                    minimized: isMin,
                    active: addr === actAddr,
                    urgent: wl ? wl.urgent : false,
                    wayland: wl ? wl.wayland : null
                })
            }
        }

        // Prune closed windows from minimizedMap
        let minChanged = false
        let nextMin = Object.assign({}, minimizedMap)
        for (const addrKey in nextMin) {
            if (!liveAddrs[addrKey]) {
                delete nextMin[addrKey]
                minChanged = true
            }
        }
        if (minChanged) {
            minimizedMap = nextMin
            minimizedFile.setText(JSON.stringify(minimizedMap))
        }

        // Only bump clientsRevision when visible state actually changed
        let sigParts = [String(hyprGapsOut), actAddr, actClass, JSON.stringify(fsScreens)]
        for (let i = 0; i < clients.length; ++i) {
            const c = clients[i]
            sigParts.push(c.address + "|" + c.classLower + "|" + c.title + "|" + c.workspaceId + "|" + c.monitorId + "|" + (c.minimized ? 1 : 0) + "|" + (c.active ? 1 : 0) + "|" + (c.urgent ? 1 : 0))
        }
        const newSig = sigParts.join(";")
        hyprClients = clients
        fullscreenScreens = fsScreens
        if (newSig !== _lastSnapshotSig) {
            _lastSnapshotSig = newSig
            clientsRevision++
        }
    }

    function desktopEntryFor(idOrClass) {
        const info = resolveAppInfo(idOrClass, "")
        return info ? info.desktopEntry : null
    }

    function windowByAddress(addr) {
        const target = normalizeAddr(addr)
        for (let i = 0; i < hyprClients.length; ++i) {
            if (hyprClients[i].address === target) return hyprClients[i]
        }
        return null
    }

    // ════════════════════════════════════════════════════════════════════════
    // 8. Desktop Entry & Icon Resolution (with distro-agnostic aliases)
    // ════════════════════════════════════════════════════════════════════════
    readonly property var appAliases: ({
        "chromium": ["chromium", "google-chrome", "brave-origin-nightly", "brave-browser", "firefox", "zen-browser"],
        "google-chrome": ["google-chrome", "chromium", "brave-origin-nightly", "brave-browser", "firefox"],
        "browser": ["chromium", "google-chrome", "brave-origin-nightly", "brave-browser", "firefox", "zen-browser"],
        "firefox": ["firefox", "firefox-esr", "floorp", "zen-browser", "brave-origin-nightly", "chromium"],
        "vesktop": ["vesktop", "discord", "webcord", "armcord"],
        "discord": ["discord", "vesktop", "webcord", "armcord"],
        "org.telegram.desktop": ["org.telegram.desktop", "telegram-desktop", "telegramdesktop", "telegram"],
        "telegram": ["org.telegram.desktop", "telegram-desktop", "telegramdesktop", "telegram"],
        "telegram-desktop": ["org.telegram.desktop", "telegram-desktop", "telegramdesktop", "telegram"],
        "thunar": ["thunar", "org.gnome.Nautilus", "nemo", "dolphin", "pcmanfm"],
        "files": ["thunar", "org.gnome.Nautilus", "nemo", "dolphin", "pcmanfm"],
        "file-manager": ["thunar", "org.gnome.Nautilus", "nemo", "dolphin", "pcmanfm"]
    })

    property var _desktopCache: ({})

    function findDesktopEntrySingle(query) {
        if (!query) return null
        const q = String(query).trim()
        const qLower = q.toLowerCase()
        const qNoExt = qLower.endsWith(".desktop") ? qLower.slice(0, -8) : qLower

        let direct = DesktopEntries.byId(q)
        if (!direct && qNoExt !== q) direct = DesktopEntries.byId(qNoExt)
        if (direct) return direct

        const apps = DesktopEntries.applications ? DesktopEntries.applications.values : []
        let wmMatch = null
        let partialMatch = null

        for (let i = 0; i < apps.length; ++i) {
            const e = apps[i]
            if (!e) continue
            const eid = String(e.id || "").toLowerCase()
            const eidNoExt = eid.endsWith(".desktop") ? eid.slice(0, -8) : eid
            if (eid === qLower || eidNoExt === qNoExt) return e

            const wm = String(e.startupClass || "").toLowerCase()
            if (!wmMatch && wm && wm === qNoExt) {
                wmMatch = e
            }
            if (!partialMatch && qNoExt.length >= 3 && (eidNoExt === qNoExt || (wm && wm.startsWith(qNoExt)))) {
                partialMatch = e
            }
        }
        if (wmMatch) return wmMatch
        if (partialMatch) return partialMatch

        const heur = DesktopEntries.heuristicLookup(q)
        return heur || null
    }

    function resolveAppInfo(idOrClass, fallbackTitle) {
        const key = String(idOrClass || "").trim()
        const lower = key.toLowerCase()
        if (!lower) return null

        if (_desktopCache[lower] !== undefined) {
            const cached = _desktopCache[lower]
            if (cached) return cached
        }

        let entry = findDesktopEntrySingle(key)
        let resolvedId = lower

        if (!entry && appAliases[lower]) {
            const al = appAliases[lower]
            for (let i = 0; i < al.length; ++i) {
                if (al[i].toLowerCase() === lower) continue
                const alt = findDesktopEntrySingle(al[i])
                if (alt) {
                    entry = alt
                    resolvedId = al[i].toLowerCase()
                    break
                }
            }
        }

        if (entry) {
            const info = {
                id: resolvedId,
                name: entry.name || key,
                icon: entry.icon || resolvedId,
                exec: entry.execString || "",
                desktopEntry: entry
            }
            _desktopCache[lower] = info
            return info
        }

        return {
            id: lower,
            name: fallbackTitle || key,
            icon: lower,
            exec: "",
            desktopEntry: null
        }
    }

    function resolveIconSource(iconName, fallbackId) {
        const candidates = [iconName, fallbackId]
        for (let i = 0; i < candidates.length; ++i) {
            let raw = candidates[i]
            if (!raw) continue
            raw = String(raw).trim()
            if (!raw) continue
            if (raw.startsWith("file://") || raw.startsWith("image://")) return raw
            if (raw.startsWith("/")) return "file://" + raw

            // Strip accidental image extension when doing icon-theme lookup
            let base = raw.replace(/\.(png|svg|xpm)$/i, "")
            const p = Quickshell.iconPath(base, true)
            if (p && p.length > 0) return p
            const p2 = Quickshell.iconPath(base.toLowerCase(), true)
            if (p2 && p2.length > 0) return p2
        }
        return Quickshell.iconPath("application-x-executable", true)
    }

    // ════════════════════════════════════════════════════════════════════════
    // 9. App-to-Window Matching & Per-Screen Dock Model Builder
    // ════════════════════════════════════════════════════════════════════════
    function clientMatchesApp(client, appId, pinKey, desktopEntry) {
        const cls = client.classLower
        if (!cls) return false
        const target = String(appId || "").toLowerCase()
        const rawPin = String(pinKey || "").toLowerCase()
        const wmClass = desktopEntry && desktopEntry.startupClass
            ? String(desktopEntry.startupClass).toLowerCase()
            : ""
        const desktopId = desktopEntry && desktopEntry.id
            ? String(desktopEntry.id).toLowerCase().replace(/\.desktop$/, "")
            : ""

        if (cls === target || cls === rawPin || (wmClass && cls === wmClass) || (desktopId && cls === desktopId))
            return true

        // Prefix match (e.g. "brave" -> "brave-browser", "code" -> "code-oss")
        if (target.length >= 3 && (cls.startsWith(target) || target.startsWith(cls)))
            return true
        if (rawPin.length >= 3 && cls.startsWith(rawPin))
            return true
        return false
    }

    function windowsForApp(appId, screenName) {
        const _rev = clientsRevision
        const info = resolveAppInfo(appId, "")
        const monObj = screenName ? hyprMonitorsByName[screenName] : null
        const monId = monObj ? monObj.id : -999

        let matched = []
        for (let i = 0; i < hyprClients.length; ++i) {
            const c = hyprClients[i]
            if (clientMatchesApp(c, info ? info.id : appId, appId, info ? info.desktopEntry : null)) {
                matched.push(c)
            }
        }

        // Prioritize windows on this monitor first
        if (monId !== -999 && matched.length > 1) {
            matched.sort((a, b) => {
                const am = a.monitorId === monId ? 0 : 1
                const bm = b.monitorId === monId ? 0 : 1
                if (am !== bm) return am - bm
                return a.workspaceId - b.workspaceId
            })
        }
        return matched
    }

    function buildModelForScreen(screenName) {
        const _rev = clientsRevision
        const monObj = screenName ? hyprMonitorsByName[screenName] : null
        const monId = monObj ? monObj.id : -999

        let pinnedItems = []
        let claimedAddrs = {}
        let pinnedKeysLower = {}

        // 1. Pinned apps
        const pins = effectivePinnedIds || []
        const clientsArr = hyprClients || []
        for (let i = 0; i < pins.length; ++i) {
            const pinKey = pins[i]
            const info = resolveAppInfo(pinKey, pinKey)
            if (!info) continue
            pinnedKeysLower[pinKey.toLowerCase()] = true
            pinnedKeysLower[info.id.toLowerCase()] = true
            if (info.desktopEntry && info.desktopEntry.startupClass) {
                pinnedKeysLower[String(info.desktopEntry.startupClass).toLowerCase()] = true
            }

            let wins = []
            let minCount = 0
            let isActive = false
            let isUrgent = false

            for (let j = 0; j < clientsArr.length; ++j) {
                const c = clientsArr[j]
                if (clientMatchesApp(c, info.id, pinKey, info.desktopEntry)) {
                    wins.push(c)
                    claimedAddrs[c.address] = true
                    if (c.minimized) minCount++
                    if (c.active) isActive = true
                    if (c.urgent) isUrgent = true
                }
            }

            pinnedItems.push({
                id: info.id,
                pinKey: pinKey,
                name: info.name,
                icon: info.icon,
                exec: info.exec,
                desktopEntry: info.desktopEntry,
                pinned: true,
                instances: wins.length,
                minimizedCount: minCount,
                allMinimized: wins.length > 0 && minCount === wins.length,
                active: isActive,
                urgent: isUrgent,
                windows: wins
            })
        }

        // 2. Non-pinned running apps (own-monitor windows ordered first)
        let orderedClients = hyprClients.slice()
        if (monId !== -999) {
            orderedClients.sort((a, b) => {
                const am = a.monitorId === monId ? 0 : 1
                const bm = b.monitorId === monId ? 0 : 1
                return am - bm
            })
        }

        let runningByClass = {}
        let runningOrder = []

        for (let i = 0; i < orderedClients.length; ++i) {
            const c = orderedClients[i]
            if (!c.classLower || claimedAddrs[c.address]) continue
            if (pinnedKeysLower[c.classLower]) continue

            if (!runningByClass[c.classLower]) {
                const info = resolveAppInfo(c.className, c.title || c.className)
                if (pinnedKeysLower[info.id.toLowerCase()]) continue
                runningByClass[c.classLower] = {
                    id: info.id,
                    pinKey: c.classLower,
                    name: info.name,
                    icon: info.icon,
                    exec: info.exec,
                    desktopEntry: info.desktopEntry,
                    pinned: false,
                    instances: 0,
                    minimizedCount: 0,
                    allMinimized: false,
                    active: false,
                    urgent: false,
                    windows: []
                }
                runningOrder.push(runningByClass[c.classLower])
            }

            const entry = runningByClass[c.classLower]
            entry.windows.push(c)
            entry.instances++
            if (c.minimized) entry.minimizedCount++
            if (c.active) entry.active = true
            if (c.urgent) entry.urgent = true
        }

        for (let i = 0; i < runningOrder.length; ++i) {
            const e = runningOrder[i]
            e.allMinimized = e.instances > 0 && e.minimizedCount === e.instances
        }

        if (cfgSortRunningApps) {
            runningOrder.sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()))
        }

        return {
            pinned: pinnedItems,
            running: runningOrder
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // 10. Hyprland Actions (Dual Lua 0.56+ / Legacy <0.55 Dispatch)
    // ════════════════════════════════════════════════════════════════════════
    function luaEscape(str) {
        return String(str).replace(/\\/g, "\\\\").replace(/"/g, "\\\"")
    }

    function hyprDispatch(luaExpr, legacyCmd) {
        if (Hyprland.usingLua) {
            Hyprland.dispatch(luaExpr)
        } else {
            Hyprland.dispatch(legacyCmd)
        }
    }

    function focusWindow(addr, waylandHandle) {
        if (waylandHandle && typeof waylandHandle.activate === "function") {
            waylandHandle.activate()
        }
        hyprDispatch(
            'hl.dsp.focus({window="address:' + addr + '"})',
            "focuswindow address:" + addr
        )
    }

    function closeWindow(winObj) {
        if (!winObj) return
        if (winObj.wayland && typeof winObj.wayland.close === "function") {
            winObj.wayland.close()
        } else {
            hyprDispatch(
                'hl.dsp.window.close({window="address:' + winObj.address + '"})',
                "closewindow address:" + winObj.address
            )
        }
        refreshDebounce.restart()
    }

    function focusWorkspace(wsId) {
        hyprDispatch(
            'hl.dsp.focus({workspace=' + wsId + '})',
            "workspace " + wsId
        )
    }

    function moveWindowToWorkspace(addr, wsSpec) {
        const isNum = typeof wsSpec === "number"
        const luaWs = isNum ? String(wsSpec) : ('"' + luaEscape(wsSpec) + '"')
        hyprDispatch(
            'hl.dsp.window.move({workspace=' + luaWs + ', window="address:' + addr + '"})',
            "movetoworkspacesilent " + wsSpec + ",address:" + addr
        )
    }

    function restoreFloatingGeometry(addr, saved) {
        if (!saved || !saved.floating) return
        if (Array.isArray(saved.at) && saved.at.length >= 2) {
            hyprDispatch(
                'hl.dsp.window.move({x=' + saved.at[0] + ', y=' + saved.at[1] + ', window="address:' + addr + '"})',
                "movewindowpixel exact " + saved.at[0] + " " + saved.at[1] + ",address:" + addr
            )
        }
        if (Array.isArray(saved.size) && saved.size.length >= 2) {
            hyprDispatch(
                'hl.dsp.window.resize({x=' + saved.size[0] + ', y=' + saved.size[1] + ', window="address:' + addr + '"})',
                "resizewindowpixel exact " + saved.size[0] + " " + saved.size[1] + ",address:" + addr
            )
        }
    }

    function minimizeWindow(winObj) {
        if (!winObj || winObj.minimized) return
        let next = Object.assign({}, minimizedMap)
        next[winObj.address] = {
            workspace: winObj.workspaceId > 0 ? winObj.workspaceId : 1,
            floating: !!winObj.floating,
            at: winObj.at || [0, 0],
            size: winObj.size || [800, 600],
            class: winObj.classLower
        }
        minimizedMap = next
        saveMinimizedMap()
        moveWindowToWorkspace(winObj.address, "special:minimized")
        refreshDebounce.restart()
    }

    function restoreWindow(winObj) {
        if (!winObj) return
        const saved = minimizedMap[winObj.address]
        const targetWs = (saved && saved.workspace > 0) ? saved.workspace : 1
        if (saved) {
            let next = Object.assign({}, minimizedMap)
            delete next[winObj.address]
            minimizedMap = next
            saveMinimizedMap()
        }
        moveWindowToWorkspace(winObj.address, targetWs)
        if (saved && saved.floating) {
            restoreFloatingGeometry(winObj.address, saved)
        }
        focusWorkspace(targetWs)
        focusWindow(winObj.address, winObj.wayland)
        refreshDebounce.restart()
    }

    function toggleMinimizeWindow(winObj) {
        if (!winObj) return
        if (winObj.minimized) restoreWindow(winObj)
        else minimizeWindow(winObj)
    }

    function activateWindow(winObj) {
        if (!winObj) return
        if (winObj.minimized) {
            restoreWindow(winObj)
        } else {
            if (winObj.workspaceId > 0) focusWorkspace(winObj.workspaceId)
            focusWindow(winObj.address, winObj.wayland)
        }
    }

    function minimizeAllForApp(appId) {
        const wins = windowsForApp(appId, "")
        let next = Object.assign({}, minimizedMap)
        let moved = false
        for (let i = 0; i < wins.length; ++i) {
            const w = wins[i]
            if (w.minimized) continue
            next[w.address] = {
                workspace: w.workspaceId > 0 ? w.workspaceId : 1,
                floating: !!w.floating,
                at: w.at || [0, 0],
                size: w.size || [800, 600],
                class: w.classLower
            }
            moveWindowToWorkspace(w.address, "special:minimized")
            moved = true
        }
        if (moved) {
            minimizedMap = next
            saveMinimizedMap()
            refreshDebounce.restart()
        }
    }

    function restoreAllForApp(appId) {
        const wins = windowsForApp(appId, "")
        let next = Object.assign({}, minimizedMap)
        let firstRestored = null
        let firstWs = 1
        let restoredAny = false

        for (let i = 0; i < wins.length; ++i) {
            const w = wins[i]
            if (!w.minimized) continue
            const saved = next[w.address]
            const ws = (saved && saved.workspace > 0) ? saved.workspace : 1
            delete next[w.address]
            moveWindowToWorkspace(w.address, ws)
            if (saved && saved.floating) {
                restoreFloatingGeometry(w.address, saved)
            }
            if (!firstRestored) {
                firstRestored = w
                firstWs = ws
            }
            restoredAny = true
        }
        if (restoredAny) {
            minimizedMap = next
            saveMinimizedMap()
            if (firstRestored) {
                focusWorkspace(firstWs)
                focusWindow(firstRestored.address, firstRestored.wayland)
            }
            refreshDebounce.restart()
        }
    }

    function closeAllForApp(appId) {
        const wins = windowsForApp(appId, "")
        for (let i = 0; i < wins.length; ++i) {
            closeWindow(wins[i])
        }
    }

    function cleanExecLine(execStr) {
        if (!execStr) return ""
        return String(execStr)
            .replace(/@@u|@@/g, "")
            .split(/\s+/)
            .filter(tok => tok.length > 0 && !tok.startsWith("%"))
            .join(" ")
            .trim()
    }

    function launchApp(appData) {
        if (!appData) return
        const entry = appData.desktopEntry || desktopEntryFor(appData.id)
        if (entry && typeof entry.execute === "function") {
            entry.execute()
            return
        }
        const cleaned = cleanExecLine(appData.exec || (entry ? entry.execString : ""))
        if (cleaned) {
            Quickshell.execDetached(["sh", "-c", cleaned])
        } else if (appData.id) {
            Quickshell.execDetached(["gtk-launch", appData.id])
        }
    }

    function launchAppNewWindow(appData) {
        if (!appData) return
        const cleaned = cleanExecLine(appData.exec)
        if (cleaned) {
            Quickshell.execDetached(["sh", "-c", cleaned])
        } else {
            launchApp(appData)
        }
    }

    function launchAppLauncher() {
        const cmd = cfgLauncherCommand || "rofi-themed -show drun"
        Quickshell.execDetached(["sh", "-c", cmd])
    }

    function focusOrLaunch(appData, screenName) {
        if (!appData) return
        const wins = windowsForApp(appData.id, screenName)
        if (wins.length === 0) {
            launchApp(appData)
            return
        }

        // If any window of this app is minimized, restore them first
        const hasMinimized = wins.some(w => w.minimized)
        if (hasMinimized) {
            restoreAllForApp(appData.id)
            return
        }

        // Cycle through open windows of this app
        let curIdx = _cycleIndexMap[appData.id] || 0
        // If one window is currently active, advance past it
        const actIdx = wins.findIndex(w => w.active)
        if (actIdx >= 0) {
            curIdx = (actIdx + 1) % wins.length
        } else {
            curIdx = curIdx % wins.length
        }
        _cycleIndexMap[appData.id] = (curIdx + 1) % wins.length
        activateWindow(wins[curIdx])
    }

    function cycleAppWindow(appId, step, screenName) {
        const wins = windowsForApp(appId, screenName)
        if (wins.length <= 1) return
        let cur = wins.findIndex(w => w.active)
        if (cur < 0) cur = 0
        const next = (cur + step + wins.length) % wins.length
        activateWindow(wins[next])
    }

    // ════════════════════════════════════════════════════════════════════════
    // 11. External IPC Interface (replaces SIGUSR1/USR2 & toggle scripts)
    // ════════════════════════════════════════════════════════════════════════
    IpcHandler {
        target: "dock"

        function toggle(): string {
            root.setDockEnabledPersist(!root.dockEnabled)
            return root.dockEnabled ? "on" : "off"
        }

        function setEnabled(state: string): string {
            const enable = (state === "on" || state === "true" || state === "1" || state === "show")
            root.setDockEnabledPersist(enable)
            return root.dockEnabled ? "on" : "off"
        }

        function status(): string {
            return root.dockEnabled ? "on" : "off"
        }

        function hide(screenName: string): string {
            let next = Object.assign({}, root.hiddenScreens)
            if (!screenName || screenName === "all") {
                const screens = Quickshell.screens
                for (let i = 0; i < screens.length; ++i) {
                    next[screens[i].name] = true
                }
            } else {
                next[screenName] = true
            }
            root.hiddenScreens = next
            return "hidden"
        }

        function reveal(screenName: string): string {
            if (!screenName || screenName === "all") {
                root.hiddenScreens = ({})
            } else {
                let next = Object.assign({}, root.hiddenScreens)
                delete next[screenName]
                root.hiddenScreens = next
            }
            return "revealed"
        }

        function reload(): string {
            walFile.reload()
            confFile.reload()
            pinnedFile.reload()
            enabledFile.reload()
            minimizedFile.reload()
            langFile.reload()
            root._desktopCache = ({})
            refreshDebounce.restart()
            return "reloaded"
        }
    }

    Component.onCompleted: {
        Hyprland.refreshToplevels()
        stateQueryProc.running = true
        gapsQueryProc.running = true
    }

    // ════════════════════════════════════════════════════════════════════════
    // 12. Native Multi-Monitor Instantiation (auto-adapts to hotplug/unplug)
    // ════════════════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens

        DockScreen {
            required property var modelData
            rootState: root
            screenObj: modelData
        }
    }
}
