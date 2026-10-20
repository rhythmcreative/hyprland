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
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 40
    height: 40

    readonly property bool isScreenHidden: (islandRoot && barWin.screen && islandRoot.hiddenScreens && islandRoot.hiddenScreens[barWin.screen.name] === true)
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

    // System stats
    property int cpuPercent: 5
    property string cpuBar: "▁▁▁▁"
    property string memStr: "7.6G/14.9G"
    property string cpuTempStr: "󰔏 66°C"
    property string gpuTempStr: "󰔏 51°C"
    property string cavaBars: "________"

    // Bluetooth full state & icons
    property int btConnectedCount: 0
    property bool btPowered: true
    property string btType: "default"
    property string btDeviceName: ""
    property int btBattery: -1
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
    property bool isEthernet: false
    property bool isWifiConnected: true
    property bool isWifiEnabled: true
    property int wifiSignal: 75
    property string wifiSsid: ""
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
    property int volPercent: 46
    property bool volMuted: false
    property bool isHeadphones: false
    property int brightnessPercent: 84
    property bool hasBattery: true
    property int batPercent: 91
    property bool batCharging: false
    property bool batPlugged: false
    property bool batDual: false
    property string batDetail: ""
    property string batIcon: "󰁹"

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

    function toggleSysMon() {
        const scrName = (barWin.screen && barWin.screen.name) ? barWin.screen.name : ""
        if (barWin.islandRoot && typeof barWin.islandRoot.toggleSysMon === "function") {
            barWin.islandRoot.toggleSysMon(scrName)
        } else {
            barWin.run("quickshell ipc -p $HOME/.config/quickshell/waybar-island/shell.qml --any-display call island toggleSysMon '" + scrName + "'")
        }
    }

    // --- Timers & Processes ---
    // 1. Workspaces (Per-monitor active workspace) & Keymap
    Process {
        id: wsProc
        command: ["bash", "-c", "hyprctl -j monitors 2>/dev/null; echo '==='; hyprctl -j workspaces 2>/dev/null; echo '==='; $HOME/.local/bin/kb-layout 2>/dev/null || echo 'US'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parts = text.split("===")
                    if (parts.length >= 3) {
                        const mons = JSON.parse(parts[0].trim())
                        const ws = JSON.parse(parts[1].trim())
                        ws.sort((a, b) => a.id - b.id)
                        barWin.rawWorkspaces = ws

                        const scrName = (barWin.screen && barWin.screen.name) ? barWin.screen.name : ""
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

    Timer {
        interval: 300
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!wsProc.running) wsProc.running = true
    }

    // 2. Comprehensive System Stats (CPU calculation, RAM, Temps, Audio, Brightness, Bluetooth, WiFi, Battery)
    Process {
        id: sysProc
        command: ["bash", "-c", "
            # 1. Multi-core CPU calculation matching Waybar {icon0}{icon1}{icon2}{icon3} {usage}%
            cpu_info=$(python3 -c '
import time

def read_cpu():
    cores = []
    tot_idle = 0
    tot_all = 0
    with open(\"/proc/stat\") as f:
        for line in f:
            if line.startswith(\"cpu\"):
                p = line.split()
                if p[0] == \"cpu\":
                    tot_idle = int(p[4]) + int(p[5])
                    tot_all = sum(int(x) for x in p[1:])
                elif p[0][3:].isdigit():
                    idle = int(p[4]) + int(p[5])
                    tot = sum(int(x) for x in p[1:])
                    cores.append((idle, tot))
    return cores, tot_idle, tot_all

c1, ti1, ta1 = read_cpu()
time.sleep(0.12)
c2, ti2, ta2 = read_cpu()

dtot_all = ta2 - ta1
didle_all = ti2 - ti1
overall_pct = max(0, min(100, int(((dtot_all - didle_all) / max(dtot_all, 1)) * 100)))

icons = [\"▁\", \"▂\", \"▃\", \"▄\", \"▅\", \"▆\", \"▇\", \"█\"]
bars = \"\"
N = len(c1)
if N >= 4:
    for k in range(4):
        s = k * N // 4
        e = (k + 1) * N // 4
        u = sum((c2[i][1] - c2[i][0]) - (c1[i][1] - c1[i][0]) for i in range(s, e))
        t = sum(c2[i][1] - c1[i][1] for i in range(s, e))
        pct = max(0.0, min(1.0, u / max(t, 1)))
        bars += icons[min(int(pct * 8), 7)]
elif N > 0:
    for k in range(4):
        i = min(k * N // 4, N - 1)
        u = (c2[i][1] - c2[i][0]) - (c1[i][1] - c1[i][0])
        t = c2[i][1] - c1[i][1]
        pct = max(0.0, min(1.0, u / max(t, 1)))
        bars += icons[min(int(pct * 8), 7)]
else:
    idx = min(int((overall_pct / 100.0) * 8), 7)
    bars = icons[idx] * 4

print(f\"{bars}|{overall_pct}\")
' 2>/dev/null || echo \"▁▁▁▁|10\")

            # 2. RAM
            ram_used=$(free -m | awk '/Mem:/ {printf \"%.1fG/%.1fG\", $3/1024, $2/1024}')

            # 3. CPU Temp (Dynamic scan: AMD k10temp, Intel coretemp, zenpower, or thermal_zone)
            cpu_raw=\"\"
            for hw in /sys/class/hwmon/hwmon*; do
                hwn=\$(cat \"\$hw/name\" 2>/dev/null)
                case \"\$hwn\" in
                    k10temp|coretemp|zenpower|cpu_thermal)
                        cpu_raw=\$(cat \"\$hw/temp1_input\" 2>/dev/null || cat \"\$hw/temp2_input\" 2>/dev/null)
                        [ -n \"\$cpu_raw\" ] && break
                        ;;
                esac
            done
            [ -z \"\$cpu_raw\" ] && cpu_raw=\$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | head -n1)
            if [ -n \"\$cpu_raw\" ] && [ \"\$cpu_raw\" -gt 0 ] 2>/dev/null; then
                cpu_temp=\"󰔏 \$((cpu_raw / 1000))°C\"
            else
                cpu_temp=\"󰔏 --°C\"
            fi

            # 4. GPU Temp (Dynamic scan: NVIDIA nvidia-smi, AMD amdgpu, or Intel drm)
            gpu_t=\"\"
            if command -v nvidia-smi >/dev/null 2>&1; then
                nv_t=\$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -d ' ')
                [ -n \"\$nv_t\" ] && [ \"\$nv_t\" -gt 0 ] 2>/dev/null && gpu_t=\"\${nv_t}°C\"
            fi
            if [ -z \"\$gpu_t\" ]; then
                for hw in /sys/class/hwmon/hwmon*; do
                    if grep -qi \"amdgpu\" \"\$hw/name\" 2>/dev/null; then
                        t_val=\$(cat \"\$hw/temp1_input\" 2>/dev/null)
                        [ -n \"\$t_val\" ] && [ \"\$t_val\" -gt 0 ] 2>/dev/null && gpu_t=\"\$((t_val / 1000))°C\" && break
                    fi
                done
            fi
            [ -z \"\$gpu_t\" ] && gpu_temp=\"󰔏 --°C\" || gpu_temp=\"󰔏 \$gpu_t\"

            # 5. Battery & Power detection
            has_b=0
            bat_count=0
            tot_energy_now=0
            tot_energy_full=0
            tot_cap=0
            is_charging=0
            bat_caps=\"\"

            for b in /sys/class/power_supply/*; do
                [ -d \"\$b\" ] || continue
                btype=\$(cat \"\$b/type\" 2>/dev/null || true)
                if [ \"\$btype\" = \"Battery\" ]; then
                    if [ -f \"\$b/scope\" ] && grep -qi \"device\" \"\$b/scope\"; then
                        continue
                    fi
                    if [ -f \"\$b/present\" ] && [ \"\$(cat \"\$b/present\" 2>/dev/null)\" = \"0\" ]; then
                        continue
                    fi
                    has_b=1
                    bat_count=\$((bat_count + 1))
                    c=\$(cat \"\$b/capacity\" 2>/dev/null || echo 0)
                    s=\$(cat \"\$b/status\" 2>/dev/null || echo \"Unknown\")
                    en_now=\$(cat \"\$b/energy_now\" 2>/dev/null || cat \"\$b/charge_now\" 2>/dev/null || echo 0)
                    en_full=\$(cat \"\$b/energy_full\" 2>/dev/null || cat \"\$b/charge_full\" 2>/dev/null || echo 0)

                    if [ \"\$en_full\" -gt 0 ] 2>/dev/null; then
                        tot_energy_now=\$((tot_energy_now + en_now))
                        tot_energy_full=\$((tot_energy_full + en_full))
                    fi
                    tot_cap=\$((tot_cap + c))
                    if [ \"\$s\" = \"Charging\" ]; then
                        is_charging=1
                    fi
                    bname=\$(basename \"\$b\")
                    [ -n \"\$bat_caps\" ] && bat_caps=\"\$bat_caps │ \"
                    bat_caps=\"\${bat_caps}\${c}%\"
                fi
            done

            ac_online=0
            for a in /sys/class/power_supply/*; do
                [ -d \"\$a\" ] || continue
                atype=\$(cat \"\$a/type\" 2>/dev/null || true)
                if [ \"\$atype\" = \"Mains\" ] || [ \"\$atype\" = \"USB\" ] || [ \"\$atype\" = \"USB_PD\" ] || [ \"\$atype\" = \"USB_C\" ] || [[ \"\$a\" =~ (AC|ADP|ACAD) ]]; then
                    if [ -f \"\$a/scope\" ] && grep -qi \"device\" \"\$a/scope\"; then
                        continue
                    fi
                    if [ \"\$(cat \"\$a/online\" 2>/dev/null)\" = \"1\" ]; then
                        ac_online=1
                        break
                    fi
                fi
            done

            if [ \"\$has_b\" -eq 1 ]; then
                if [ \"\$tot_energy_full\" -gt 0 ] 2>/dev/null; then
                    bat_cap=\$((tot_energy_now * 100 / tot_energy_full))
                elif [ \"\$bat_count\" -gt 0 ]; then
                    bat_cap=\$((tot_cap / bat_count))
                else
                    bat_cap=100
                fi
                if [ \"\$is_charging\" -eq 1 ]; then
                    bat_status=\"Charging\"
                elif [ \"\$ac_online\" -eq 1 ]; then
                    bat_status=\"Plugged\"
                else
                    bat_status=\"Discharging\"
                fi
            else
                bat_cap=100
                bat_status=\"AC\"
            fi

            # 6. Brightness
            bri_pct=$(brightnessctl -m 2>/dev/null | head -n1 | awk -F, '{print $4}' | tr -d '%')
            [ -z \"$bri_pct\" ] && bri_pct=84

            # 7. Audio (Volume, Mute, Sink)
            vol_line=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
            vol_val=$(echo \"$vol_line\" | awk '{print int($2 * 100)}')
            is_muted=0
            if echo \"$vol_line\" | grep -q \"MUTED\"; then is_muted=1; fi
            sink_name=$(wpctl status 2>/dev/null | awk '/Sinks:/{flag=1; next} /Sources:/{flag=0} flag && /\\*/{print}')
            is_hp=0
            if echo \"$sink_name\" | grep -iqE 'headphone|headset|buds|wh-|airpod|ear'; then is_hp=1; fi

            # 8. Bluetooth (Powered, Count, Device Type, Name, Battery)
            bt_pow=$(bluetoothctl show 2>/dev/null | grep -q \"Powered: yes\" && echo 1 || echo 0)
            bt_cnt=$(bluetoothctl devices Connected 2>/dev/null | wc -l)
            bt_typ=\"default\"
            bt_name=\"\"
            bt_bat=\"\"
            if [ \"$bt_cnt\" -gt 0 ]; then
                first_mac=$(bluetoothctl devices Connected 2>/dev/null | head -n1 | awk '{print $2}')
                if [ -n \"$first_mac\" ]; then
                    bt_name=$(bluetoothctl devices Connected 2>/dev/null | head -n1 | cut -d' ' -f3-)
                    info_out=$(bluetoothctl info \"$first_mac\" 2>/dev/null)
                    dev_icon=$(echo \"$info_out\" | grep \"Icon:\" | awk '{print $2}')
                    case \"$dev_icon\" in
                        *headphone*|*headset*|*audio*) bt_typ=\"audio\" ;;
                        *gamepad*|*joystick*) bt_typ=\"gamepad\" ;;
                        *mouse*) bt_typ=\"mouse\" ;;
                        *keyboard*) bt_typ=\"keyboard\" ;;
                        *phone*) bt_typ=\"phone\" ;;
                        *) bt_typ=\"default\" ;;
                    esac
                    bat_raw=$(echo \"$info_out\" | grep -i \"Battery Percentage:\" | head -n1)
                    if [ -n \"$bat_raw\" ]; then
                        bt_bat=$(echo \"$bat_raw\" | grep -o '([0-9]\\+)' | tr -d '()')
                        [ -z \"$bt_bat\" ] && bt_bat=$(echo \"$bat_raw\" | grep -o '[0-9]\\+' | tail -n1)
                    fi
                    if [ -z \"$bt_bat\" ]; then
                        mac_under=$(echo \"$first_mac\" | tr ':' '_')
                        bt_bat=$(upower -e 2>/dev/null | grep -i \"$mac_under\" | head -n1 | xargs -r upower -i 2>/dev/null | grep -i \"percentage:\" | awk '{print $2}' | tr -d '%')
                    fi
                fi
            fi

            # 9. WiFi / Network (Ethernet, WiFi State, Signal, SSID)
            is_eth=0
            if nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -q \"^ethernet:connected\"; then is_eth=1; fi
            is_wifi=0
            if nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -q \"^wifi:connected\"; then is_wifi=1; fi
            wifi_en=1
            if [ \"$(nmcli radio wifi 2>/dev/null)\" = \"disabled\" ]; then wifi_en=0; fi
            wifi_line=$(nmcli -t -f IN-USE,SIGNAL,SSID dev wifi 2>/dev/null | grep \"^\\*\" | head -n1)
            wifi_sig=$(echo \"$wifi_line\" | cut -d: -f2)
            wifi_ssid=$(echo \"$wifi_line\" | cut -d: -f3)
            [ -z \"$wifi_sig\" ] && wifi_sig=0

            echo \"$cpu_info|$ram_used|$cpu_temp|$gpu_temp|$bat_cap|$bat_status|$bri_pct|$vol_val|$is_muted|$is_hp|$bt_cnt|$bt_pow|$bt_typ|$bt_name|$is_eth|$is_wifi|$wifi_en|$wifi_sig|$wifi_ssid|$has_b|$bat_count|$bat_caps|$bt_bat\"
        "]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const p = text.trim().split("|")
                    if (p.length >= 20) {
                        barWin.cpuBar = p[0] || "▁▁▁▁"
                        barWin.cpuPercent = parseInt(p[1]) || 5
                        barWin.memStr = p[2] || "7.6G/14.9G"
                        barWin.cpuTempStr = p[3] || "󰔏 58°C"
                        barWin.gpuTempStr = p[4] || "󰔏 51°C"

                        if (p.length >= 21) barWin.hasBattery = (p[20] === "1")
                        const batCount = (p.length >= 22) ? (parseInt(p[21]) || 0) : (barWin.hasBattery ? 1 : 0)
                        barWin.batDual = (batCount >= 2)
                        barWin.batDetail = (p.length >= 23) ? p[22] : ""

                        barWin.batPercent = parseInt(p[5]) || 0
                        const bStatus = p[6] || (barWin.hasBattery ? "Discharging" : "AC")
                        barWin.batCharging = (bStatus === "Charging")
                        barWin.batPlugged = (bStatus === "Plugged")

                        if (!barWin.hasBattery || batCount === 0 || bStatus === "AC") {
                            barWin.batIcon = "󰚥"
                        } else if (barWin.batCharging || barWin.batPlugged) {
                            barWin.batIcon = "󰂄"
                        } else {
                            const b = barWin.batPercent
                            if (b > 90) barWin.batIcon = "󰁹"
                            else if (b > 80) barWin.batIcon = "󰂂"
                            else if (b > 70) barWin.batIcon = "󰂁"
                            else if (b > 60) barWin.batIcon = "󰂀"
                            else if (b > 50) barWin.batIcon = "󰁾"
                            else if (b > 40) barWin.batIcon = "󰁽"
                            else if (b > 30) barWin.batIcon = "󰁼"
                            else if (b > 20) barWin.batIcon = "󰁻"
                            else barWin.batIcon = "󰁺"
                        }

                        barWin.brightnessPercent = parseInt(p[7]) || 84
                        barWin.volPercent = parseInt(p[8]) || 46
                        barWin.volMuted = (p[9] === "1")
                        barWin.isHeadphones = (p[10] === "1")

                        // Bluetooth
                        barWin.btConnectedCount = parseInt(p[11]) || 0
                        barWin.btPowered = (p[12] === "1")
                        barWin.btType = p[13] || "default"
                        barWin.btDeviceName = p[14] || ""
                        barWin.btBattery = (p.length >= 24 && p[23] !== "") ? (parseInt(p[23]) || -1) : -1

                        // Network
                        barWin.isEthernet = (p[15] === "1")
                        barWin.isWifiConnected = (p[16] === "1")
                        barWin.isWifiEnabled = (p[17] === "1")
                        barWin.wifiSignal = parseInt(p[18]) || 0
                        barWin.wifiSsid = p[19] || ""
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!sysProc.running) sysProc.running = true
    }

    // 3. Cava Stream
    Process {
        id: cavaStream
        command: ["bash", "-c", "$HOME/.config/waybar/scripts/cava.sh"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                const tr = line.trim()
                if (tr.length > 0) barWin.cavaBars = tr
            }
        }
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
                                    barWin.run("hyprctl dispatch workspace " + modelData.id)
                                    barWin.activeWsId = modelData.id
                                }
                            }
                        }
                    }
                }

                WheelHandler {
                    onWheel: event => {
                        if (event.angleDelta.y > 0) barWin.run("hyprctl dispatch workspace m-1")
                        else if (event.angleDelta.y < 0) barWin.run("hyprctl dispatch workspace m+1")
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
                    Rectangle { width: 1; implicitHeight: 30; color: barWin.colMuted; opacity: 0.35 }

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
                    Rectangle { width: 1; implicitHeight: 30; color: barWin.colMuted; opacity: 0.35 }

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
                    Rectangle { width: 1; implicitHeight: 30; color: barWin.colMuted; opacity: 0.35 }

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
                    onClicked: {
                        barWin.run("$HOME/.local/bin/notch-language-helper switch 2>/dev/null || $HOME/.local/bin/toggle-keyboard-layout 2>/dev/null || hyprctl switchxkblayout all next")
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
                    Rectangle { width: 1; implicitHeight: 30; color: barWin.colMuted; opacity: 0.35 }

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
                    Rectangle { width: 1; implicitHeight: 30; color: barWin.colMuted; opacity: 0.35 }

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
                                    barWin.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
                                    barWin.volMuted = !barWin.volMuted
                                }
                            }
                            onDoubleClicked: barWin.run("pavucontrol")
                        }

                        WheelHandler {
                            onWheel: event => {
                                if (event.angleDelta.y > 0) barWin.run("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 2%+")
                                else if (event.angleDelta.y < 0) barWin.run("wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-")
                            }
                        }
                    }

                    // Divider
                    Rectangle { width: 1; implicitHeight: 30; color: barWin.colMuted; opacity: 0.35 }

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
                                if (event.angleDelta.y > 0) barWin.run("brightnessctl set 2%+")
                                else if (event.angleDelta.y < 0) barWin.run("brightnessctl set 2%-")
                            }
                        }
                    }

                    // Divider
                    Rectangle { width: 1; implicitHeight: 30; color: barWin.colMuted; opacity: 0.35 }

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
