# Contributing to rhythm's hyprland

First off, thank you for considering contributing! 💖 

Whether you are here to fix a small typo, polish a Waybar module, fine-tune animations in Quickshell, support a new Linux distribution, or optimize shell scripts, your help is genuinely appreciated. This project is built by humans for humans, and every contribution—big or small—makes this desktop experience better for everyone.

---

## 🌟 How You Can Help

You don't need to be an expert in Wayland or C++ to contribute. Here are some of the ways you can jump in:

- **Reporting bugs:** Found something broken on your distro or GPU? Tell us about it! Detailed bug reports save hours of head-scratching.
- **Improving visual aesthetics:** Got ideas for color schemes, Waybar layouts, Rofi styling, or Quickshell widgets? Visual improvements are always welcome (we love screenshots!).
- **Multi-distro support & compatibility:** Helping ensure smooth installs across Arch, Fedora, Debian, Ubuntu, Alpine, openSUSE, and NixOS.
- **Documentation & guides:** Clear explanations, troubleshooting tips, or translations make this setup accessible to more people.
- **Code & script refinement:** Making our helper tools (`rhythm`, `rhythm-doctor`, `install.sh`) cleaner, safer, and faster.

---

## 🧭 Project Architecture at a Glance

Before making changes, here is a quick tour of how things fit together:

- **`.config/`**: The heart of the desktop. Contains configs for Hyprland (`hyprland.lua`), Waybar (`waybar/`), Quickshell (`quickshell/` - the dynamic island notch), Rofi (`rofi/`), Kitty, Fastfetch, and GTK themes.
- **`.local/bin/` & `rhythm` CLI**: Over 80 unified helper scripts that power features like wallpaper switching, screenshot tools, Do Not Disturb toggles, and system updates.
- **`install.sh`**: The interactive and non-interactive setup script that handles distro detection, package installation, GPU auto-configuration (NVIDIA/AMD/Intel), theme synchronization, and dotfile deployment.
- **`sddm/`**: The customized Astronaut theme synced with Pywal's real-time color palette.
- **`hosts/`, `homes/`, `flake.nix`**: NixOS configuration files and modules.
- **`docs/`**: Documentation and Architecture Decision Records (ADRs).

---

## 🛠️ Development Guidelines & Best Practices

To keep the setup reliable for thousands of daily setups, please keep these practical guidelines in mind:

### 1. Safety in Shell Scripts
- The installer runs with strict error handling (`set -e` and error traps).
- **Avoid arithmetic pitfalls:** In bash, `((count++))` when `count` is `0` returns an exit code of `1` and can cause immediate script termination under `set -e`. Always prefer safe assignments like `count=$((count + 1))`.
- Always quote variables (`"$VAR"`) to avoid word-splitting and whitespace issues.
- Preserve fallback paths: if a package is unavailable on one distro, catch errors gracefully with `|| true` or check availability before executing.

### 2. Testing Your Changes
- **Dry-Run Mode:** You can test installation changes without touching your system using:
  ```bash
  ./install.sh --dry-run
  ```
- **Syntax Check:** Always run a quick syntax validation before opening a PR:
  ```bash
  bash -n install.sh
  ```
- When adding or changing distro-specific logic, test inside a clean VM or container if possible.

### 3. Human, Clear Git Commits
- We prefer **clear, natural sentence commit messages** rather than rigid or robotic prefixes (e.g. `Add real-time progress bar for package installations` instead of `feat(installer): add bar`).
- Write commit summaries that describe *what* changed and *why*.

---

## 📬 Submitting a Pull Request

1. **Fork the repo** and create a descriptive branch:
   ```bash
   git checkout -b my-awesome-feature
   ```
2. **Make your changes** cleanly and test them.
3. If your changes affect the UI or aesthetics (Waybar, Quickshell, Lockscreen, Rofi), **please attach screenshots or a short GIF** to the PR. We love seeing how it looks!
4. Open the Pull Request against the `main` branch.
5. We will review your PR with care and friendly feedback as soon as possible.

---

## 🐛 Reporting Issues

If you run into an error or something doesn't work as expected:
1. Check the installation log in `/tmp/hyprland-install-<user>.<hash>.log` or run:
   ```bash
   rhythm debug summary
   rhythm-doctor
   ```
2. Open an issue on GitHub describing:
   - Your distribution (e.g. Arch, Debian 13, Fedora 41, etc.)
   - Your GPU (NVIDIA, AMD, Intel, or hybrid)
   - The steps to reproduce the issue
   - Relevant log snippets or error lines

---

Thank you for contributing to **rhythm's hyprland** and helping make the Linux desktop a more beautiful place! 🚀
