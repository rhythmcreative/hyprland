#!/bin/bash
# auto-battery-setup.sh - Automatic power and battery detection for Waybar
# Detects whether the system is a desktop PC (0 batteries), standard laptop (1 battery),
# or dual-battery laptop (e.g. ThinkPad T480 with BAT0 and BAT1).

WAYBAR_DIR="$HOME/.config/waybar"
CONFIG="$WAYBAR_DIR/config"

# Detect real system batteries (exclude peripheral devices like wireless mice)
BATS=()
for b in /sys/class/power_supply/*; do
    [ -d "$b" ] || continue
    if [ -f "$b/type" ] && grep -qi "battery" "$b/type"; then
        if [ -f "$b/scope" ] && grep -qi "device" "$b/scope"; then
            continue
        fi
        BATS+=("$(basename "$b")")
    fi
done

NUM_BATS=${#BATS[@]}

# Update all waybar configs (base config and any per-monitor config-* files)
for cfg in "$CONFIG" "$WAYBAR_DIR"/config-*; do
    [ -f "$cfg" ] || continue

    # Is this file ours to write?
    #
    # On NixOS, ~/.config/waybar is a real directory but its entries are
    # symlinks into /nix/store (home-manager `recursive = true`), so `config`
    # is READ-ONLY. Writing it failed with a shell error on stderr, which
    # launch.sh swallowed into its log, and the per-monitor configs were then
    # generated from the UNPATCHED base. It is not worth failing over: the
    # shipped base already carries "battery", which is correct for the single
    # battery case, and the per-monitor files below are always writable.
    if [ ! -w "$cfg" ]; then
        echo "auto-battery-setup: $cfg is read-only (store link?), leaving it alone" >&2
        continue
    fi

    # Clean existing power/battery modules from modules-right
    CLEAN_CONFIG=$(jq '.["modules-right"] |= map(select(. != "battery" and . != "battery#bat0" and . != "battery#bat1" and . != "custom/desktop-power" and . != "custom/dual-battery"))' "$cfg" 2>/dev/null)

    if [ -n "$CLEAN_CONFIG" ] && echo "$CLEAN_CONFIG" | jq . >/dev/null 2>&1; then
        if [ "$NUM_BATS" -ge 2 ]; then
            # Dual battery mode (ThinkPad / Asus)
            FINAL_CONFIG=$(echo "$CLEAN_CONFIG" | jq '.["modules-right"] += ["battery#bat0", "battery#bat1"]')
        elif [ "$NUM_BATS" -eq 1 ]; then
            # Single battery mode (standard laptop)
            FINAL_CONFIG=$(echo "$CLEAN_CONFIG" | jq '.["modules-right"] += ["battery"]')
        else
            # Desktop PC mode (no battery)
            FINAL_CONFIG=$(echo "$CLEAN_CONFIG" | jq '.["modules-right"] += ["custom/desktop-power"]')
        fi

        if [ -n "$FINAL_CONFIG" ] && echo "$FINAL_CONFIG" | jq . >/dev/null 2>&1; then
            # Write via a temp file in the same directory and rename: a partial
            # write would leave waybar with a truncated JSON and no bar at all.
            tmp="$cfg.auto-battery.$$"
            if echo "$FINAL_CONFIG" > "$tmp" 2>/dev/null; then
                mv -f "$tmp" "$cfg" 2>/dev/null || rm -f "$tmp"
            else
                rm -f "$tmp" 2>/dev/null
            fi
        fi
    fi
done

# Now that launch.sh has generated config-<monitor> from the base, patch those
# too. They live in the same writable directory, so on NixOS this is where the
# battery module actually gets chosen; the base config cannot be touched there.
for cfg in "$WAYBAR_DIR"/config-*; do
    [ -f "$cfg" ] || continue
    [ -w "$cfg" ] || continue
    # Do not process ourselves twice.
    [ "$cfg" = "$CONFIG" ] && continue

    CLEAN_CONFIG=$(jq '.["modules-right"] |= map(select(. != "battery" and . != "battery#bat0" and . != "battery#bat1" and . != "custom/desktop-power" and . != "custom/dual-battery"))' "$cfg" 2>/dev/null)
    [ -n "$CLEAN_CONFIG" ] || continue
    echo "$CLEAN_CONFIG" | jq . >/dev/null 2>&1 || continue

    if [ "$NUM_BATS" -ge 2 ]; then
        FINAL_CONFIG=$(echo "$CLEAN_CONFIG" | jq '.["modules-right"] += ["battery#bat0", "battery#bat1"]')
    elif [ "$NUM_BATS" -eq 1 ]; then
        FINAL_CONFIG=$(echo "$CLEAN_CONFIG" | jq '.["modules-right"] += ["battery"]')
    else
        FINAL_CONFIG=$(echo "$CLEAN_CONFIG" | jq '.["modules-right"] += ["custom/desktop-power"]')
    fi
    echo "$FINAL_CONFIG" | jq . >/dev/null 2>&1 || continue

    tmp="$cfg.auto-battery.$$"
    if echo "$FINAL_CONFIG" > "$tmp" 2>/dev/null; then
        mv -f "$tmp" "$cfg" 2>/dev/null || rm -f "$tmp"
    else
        rm -f "$tmp" 2>/dev/null
    fi
done
