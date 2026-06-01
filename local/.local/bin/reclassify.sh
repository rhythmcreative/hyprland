#!/bin/bash
cd /home/rhythmcreative/Pictures/Wallpapers || exit 1
# Flatten first
find . -mindepth 2 -type f -exec mv -t . {} +
find . -mindepth 1 -type d -empty -delete

# Get mapping
curl -s https://raw.githubusercontent.com/bjarneo/wallpapers/main/wallpapers.json | jq -r 'to_entries[] | "\(.key|split("/")|last) \(.key)"' > /tmp/full_paths.txt

# Re-classify
while read -r filename fullpath; do
  dir=$(dirname "$fullpath")
  if [ -f "$filename" ]; then
    mkdir -p "$dir"
    mv "$filename" "$dir/"
  fi
done < /tmp/full_paths.txt
