#!/bin/bash

# Sync VS Code with pywal colors
# This script applies pywal colors to VS Code settings

# VS Code config paths
VSCODE_CONFIG_DIR="$HOME/.config/Code - OSS/User"
VSCODE_SETTINGS="$VSCODE_CONFIG_DIR/settings.json"
PYWAL_VSCODE_COLORS="$HOME/.cache/wal/colors-vscode-enhanced.json"
PYWAL_VSCODE_COLORS_FALLBACK="$HOME/.cache/wal/colors-vscode.json"

# Create VS Code config directory if it doesn't exist
mkdir -p "$VSCODE_CONFIG_DIR"

# Check if enhanced template was generated, otherwise use fallback
if [ -f "$PYWAL_VSCODE_COLORS" ]; then
    COLORS_FILE="$PYWAL_VSCODE_COLORS"
elif [ -f "$PYWAL_VSCODE_COLORS_FALLBACK" ]; then
    COLORS_FILE="$PYWAL_VSCODE_COLORS_FALLBACK"
else
    echo "No VS Code color file found from pywal"
    exit 1
fi

# Backup existing settings if they exist
if [ -f "$VSCODE_SETTINGS" ]; then
    cp "$VSCODE_SETTINGS" "$VSCODE_SETTINGS.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Create temporary file to work with
TEMP_SETTINGS=$(mktemp)

# If settings.json exists, merge with pywal colors
if [ -f "$VSCODE_SETTINGS" ]; then
    # Use jq to merge existing settings with pywal colors
    if command -v jq >/dev/null 2>&1; then
        # Remove existing colorCustomizations and tokenColorCustomizations
        jq 'del(."workbench.colorCustomizations") | del(."editor.tokenColorCustomizations")' "$VSCODE_SETTINGS" > "$TEMP_SETTINGS.clean"
        
        # Merge with pywal colors
        jq -s '.[0] * .[1]' "$TEMP_SETTINGS.clean" "$COLORS_FILE" > "$TEMP_SETTINGS"
        rm "$TEMP_SETTINGS.clean"
    else
        # Fallback: just copy pywal colors if jq is not available
        cp "$COLORS_FILE" "$TEMP_SETTINGS"
    fi
else
    # No existing settings, just use pywal colors
    cp "$COLORS_FILE" "$TEMP_SETTINGS"
fi

# Move temp file to final location
mv "$TEMP_SETTINGS" "$VSCODE_SETTINGS"

echo "VS Code colors synchronized with pywal"

# Optional: Reload VS Code if it's running
if pgrep -f "code" > /dev/null; then
    echo "VS Code is running. You may need to reload the window to see changes."
    echo "Press Ctrl+Shift+P and run 'Developer: Reload Window' or restart VS Code"
fi
