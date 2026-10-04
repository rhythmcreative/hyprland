# ADR-0003: rust-dock becomes a buildRustPackage derivation

## Status
Accepted (packaging pending: needs a real cargoHash from one build)

## Context
install.sh compiles rust-dock with cargo from GitHub at install time.
Nix builds must be fixed-output: dependencies vendored by hash, source
pinned, no network at build time.

## Decision
packages/rust-dock uses rustPlatform.buildRustPackage with fetchFromGitHub
plus cargoHash. The derivation ships with placeholder hashes documenting
exactly which command produces the real ones; the first NixOS build fills
them in.

## Alternatives Considered
- **naersk / crane** — same vendoring requirement with more machinery;
  buildRustPackage is enough for one binary with GTK4 inputs.
- **Keep the imperative cargo build on NixOS** — breaks on first run:
  no toolchain in the base closure, and the result would be an undeclared
  mutable binary outside the store.

## Consequences
- Positive: reproducible dock binary, updated through flake inputs like
  everything else.
- Negative: upstream must commit Cargo.lock, otherwise every build resolves
  fresh dependency versions and the hash churns.
- Negative: rust-dock updates need the hash refreshed by hand until
  upstream tags stable releases.

## Trade-offs
Reproducibility is prioritised over the convenience of tracking a branch;
the one manual hash step is documented in docs/nixos.md.
