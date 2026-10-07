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
      # NOTE: Wallpaper fetching is best-effort and must NEVER abort Home Manager activation.
      # Activation blocks run sourced with `set -e` and `set -o pipefail`. We guard the entire
      # routine in a subshell and use safe directory/file checks.
      (
        num_existing=0
        if [ -d ${lib.escapeShellArg wallDir} ]; then
          num_existing=$(${pkgs.findutils}/bin/find ${lib.escapeShellArg wallDir} -maxdepth 1 -type f ! -name 'default.jpg' 2>/dev/null | wc -l || echo 0)
        fi

        if [ "$num_existing" -eq 0 ]; then
          # Home Manager activation runs at boot or switch, possibly before NetworkManager
          # is online. Wait briefly for connectivity.
          tries=0
          while [ $tries -lt 6 ] \
            && ! ${pkgs.curl}/bin/curl -fsSL --connect-timeout 5 --max-time 10 -o /dev/null https://api.github.com 2>/dev/null; do
            sleep 3
            tries=$((tries + 1))
          done

          mkdir -p ${lib.escapeShellArg wallDir}
          tmp="$(${pkgs.coreutils}/bin/mktemp -d 2>/dev/null || true)"
          fw_repo="https://github.com/deadduck-09/FireWalls.git"

          if [ "${cfg.wallpaper.mode}" = "all" ]; then
            if [ -n "$tmp" ] && ${pkgs.git}/bin/git clone --depth 1 --filter=blob:none --sparse "$fw_repo" "$tmp/fw" >/dev/null 2>&1 \
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
              printf '%s\n' "$url_list" | ${pkgs.coreutils}/bin/shuf -n 50 | ${pkgs.findutils}/bin/xargs -P 6 -I {} sh -c '
                url="$1"
                case "$url" in
                  https://raw.githubusercontent.com/deadduck-09/FireWalls/main/*) ;;
                  *) exit 0 ;;
                esac
                dest=${lib.escapeShellArg wallDir}/"$(basename "$url")"
                tmp_part="$dest.part.$$"
                if ${pkgs.curl}/bin/curl -g -fsSL --connect-timeout 10 --max-time 120 "$url" -o "$tmp_part" 2>/dev/null; then
                  mv -f "$tmp_part" "$dest" 2>/dev/null || true
                else
                  rm -f "$tmp_part" 2>/dev/null || true
                fi
              ' _ {} 2>/dev/null || true
            else
              # Fallback if GitHub API is rate-limited: sparse git clone
              if [ -n "$tmp" ] && ${pkgs.git}/bin/git clone --depth 1 --filter=blob:none --sparse "$fw_repo" "$tmp/fw" >/dev/null 2>&1 \
              && (cd "$tmp/fw" && ${pkgs.git}/bin/git sparse-checkout set Desktop/Wallpapers >/dev/null 2>&1); then
                ${pkgs.findutils}/bin/find "$tmp/fw/Desktop/Wallpapers" -type f \
                  \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) 2>/dev/null \
                  | ${pkgs.coreutils}/bin/shuf -n 50 \
                  | ${pkgs.findutils}/bin/xargs -I {} cp {} ${lib.escapeShellArg wallDir}/ 2>/dev/null || true
              fi
            fi
          fi
          if [ -n "$tmp" ]; then
            rm -rf "$tmp" 2>/dev/null || true
          fi
        fi
      ) || true
    '';
  };
}
