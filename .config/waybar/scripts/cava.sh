#! /bin/bash

export LC_ALL="${LC_ALL:-C.UTF-8}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

dict="s/;//g;s/0/▁/g;s/1/▂/g;s/2/▃/g;s/3/▄/g;s/4/▅/g;s/5/▆/g;s/6/▇/g;s/7/█/g;"

AUDIO_SOURCE=$(pactl info 2>/dev/null | awk '/Default Sink:/{print $3".monitor"}')
[ -z "$AUDIO_SOURCE" ] && AUDIO_SOURCE="auto"

config_file="/tmp/waybar_cava_config_$$"
cat > "$config_file" <<EOF
[general]
framerate = 30
bars = 12
sleep_timer = 5

[input]
method = pulse
source = $AUDIO_SOURCE

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
EOF

cleanup() {
    rm -f "$config_file"
    [ -n "${CAVA_PID:-}" ] && kill "$CAVA_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Single streaming sed -u process: ZERO per-frame forks (was ~120-180 forks/sec)
cava -p "$config_file" 2>/dev/null | sed -u "$dict" 2>/dev/null
