#!/bin/bash
TARGET_DIR="$1"
CACHE_DIR="/home/rhythmcreative/.cache/quickshell-wallpaper-thumbs"
mkdir -p "$CACHE_DIR"

find -L "$TARGET_DIR" -type f -regextype posix-extended -regex '.*\.(jpg|png|jpeg|gif|webp)' > /tmp/wallpaper_list.txt
jq -R . /tmp/wallpaper_list.txt | jq -s . > /tmp/wallpapers.json

cat > /tmp/gen_thumbs.py << 'PY'
import hashlib, os, subprocess, concurrent.futures
cache_dir = "/home/rhythmcreative/.cache/quickshell-wallpaper-thumbs"
def gen_thumb(img):
    img = img.strip()
    if not img: return
    h = hashlib.md5(img.encode()).hexdigest()
    out = os.path.join(cache_dir, h + ".jpg")
    if not os.path.exists(out):
        subprocess.run(["ffmpeg", "-y", "-i", img, "-frames:v", "1", "-vf", "scale=500:-1", out], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
if os.path.exists("/tmp/wallpaper_list.txt"):
    with open("/tmp/wallpaper_list.txt", "r") as f:
        imgs = f.readlines()
    with concurrent.futures.ThreadPoolExecutor(max_workers=16) as ex:
        ex.map(gen_thumb, imgs)
PY
python3 /tmp/gen_thumbs.py &
