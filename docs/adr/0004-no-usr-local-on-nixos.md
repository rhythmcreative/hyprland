# ADR-0004: No /usr/local on NixOS; helpers patched to store paths

## Status
Accepted

## Context
Several Arch scripts assume FHS locations: /usr/local/lib/rhythm for the
privileged SDDM sync helper, /usr/share/sddm for the theme and template,
/usr/share/icons for icon syncing, /usr/bin for pkill and hyprlock probes.
NixOS has an immutable /usr with no /usr/local convention.

## Decision
- The helpers derivation patches the load-bearing paths at build time
  (rust-dock binary, hyprlock probe, pkill) and excludes scripts whose
  whole job is mutating /usr or /etc (SDDM deploy, live greeter sync,
  sudo wrapper): those concepts are embodied by NixOS modules instead.
- The privilege boundary reasoning from install.sh transfers unchanged:
  anything root touches must be a root-owned store path, never something
  the user can rewrite. No NOPASSWD sudoers entry ships on NixOS.
- Live pywal recolouring of the greeter is dropped: the theme palette is
  baked into the sddm-astronaut override at build time. The desktop itself
  keeps live recolouring; only the login screen uses the last-build palette.

## Alternatives Considered
- **Rewrite the greeter theme per wallpaper into /var/lib** — mutable
  theme copies outside the store reintroduce exactly the drift the modules
  remove, for a screen shown seconds per day. Not worth it.
- **security.wrappers for the sync helper** — keeps a setuid path for a
  feature that has no writable target on NixOS; machinery without a job.

## Consequences
- Positive: no privilege escalation surface carried over from Arch.
- Negative: greeter palette goes stale between rebuilds (cosmetic only).

## Trade-offs
Security and simplicity are prioritised over the greeter always matching
the wallpaper; the trade is documented, not hidden.
