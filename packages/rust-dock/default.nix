# rust-dock packaged from source.
#
# install.sh builds this with cargo from GitHub at install time. Nix needs a
# fixed-output vendoring hash instead. The placeholder below fails on the
# first build telling you the real hash; paste it in and rebuild.
{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, gtk4
, gtk4-layer-shell
, cargoHash ? "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
}:

rustPlatform.buildRustPackage {
  pname = "rust-dock";
  version = "0.24.0";

  # Pin to a reviewable commit once the upstream history settles; tracking
  # a branch would silently move the binary under every rebuild.
  src = fetchFromGitHub {
    owner = "rhythmcreative";
    repo = "rust-dock";
    rev = "main";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  inherit cargoHash;

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ gtk4 gtk4-layer-shell ];

  # Upstream must commit Cargo.lock for reproducible vendoring; without it
  # every build resolves fresh dependency versions.
  meta = {
    description = "Application dock for the Rhythm Hyprland desktop";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
