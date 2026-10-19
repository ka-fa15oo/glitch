"""Generates the app icon and the menu bar icon (two glowing pixel eyes) into Glitch/Assets.xcassets.

Run from the repo root: python3 Tools/make_icon.py
"""
import json
import math
import os

from PIL import Image, ImageDraw

G = 24  # art grid
BG = (14, 12, 14)
EDGE = (40, 36, 40)
CRIM = (184, 26, 36)
HOT = (240, 70, 66)
GLOW = (92, 14, 20)

ASSETS = os.path.join(os.path.dirname(__file__), "..", "Glitch", "Assets.xcassets")


def eyes():
    """[(x0, y0, x1, y1, colour)] cells on the 24 grid, back to front."""
    cells = []
    for x0 in (5, 14):
        cells += [(x0 - 1, 9, x0 + 6, 15, GLOW), (x0, 10, x0 + 5, 14, CRIM), (x0 + 1, 11, x0 + 4, 12, HOT)]
    return cells


def app_icon(size):
    if size < 256:  # draw big and scale down, like macOS does for small icon sizes
        return app_icon(1024).resize((size, size), Image.LANCZOS)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pad = round(size * 0.1)  # macOS icon grid: the tile sits inside a transparent margin
    d.rounded_rectangle([pad, pad, size - pad, size - pad], radius=round(size * 0.18), fill=BG,
                        outline=EDGE, width=max(1, size // 256))
    cell = (size - 2 * pad) / G
    for x0, y0, x1, y1, c in eyes():
        d.rectangle([pad + x0 * cell, pad + y0 * cell, pad + x1 * cell - 1, pad + y1 * cell - 1], fill=c)
    return img


def menu_icon(px, cells):
    """Template image: black shapes on transparent; macOS tints it for light and dark menu bars."""
    img = Image.new("RGBA", (240, 240), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cell = 240 / G
    for x0, y0, x1, y1 in cells:
        d.rectangle([x0 * cell, y0 * cell, x1 * cell - 1, y1 * cell - 1], fill=(0, 0, 0, 255))
    return img.resize((px, px), Image.LANCZOS)


# the menu bar shows the selected character's eyes
GLITCH_EYES = [(3, 10, 10, 14), (14, 10, 21, 14)]                       # wide slits, like the app icon
WIZZY_EYES = [c for cx in (6, 18) for c in ((cx - 1, 8, cx + 1, 16), (cx - 4, 11, cx + 4, 13))]   # two star points


def flower_icon(px):
    """Faelis: five round petals with a gap round the middle, so it reads as a flower at menu bar size."""
    img = Image.new("RGBA", (240, 240), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c, ring, petal, heart = 120, 66, 44, 24
    for i in range(5):
        a = -math.pi / 2 + i * 2 * math.pi / 5
        x, y = c + ring * math.cos(a), c + ring * math.sin(a)
        d.ellipse([x - petal, y - petal, x + petal, y + petal], fill=(0, 0, 0, 255))
    d.ellipse([c - heart - 12, c - heart - 12, c + heart + 12, c + heart + 12], fill=(0, 0, 0, 0))   # the gap
    d.ellipse([c - heart, c - heart, c + heart, c + heart], fill=(0, 0, 0, 255))
    return img.resize((px, px), Image.LANCZOS)


def write(folder, images, contents):
    path = os.path.join(ASSETS, folder)
    os.makedirs(path, exist_ok=True)
    for name, img in images:
        img.save(os.path.join(path, name))
    with open(os.path.join(path, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)


os.makedirs(ASSETS, exist_ok=True)
with open(os.path.join(ASSETS, "Contents.json"), "w") as f:
    json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)

icons, entries = [], []
for pt in (16, 32, 128, 256, 512):
    for scale in (1, 2):
        name = f"icon_{pt}x{pt}@{scale}x.png"
        icons.append((name, app_icon(pt * scale)))
        entries.append({"idiom": "mac", "size": f"{pt}x{pt}", "scale": f"{scale}x", "filename": name})
write("AppIcon.appiconset", icons, {"images": entries, "info": {"author": "xcode", "version": 1}})

for folder, draw in (("MenuBarIcon.imageset", lambda px: menu_icon(px, GLITCH_EYES)),
                     ("MenuBarIconWizzy.imageset", lambda px: menu_icon(px, WIZZY_EYES)),
                     ("MenuBarIconFaelis.imageset", flower_icon)):
    write(folder, [("menubar.png", draw(18)), ("menubar@2x.png", draw(36))], {
        "images": [{"idiom": "universal", "scale": "1x", "filename": "menubar.png"},
                   {"idiom": "universal", "scale": "2x", "filename": "menubar@2x.png"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"template-rendering-intent": "template"},
    })

# self-check: every icon slot exists at the pixel size it claims
for e in entries:
    pt, scale = int(e["size"].split("x")[0]), int(e["scale"][0])
    with Image.open(os.path.join(ASSETS, "AppIcon.appiconset", e["filename"])) as im:
        assert im.size == (pt * scale, pt * scale), e
print("ok:", len(entries), "app icon sizes + menu bar icons for Glitch, Wizzy and Faelis")
