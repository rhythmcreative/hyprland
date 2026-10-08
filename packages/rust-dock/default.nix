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

  # In NixOS, desktop entries and icons are located in paths pointed to by XDG_DATA_DIRS
  # (e.g. /run/current-system/sw/share, ~/.nix-profile/share, /etc/profiles/per-user/...)
  # rather than hardcoded /usr/share. We patch get_search_paths() in src/app_info.rs.
  postPatch = ''
    substituteInPlace src/app_info.rs \
      --replace '    fn get_search_paths() -> Vec<PathBuf> {
        let mut paths = vec![
            PathBuf::from("/usr/share/applications"),
            PathBuf::from("/usr/local/share/applications"),
            PathBuf::from("/var/lib/flatpak/exports/share/applications"),
        ];' '    fn get_search_paths() -> Vec<PathBuf> {
        let mut paths = Vec::new();
        if let Ok(xdg_data_dirs) = std::env::var("XDG_DATA_DIRS") {
            for dir in xdg_data_dirs.split(":") {
                let p = PathBuf::from(dir).join("applications");
                if p.exists() && !paths.contains(&p) { paths.push(p); }
            }
        }
        for extra in &["/run/current-system/sw/share/applications", "/etc/profiles/per-user"] {
            let p = PathBuf::from(extra);
            if p.exists() && !paths.contains(&p) { paths.push(p); }
        }
        for p_def in &["/usr/share/applications", "/usr/local/share/applications", "/var/lib/flatpak/exports/share/applications"] {
            let p = PathBuf::from(p_def);
            if p.exists() && !paths.contains(&p) { paths.push(p); }
        }'

    substituteInPlace src/style.rs \
      --replace '    if let Some(mut pywal_path) = dirs::cache_dir() {
        pywal_path.push("wal/colors-waybar.css");
        if pywal_path.exists()
            && let Ok(pywal_css) = std::fs::read_to_string(pywal_path) {
                css_data.push_str(&pywal_css);
            }
    }' '    let mut pywal_loaded = false;
    if let Some(mut pywal_path) = dirs::cache_dir() {
        pywal_path.push("wal/colors-waybar.css");
        if pywal_path.exists()
            && let Ok(pywal_css) = std::fs::read_to_string(pywal_path) {
                css_data.push_str(&pywal_css);
                pywal_loaded = true;
            }
    }
    if !pywal_loaded {
        if let Some(mut waybar_path) = dirs::config_dir() {
            waybar_path.push("waybar/colors-pywal.css");
            if waybar_path.exists()
                && let Ok(waybar_css) = std::fs::read_to_string(waybar_path) {
                    css_data.push_str(&waybar_css);
                }
        }
    }'

    substituteInPlace src/dock.rs \
      --replace '&& m.connector().map(|c| c.to_string()).as_deref() == Some(monitor_name) {' \
                '&& (m.connector().map(|c| c.to_string()).as_deref() == Some(monitor_name) || m.description().map(|d| d.to_string()).as_deref().map(|s| s.contains(monitor_name)).unwrap_or(false)) {'
  '';

  # Upstream must commit Cargo.lock for reproducible vendoring; without it
  # every build resolves fresh dependency versions.
  meta = {
    description = "Application dock for the Rhythm Hyprland desktop";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
