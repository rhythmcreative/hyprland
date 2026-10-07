# rust-dock packaged from source.
#
# install.sh builds this with cargo from GitHub at install time. Nix needs a
# fixed-output vendoring hash instead. The placeholder below fails on the
# first build telling you the real hash; paste it in and rebuild.
{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, wrapGAppsHook4
, gtk4
, gtk4-layer-shell
, cargoHash ? "sha256-YoRqqrFjjeF4sQ1IPuQSyKaFrq+FP83kVq2v0c7ZtLQ="
}:

rustPlatform.buildRustPackage {
  pname = "rust-dock";
  version = "0.24.0";

  # Pinned to a reviewable commit; tracking a branch would silently move
  # the binary under every rebuild.
  src = fetchFromGitHub {
    owner = "rhythmcreative";
    repo = "rust-dock";
    rev = "8fbc060edba539d2a973137427401a21da64c532";
    hash = "sha256-cs+ycP+oXqFG3OXm3c0GaIYlvpzmF2oKJd5AZslpyDk=";
  };

  inherit cargoHash;

  nativeBuildInputs = [ pkg-config wrapGAppsHook4 ];
  buildInputs = [ gtk4 gtk4-layer-shell ];

  # Upstream must commit Cargo.lock for reproducible vendoring; without it
  # every build resolves fresh dependency versions.
  meta = {
    description = "Application dock for the Rhythm Hyprland desktop";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
