# ADR-0002: pywal16 replaces python-pywal; rnnoise-plugin replaces noise-suppression-for-voice

## Status
Accepted

## Context
Two Arch packages in the stack have no nixpkgs equivalent: python-pywal
(upstream archived) and noise-suppression-for-voice (AUR-only).

## Decision
- Theming uses pywal16: same `wal` binary, same ~/.cache/wal outputs
  (colors.sh included), so every call site and parser works unchanged.
- Microphone denoising uses the rnnoise LADSPA plugin through a PipeWire
  filter-chain drop-in (services.pipewire.extraConfig), replacing the
  AUR package's filter-chain template.

## Alternatives Considered
- **Package python-pywal ourselves** — packaging a dead upstream to avoid
  a drop-in rename; pywal16 is the community-maintained fork and already
  in nixpkgs.
- **EasyEffects for denoising** — heavier (full GTK app + service) for a
  single always-on filter; kept available as an app, not the default path.

## Consequences
- Positive: zero script changes for theming; denoising always on without
  an AUR dependency.
- Negative: if pywal16 ever drifts from the wal CLI contract, every
  sync script feels it at once (mitigated: the contract is tiny and stable).

## Trade-offs
Drop-in compatibility is prioritised over byte-identical behaviour with
the Arch setup; both replacements are the standard NixOS answers.
