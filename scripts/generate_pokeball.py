#!/usr/bin/env python3
"""Generate the pokeball cursor image."""
import os
from PIL import Image, ImageDraw

app_dir = os.path.expanduser("~/.claude/Pokemon Notify.app")
out_path = os.path.join(app_dir, "Contents/Resources/pokeball_cursor.png")

size = 32
img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

cx, cy, r = 16, 16, 13

d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(0, 0, 0, 255))
d.ellipse([cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 2], fill=(220, 40, 40, 255))
d.chord([cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 2], start=0, end=180, fill=(255, 255, 255, 255))
d.rectangle([cx - r, cy - 1, cx + r, cy + 1], fill=(0, 0, 0, 255))
d.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=(0, 0, 0, 255))
d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=(255, 255, 255, 255))

img.save(out_path)
print(f"Saved pokeball cursor to {out_path}")
