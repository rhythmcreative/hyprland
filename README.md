# Rhythm arch Hyprland

Personal Hyprland for a hyprland-based arch linux setup.

## Features
- Window manager: hyprland
- Terminal: kitty
- Shell: zsh (with starship & oh-my-zsh)
- Styling: pywal (automated color schemes)
- Bar: waybar
- Launcher: rofi
- Notifications: mako
- Custom scripts: a large collection of scripts in `~/.local/bin` for theme management, wallpaper switching, and system sync.

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/Hyprland.git ~/Hyprland
   cd ~/Hyprland
   ```

2. Run the installation script:
   ```bash
   ./install.sh
   ```

The script will:
- Install yay if not present.
- Install all necessary packages from packages.txt.
- Symlink configuration files using stow.
- Set up zsh and oh-my-zsh.

## Structure
- `config/`: contents of `~/.config/`.
- `local/`: contents of `~/.local/bin/`.
- `zsh/`: zsh configuration.
- `bash/`: bash configuration.
- `packages.txt`: list of explicitly installed packages via pacman/aur.
- `flatpaks.txt`: list of installed flatpak applications.
- Wallpapers: the installer automatically downloads a high-quality wallpaper collection from `bjarneo/wallpapers` if your folder is empty.

## Custom scripts
This setup includes many scripts in `~/.local/bin`. Some key ones:
- `change-theme`: switch between different system-wide themes.
- `change-wallpaper`: update wallpaper and sync colors via pywal.
- `waybar-restart`: restart the waybar.
- `sync-pywal-all`: synchronize colors across all supported applications.
