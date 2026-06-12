#! /bin/bash

bar="▁▂▃▄▅▆▇█"
dict="s/;//g;"

i=0
while [ $i -lt ${#bar} ]; do
    dict="${dict}s/$i/${bar:$i:1}/g;"
    i=$((i=i+1))
done

AUDIO_SOURCE=$(pactl info 2>/dev/null | awk '/Default Sink:/{print $3".monitor"}')
[ -z "$AUDIO_SOURCE" ] && AUDIO_SOURCE="auto"

config_file="/tmp/waybar_cava_config_$$"
echo "
[general]
bars = 12

[input]
method = pulse
source = $AUDIO_SOURCE

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
" > "$config_file"

trap "rm -f $config_file" EXIT

cava -p "$config_file" | while read -r line; do
    echo "$line" | sed "$dict"
done
