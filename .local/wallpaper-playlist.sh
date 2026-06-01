#!/usr/bin/env bash

SETTINGS="/home/rhythmcreative/.config/quickshell/wallpaper/settings.json"
APPLY_SCRIPT="$HOME/.local/bin/wallpaper-apply.sh"
APPLY_STATIC="$HOME/.local/bin/wallpaper-apply-static.sh"

current_index=0
last_count=0
was_active=false

while true; do
    if [[ ! -f "$SETTINGS" ]]; then
        sleep 2
        continue
    fi

    playlist=$(jq -r '.playlist // [] | @json' "$SETTINGS" 2>/dev/null)
    active=$(jq -r '.playlistActive // false' "$SETTINGS" 2>/dev/null)
    interval=$(jq -r '.playlistInterval // 30' "$SETTINGS" 2>/dev/null)
    shuffle=$(jq -r '.playlistShuffle // false' "$SETTINGS" 2>/dev/null)

    current_count=$(echo "$playlist" | jq 'length' 2>/dev/null)
    if [[ "$current_count" != "$last_count" ]]; then
        current_index=0
    fi
    last_count="$current_count"


    if [[ "$active" == "true" ]]; then
        count=$current_count

        if [[ "$count" -gt 0 ]]; then

            if [[ "$was_active" != "true" ]]; then
                current_index=0
                remaining=-1
            else
                now=$(date +%s%3N)
                last_applied=$(jq -r '.playlistLastApplied // 0' "$SETTINGS" 2>/dev/null)
                interval_ms=$(( interval * 60 * 1000 ))
                elapsed=$(( now - last_applied ))
                remaining=$(( interval_ms - elapsed ))
            fi

            if [[ $remaining -gt 0 ]]; then
                sleep_end=$(( $(date +%s%3N) + remaining ))
                while true; do
                    now=$(date +%s%3N)
                    if [[ $now -ge $sleep_end ]]; then
                        break
                    fi
                    sleep 2
                    active=$(jq -r '.playlistActive // false' "$SETTINGS" 2>/dev/null)
                    count=$(jq -r '.playlist | length' "$SETTINGS" 2>/dev/null)
                    if [[ "$active" != "true" ]] || [[ "$count" -eq 0 ]]; then
                        current_index=0
                        was_active=false
                        break
                    fi
                done
            fi

            playlist=$(jq -r '.playlist // [] | @json' "$SETTINGS" 2>/dev/null)
            active=$(jq -r '.playlistActive // false' "$SETTINGS" 2>/dev/null)
            shuffle=$(jq -r '.playlistShuffle // false' "$SETTINGS" 2>/dev/null)
            count=$(echo "$playlist" | jq 'length' 2>/dev/null)

            if [[ "$active" != "true" ]] || [[ "$count" -eq 0 ]]; then
                current_index=0
                was_active=false
                sleep 2
                continue
            fi

            was_active=true

            if [[ "$shuffle" == "true" ]]; then
                new_index=$(( RANDOM % count ))
                if [[ $count -gt 1 ]]; then
                    while [[ $new_index -eq $current_index ]]; do
                        new_index=$(( RANDOM % count ))
                    done
                fi
                current_index=$new_index
            fi

            current_index=$(( current_index % count ))

            folder=$(echo "$playlist" | jq -r ".[$current_index]" 2>/dev/null | tr -d '[:space:]')


            now=$(date +%s%3N)
            tmp=$(mktemp)
            jq -c --arg w "$folder" --argjson t "$now" \
                '.lastWallpaper = $w | .playlistLastApplied = $t' \
                "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

            if [[ -d "$folder" ]]; then
                bash "$APPLY_SCRIPT" "$folder"
            elif [[ -f "$folder" ]]; then
                bash "$APPLY_STATIC" "$folder"
            fi

            if [[ "$shuffle" != "true" ]]; then
                current_index=$(( (current_index + 1) % count ))
            fi
        else
            sleep 2
        fi
    else
        current_index=0
        was_active=false
        sleep 2
    fi
done