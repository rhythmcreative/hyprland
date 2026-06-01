# Dotfiles
Personal Arch config, for personal use.

## Preview

<p align="center">
  <img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/8f795fa4-794d-4bd2-820f-7bc677c7bd47" /
</p>

<p align="center">
  <img width="2556" height="1438" alt="image" src="https://github.com/user-attachments/assets/2b599399-f833-4fdd-ae62-f85fab68a1ff" />
</p>

<p align="center">
<img width="2557" height="1440" alt="image" src="https://github.com/user-attachments/assets/680a6f98-e58e-42ac-86a1-7063513f0d39" />
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
* Quickshell

### Utilities
* Pywal
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
git clone https://github.com/rhythmcreative/Hyprland.git
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

Configurations are adapted and customized for personal use. :)
