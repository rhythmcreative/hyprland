# ADR-0006: hyprlandPlugins replace hyprpm; plain rofi is Wayland now

## Status
Accepted

## Context
install.sh enables the hyprbars and hyprexpo plugins through hyprpm, which
downloads and builds at runtime against the running compositor. rofi on
Arch is X11-first with a Wayland patchset. Both are impure steps that Nix
cannot reproduce.

## Decision
- Plugins come from pkgs.hyprlandPlugins (hyprbars), pinned by the flake
  inputs like everything else, and load at startup through
  `hyprctl plugin load` driven by environment (no plugins option exists
  in the NixOS or home-manager Hyprland modules). hyprexpo is dropped:
  upstream removed it from the hyprland-plugins repo and ships no
  standalone source, so there is nothing reproducible to build.
- The launcher is plain pkgs.rofi (the old rofi-wayland package was
  merged into it upstream), and home-manager's rofi module should
  point at it when configured.

## Alternatives Considered
- **Package hyprexpo from an old tag** -- the last tag shipping it
  predates the current Hyprland minor line and the plugin ABI would
  almost certainly refuse to load. Rejected until upstream restores it.
- **Keep hyprpm and let it build on activation** — impure network builds
  during activation, version skew against the nixpkgs Hyprland, and
  failures with no rollback story. Rejected outright.

## Consequences
- Positive: plugin versions move in lockstep with the compositor.
- Negative: a plugin not yet in hyprlandPlugins needs packaging before use.
- Negative: no overview/expo effect on NixOS until hyprexpo returns
  upstream (hyprbars keeps working).

## Trade-offs
Pinned reproducibility is prioritised over installing any plugin on demand.
