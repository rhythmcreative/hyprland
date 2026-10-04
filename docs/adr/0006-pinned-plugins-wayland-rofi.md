# ADR-0006: hyprlandPlugins replace hyprpm; rofi-wayland replaces rofi

## Status
Accepted

## Context
install.sh enables the hyprbars and hyprexpo plugins through hyprpm, which
downloads and builds at runtime against the running compositor. rofi on
Arch is X11-first with a Wayland patchset. Both are impure steps that Nix
cannot reproduce.

## Decision
- Plugins come from pkgs.hyprlandPlugins (hyprbars, hyprexpo), pinned by
  the flake inputs like everything else; programs.hyprland loads them.
- The launcher is pkgs.rofi-wayland, and home-manager's rofi module should
  point at it when configured.

## Alternatives Considered
- **Keep hyprpm and let it build on activation** — impure network builds
  during activation, version skew against the nixpkgs Hyprland, and
  failures with no rollback story. Rejected outright.

## Consequences
- Positive: plugin versions move in lockstep with the compositor.
- Negative: a plugin not yet in hyprlandPlugins needs packaging before use.

## Trade-offs
Pinned reproducibility is prioritised over installing any plugin on demand.
