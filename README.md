
<h1 align="center">Dotfiles rhythmcreative</h1>

<div align="center">
*Personal Arch config, for personal use.*
</div>

[![Typing SVG](https://readme-typing-svg.herokuapp.com?font=Fira+Code&pause=1000&color=F7F7F7&vCenter=true&multiline=true&width=435&height=35&lines=PREVIEW)](https://git.io/typing-svg)
<p align="center">
  <img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/8f795fa4-794d-4bd2-820f-7bc677c7bd47" /
</p>

<p align="center">
  <img width="2556" height="1438" alt="image" src="https://github.com/user-attachments/assets/2b599399-f833-4fdd-ae62-f85fab68a1ff" />
</p>

<p align="center">
<img width="2526" height="1402" alt="image" src="https://github.com/user-attachments/assets/b1c065d4-1529-479b-ae72-0c4337d930ef" />
</p>

<p align="center">
<img width="2557" height="1440" alt="image" src="https://github.com/user-attachments/assets/680a6f98-e58e-42ac-86a1-7063513f0d39" />
</p>
<p align="center">
<img width="1920" height="1080" alt="Hola" src="https://github.com/user-attachments/assets/711a23c0-3f8e-4e02-ad1c-d2dcfd3d0d2c" />
</p>

[![Typing SVG](https://readme-typing-svg.herokuapp.com?font=Fira+Code&pause=1000&color=F7F7F7&vCenter=true&multiline=true&width=435&height=35&lines=PREVIEW+PYWAL)](https://git.io/typing-svg)
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
| Clipboard | Swappy |
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
