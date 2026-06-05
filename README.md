
<h1 align="center">Dotfiles rhythmcreative</h1>

<div align="center">
 <p><i>Personal Arch config, for everyone to use :)</i></p>
</div>

<div align="center">

[![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793d1?style=for-the-badge&logo=archlinux&logoColor=white "Arch Linux - A simple, lightweight distribution")](https://archlinux.org/)
[![Hyprland](https://img.shields.io/badge/Hyprland-abd6fd?style=for-the-badge "Hyprland - A dynamic tiling Wayland compositor based on wlroots that doesn't sacrifice on its looks")](https://hyprland.org/)
[![Waybar](https://img.shields.io/badge/Waybar-cdd6f4?style=for-the-badge "Waybar - Highly customizable Wayland bar for Sway and Wlroots based compositors")](https://github.com/Alexays/Waybar)
[![Hyprlock](https://img.shields.io/badge/Hyprlock-89dceb?style=for-the-badge "Hyprlock - Hyprland's GPU-accelerated screen locking utility")](https://github.com/hyprwm/hyprlock)
[![Rofi](https://img.shields.io/badge/Rofi-fab387?style=for-the-badge "Rofi- A window switcher, application launcher and dmenu replacement")](https://github.com/lbonn/rofi)
[![Sddm](https://img.shields.io/badge/Sddm-a6e3a1?style=for-the-badge "Simple Desktop Display Manager")](https://github.com/sddm/sddm)
[![Pywal](https://img.shields.io/badge/Pywal-cba6f7?style=for-the-badge "Pywal - A tool that generates a color palette from the dominant colors in an image")](https://github.com/dylanaraps/pywal)

</div>

[![Typing SVG](https://readme-typing-svg.herokuapp.com?font=Fira+Code&pause=1000&color=F7F7F7&vCenter=true&multiline=true&width=435&height=35&lines=PREVIEW)](https://git.io/typing-svg)
<p align="center">
<img width="2555" height="1435" alt="image" src="https://github.com/user-attachments/assets/32849cc1-4239-4515-b6c3-f3c5b522b67c" />
</p>

<p align="center">
 <img width="2550" height="1418" alt="image" src="https://github.com/user-attachments/assets/109227de-e886-4b8e-8e9d-e2fc5b3ea54c" />
</p>

<p align="center">
<img width="2537" height="1413" alt="image" src="https://github.com/user-attachments/assets/faab3b29-7a7e-4b22-b00e-118915efc53a" />
</p>

<p align="center">
<img width="2527" height="1425" alt="image" src="https://github.com/user-attachments/assets/85c9f5d4-6bfa-43fb-9ffb-630e58eba559" />
</p>

<p align="center">
<img width="1920" height="1080" alt="Hola" src="https://github.com/user-attachments/assets/fa1f3449-ab38-48e7-af89-879c38161e86" />
</p>

[![Typing SVG](https://readme-typing-svg.herokuapp.com?font=Fira+Code&pause=1000&color=F7F7F7&vCenter=true&multiline=true&width=435&height=35&lines=PREVIEW+PYWAL)](https://git.io/typing-svg)
<table>
 <tr>
  <td width="50%"> <img width="2552" height="1437" alt="image" src="https://github.com/user-attachments/assets/4ad9216b-ce6f-4641-b017-4366fdf06e44" />

</td>
    <td width="50%"> <img width="2545" height="1436" alt="image" src="https://github.com/user-attachments/assets/bb3d5667-082d-4827-818f-b6e59398f5b4" />

</td>
  </tr>
  <tr>
    <td width="50%"><img width="2555" height="1434" alt="image" src="https://github.com/user-attachments/assets/c7dc9236-9542-45ed-a161-e9ed8f1e95b1" />

</td>
    <td width="50%"><img width="2555" height="1436" alt="image" src="https://github.com/user-attachments/assets/fdfe3243-b250-4d93-9f31-002cdbd6ac5a" />

</td>
  </tr>
</table>

> [!NOTE]
> Everything syncs with Pywal to have a theme that fits the wallpaper included with SDDM.



[![Typing SVG](https://readme-typing-svg.herokuapp.com?font=Fira+Code&pause=1000&color=F7F7F7&vCenter=true&multiline=true&width=435&height=35&lines=INSTALLATION)](https://git.io/typing-svg)

For installation it is done through the commands below

```bash
git clone https://github.com/rhythmcreative/hyprland.git
cd ~/hyprland
./install.sh
```
> [!IMPORTANT]
> Do <b>NOT</b> run `install.sh` as sudo so that the installation is done correctly

[![Typing SVG](https://readme-typing-svg.herokuapp.com?font=Fira+Code&pause=1000&color=F7F7F7&vCenter=true&multiline=true&width=435&height=35&lines=WALLPAPERS)](https://git.io/typing-svg)

You can have more than 3000 wallpapers, all of them can be downloaded through the following commands:

```bash
curl -L "https://raw.githubusercontent.com/rhythmcreative/wallpapers/main/pack_[NUMBER].zip" -o
"/tmp/pack_[NUMBER].zip"
unzip -q -o "/tmp/pack_[NUMBER].zip" -d "/tmp/wallpaper_install"
cp -r "/tmp/wallpaper_install/pack_1"/* ~/Pictures/Wallpapers/
rm -rf "/tmp/wallpaper_install" "/tmp/pack_1.zip"
```
or use `install.sh` and from there you can download the packages you want

> [!NOTE]
> All wallpapers are taken from this page [Link](https://bjarneo.github.io/wallpapers/)

[![Typing SVG](https://readme-typing-svg.herokuapp.com?font=Fira+Code&pause=1000&color=F7F7F7&vCenter=true&multiline=true&width=435&height=35&lines=COMPONENTS)](https://git.io/typing-svg)

| Component | Tool |
|---|---|
| Window Manager | Hyprland |
| Status Bar | Waybar |
| Terminal | Kitty |
| Launcher | Rofi |
| Lockscreen | Hyprlock + Hypridle |
| File Manager | Thunar |
| Theming | Pywal (Sync's with the wallpaper) |
| Wallpaper | awww |
| Screenshot | Swappy |
| AUR Helper | yay |
| Login Manager | SDDM |

[![Typing SVG](https://readme-typing-svg.herokuapp.com?font=Fira+Code&pause=1000&color=F7F7F7&vCenter=true&multiline=true&width=435&height=35&lines=KEYBINDINGS)](https://git.io/typing-svg)

| Binding | Action |
| --- | --- |
| `Super + Return` | Launch kitty |
| `Super + Q` | Kill active window |
| `Super + A` | Launcher (rofi) |
| `Super + E` | File manager (thunar) |
| `Super + W` | Toggle floating |
| `Super + L` | Lock screen |
| `Super + P` | Screenshot (area) |
| `Super + M` | Exit Hyprland |
| `Super + Z` | Enable power sade mode (for laptop's) |
| `Super + K` | Toogle keyboard layout |
| `Alt + Return` | Fullscreen |
| `Super + BackSpace` | Power menu |
| `Super + Shift + W` | Wallpaper Selector |
| `Super + Shift + P` | Selector of colors |
| `F10` | Enable / Disable Bluetooth |
| `F11 & F12` | Volumen Up / Down |
| `Super + 1 to 0` | Switch workspaces |


Configurations are adapted and customized for personal use. :)
