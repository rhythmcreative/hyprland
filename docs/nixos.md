# NixOS support

The same desktop, deployed declaratively. The Arch installer is untouched;
this is a second backend in the same repo, sharing every config. Read
docs/adr/0001-nixos-flake-layout.md first for the why of each decision.

## What you get

- Hyprland with portals and the hyprbars plugin pinned (hyprexpo
  has no reproducible source upstream and is skipped, see ADR-0006).
- SDDM on Wayland with the astronaut theme, login on the internal panel
  (lid closed: external output), same logic as on Arch.
- All dotfiles, all helper scripts, all user units (island, wallpaper
  watcher, dock watcher, bluetooth agent, power profile, privacy shield,
  night light, caffeine).
- PipeWire with microphone denoising, NetworkManager, Bluetooth,
  power-profiles-daemon, fonts, cursor and icon themes.

## Install on a NixOS machine

The installer detects NixOS and does all of this for you:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rhythmcreative/hyprland/main/install.sh)"
```

It has two halves, because the desktop has two halves:

- **User scope** — a standalone home-manager flake in
  `~/.config/home-manager`: dotfiles, helper scripts, user units, and the
  desktop programs as `home.packages`. No sudo.
- **System scope** — `modules/nixos` wired into `/etc/nixos` for what cannot
  live in `$HOME`: the SDDM astronaut greeter, Nerd Fonts, portals, PipeWire
  with rnnoise, your groups, the Hyprland session and its companions.

The system half is a generated `/etc/nixos/flake.nix` that imports your
`configuration.nix` as a module, so that file is never rewritten. nixpkgs is
pinned to the release you installed with, not `nixos-unstable`: installing a
desktop should not drag the whole system across a channel jump. Use
`--no-system` (or `RHYTHM_NO_SYSTEM=1`) for the user half only, and
`RHYTHM_NIXOS_CHANNEL` to pin a different branch.

To drive it by hand instead:

```bash
# 1. Take NixOS/nixpkgs/nixos-unstable as your base at install time.
# 2. Copy hosts/asus/configuration.nix and homes/rhythm/home.nix,
#    set username, gpu and monitors, and wire the inputs in your flake:
#      inputs.hyprland.url = "github:rhythmcreative/hyprland?ref=beta";
sudo nixos-rebuild switch --flake .#your-host
```

Standalone home-manager (non-NixOS with Nix, or testing the user scope):

```bash
home-manager switch --flake .#rhythm
```

## First boot checklist (do this on real hardware)

1. `nix flake check` — must be green before anything else.
2. Nothing to fill in packages/rust-dock: source and vendor hashes are
   pinned and the binary was built during review. Only refresh them when
   you move the pinned commit (see ADR-0003).
3. Log in through SDDM, lid open: greeter on the internal panel only.
4. Close the lid, reboot: greeter on the external output.
5. Leave the machine 5 minutes: lock screen, not a black screen.
6. Unplug the external monitor and plug it back: wallpaper returns.
7. `systemctl --user status waybar-island wallpaper-monitor-watcher`
   both active; island visible on every connected monitor.
8. Change the wallpaper: bars, island and apps follow the new palette.
9. If the greeter shows the default breeze theme instead of astronaut,
   fix the theme directory name in modules/nixos/sddm.nix to match what
   the nixpkgs sddm-astronaut package installs.

## Deliberate differences from Arch

- No live greeter recolouring: the login theme palette is baked in at
  build time (the store is read-only). The desktop itself recolours live.
- No OTA updater: updates are `nix flake update` plus `nixos-rebuild
  switch`; rollbacks are boot generations. `system-ota`, `ota-updater`,
  `ota-snapshot` and `rhythm-sddm-deploy` are not installed.
- No `hyprpm`: plugins come from nixpkgs pins.
- `monitors.conf` is seeded once and never overwritten; edit it with
  nwg-displays as usual.
- Wallpaper packs download on first activation
  (`rhythm.wallpaper.mode = "random"` by default), never into the store.
- Quickshell tracks the nixpkgs release, not -git. If the island needs a
  newer Quickshell than nixpkgs ships, pin it as a flake input.
- `toggle-noise-suppression` still mentions pacman in its prompts; the
  actual denoising is always-on through PipeWire (ADR-0002).

## Options

All knobs live under `rhythm.*` and are documented in
modules/options.nix: `username`, `gpu` ("auto", "nvidia", "amd",
"intel"), `monitors.seedText`, `wallpaper.mode`, `features.*`
(island, wallpaperWatcher, rustDock, bluetooth, powerProfile,
privacyShield, nightlight, caffeine, otaCheck, flatpaks),
`sddm.themeConfig`, `packageSet.*` overrides.
