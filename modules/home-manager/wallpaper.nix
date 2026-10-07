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
      # NOTE: no `exit` anywhere in here. Activation blocks run sourced in
      # one shell: `exit` would silently end the whole activation with code
      # 0 and skip every later step, including linkGeneration. That exact
      # bug shipped once and left homes half-deployed looking healthy.
      num_existing=$(find ${lib.escapeShellArg wallDir} -type f 2>/dev/null | grep -v 'default\.jpg$' | wc -l)
      if [ "$num_existing" -eq 0 ]; then
        # Home-manager activation runs at boot, possibly before NetworkManager
        # is online. Wait a little for connectivity instead of failing
        # silently on the first boot and never retrying (the guard above only
        # runs while the directory is empty, so a failed first run would need
        # another switch to retry).
        tries=0
        while [ $tries -lt 18 ] \
          && ! ${pkgs.curl}/bin/curl -fsSL --connect-timeout 5 --max-time 10 -o /dev/null https://api.github.com 2>/dev/null; do
          sleep 5
          tries=$((tries + 1))
        done
        mkdir -p ${lib.escapeShellArg wallDir}
        tmp="$(mktemp -d)"
        fw_repo="https://github.com/deadduck-09/FireWalls.git"
        if [ "${cfg.wallpaper.mode}" = "all" ]; then
          if ${pkgs.git}/bin/git clone --depth 1 --filter=blob:none --sparse "$fw_repo" "$tmp/fw" >/dev/null 2>&1 \
          && (cd "$tmp/fw" && ${pkgs.git}/bin/git sparse-checkout set Desktop/Wallpapers >/dev/null 2>&1); then
            ${pkgs.findutils}/bin/find "$tmp/fw/Desktop/Wallpapers" -type f \
              \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) \
              -exec cp {} ${lib.escapeShellArg wallDir}/ \; 2>/dev/null || true
          fi
        else
          tree_json="$(${pkgs.curl}/bin/curl -fsSL --connect-timeout 10 --max-time 60 \
            "https://api.github.com/repos/deadduck-09/FireWalls/git/trees/main?recursive=1" 2>/dev/null || true)"
          url_list=""
          if [ -n "$tree_json" ]; then
            url_list=$(echo "$tree_json" | ${pkgs.jq}/bin/jq -r '
              .tree[]? | select(.type=="blob") | .path
              | select(test("^Desktop/Wallpapers/[^\\n]*$"))
              | select(test("\\.(jpg|jpeg|png|webp|gif)$"; "i"))
              | "https://raw.githubusercontent.com/deadduck-09/FireWalls/main/\(.)"
            ' 2>/dev/null || true)
          fi
          if [ -n "$url_list" ]; then
            echo "$url_list" | ${pkgs.coreutils}/bin/shuf -n 50 | ${pkgs.findutils}/bin/xargs -P 6 -I {} sh -c '
              dest=${lib.escapeShellArg wallDir}/"$(basename "$1")"
              ${pkgs.curl}/bin/curl -g -fsSL --connect-timeout 10 --max-time 120 "$1" -o "$dest" 2>/dev/null || rm -f "$dest"
            ' _ {} || true
          else
            # Fallback if GitHub API is rate-limited: sparse git clone
            if ${pkgs.git}/bin/git clone --depth 1 --filter=blob:none --sparse "$fw_repo" "$tmp/fw" >/dev/null 2>&1 \
            && (cd "$tmp/fw" && ${pkgs.git}/bin/git sparse-checkout set Desktop/Wallpapers >/dev/null 2>&1); then
              ${pkgs.findutils}/bin/find "$tmp/fw/Desktop/Wallpapers" -type f \
                \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) 2>/dev/null \
                | ${pkgs.coreutils}/bin/shuf -n 50 \
                | ${pkgs.findutils}/bin/xargs -I {} cp {} ${lib.escapeShellArg wallDir}/ 2>/dev/null || true
            fi
          fi
        fi
        rm -rf "$tmp" 2>/dev/null || true
      fi
    '';
  };
}
