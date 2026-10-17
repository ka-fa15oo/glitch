"""Character 2 (cosmic mage) sprite generator. Same 72x96 grid, same joints and part names as Glitch,
written with a "mage_" prefix so the rig can load either set.  Run:  python3 Tools/make_mage.py [preview.png]"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

W, H = 72, 96
OUT = os.path.join(os.path.dirname(__file__), "..", "Glitch", "Sprites")
PREFIX = "mage_"


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


# outline, shadow, base, light, highlight
RAMPS = {
    "navy": [rgb(c) for c in ("04050d", "0a0f26", "141d45", "1f2c63", "33467f")],
    "silver": [rgb(c) for c in ("0b0b12", "2a2a3a", "5b5d75", "9496ad", "d6d8ea")],
    "wood": [rgb(c) for c in ("07050a", "1a1220", "2e2236", "45364f", "625070")],
    "gold": [rgb(c) for c in ("1a1204", "5a400e", "a07a1c", "d4a92e", "f2d36a")],
    "hand": [rgb(c) for c in ("08080d", "1d1d2a", "3a3a50", "585a74", "7e819c")],
}
SKY = rgb("04051a")
STAR = rgb("e8e6ff")
STAR_DIM = rgb("7f86c4")
GOLD = rgb("f0d890")
NEBULA = [rgb("3a1f5e"), rgb("5a2a7a"), rgb("8e3a8e"), rgb("c0609e")]  # faint to bright
EYE = rgb("d8f0ff")
EYE_DIM = rgb("5d7fa8")


def tl(p0, p1, w):
    """Polygon for a thick line."""
    (x0, y0), (x1, y1) = p0, p1
    dx, dy = x1 - x0, y1 - y0
    n = math.hypot(dx, dy)
    nx, ny = -dy / n * w / 2, dx / n * w / 2
    return [(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)]


def disc(cx, cy, r, n=14):
    return [(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n)) for i in range(n)]


class Layer:
    """Same pixel shading as Tools/make_sprites.py (copied so running this never rewrites Glitch's sprites)."""

    def __init__(self, material, polys, seed=1, grit=0.07):
        self.mask = Image.new("L", (W, H), 0)
        d = ImageDraw.Draw(self.mask)
        for p in polys:
            d.polygon(p, fill=255)
        self.img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        self.rng = random.Random(seed)
        ramp = RAMPS[material]
        for y in range(H):
            for x in range(W):
                if not self.inside(x, y):
                    continue
                l, u = self.steps(x, y, -1, 0), self.steps(x, y, 0, -1)
                r, dn = self.steps(x, y, 1, 0), self.steps(x, y, 0, 1)
                if min(l, u, r, dn) == 1:
                    idx = 0
                else:
                    tl_, br = min(l, u), min(r, dn)
                    idx = 2
                    if tl_ == 2 or (tl_ == 3 and (x + y) % 2 == 0):
                        idx = 3
                    if br == 2 or (br == 3 and (x + y) % 2 == 0):
                        idx = 1
                    if idx >= 2 and self.rng.random() < grit:
                        idx -= 1
                    elif idx == 3 and tl_ == 2 and self.rng.random() < 0.3:
                        idx = 4
                self.img.putpixel((x, y), ramp[idx])

    def inside(self, x, y):
        return 0 <= x < W and 0 <= y < H and self.mask.getpixel((x, y)) > 0

    def steps(self, x, y, dx, dy, limit=5):
        n = 1
        while n <= limit and self.inside(x + dx * n, y + dy * n):
            n += 1
        return n


def combine(name, *layers, extra=None):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for layer in layers:
        img.alpha_composite(layer.img)
    if extra:
        extra(img)
    img.save(os.path.join(OUT, PREFIX + name + ".png"))
    return img


def empty(name):
    return combine(name)


def put(img, pts, color):
    for x, y in pts:
        if 0 <= x < W and 0 <= y < H:
            img.putpixel((x, y), color)


def nebula(seed, strength, outline):
    """Purple-pink clouds drifting through the cloth; outline pixels stay plain so the silhouette reads."""
    rng = random.Random(seed)
    waves = [(rng.uniform(0.05, 0.13), rng.uniform(0.04, 0.1), rng.uniform(0, 6.3)) for _ in range(4)]

    def apply(im):
        for y in range(H):
            for x in range(W):
                px = im.getpixel((x, y))
                if not px[3] or px == outline:
                    continue
                v = sum(math.sin(x * a + y * b + p) for a, b, p in waves) / len(waves)   # -1..1
                v = v * strength + rng.uniform(-0.08, 0.08)
                if v > 0.62:
                    im.putpixel((x, y), NEBULA[3] if v > 0.8 else NEBULA[2])
                elif v > 0.42:
                    im.putpixel((x, y), NEBULA[1])
                elif v > 0.3 and (x + y) % 2 == 0:
                    im.putpixel((x, y), NEBULA[0])
                elif rng.random() < 0.012:
                    im.putpixel((x, y), STAR_DIM)
    return apply


parts = {}
os.makedirs(OUT, exist_ok=True)

# ------------------------------------------------------------------ legs: hidden under the robe (the mage glides)
for n in ("thighL", "shinL", "footL", "thighR", "shinR", "footR", "pauldronFar", "pauldronNear", "sash"):
    parts[n] = empty(n)

# ------------------------------------------------------------------ robe: back half (cape) and front half (tunic)
ROBE_FRONT = [(33, 37), (47, 37), (50, 50), (52, 68), (53, 84), (50, 87), (45, 85), (40, 88), (35, 85),
              (30, 87), (28, 84), (29, 68), (31, 50)]
CAPE = [(31, 31), (50, 31), (55, 42), (58, 62), (59, 82), (56, 87), (51, 84), (46, 85), (41, 84), (36, 85),
        (31, 84), (27, 87), (26, 70), (27, 50), (28, 40)]


def cape_extra(im):
    for fx in (29, 54, 57):                                   # vertical folds
        for y in range(46, 86):
            if im.getpixel((fx, y))[3] and im.getpixel((fx, y - 1))[3] and y % 6:
                im.putpixel((fx, y), RAMPS["gold"][1])


def robe_extra(im):
    nebula(51, 1.5, RAMPS["navy"][0])(im)
    for x in range(W):                                        # silver cord at the waist
        for y in (57, 58):
            if im.getpixel((x, y))[3] and im.getpixel((x, y)) != RAMPS["navy"][0]:
                im.putpixel((x, y), RAMPS["silver"][3] if y == 57 else RAMPS["silver"][1])
    put(im, [(37, 59), (37, 60), (37, 61), (36, 62), (36, 63), (36, 64)], RAMPS["silver"][2])   # tassel


parts["tunic"] = combine("tunic", Layer("navy", [ROBE_FRONT], seed=9, grit=0.01), extra=robe_extra)
parts["cape"] = combine("cape", Layer("gold", [CAPE], seed=37, grit=0.01), extra=cape_extra)
parts["cloak"] = combine(                                     # shoulder mantle under the hood
    "cloak",
    Layer("navy", [[(31, 32), (49, 32), (53, 38), (51, 43), (32, 43), (28, 39)]], seed=38, grit=0.04),
    extra=lambda im: [put(im, [(x, 43)], RAMPS["silver"][2]) for x in range(29, 52)
                      if im.getpixel((x, 43))[3] and im.getpixel((x, 44))[3] == 0],
)

# ------------------------------------------------------------------ sleeves and hands
parts["armFarUpper"] = combine("armFarUpper", Layer("navy", [tl((29, 38), (25, 48), 5)], seed=21))
parts["armFarFore"] = combine(
    "armFarFore",
    Layer("navy", [[(22, 45), (27, 46), (25, 53), (19, 52)]], seed=24, grit=0.01),
    Layer("hand", [disc(21.5, 51, 2.2, 10)], seed=25),
)
parts["armNearUpper"] = combine("armNearUpper", Layer("navy", [tl((51, 38), (54, 49), 6)], seed=17))
parts["armNearFore"] = combine(
    "armNearFore",
    Layer("navy", [[(51, 46), (56, 49), (50, 57), (46, 59), (47, 54)]], seed=16),
    Layer("hand", [disc(46.5, 58, 2, 10)], seed=19),
)

# ------------------------------------------------------------------ hood: deep, no face, a night sky inside
HOOD = [(37, 6), (44, 4), (49, 6), (51, 12), (51, 20), (49, 28), (47, 34), (42, 37), (34, 37), (31, 32),
        (30, 22), (31, 14), (33, 9)]
OPENING = [(31, 15), (35, 12), (40, 14), (42, 20), (40, 27), (35, 30), (32, 28), (30, 22)]


def hood_extra(im):
    sky = Image.new("L", (W, H), 0)
    ImageDraw.Draw(sky).polygon(OPENING, fill=255)
    for y in range(H):
        for x in range(W):
            if not sky.getpixel((x, y)):
                continue
            edge = any(not sky.getpixel((x + dx, y + dy)) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            im.putpixel((x, y), RAMPS["navy"][3] if edge and x > 38 else SKY)   # lit inner rim on the near side


parts["head"] = combine("head", Layer("navy", [HOOD], seed=43, grit=0.01), extra=hood_extra)


# two points of light; moods only change how much they glow and their shape
def eyes(name, bright, dim=()):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    put(img, dim, EYE_DIM)
    put(img, bright, EYE)
    img.save(os.path.join(OUT, PREFIX + name + ".png"))


eyes("eyes_open", [(32, 20), (37, 20)], [(31, 20), (33, 20), (36, 20), (38, 20)])
eyes("eyes_half", [], [(32, 20), (37, 20)])
eyes("eyes_closed", [], [])
eyes("eyes_wide", [(32, 19), (32, 20), (37, 19), (37, 20)], [(31, 19), (33, 19), (31, 20), (33, 20),
                                                          (36, 19), (38, 19), (36, 20), (38, 20)])
eyes("eyes_angry", [(32, 21), (37, 21)], [(31, 20), (38, 20)])
eyes("eyes_happy", [(31, 21), (32, 20), (33, 21), (36, 21), (37, 20), (38, 21)])

# ------------------------------------------------------------------ staff: taller than the mage, a yellow star on its tip
STAFF_BASE, STAFF_TOP = (23, 92), (18, 5)


def staff_extra(im):
    star = [(18, 0), (18, 1), (15, 2), (16, 2), (17, 2), (18, 2), (19, 2), (20, 2), (21, 2),
            (17, 3), (18, 3), (19, 3), (16, 4), (17, 4), (19, 4), (20, 4), (16, 5), (20, 5)]
    put(im, star, RAMPS["gold"][3])
    put(im, [(15, 2), (21, 2), (16, 5), (20, 5), (18, 0)], RAMPS["gold"][2])   # dimmer points
    put(im, [(18, 2), (18, 3)], GOLD)
    put(im, [(12, 1), (24, 4), (14, 8)], STAR)                # small white stars around the tip
    put(im, [(23, 0), (11, 5), (22, 8)], STAR_DIM)


parts["staff"] = combine("staff", Layer("wood", [tl(STAFF_BASE, STAFF_TOP, 2.6)], seed=29, grit=0.1),
                         extra=staff_extra)

# ------------------------------------------------------------------ ground shadow, a little smaller: it hovers
shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
for y in range(91, 96):
    for x in range(2, 70):
        dx, dy = (x - 40) / 18.0, (y - 93.5) / 1.6
        if dx * dx + dy * dy <= 1:
            shadow.putpixel((x, y), (0, 0, 0, 80))
shadow.save(os.path.join(OUT, PREFIX + "shadow.png"))

if __name__ == "__main__":
    order = ["cape", "thighL", "shinL", "thighR", "shinR", "footL", "footR", "sash", "tunic", "staff", "pauldronFar",
             "armFarUpper", "armFarFore", "cloak", "pauldronNear", "head", "armNearUpper", "armNearFore"]
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    canvas.alpha_composite(shadow)
    for n in order:
        canvas.alpha_composite(parts[n])
    canvas.alpha_composite(Image.open(os.path.join(OUT, PREFIX + "eyes_open.png")))
    scale = 6
    big = canvas.resize((W * scale, H * scale), Image.NEAREST)
    bg = Image.new("RGBA", (W * scale * 2 + 60, H * scale + 40), rgb("d9dce3"))   # light and dark desktop
    bg.paste(Image.new("RGBA", (W * scale + 30, H * scale + 40), rgb("1b1b20")), (W * scale + 30, 0))
    bg.alpha_composite(big, (20, 20))
    bg.alpha_composite(big, (W * scale + 40, 20))
    preview = sys.argv[1] if len(sys.argv) > 1 else os.path.join(OUT, "..", "..", "previews", "mage", "still.png")
    os.makedirs(os.path.dirname(preview), exist_ok=True)
    bg.save(preview)
    print(preview)
