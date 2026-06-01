# Hyprland

Personal arch linux configuration built around **hyprland**, featuring a dynamic workflow, pywal integration for automated styling, and a powerful collection of custom scripts.

## Preview

<p align="center">
  <img src="https://raw.githubusercontent.com/rhythmcreative/Hyprland/main/.config/wal/templates/hyprland-enhanced.conf" width="800" alt="Hyprland setup">
</p>

## Components

### Window manager
* Hyprland

### Terminal
* Kitty

### Shell
* Zsh
* Starship
* Oh-my-zsh

### Bar & ui
* Waybar
* Rofi
* Mako (notifications)
* Quickshell

### Utilities
* Pywal (color synchronization)
* Fastfetch
* Hyprlock & hypridle
* Thunar & dolphin

## Features
* Automated color schemes based on wallpaper via pywal
* Hardware detection for asus laptops and nvidia gpus
* Extensive script collection for system management
* Optimized for high performance and fast startup
* Comprehensive flatpak application support

## Installation

Clone the repository:

```bash
git clone https://github.com/rhythmcreative/Hyprland.git ~/Hyprland
```

Run the installation script:

```bash
cd ~/Hyprland
chmod +x install.sh
./install.sh
```

The script will automatically detect your hardware, install dependencies, set up symlinks using stow, and configure your shell.

## Keybindings

| Binding | Action |
| --- | --- |
| `Super + Return` | Launch kitty |
| `Super + Q` | Kill active window |
| `Super + A` | Launcher (rofi) |
| `Super + E` | File manager (thunar) |
| `Super + W` | Toggle floating |
| `Super + L` | Lock screen |
| `Super + B` | Change wallpaper (random) |
| `Super + C` | Toggle waybar |
| `Super + P` | Screenshot (area) |
| `Super + BackSpace` | Power menu |

## Included configurations

```text
.config/
├── hypr
├── kitty
├── waybar
├── rofi
├── mako
├── wal
├── quickshell
└── kvantum

.local/bin/
└── (over 100+ custom scripts)
```

## Credits
* Hyprland team
* Pywal developers
* Bjarneo (wallpapers)
* Arch linux community

Configurations are adapted and customized for personal use.
