#!/usr/bin/env bash
# Script to launch Alpine Linux VM for testing and visual inspection.
# Opens on workspace 2 in a dedicated GTK window.

set -euo pipefail

DISK_IMG="$HOME/alpine-test.qcow2"
ISO_IMG="$HOME/Downloads/alpine-standard-3.24.2-x86_64.iso"
MONITOR_SOCK="/tmp/qemu-alpine-monitor.sock"

# Remove stale monitor socket if present
rm -f "$MONITOR_SOCK"

# Configure Hyprland window rule so QEMU is placed directly on workspace 2
if command -v hyprctl >/dev/null 2>&1; then
    hyprctl eval 'hl.window_rule({ name = "qemu-workspace", match = { class = "qemu.*" }, workspace = 2 })' >/dev/null 2>&1 || true
fi

# Create test disk if it does not exist
if [ ! -f "$DISK_IMG" ]; then
    echo "Creating virtual disk at $DISK_IMG (20GB)..."
    qemu-img create -f qcow2 "$DISK_IMG" 20G
fi

BOOT_ARGS=("-boot" "c")
if [ -f "$ISO_IMG" ]; then
    BOOT_ARGS+=("-cdrom" "$ISO_IMG")
fi

echo "Starting Alpine Linux VM on Workspace 2..."
echo "SSH forward available: ssh -p 2222 rhythmcreative@localhost (or root@localhost)"
echo "Switch to Workspace 2 in Hyprland (SUPER + 2) to view and interact."

exec qemu-system-x86_64 \
    -enable-kvm \
    -m 4G \
    -smp 4 \
    -drive file="$DISK_IMG",if=virtio \
    "${BOOT_ARGS[@]}" \
    -vga virtio \
    -display gtk,gl=on \
    -monitor unix:"$MONITOR_SOCK",server,nowait \
    -nic user,model=virtio-net-pci,hostfwd=tcp::2222-:22 \
    -name "Alpine Linux VM" \
    "$@"
