"""Character 3 (Faelis, the elf queen) sprite generator. Same 72x96 grid, joints and part names as Wizzy,
written with an "elf_" prefix.  Run:  python3 Tools/make_elf.py [preview.png]   Check:  python3 Tools/make_elf.py --check"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

W, H = 72, 96
OUT = os.path.join(os.path.dirname(__file__), "..", "Glitch", "Sprites")
PREFIX = "elf_"


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


# outline, shadow, base, light, highlight
RAMPS = {
    "cream": [rgb(c) for c in ("4a3e2a", "c9b98f", "ece0bd", "f7efd6", "fffaf0")],
    "leaf": [rgb(c) for c in ("0f2a14", "2f6b34", "4f9a45", "79c25a", "b0e07a")],
    "skin": [rgb(c) for c in ("5a3a2c", "d9a98a", "f2cdb0", "fbe2cc", "fff3e6")],
    "hair": [rgb(c) for c in ("6a4a10", "c8962e", "e8c25a", "f6dc84", "fff2b8")],
    "wood": [rgb(c) for c in ("2a1a0e", "5a3a1e", "7d5430", "a07040", "c08c58")],
}
EYE = rgb("2fae4a")
EYE_DARK = rgb("0f4a1e")
LASH = rgb("5a3a2c")
LIP = rgb("d98a86")
PETALS = [rgb("fffaf0"), rgb("f6b8c8"), rgb("fff2b8")]   # white, soft pink, pale yellow
HEART = rgb("e8b030")


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
    """Same pixel shading as Tools/make_mage.py (copied so running this never rewrites Wizzy's sprites)."""

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


def put(img, pts, color):
    for x, y in pts:
        if 0 <= x < W and 0 <= y < H:
            img.putpixel((x, y), color)


def flower(img, cx, cy, petal):
    """A five-pixel blossom: gold heart, four petals."""
    put(img, [(cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)], petal)
    put(img, [(cx, cy)], HEART)


def build():
    parts = {}
    os.makedirs(OUT, exist_ok=True)

    # legs hidden under the long dress (she glides like Wizzy), no pauldrons, no sash
    for n in ("thighL", "shinL", "footL", "thighR", "shinR", "footR", "pauldronFar", "pauldronNear", "sash"):
        parts[n] = combine(n)

    # ------------------------------------------------------------------ back layer: green cape, long blonde hair over it
    CAPE = [(32, 32), (50, 32), (55, 42), (57, 62), (58, 84), (54, 88), (48, 86), (42, 88), (36, 86), (30, 88),
            (27, 86), (27, 66), (28, 48), (29, 38)]
    HAIR = [(41, 8), (50, 9), (54, 15), (55, 28), (56, 44), (55, 58), (52, 65), (48, 60), (47, 44), (45, 30)]

    def cape_extra(im):
        for y in range(40, 86):                                # a few lighter strands down the hair
            for x in (50, 53):
                if im.getpixel((x, y))[:3] == RAMPS["hair"][2][:3] and y % 5:
                    im.putpixel((x, y), RAMPS["hair"][3])

    parts["cape"] = combine("cape", Layer("leaf", [CAPE], seed=37, grit=0.02), Layer("hair", [HAIR], seed=41, grit=0.03),
                            extra=cape_extra)

    # ------------------------------------------------------------------ dress: cream, green belt and leafy hem
    NECK = [(37, 27), (42, 27), (42, 36), (37, 36)]
    DRESS = [(34, 34), (46, 34), (48, 44), (47, 54), (50, 66), (53, 80), (54, 88), (26, 88), (27, 80), (30, 66),
             (33, 54), (32, 44)]

    def dress_extra(im):
        outline = RAMPS["cream"][0]
        for x in range(W):
            for y in (53, 54):                                 # green belt
                if im.getpixel((x, y))[3] and im.getpixel((x, y)) != outline:
                    im.putpixel((x, y), RAMPS["leaf"][3] if y == 53 else RAMPS["leaf"][1])
            for y in range(83, 88):                            # hem: green band with a leaf edge
                px = im.getpixel((x, y))
                if px[3] and px != outline and (y > 84 or (y == 84 and x % 3) or (y == 83 and x % 3 == 1)):
                    im.putpixel((x, y), RAMPS["leaf"][2] if y < 86 else RAMPS["leaf"][1])
        put(im, [(39, 52), (40, 51), (40, 55), (41, 56)], RAMPS["leaf"][3])   # little leaves on the belt
        put(im, [(40, 53), (40, 54)], HEART)                                    # its gold clasp
        put(im, [(x, 35) for x in range(36, 44)], RAMPS["leaf"][2])             # green neckline trim
        for y in range(58, 82, 6):                             # a thin vine down the skirt front
            put(im, [(38, y), (37, y + 1), (38, y + 2), (39, y + 3)], RAMPS["leaf"][1])
            put(im, [(36, y + 1)], RAMPS["leaf"][3])

    parts["tunic"] = combine("tunic", Layer("skin", [NECK], seed=8, grit=0.0),
                             Layer("cream", [DRESS], seed=9, grit=0.01), extra=dress_extra)

    # green shawl over the shoulders, its lower edge cut into leaves
    def shawl_extra(im):
        for x in range(30, 51):
            if x % 3 == 0 and im.getpixel((x, 39))[3]:
                put(im, [(x, 40)], RAMPS["leaf"][0])

    parts["cloak"] = combine(
        "cloak", Layer("leaf", [[(31, 33), (36, 33), (37, 36), (43, 36), (44, 33), (48, 33), (51, 37), (49, 40),
                                 (33, 40), (29, 37)]], seed=38, grit=0.03), extra=shawl_extra)

    # ------------------------------------------------------------------ arms: cream sleeves, bare forearms
    parts["armFarUpper"] = combine("armFarUpper", Layer("cream", [tl((33, 36), (29, 46), 4.5)], seed=21))
    parts["armFarFore"] = combine("armFarFore", Layer("skin", [tl((29, 45), (26, 53), 3.4)], seed=24),
                                  Layer("skin", [disc(25.5, 55, 2.1, 10)], seed=25))
    parts["armNearUpper"] = combine("armNearUpper", Layer("cream", [tl((47, 36), (50, 46), 5)], seed=17))
    parts["armNearFore"] = combine("armNearFore", Layer("skin", [tl((50, 46), (46, 54), 3.4)], seed=16),
                                   Layer("skin", [disc(45.5, 55, 2, 10)], seed=19))

    # ------------------------------------------------------------------ head: face turned left, hair, pointed ear, flower crown
    FACE = [(34, 13), (44, 12), (47, 16), (47, 24), (44, 29), (39, 31), (35, 29), (32, 24), (32, 17)]
    HAIR_TOP = [(33, 9), (40, 6), (47, 7), (51, 12), (52, 22), (50, 30), (47, 30), (46, 20), (43, 14), (36, 15),
                (32, 18), (31, 13)]
    FRINGE = [(31, 12), (36, 12), (34, 16), (33, 22), (33, 30), (30, 29), (30, 18)]   # strand framing the face
    EAR = [(46, 17), (54, 11), (49, 21), (46, 22)]

    def head_extra(im):
        put(im, [(35, 25), (36, 25)], LIP)                     # mouth
        put(im, [(33, 22)], RAMPS["skin"][1])                  # nose shadow
        put(im, [(x, 9 + (x - 41) ** 2 // 14) for x in range(32, 51)], RAMPS["leaf"][2])   # crown band
        put(im, [(x, 8 + (x - 41) ** 2 // 14) for x in range(33, 50, 2)], RAMPS["leaf"][3])
        for i, (cx, cy) in enumerate([(33, 11), (37, 8), (41, 6), (45, 7), (49, 10)]):
            flower(im, cx, cy, PETALS[i % 3])
        put(im, [(35, 9), (39, 6), (43, 6), (47, 8), (51, 12)], RAMPS["leaf"][1])          # leaf tips between

    parts["head"] = combine("head", Layer("skin", [FACE], seed=43, grit=0.0), Layer("hair", [HAIR_TOP, FRINGE], seed=44, grit=0.03),
                            Layer("skin", [EAR], seed=45, grit=0.0), extra=head_extra)

    # ------------------------------------------------------------------ eyes: green, moods change lids and brows
    def eyes(name, iris=(), dark=(), lash=()):
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        put(img, lash, LASH)
        put(img, dark, EYE_DARK)
        put(img, iris, EYE)
        img.save(os.path.join(OUT, PREFIX + name + ".png"))

    eyes("eyes_open", [(35, 20), (40, 20)], [(36, 20), (41, 20)], [(34, 19), (35, 19), (36, 19), (39, 19), (40, 19), (41, 19)])
    eyes("eyes_half", [(35, 20), (40, 20)], [], [(34, 20), (36, 20), (35, 19), (39, 20), (41, 20), (40, 19)])
    eyes("eyes_closed", [], [], [(34, 20), (35, 20), (36, 20), (39, 20), (40, 20), (41, 20)])
    eyes("eyes_wide", [(35, 20), (35, 21), (40, 20), (40, 21)], [(36, 20), (41, 20)],
         [(34, 18), (35, 18), (36, 18), (39, 18), (40, 18), (41, 18)])
    eyes("eyes_angry", [(35, 20), (40, 20)], [(36, 20), (41, 20)], [(34, 18), (35, 19), (36, 19), (39, 19), (40, 19), (41, 18)])
    eyes("eyes_happy", [], [], [(34, 20), (35, 19), (36, 20), (39, 20), (40, 19), (41, 20)])

    # ------------------------------------------------------------------ wings: two pairs of sheer fairy wings behind her
    WINGS = [
        [(45, 33), (52, 20), (60, 10), (67, 7), (69, 13), (64, 24), (52, 35)],        # near upper
        [(46, 40), (56, 43), (64, 51), (66, 60), (60, 62), (51, 52)],                 # near lower
        [(35, 33), (28, 22), (20, 13), (13, 11), (12, 17), (19, 27), (31, 36)],       # far upper
        [(34, 40), (25, 45), (18, 53), (17, 60), (23, 60), (31, 50)],                 # far lower
    ]
    VEIL, RIM, VEIN = (214, 244, 222, 120), (126, 196, 146, 235), (150, 214, 160, 200)

    def wings():
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        for poly in WINGS:
            d.polygon(poly, fill=VEIL, outline=RIM)
            root, tip = poly[0], max(poly, key=lambda q: math.dist(q, poly[0]))
            d.line([root, tip], fill=VEIN)                                # the main vein
        put(img, [(62, 13), (59, 18), (60, 54), (18, 17), (22, 54)], RAMPS["leaf"][4])   # glints
        img.save(os.path.join(OUT, PREFIX + "wings.png"))
        return img

    parts["wings"] = wings()

    # ------------------------------------------------------------------ wand: small, held in the far hand, a blossom at its tip
    def wand_extra(im):
        put(im, [(18, 42), (16, 41), (20, 40)], RAMPS["leaf"][3])   # leaves under the blossom
        flower(im, 18, 40, PETALS[1])
        put(im, [(15, 37), (21, 36), (14, 42)], RAMPS["leaf"][4])   # glints

    parts["wand"] = combine("wand", Layer("wood", [tl((26, 58), (18, 42), 1.8)], seed=31, grit=0.05), extra=wand_extra)

    # ------------------------------------------------------------------ ground shadow, a little smaller: she hovers
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for y in range(91, 96):
        for x in range(2, 70):
            dx, dy = (x - 40) / 16.0, (y - 93.5) / 1.6
            if dx * dx + dy * dy <= 1:
                shadow.putpixel((x, y), (0, 0, 0, 80))
    shadow.save(os.path.join(OUT, PREFIX + "shadow.png"))
    parts["shadow"] = shadow
    return parts


# every name SpriteSet(prefix:) reads, plus the wings, the wand and the shadow
NAMES = ["cape", "thighL", "shinL", "footL", "thighR", "shinR", "footR", "sash", "tunic", "cloak", "pauldronFar",
         "pauldronNear", "armFarUpper", "armFarFore", "armNearUpper", "armNearFore", "head", "wings", "wand", "shadow"] \
    + ["eyes_" + k for k in ("open", "closed", "half", "happy", "angry", "wide")]
VISIBLE = ["cape", "tunic", "cloak", "head", "armFarUpper", "armFarFore", "armNearUpper", "armNearFore", "wings", "wand",
           "eyes_open"]


def check():
    imgs = {}
    for n in NAMES:
        im = Image.open(os.path.join(OUT, PREFIX + n + ".png"))
        assert im.size == (W, H), (n, im.size)
        assert im.mode == "RGBA", (n, im.mode)
        imgs[n] = im
    for n in VISIBLE:
        assert imgs[n].getbbox(), n + " is empty"
    head = [p for p in imgs["head"].getdata() if p[3]]
    assert sum(1 for r, g, b, a in head if g > r and g > b) >= 20, "flower crown needs its leaves"
    tunic = [p for p in imgs["tunic"].getdata() if p[3]]
    r, g, b, _ = max(set(tunic), key=tunic.count)
    assert r > 200 and g > 190 and b > 150, "dress should be cream"
    print("OK")


if __name__ == "__main__":
    if "--check" in sys.argv:
        check()
        sys.exit()
    parts = build()
    order = ["wings", "cape", "tunic", "armFarUpper", "wand", "armFarFore", "cloak", "head", "armNearUpper", "armNearFore"]
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    canvas.alpha_composite(parts["shadow"])
    for n in order:
        canvas.alpha_composite(parts[n])
    canvas.alpha_composite(Image.open(os.path.join(OUT, PREFIX + "eyes_open.png")))
    scale = 6
    big = canvas.resize((W * scale, H * scale), Image.NEAREST)
    bg = Image.new("RGBA", (W * scale * 2 + 60, H * scale + 40), rgb("d9dce3"))   # light and dark desktop
    bg.paste(Image.new("RGBA", (W * scale + 30, H * scale + 40), rgb("1b1b20")), (W * scale + 30, 0))
    bg.alpha_composite(big, (20, 20))
    bg.alpha_composite(big, (W * scale + 40, 20))
    preview = sys.argv[1] if len(sys.argv) > 1 else os.path.join(OUT, "..", "..", "previews", "elf", "still.png")
    os.makedirs(os.path.dirname(preview), exist_ok=True)
    bg.save(preview)
    print(preview)
