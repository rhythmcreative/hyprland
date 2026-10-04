# Wallpaper packs, fetched once on first activation.
#
# install.sh clones the FireWalls collection at install time. Nix never puts
# 850 MB of wallpapers in the store, so this stays imperative: an activation
# script that runs only while ~/Pictures/Wallpapers is still empty, then
# never again. Afterwards the usual selector, random picker and backend own
# the directory, exactly like on Arch.
{ config, lib, pkgs, ... }:

let
  cfg = config.rhythm;
  wallDir = "${config.home.homeDirectory}/Pictures/Wallpapers";
in
{
  config = lib.mkIf (cfg.enable && cfg.wallpaper.mode != "none") {
    home.activation.fetchWallpapers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -n "$(ls -A ${lib.escapeShellArg wallDir} 2>/dev/null)" ]; then exit 0; fi
      mkdir -p ${lib.escapeShellArg wallDir}
      tmp="$(mktemp -d)"
      trap 'rm -rf "$tmp"' EXIT
      fw_repo="https://github.com/deadduck-09/FireWalls.git"
      if [ "${cfg.wallpaper.mode}" = "all" ]; then
        ${pkgs.git}/bin/git clone --depth 1 --filter=blob:none --sparse "$fw_repo" "$tmp/fw" >/dev/null 2>&1 || exit 0
        (cd "$tmp/fw" && ${pkgs.git}/bin/git sparse-checkout set Desktop/Wallpapers >/dev/null 2>&1) || exit 0
        ${pkgs.findutils}/bin/find "$tmp/fw/Desktop/Wallpapers" -type f \
          \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) \
          -exec cp {} ${lib.escapeShellArg wallDir}/ \; 2>/dev/null || true
      else
        tree_json="$(${pkgs.curl}/bin/curl -fsSL --connect-timeout 10 --max-time 60 \
          "https://api.github.com/repos/deadduck-09/FireWalls/git/trees/main?recursive=1" 2>/dev/null || true)"
        [ -n "$tree_json" ] || exit 0
        echo "$tree_json" | ${pkgs.jq}/bin/jq -r '
          .tree[]? | select(.type=="blob") | .path
          | select(test("^Desktop/Wallpapers/[^\\n]*$"))
          | select(test("\\.(jpg|jpeg|png|webp|gif)$"; "i"))
          | "https://raw.githubusercontent.com/deadduck-09/FireWalls/main/\(.)"
        ' 2>/dev/null | ${pkgs.coreutils}/bin/shuf -n 50 | ${pkgs.findutils}/bin/xargs -P 6 -I {} sh -c '
          dest=${lib.escapeShellArg wallDir}/"$(basename "$1")"
          ${pkgs.curl}/bin/curl -g -fsSL --connect-timeout 10 --max-time 120 "$1" -o "$dest" 2>/dev/null || rm -f "$dest"
        ' _ {} || true
      fi
    '';
  };
}
