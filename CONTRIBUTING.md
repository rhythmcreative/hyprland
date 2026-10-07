# Contributing

Thanks for taking the time to help improve this project. This repository holds my personal desktop setup, but since it has grown to support multiple distributions and varied hardware, bug fixes, suggestions, and pull requests are very welcome.

---

## Where you can help

- Fixing install issues on different distributions (Arch, Fedora, Debian, Ubuntu, Alpine, openSUSE, NixOS).
- Hardware-specific fixes (NVIDIA driver quirks, multi-monitor setups, audio routing, scaling).
- Improvements to helper scripts under `~/.local/bin/` or `install.sh`.
- Tweaks and optimizations for Waybar, Quickshell, Rofi, or SDDM.
- Documentation fixes and clarifying setup steps.

---

## Repository layout

- `.config/`: User configurations for Hyprland (`hyprland.lua`), Waybar, Quickshell (dynamic island), Rofi, Kitty, Fastfetch, etc.
- `.local/bin/`: Standalone helper scripts and wrappers accessed via the `rhythm` command.
- `install.sh`: The installer script that detects distros, sets up dependencies, configures drivers, and syncs configurations.
- `sddm/`: Astronaut login theme and Pywal color hooks.
- `hosts/`, `homes/`, `flake.nix`: NixOS flake configurations.
- `docs/`: Extra guides and architecture notes.

---

## Guidelines for code changes

### Writing shell scripts
- The installer runs under `set -e`. Be very careful with arithmetic operations: in Bash, `((i++))` returns exit code 1 when `i` is 0, which immediately stops script execution. Use `i=$((i + 1))` instead.
- Always quote variables to prevent word-splitting and unexpected glob expansion.
- If a package or command might not be present on every system, guard it or handle failures gracefully instead of letting the script crash.

### Testing before submitting
Before opening a pull request, verify your changes:
- Run a bash syntax check on modified scripts:
  ```bash
  bash -n install.sh
  ```
- Run the installer in preview/dry-run mode to confirm nothing breaks:
  ```bash
  ./install.sh --dry-run
  ```
- If you're adding support for a specific distro, test it inside a clean VM or container if possible.

### Commit messages and PRs
- Write clear, straightforward commit messages in plain English explaining what was changed and why (for example: `Fix lockscreen blur on multi-monitor setup` or `Add fallback packages for openSUSE`).
- Avoid tiny fragmented commits when possible; keep changes cohesive.
- If your pull request changes anything visual (Waybar styling, Quickshell widgets, colors, lockscreen), please include a screenshot or short screen recording in the PR description so it's easy to see the result.

---

## Reporting bugs

When reporting an issue, please include enough context to reproduce or diagnose it:
1. Your distribution and version (e.g. Arch, Fedora 41, Debian 13, Ubuntu 24.04).
2. Your GPU (NVIDIA, AMD, Intel, hybrid).
3. The exact command you ran and what happened.
4. The relevant lines from `/tmp/hyprland-install-<user>.<hash>.log` or the output of `rhythm debug summary`.
