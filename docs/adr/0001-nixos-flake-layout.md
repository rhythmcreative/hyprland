# ADR-0001: Ship NixOS support as a flake with system and home modules

## Status
Accepted

## Context
The repo deploys an Arch-only Hyprland desktop through install.sh (pacman,
AUR, /usr and /etc writes, systemd enables). Supporting NixOS needs the same
desktop expressed declaratively, without forking the configs: the Hyprland,
quickshell, waybar and helper sources must stay single-sourced.

## Decision
Add flake.nix exposing nixosModules.rhythm-hyprland and
homeManagerModules.rhythm-hyprland, sharing options from modules/options.nix.
The modules reference the existing .config, .local/bin and sddm sources in
place; nothing is duplicated.

## Alternatives Considered
- **Separate NixOS-only repo** — configs would drift between Arch and NixOS
  within weeks; every wallpaper or island fix would need porting twice.
- **Imperative nix port (install.sh with nix-env)** — keeps every Arch-ism
  (hyprpm, cargo build, /usr writes) and gains nothing from Nix except a
  different package downloader.
- **Full home-manager only, no NixOS module** — leaves SDDM, PAM, sudoers,
  drivers and services imperative, which is exactly the half that breaks
  across distros.

## Consequences
- Positive: one source of truth for configs on both distros; Arch path untouched.
- Negative: the flake cannot be tested on the Arch maintainer machine
  (no NixOS there); first boot must be validated on NixOS hardware.
- Negative: options must be set twice (system + home) when not using the
  NixOS module's home-manager wiring.

## Trade-offs
A single repo with two deploy backends is prioritised over per-distro repos,
at the cost of the maintainer testing NixOS releases on real hardware.
