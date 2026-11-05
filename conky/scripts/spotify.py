#!/usr/bin/env python3
import subprocess
import os
import urllib.request
from PIL import Image, ImageDraw

COVER_PATH = "/tmp/spotify_cover.png"
LAST_URL_FILE = "/tmp/spotify_last_url.txt"
OUTPUT_LUA = "/tmp/spotify_state.lua"
TMP_LUA = "/tmp/spotify_state.lua.tmp"

def escape_lua(s):
    if not s:
        return ""
    return str(s).replace('\\', '\\\\').replace('"', '\\"').replace('\n', ' ').strip()

def write_state(data):
    lines = ["return {"]
    for k, v in data.items():
        if isinstance(v, bool):
            lines.append(f'  {k} = {str(v).lower()},')
        elif isinstance(v, (int, float)):
            lines.append(f'  {k} = {v},')
        else:
            lines.append(f'  {k} = "{escape_lua(v)}",')
    lines.append("}")
    content = "\n".join(lines) + "\n"

    try:
        with open(TMP_LUA, "w", encoding="utf-8") as f:
            f.write(content)
        os.replace(TMP_LUA, OUTPUT_LUA)
    except Exception:
        pass

def update_cover(art_url):
    if not art_url:
        return False

    last_url = ""
    if os.path.exists(LAST_URL_FILE):
        try:
            with open(LAST_URL_FILE, "r") as f:
                last_url = f.read().strip()
        except Exception:
            pass

    if art_url == last_url and os.path.exists(COVER_PATH):
        return True

    try:
        raw_tmp = "/tmp/spotify_cover_raw.tmp"
        if art_url.startswith("file://"):
            src = art_url[7:]
            im = Image.open(src).convert("RGBA")
        else:
            urllib.request.urlretrieve(art_url, raw_tmp)
            im = Image.open(raw_tmp).convert("RGBA")

        size = (72, 72)
        im = im.resize(size, Image.LANCZOS)

        # Rounded rectangle mask with smooth anti-aliased corners
        scale = 4
        big_size = (size[0] * scale, size[1] * scale)
        big_mask = Image.new("L", big_size, 0)
        draw = ImageDraw.Draw(big_mask)
        draw.rounded_rectangle([(0, 0), big_size], radius=10 * scale, fill=255)
        mask = big_mask.resize(size, Image.LANCZOS)

        im.putalpha(mask)
        im.save(COVER_PATH, "PNG")

        with open(LAST_URL_FILE, "w") as f:
            f.write(art_url)
        return True
    except Exception:
        return False

def main():
    cmd = [
        "playerctl", "-p", "spotify", "metadata",
        "--format", "{{status}}|{{xesam:title}}|{{xesam:artist}}|{{xesam:album}}|{{mpris:length}}|{{position}}|{{mpris:artUrl}}"
    ]

    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=1)
        if p.returncode != 0 or not p.stdout.strip():
            write_state({
                "running": False,
                "status": "Offline",
                "title": "No Track Playing",
                "artist": "Spotify is offline",
                "album": "",
                "pos_str": "--:--",
                "len_str": "--:--",
                "progress": 0.0,
                "has_cover": False
            })
            return
        parts = p.stdout.strip().split("|")
    except Exception:
        write_state({
            "running": False,
            "status": "Offline",
            "title": "No Track Playing",
            "artist": "Spotify is offline",
            "album": "",
            "pos_str": "--:--",
            "len_str": "--:--",
            "progress": 0.0,
            "has_cover": False
        })
        return

    status = parts[0] if len(parts) > 0 and parts[0] else "Unknown"
    title = parts[1] if len(parts) > 1 and parts[1] else "Unknown Title"
    artist = parts[2] if len(parts) > 2 and parts[2] else "Unknown Artist"
    album = parts[3] if len(parts) > 3 and parts[3] else ""

    length_us = 0
    if len(parts) > 4 and parts[4].isdigit():
        length_us = int(parts[4])

    pos_us = 0
    if len(parts) > 5 and parts[5].isdigit():
        pos_us = int(parts[5])

    art_url = parts[6] if len(parts) > 6 else ""

    length_sec = length_us // 1000000
    pos_sec = pos_us // 1000000

    pos_min, pos_s = divmod(pos_sec, 60)
    len_min, len_s = divmod(length_sec, 60)

    pos_str = f"{pos_min:02d}:{pos_s:02d}"
    len_str = f"{len_min:02d}:{len_s:02d}"

    progress = 0.0
    if length_sec > 0:
        progress = round(min(max(pos_sec / length_sec, 0.0), 1.0), 3)

    has_cover = update_cover(art_url)

    write_state({
        "running": True,
        "status": status,
        "title": title,
        "artist": artist,
        "album": album,
        "pos_str": pos_str,
        "len_str": len_str,
        "progress": progress,
        "has_cover": has_cover
    })

if __name__ == "__main__":
    main()
