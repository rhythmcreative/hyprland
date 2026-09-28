#!/bin/bash

# --- Robust Multi-Monitor Waybar Launcher ---
WAYBAR_DIR="$HOME/.config/waybar"
STATE_FILE="$WAYBAR_DIR/vertical_state"
LOG_FILE="$HOME/.cache/waybar-launch.log"

# Monitor add/remove events can arrive in bursts, and wallpaper/theme sync can
# launch Waybar at the same time. Serialize the kill-and-spawn sequence so two
# launchers can never leave duplicate bars on the same output. Use a mkdir lock
# rather than a flock file descriptor: Waybar modules (notably Cava) inherit
# open file descriptors and otherwise hold the flock after the launcher exits.
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
LOCK_DIR="$RUNTIME_DIR/waybar-launch.lock"
mkdir -p "$RUNTIME_DIR" 2>/dev/null || true
# Migrate the temporary regular lock file used by the previous implementation.
[ -f "$LOCK_DIR" ] && rm -f "$LOCK_DIR"
lock_wait=0
while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    owner=$(cat "$LOCK_DIR/pid" 2>/dev/null || true)
    if [ -z "$owner" ]; then
        # Give a new lock owner time to publish its PID before treating the
        # just-created directory as stale.
        sleep 0.1
        owner=$(cat "$LOCK_DIR/pid" 2>/dev/null || true)
    fi
    if [ -z "$owner" ] || ! kill -0 "$owner" 2>/dev/null; then
        rm -f "$LOCK_DIR/pid" 2>/dev/null || true
        rmdir "$LOCK_DIR" 2>/dev/null || true
        continue
    fi
    lock_wait=$((lock_wait + 1))
    if [ "$lock_wait" -ge 150 ]; then
        echo "Timed out waiting for Waybar launcher lock held by PID $owner" >> "$LOG_FILE"
        exit 1
    fi
    sleep 0.1
done
printf '%s\n' "$$" > "$LOCK_DIR/pid"
release_waybar_lock() {
    rm -f "$LOCK_DIR/pid" 2>/dev/null || true
    rmdir "$LOCK_DIR" 2>/dev/null || true
}
trap release_waybar_lock EXIT

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

echo "--- Launching Waybar at $(date) ---" >> "$LOG_FILE"

# 1. Kill existing waybar instances aggressively
echo "Stopping existing waybar processes..." >> "$LOG_FILE"
pkill -9 waybar || true

# 1b. Los modulos de Waybar (Cava) sobreviven al pkill de la barra y se quedan
# huerfanos escribiendo "Broken pipe" al log. Se comparan lineas de comando
# completas contra las rutas conocidas, nunca un patron parcial: un pkill -f
# sobre "waybar/scripts" tambien mataba a cualquier otro proceso que mencionara
# esa ruta en sus argumentos.
for entry in /proc/[0-9]*; do
    pid="${entry#/proc/}"
    [ "$pid" = "$$" ] && continue
    # El grupo redirige tambien el error de bash si el proceso desaparece entre
    # el listado de /proc y la lectura de su linea de comandos.
    last_arg=$( { tr '\0' '\n' < "$entry/cmdline"; } 2>/dev/null | tail -n1 )
    case "$last_arg" in
        "$WAYBAR_DIR"/scripts/*.sh|/tmp/waybar_cava_config_*)
            kill "$pid" 2>/dev/null || true
            ;;
    esac
done

# Wait for process to fully release resources
sleep 0.2

# Auto-detect battery count (0 = desktop, 1 = single battery, 2+ = dual battery)
if [ -f "$WAYBAR_DIR/scripts/auto-battery-setup.sh" ]; then
    chmod +x "$WAYBAR_DIR/scripts/auto-battery-setup.sh" 2>/dev/null || true
    "$WAYBAR_DIR/scripts/auto-battery-setup.sh" >> "$LOG_FILE" 2>&1 || true
fi

# 2. Handle configuration based on state
CONFIG="$WAYBAR_DIR/config"
STYLE="$WAYBAR_DIR/style.css"

if [ -f "$STATE_FILE" ]; then
    echo "Using vertical state configuration..." >> "$LOG_FILE"
    [ -f "$WAYBAR_DIR/config-vertical" ] && CONFIG="$WAYBAR_DIR/config-vertical"
    [ -f "$WAYBAR_DIR/style-vertical.css" ] && STYLE="$WAYBAR_DIR/style-vertical.css"
fi

# 3. Launch with logging
echo "Starting Waybar base config: $CONFIG and style: $STYLE" >> "$LOG_FILE"

# Small delay to ensure display and IPC are ready
sleep 0.1

# Check and auto-detect Wayland and Hyprland environment if missing
if [ -z "$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi
if [ -z "$WAYLAND_DISPLAY" ]; then
    WL_DISP=$(ls "$XDG_RUNTIME_DIR"/wayland-[0-9]* 2>/dev/null | grep -v '\.lock$' | grep -v 'awww' | head -n1)
    if [ -n "$WL_DISP" ]; then
        export WAYLAND_DISPLAY=$(basename "$WL_DISP")
    else
        export WAYLAND_DISPLAY="wayland-1"
    fi
fi
if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -n 1)
fi

# 4. Query active monitors and spawn an independent instance per screen
monitors=""
for _ in {1..5}; do
    if command -v hyprctl >/dev/null 2>&1 && [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
        mon_json=$(hyprctl monitors -j 2>/dev/null || true)
        if [ -n "$mon_json" ] && [ "$mon_json" != "[]" ]; then
            monitors=$(echo "$mon_json" | jq -r '.[].name' 2>/dev/null || true)
            [ -n "$monitors" ] && break
        fi
    fi
    sleep 0.2
done

if [ -z "$monitors" ] || [ "$monitors" = "null" ]; then
    waybar -c "$CONFIG" -s "$STYLE" >> "$LOG_FILE" 2>&1 9>&- &
    NEW_PID=$!
    echo "Waybar single-instance launched with PID: $NEW_PID" >> "$LOG_FILE"
else
    while IFS= read -r monitor; do
        [ -z "$monitor" ] && continue
        MON_CONFIG="$WAYBAR_DIR/config-$monitor"
        # Ensure independent per-monitor config with output filter
        jq --arg out "$monitor" '.output = $out' "$CONFIG" > "$MON_CONFIG" 2>/dev/null || cp "$CONFIG" "$MON_CONFIG"
        # Do not pass the launcher's flock descriptor to the long-running bar;
        # otherwise Waybar itself keeps the lock forever and blocks relaunches.
        waybar -c "$MON_CONFIG" -s "$STYLE" >> "$LOG_FILE" 2>&1 9>&- &
        NEW_PID=$!
        echo "Waybar instance for $monitor launched (PID: $NEW_PID, config: $MON_CONFIG)" >> "$LOG_FILE"
    done <<< "$monitors"
fi

# Verification
sleep 1
if pgrep -x waybar > /dev/null; then
    echo "Waybar instances running successfully." >> "$LOG_FILE"
else
    echo "ERROR: Waybar failed to start. Check the logs above." >> "$LOG_FILE"
fi
