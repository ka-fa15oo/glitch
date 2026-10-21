"""Character 3 (white-haired lady) STILL preview only. Same 72x96 grid and Layer shading as make_mage.py.
Run:  python3 Tools/make_lady.py [out.png]"""
import os
import random
import sys

from PIL import Image, ImageDraw

W, H = 72, 96


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


# outline, shadow, base, light, highlight
RAMPS = {
    "dress": [rgb(c) for c in ("0b0818", "1a1430", "2b2250", "463a78", "6a5ca0")],
    "skin": [rgb(c) for c in ("3a2a30", "b79ca5", "e6d6da", "f6ecee", "ffffff")],
    "hair": [rgb(c) for c in ("2a2c40", "9096b8", "d6d9ea", "f0f1f8", "ffffff")],
    "gold": [rgb(c) for c in ("1a1204", "6a4e10", "b88a22", "e0b83a", "f6dc7a")],
    "shoe": [rgb(c) for c in ("000000", "0a0a10", "16161e", "262634", "3a3a4c")],
}
EYE = rgb("f2c230")
PUPIL = rgb("2a1a08")


class Layer:
    def __init__(self, material, polys, seed=1):
        self.mask = Image.new("L", (W, H), 0)
        d = ImageDraw.Draw(self.mask)
        for p in polys:
            d.polygon(p, fill=255)
        self.img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        rng, ramp = random.Random(seed), RAMPS[material]
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
                    if idx >= 2 and rng.random() < 0.05:
                        idx -= 1
                self.img.putpixel((x, y), ramp[idx])

    def inside(self, x, y):
        return 0 <= x < W and 0 <= y < H and self.mask.getpixel((x, y)) > 0

    def steps(self, x, y, dx, dy, limit=5):
        n = 1
        while n <= limit and self.inside(x + dx * n, y + dy * n):
            n += 1
        return n


def build():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    L = lambda m, *p, seed=1: img.alpha_composite(Layer(m, p, seed).img)
    # back skirt panel (hangs behind the leg)
    L("dress", [(40, 44), (46, 44), (48, 70), (47, 90), (41, 90)])
    # far (right) leg, partly hidden
    L("skin", [(39, 54), (43, 54), (43, 86), (40, 86)])
    L("shoe", [(39, 87), (44, 87), (47, 92), (40, 92)])
    # front skirt (left of slit)
    L("dress", [(30, 44), (41, 44), (38, 56), (34, 72), (35, 90), (27, 90), (28, 62)])
    # near (left) leg crossing in front through the slit
    L("skin", [(33, 56), (40, 52), (42, 60), (39, 72), (38, 86), (34, 86), (34, 74)])
    L("shoe", [(32, 87), (38, 87), (40, 92), (30, 92)])
    L("gold", [(34, 83), (39, 83), (39, 85), (34, 85)])
    # torso (halter dress) + chest opening
    L("dress", [(30, 29), (43, 29), (42, 46), (31, 46)])
    L("skin", [(34, 29), (39, 29), (36, 40)])
    # neck + head
    L("skin", [(34, 22), (39, 22), (39, 30), (34, 30)])
    L("skin", [(31, 11), (42, 11), (43, 18), (40, 24), (34, 24), (31, 18)])
    # hair: cap, short side locks, bun on the left
    L("hair", [(29, 17), (30, 9), (36, 6), (43, 9), (43, 20), (41, 15), (36, 12), (33, 14), (32, 22), (29, 22)], seed=3)
    L("hair", [(24, 13), (29, 11), (30, 18), (26, 19)], seed=4)
    L("gold", [(22, 15), (25, 15), (25, 19), (22, 19)])
    # near arm on hip (viewer's left): upper arm, forearm, hand
    L("skin", [(27, 30), (32, 30), (27, 42), (22, 40)])
    L("skin", [(22, 40), (27, 42), (34, 46), (31, 49)])
    L("gold", [(26, 33), (30, 33), (29, 36), (25, 36)])
    # far arm raised, palm open (viewer's right)
    L("skin", [(40, 30), (45, 31), (52, 37), (49, 41)])
    L("skin", [(48, 36), (53, 38), (59, 29), (55, 27)])
    L("skin", [(55, 24), (60, 26), (62, 29), (58, 31), (55, 29)])
    # eyes
    for x in (34, 39):
        img.putpixel((x, 18), EYE)
        img.putpixel((x + 1, 18), EYE)
        img.putpixel((x, 19), PUPIL)
    return img


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "previews", "lady", "still.png")
    s = build()
    bg = Image.new("RGBA", (W, H), (150, 150, 150, 255))
    bg.alpha_composite(s)
    bg.resize((W * 8, H * 8), Image.NEAREST).save(out)
