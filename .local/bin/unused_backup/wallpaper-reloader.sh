#!/bin/bash

LIMIT=1500000
CHECK_INTERVAL=3600

WALLPAPER_ENGINE_BIN="/home/rhythmcreative/linux-wallpaperengine/build/output/linux-wallpaperengine"

while true; do
    PID=$(pgrep -u "$USER" -f linux-wallpaperengine | head -n1)

    if [ -z "$PID" ]; then
        sleep 10
        continue
    fi

    RSS=$(ps -o rss= -p "$PID")
    [ -z "$RSS" ] && continue

    if [ "$RSS" -gt "$LIMIT" ]; then

        CMD=()
        while IFS= read -r -d '' arg; do
            CMD+=("$arg")
        done < /proc/$PID/cmdline

        ARGS=()
        for ((i=1; i<${#CMD[@]}; i++)); do
            ARGS+=("${CMD[i]}")
        done

        kill "$PID"

        while kill -0 "$PID" 2>/dev/null; do
            sleep 0.2
        done

        sleep 0.1

        setsid "$WALLPAPER_ENGINE_BIN" "${ARGS[@]}" >/dev/null 2>&1 < /dev/null &
    fi

    sleep $CHECK_INTERVAL
done