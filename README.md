<div align="center">

# rhythmcreative dotfiles 

*Personal Arch config, for personal use.*

</div>

<p align="center">
  <img src="https://img.shields.io/badge/Hyprland-Rice-6b7280?style=flat-square" />
  <img src="https://img.shields.io/badge/Arch-Linux-1793d1?style=flat-square&logo=arch-linux&logoColor=white" />
  <img src="https://img.shields.io/badge/Wayland-Hyprland-111827?style=flat-square" />
  <img src="https://img.shields.io/badge/Shell-Zsh-f97316?style=flat-square" />
</p>

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

## Preview Pywal

<table>
  <tr>
    <td width="50%"><img width="2560" height="1437" alt="image" src="https://github.com/user-attachments/assets/73f129b8-e4ac-4999-9c2e-2964240b5425" />
</td>
    <td width="50%"><img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/5f5d5810-f6eb-4062-9dbf-bd8f82faa93e" />
</td>
  </tr>
  <tr>
    <td width="50%"><img width="2560" height="1435" alt="image" src="https://github.com/user-attachments/assets/64a58511-9b9c-4936-a30f-2e80ee652d7e" />
</td>
    <td width="50%"><img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/b4ff5795-e24a-4189-82f2-1d4529afa6d0" />
</td>
  </tr>
</table>

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
* Supports both image and GIF's

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
└── (~60 optimized essential scripts)
```

Configurations are adapted and customized for personal use. :)
