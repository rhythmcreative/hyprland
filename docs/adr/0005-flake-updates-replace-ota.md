# ADR-0005: On NixOS, flake inputs replace the OTA updater

## Status
Accepted

## Context
system-ota detects updates by comparing .version files and the pacman
package count, then copies files over ~/.config and runs pacman -Syu.
On NixOS the store is read-only, packages come from nixpkgs inputs, and
rollbacks are generations, so every OTA mechanism except "new files" is
meaningless there.

## Decision
- The OTA checker service defaults to off on NixOS (rhythm.features.otaCheck).
- Updates are `nix flake update` plus `nixos-rebuild switch`; rollbacks are
  boot generations, which also retire the timeshift/snapper pre-OTA step.
- system-ota, ota-updater and ota-snapshot are not deployed on NixOS at all,
  so nobody can run the Arch flow against home-manager files by accident.

## Alternatives Considered
- **Port system-ota to nix verbs** — a shim translating `update` into flake
  commands preserves the `rhythm` CLI UX but adds a second updater to
  maintain for little gain; reconsider if muscle memory demands it.
- **Keep the checker for dotfiles only** — the flake input IS the dotfiles
  version; a checker would duplicate `nix flake metadata` output.

## Consequences
- Positive: one update story, atomic switch, free rollbacks.
- Negative: `rhythm update` muscle memory does nothing on NixOS until a
  shim exists (documented in docs/nixos.md).

## Trade-offs
Native Nix workflows are prioritised over CLI parity with the Arch setup.
