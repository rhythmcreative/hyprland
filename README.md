<h1 align="center">rhythm's hyprland</h1>

<div align="center">
  <p><i>Personal Arch Linux setup, customized for daily work and gaming.</i></p>
</div>

<div align="center">

[![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793d1?style=for-the-badge&logo=archlinux&logoColor=white "Arch Linux")](https://archlinux.org/)
[![Hyprland](https://img.shields.io/badge/Hyprland-abd6fd?style=for-the-badge&logo=hyprland&logoColor=black "Hyprland")](https://hyprland.org/)
[![Quickshell](https://img.shields.io/badge/Quickshell-7aa2f7?style=for-the-badge "Quickshell Dynamic Island")](https://github.com/outfoxxed/quickshell)
[![Rust--Dock](https://img.shields.io/badge/Rust--Dock-f7768e?style=for-the-badge "Rust-Dock")](https://github.com/rhythmcreative/rust-dock)
[![Waybar](https://img.shields.io/badge/Waybar-cdd6f4?style=for-the-badge "Waybar")](https://github.com/Alexays/Waybar)
[![Hyprlock](https://img.shields.io/badge/Hyprlock-89dceb?style=for-the-badge "Hyprlock")](https://github.com/hyprwm/hyprlock)
[![Rofi](https://img.shields.io/badge/Rofi-fab387?style=for-the-badge "Rofi")](https://github.com/lbonn/rofi)
[![Pywal](https://img.shields.io/badge/Pywal-cba6f7?style=for-the-badge "Pywal")](https://github.com/dylanaraps/pywal)
[![SDDM](https://img.shields.io/badge/SDDM_Astronaut-a6e3a1?style=for-the-badge "SDDM Astronaut")](https://github.com/sddm/sddm)

</div>

[![Typing SVG](https://readme-typing-svg.herokuapp.com?font=Fira+Code&pause=1000&color=FFFFFF&vCenter=true&multiline=true&width=435&height=35&lines=PREVIEW)](https://git.io/typing-svg)

<p align="center">
  <img alt="Desktop Preview" src="assets/desktop.png" width="100%" />
</p>

---

[![Typing SVG](https://readme-typing-svg.herokuapp.com?font=Fira+Code&pause=1000&color=FFFFFF&vCenter=true&multiline=true&width=435&height=35&lines=WALLPAPERS+%26+PYWAL+SYNC)](https://git.io/typing-svg)

When changing the wallpaper, Pywal automatically calculates the dominant colors and synchronizes Waybar, Quickshell, Rust-Dock, Rofi, GTK, and SDDM in real time with smooth transitions.

<table>
  <tr>
    <td width="50%">
      <p align="center"><b>Ice Blue</b></p>
      <img alt="Ice Blue Theme" src="assets/desktop.png" width="100%" />
    </td>
    <td width="50%">
      <p align="center"><b>Autumn Forest</b></p>
      <img alt="Autumn Forest Theme" src="assets/desktop_autumn.png" width="100%" />
    </td>
  </tr>
  <tr>
    <td width="50%">
      <p align="center"><b>Sakura Blossom</b></p>
      <img alt="Sakura Theme" src="assets/desktop_cherry.png" width="100%" />
    </td>
    <td width="50%">
      <p align="center"><b>Cyberpunk Neon</b></p>
      <img alt="Cyberpunk Theme" src="assets/desktop_neon.png" width="100%" />
    </td>
  </tr>
</table>

---

[![Typing SVG](https://readme-typing-svg.herokuapp.com?font=Fira+Code&pause=1000&color=FFFFFF&vCenter=true&multiline=true&width=435&height=35&lines=DYNAMIC+ISLAND+%26+SETTINGS)](https://git.io/typing-svg)

<table>
  <tr>
    <td width="50%">
      <h3 align="center">Control Center</h3>
      <img alt="Control Center" src="assets/control_center_crop.png" width="100%" />
      <p align="center"><i>Quick toggles for Wi-Fi, Bluetooth, Audio sinks, Rust-Dock, Night Light, Caffeine, volume/brightness sliders, and MPRIS media player.</i></p>
    </td>
    <td width="50%">
      <h3 align="center">Compositor Settings</h3>
      <img alt="Hyprland Settings" src="assets/hyprland_settings_crop.png" width="100%" />
      <p align="center"><i>Live controls for corner rounding, window gaps, shadows, blur effects, animations, and monitor profiles without restarting.</i></p>
    </td>
  </tr>
</table>

---

[![Typing SVG](https://readme-typing-svg.herokuapp.com?font=Fira+Code&pause=1000&color=FFFFFF&vCenter=true&multiline=true&width=435&height=35&lines=RUST-DOCK)](https://git.io/typing-svg)

<p align="center">
  <img alt="Rust-Dock" src="assets/rust_dock_crop.png" width="80%" />
</p>

Custom native dock built in Rust with GTK4 and `gtk4-layer-shell`. Features multi-monitor support, dynamic Pywal color palette adaptation, pinned applications, and active window indicators. Toggle visibility with `Super + Space`.

---

[![Typing SVG](https://readme-typing-svg.herokuapp.com?font=Fira+Code&pause=1000&color=FFFFFF&vCenter=true&multiline=true&width=435&height=35&lines=LAUNCHER+%26+CHEATSHEET)](https://git.io/typing-svg)

<table>
  <tr>
    <td width="50%">
      <h3 align="center">App Launcher (Super + A)</h3>
      <img alt="Application Launcher" src="assets/rofi_launcher_crop.png" width="100%" />
    </td>
    <td width="50%">
      <h3 align="center">Hotkeys Cheatsheet (Super + F)</h3>
      <img alt="Keybindings Cheatsheet" src="assets/rofi_hotkeys_crop.png" width="100%" />
    </td>
  </tr>
</table>

---

[![Typing SVG](https://readme-typing-svg.herokuapp.com?font=Fira+Code&pause=1000&color=FFFFFF&vCenter=true&multiline=true&width=435&height=35&lines=INSTALLATION)](https://git.io/typing-svg)

### Quick Install

Run directly from the terminal with curl:

```bash
curl -fsSL https://raw.githubusercontent.com/rhythmcreative/hyprland/main/install.sh | bash
```

### Manual Install

Clone the repository and run the script:

```bash
git clone https://github.com/rhythmcreative/hyprland.git ~/.config/hyprland-repo
cd ~/.config/hyprland-repo
./install.sh
```

> [!IMPORTANT]
> Run the installer as your regular user, not as root or with `sudo`. Root privileges are asked via `sudo` when required.

### CLI Flags

The installer supports flags for headless or automated runs:

| Flag | Description |
|---|---|
| `-y`, `--yes` | Non-interactive mode, automatically confirms prompts |
| `--preview`, `--dry-run` | Visual simulation mode without applying changes |
| `--no-reboot` | Skip reboot prompt at the end |
| `--wallpapers <mode>` | Pre-select wallpaper mode: `all`, `random`, or `none` |
| `--skip-wallpapers` | Skip downloading wallpaper packs |
| `--gpu <type>` | Override GPU driver stack: `nvidia`, `amd`, `intel`, `auto`, `none` |
| `--skip-gpu` | Skip GPU driver detection |
| `--skip-rust-dock` | Skip building rust-dock |
| `--skip-flatpaks` | Skip installing Flatpaks |
| `--replace-configs-all` | Overwrite existing configurations directly without backups |
| `-h`, `--help` | Show available options |

#### Example unattended run

```bash
curl -fsSL https://raw.githubusercontent.com/rhythmcreative/hyprland/main/install.sh | bash -s -- -y --no-reboot --skip-wallpapers
```

---

[![Typing SVG](https://readme-typing-svg.herokuapp.com?font=Fira+Code&pause=1000&color=FFFFFF&vCenter=true&multiline=true&width=435&height=35&lines=WALLPAPERS)](https://git.io/typing-svg)

Over 3,000 wallpapers are organized in downloadable packs. You can download all packs, a random selection, or grab specific packs individually:

```bash
curl -L "https://raw.githubusercontent.com/rhythmcreative/wallpapers/main/pack_1.zip" -o "/tmp/pack_1.zip"
unzip -q -o "/tmp/pack_1.zip" -d "/tmp/wallpaper_install"
cp -r "/tmp/wallpaper_install/pack_1"/* ~/Pictures/Wallpapers/
rm -rf "/tmp/wallpaper_install" "/tmp/pack_1.zip"
```

> [!NOTE]
> Curated from [Bjarneo Wallpapers](https://bjarneo.github.io/wallpapers/).

---

[![Typing SVG](https://readme-typing-svg.herokuapp.com?font=Fira+Code&pause=1000&color=FFFFFF&vCenter=true&multiline=true&width=435&height=35&lines=COMPONENTS)](https://git.io/typing-svg)

| Component | Tool |
|---|---|
| Compositor | Hyprland with official plugins |
| Dynamic Island | Quickshell (Qt6 QML with IPC) |
| Dock | Rust-Dock (GTK4 + gtk4-layer-shell) |
| Status Bar | Waybar with Pywal colors |
| Terminal | Kitty |
| Shell | Zsh with syntax highlighting and autosuggestions |
| Launcher | Rofi with Pywal themes |
| Lockscreen | Hyprlock + Hypridle |
| File Manager | Thunar + Plugins & Tumbler |
| Theming | Pywal (System-wide dynamic color synchronization) |
| Wallpaper Engine | awww with smooth synchronized fade transitions |
| Audio | Pipewire + Wireplumber |
| Display Manager | SDDM Astronaut Theme with Pywal hook |
| AUR Helper | yay |

---

[![Typing SVG](https://readme-typing-svg.herokuapp.com?font=Fira+Code&pause=1000&color=FFFFFF&vCenter=true&multiline=true&width=435&height=35&lines=KEYBINDINGS)](https://git.io/typing-svg)

| Shortcut | Action | Description |
|---|---|---|
| `Super + Return` | Launch Terminal | Opens Kitty terminal |
| `Super + Space` | Toggle Rust-Dock | Shows or hides the bottom dock |
| `Super + I` | Toggle Dynamic Island | Expands or collapses the notch |
| `Super + F` | Hotkeys Cheatsheet | Interactive keybinding search |
| `Super + X` | Quick Settings | Fast Hyprland compositor controls |
| `Super + N` | Wi-Fi Menu | Select and connect to networks |
| `Super + B` | Bluetooth Menu | Pair and connect devices |
| `Super + A` | Application Launcher | Rofi grid launcher |
| `Super + R` | Run Command | Rofi command runner |
| `Super + E` | File Manager | Opens Thunar |
| `Super + Q` | Close Window | Closes focused window |
| `Super + W` | Toggle Floating | Switches between tiled and floating |
| `Super + J` | Toggle Split | Toggles horizontal / vertical split |
| `Alt + Return` | Fullscreen | Toggles window fullscreen |
| `Super + Tab` | Workspace Overview | Visual overview of workspaces |
| `Super + M` | Exit Session | Exits Hyprland |
| `Super + L` | Lock Screen | Hyprlock |
| `Super + BackSpace` | Power Menu | Shutdown, reboot, sleep options |
| `Super + P` | Screenshot | Slurp selection into Swappy editor |
| `Super + Shift + P` | Color Picker | Hyprpicker hex copy |
| `Super + Shift + Print` | Full Screenshot | Instant capture |
| `Super + Shift + W` | Wallpaper Selector | Visual wallpaper picker |
| `Super + Shift + B` | Random Wallpaper | Sets a random wallpaper |
| `Super + Alt + W` | Change Wallpaper | Changes wallpaper and resyncs Waybar |
| `Super + Shift + G` | Performance Mode | Toggles animations and blur for gaming |
| `Super + 1 .. 0` | Switch Workspace | Move to workspace 1 through 10 |
| `Super + Shift + 1 .. 0` | Move to Workspace | Move active window to workspace 1 to 10 |
| `F10` | Toggle Bluetooth | Hardware toggle |
| `F11 / F12` | Volume Down / Up | Fine audio tuning |
