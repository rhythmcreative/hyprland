#!/bin/bash

# --- Roblox (Sober) Gaming Mode for Arch/Hyprland (Visuals ON) ---

# 1. Ensure we ARE NOT in "performance mode" to keep animations/blur
if [[ -f "/tmp/hypr_performance_mode" ]]; then
    ~/.config/hypr/scripts/toggle_performance.sh
fi

# 2. Set CPU to Performance Mode for raw power
echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null

# 3. Launch Sober with FORCED NVIDIA GPU Offload
echo "Launching Sober on NVIDIA GPU with Visual Effects ON..."
flatpak run --device=all \
    --env=__NV_PRIME_RENDER_OFFLOAD=1 \
    --env=__GLX_VENDOR_LIBRARY_NAME=nvidia \
    --env=VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json \
    org.vinegarhq.Sober &
