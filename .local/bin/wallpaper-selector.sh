#!/usr/bin/env bash
export PATH="$HOME/.local/bin:$PATH"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"



QML_XHR_ALLOW_FILE_READ=1 quickshell -p "/home/rhythmcreative/.config/quickshell/wallpaper"
