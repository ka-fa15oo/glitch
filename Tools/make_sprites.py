"""Glitch sprite generator (72x96). Every body part is its own PNG so one part can be
reworked without touching the others.  Run:  python3 Tools/make_sprites.py [preview.png]"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

W, H = 72, 96
OUT = os.path.join(os.path.dirname(__file__), "..", "Glitch", "Sprites")
os.makedirs(OUT, exist_ok=True)


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


# outline, shadow, base, light, highlight
RAMPS = {
    "steel": [rgb(c) for c in ("090d10", "1a2327", "37484e", "62808a", "a9c3c6")],
    "dark": [rgb(c) for c in ("050407", "0b0a0f", "16141c", "27242f", "403b4b")],
    "brown": [rgb(c) for c in ("0c0706", "21160f", "463428", "6e5a4a", "9c8672")],
    "tunic": [rgb(c) for c in ("08070a", "131118", "211e28", "353040", "4d465b")],
    "orange": [rgb(c) for c in ("140803", "3a1a08", "87431a", "c4642b", "eba160")],
    "red": [rgb(c) for c in ("0e0205", "34050f", "6a0a1a", "9a1428", "c42439")],
    "ash": [rgb(c) for c in ("08080b", "1b1b22", "383844", "5a5a6c", "8a8a9e")],
    "cape": [rgb(c) for c in ("0c0204", "2a0610", "55091a", "7e1226", "b02438")],
    "leather": [rgb(c) for c in ("0a0605", "1c1008", "3b2210", "5c3a1c", "86592b")],
    "gold": [rgb(c) for c in ("120c04", "3a2a0d", "7a5e24", "b8963f", "e6d79c")],
}
CRIMSON = rgb("d4102a")
CRIMSON_DARK = rgb("55081a")
VOID = rgb("030204")
CX = 40  # head centre


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
    def __init__(self, material, polys, seed=1, grit=0.07, chip=0.0):
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
                    if tl_ == 2:
                        idx = 3
                    elif tl_ == 3 and (x + y) % 2 == 0:
                        idx = 3
                    if br == 2:
                        idx = 1
                    elif br == 3 and (x + y) % 2 == 0:
                        idx = 1
                    if idx >= 2 and self.rng.random() < grit:
                        idx -= 1
                    elif idx == 3 and tl_ == 2 and self.rng.random() < 0.3:
                        idx = 4
                self.img.putpixel((x, y), ramp[idx])
        if chip:
            for y in range(H):
                for x in range(W):
                    if self.inside(x, y) and min(self.steps(x, y, -1, 0), self.steps(x, y, 1, 0),
                                                  self.steps(x, y, 0, -1), self.steps(x, y, 0, 1)) == 1 \
                            and self.rng.random() < chip:
                        self.img.putpixel((x, y), (0, 0, 0, 0))

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
    img.save(os.path.join(OUT, name + ".png"))
    return img


def put(img, pts, color):
    for x, y in pts:
        if 0 <= x < W and 0 <= y < H:
            img.putpixel((x, y), color)


def mx(x):  # mirror around the head centre
    return 2 * CX - x


parts = {}

# ------------------------------------------------------------------ legs: thigh + shin per side (jointed at hip and knee)
def boots_extra(im):
    for x in range(W):                                        # soles
        for y in (93, 94):
            if im.getpixel((x, y))[3]:
                im.putpixel((x, y), RAMPS["dark"][0])


# straight legs: hip, knee and ankle almost on one line, a little apart
HIP_L, KNEE_L, ANKLE_L = (38, 60), (33, 74), (28, 88)
HIP_R, KNEE_R, ANKLE_R = (44, 60), (47, 74), (50, 88)
FOOT = [(-4, -2), (5, -2), (6, 2), (7, 6), (-13, 6), (-11, 3), (-7, 1)]      # toe points left, relative to ankle
TOE = [(-12, 3), (-8, 2), (-6, 5), (-12, 5)]


def at(points, origin):
    return [(origin[0] + x, origin[1] + y) for x, y in points]


parts["thighL"] = combine("thighL", Layer("tunic", [tl(HIP_L, KNEE_L, 10)], seed=3, chip=0.04))
parts["thighR"] = combine("thighR", Layer("tunic", [tl(HIP_R, KNEE_R, 10)], seed=4, chip=0.04))
parts["shinL"] = combine("shinL", Layer("steel", [tl(KNEE_L, ANKLE_L, 7), disc(*KNEE_L, 4.5)], seed=5, chip=0.05))
parts["shinR"] = combine("shinR", Layer("steel", [tl(KNEE_R, ANKLE_R, 7), disc(*KNEE_R, 4.5)], seed=6, chip=0.05))
parts["footL"] = combine(
    "footL",
    Layer("leather", [at(FOOT, ANKLE_L)], seed=7),
    Layer("steel", [at(TOE, ANKLE_L)], seed=8),
    extra=boots_extra,
)
parts["footR"] = combine(
    "footR",
    Layer("leather", [at(FOOT, ANKLE_R)], seed=9),
    Layer("steel", [at(TOE, ANKLE_R)], seed=10),
    extra=boots_extra,
)

# ------------------------------------------------------------------ tunic + chest plate + sash (3/4 turned left)
def tunic_extra(im):
    g = RAMPS["gold"]
    for y in range(40, 53):                                   # cross on the plate
        for x in (38, 39):
            if im.getpixel((x, y))[3]:
                im.putpixel((x, y), g[3] if x == 38 else g[1])
    for x in range(34, 44):
        for y in (44, 45):
            if im.getpixel((x, y))[3]:
                im.putpixel((x, y), g[3] if y == 44 else g[1])
    for x in range(31, 46):                                   # collar trim
        if im.getpixel((x, 37))[3]:
            im.putpixel((x, 37), g[2])


parts["tunic"] = combine(
    "tunic",
    Layer("tunic", [[(30, 36), (48, 36), (52, 50), (49, 63), (32, 63), (28, 50)]], seed=9, chip=0.02, grit=0.05),
    Layer("steel", [[(31, 38), (46, 38), (49, 48), (45, 57), (34, 57), (29, 48)]], seed=10, grit=0.06),
    extra=tunic_extra,
)
parts["sash"] = combine(
    "sash",
    Layer("orange", [[(29, 57), (51, 57), (52, 62), (30, 62)], tl((34, 62), (32, 77), 3.2), tl((40, 62), (42, 73), 3)],
          seed=13, grit=0.1),
    extra=lambda im: put(im, [(38, 59), (39, 59), (38, 60), (39, 60)], RAMPS["gold"][4]),
)

# ------------------------------------------------------------------ arms: upper arm + forearm per side (elbow joint)
parts["armFarUpper"] = combine("armFarUpper", Layer("tunic", [tl((29, 38), (25, 48), 6)], seed=21, chip=0.03))
parts["armFarFore"] = combine(
    "armFarFore",
    Layer("tunic", [tl((25, 48), (34, 56), 5)], seed=24, chip=0.03),
    Layer("steel", [tl((25, 48), (30, 53), 5)], seed=22),
    Layer("orange", [[(31, 53), (39, 52), (40, 59), (32, 60)]], seed=23),
)
parts["armNearUpper"] = combine("armNearUpper", Layer("tunic", [tl((51, 38), (55, 49), 7)], seed=17, chip=0.03))
parts["armNearFore"] = combine(
    "armNearFore",
    Layer("tunic", [tl((55, 49), (44, 53), 6)], seed=16, chip=0.03),
    Layer("steel", [tl((55, 49), (49, 52), 6)], seed=18),
    Layer("orange", [[(38, 50), (46, 50), (47, 57), (39, 58)]], seed=19),
)

# ------------------------------------------------------------------ sword, point resting on the ground
TIP, HILT = (5, 94), (36, 59)
_dx, _dy = HILT[0] - TIP[0], HILT[1] - TIP[1]
_len = math.hypot(_dx, _dy)
_ux, _uy = _dx / _len, _dy / _len
_nx, _ny = -_uy, _ux


def along(t, off):
    return (TIP[0] + _dx * t + _nx * off, TIP[1] + _dy * t + _ny * off)


def sword_extra(im):
    # central fuller (groove) and bright edge
    for i in range(0, 60):
        t = 0.12 + 0.78 * i / 59
        x, y = along(t, 0)
        if 0 <= round(x) < W and 0 <= round(y) < H:
            im.putpixel((round(x), round(y)), RAMPS["steel"][1])
        x, y = along(t, -2.1)
        if 0 <= round(x) < W and 0 <= round(y) < H and im.getpixel((round(x), round(y)))[3]:
            im.putpixel((round(x), round(y)), RAMPS["steel"][4])
    # grip wrap
    for k in range(5):
        x, y = HILT[0] + _ux * (1 + k * 1.6), HILT[1] + _uy * (1 + k * 1.6)
        for off in (-1, 0, 1):
            px_, py_ = round(x + _nx * off), round(y + _ny * off)
            if 0 <= px_ < W and 0 <= py_ < H:
                im.putpixel((px_, py_), RAMPS["dark"][2] if k % 2 else RAMPS["red"][2])


blade = [along(0.0, 0), along(0.18, 2.2), along(0.55, 3.0), along(1.0, 3.4),
         along(1.0, -3.4), along(0.55, -3.0), along(0.18, -2.2)]
nicks = [[along(t, -2.9), along(t + 0.045, -2.9), along(t + 0.02, -5.3)] for t in (0.42, 0.58, 0.74)]
guard = [tl(along(1.0, -9), along(1.0, 9), 3.2), disc(*along(1.0, -9), 2.2), disc(*along(1.0, 9), 2.2)]
pommel = disc(HILT[0] + _ux * 10, HILT[1] + _uy * 10, 2.6)
parts["sword"] = combine(
    "sword",
    Layer("steel", [blade] + nicks, seed=29, grit=0.05),
    Layer("gold", guard + [pommel], seed=31),
    extra=sword_extra,
)

# ------------------------------------------------------------------ cape hanging from the back + neat collar
def cape_extra(im):
    for fx in (28, 34, 51, 56):                               # vertical folds
        for y in range(44, 86):
            if im.getpixel((fx, y))[3] and im.getpixel((fx, y - 1))[3] and (y % 7):
                im.putpixel((fx, y), RAMPS["cape"][1])
    for x in range(W):                                        # hem trim
        for y in range(78, 90):
            if im.getpixel((x, y))[3] and not im.getpixel((x, y + 1))[3] and y > 80:
                put(im, [(x, y - 1)], RAMPS["gold"][2])


parts["cape"] = combine(
    "cape",
    Layer("cape", [[(30, 28), (52, 28), (57, 40), (61, 62), (62, 83), (58, 87), (51, 84), (46, 88), (38, 85),
                    (31, 88), (26, 84), (22, 86), (21, 62), (25, 40)]], seed=37, grit=0.06),
    extra=cape_extra,
)
parts["cloak"] = combine(
    "cloak",
    Layer("cape", [[(30, 27), (47, 27), (50, 34), (44, 36), (33, 36), (27, 34)]], seed=38, grit=0.05),
    extra=lambda im: [put(im, [(x, 35)], RAMPS["gold"][2]) for x in range(29, 49) if im.getpixel((x, 35))[3]],
)
parts["pauldronFar"] = combine(
    "pauldronFar",
    Layer("steel", [[(24, 29), (32, 29), (34, 36), (29, 41), (23, 37)],
                    [(26, 24), (29, 30), (24, 31)]], seed=41, chip=0.05),
)
parts["pauldronNear"] = combine(
    "pauldronNear",
    Layer("steel", [[(43, 28), (53, 28), (58, 33), (58, 40), (54, 44), (47, 43), (44, 37)],
                    [(52, 23), (55, 30), (50, 30)]], seed=42, chip=0.05),
    extra=lambda im: put(im, [(49, 32), (54, 34), (54, 40)], RAMPS["gold"][3]),
)

# ------------------------------------------------------------------ head: bare, gaunt, turned to the left
head_layer = Layer(
    "ash",
    [[(35, 7), (44, 7), (48, 10), (49, 16), (48, 22), (44, 27), (41, 31), (36, 31), (34, 27), (31, 22), (30, 16), (32, 10)],
     [(35, 30), (43, 30), (44, 38), (34, 38)]],
    seed=43, grit=0.1,
)


def head_extra(im):
    band = Image.new("L", (W, H), 0)
    bd = ImageDraw.Draw(band)
    bd.polygon([(31, 16), (35, 16), (36, 20), (35, 22), (31, 22), (30, 19)], fill=255)      # far eye socket
    bd.polygon([(37, 16), (43, 16), (44, 20), (43, 22), (37, 22), (36, 19)], fill=255)      # near eye socket
    for y in range(H):
        for x in range(W):
            if band.getpixel((x, y)) and im.getpixel((x, y))[3]:
                im.putpixel((x, y), VOID)
    put(im, [(34, 23), (34, 24)], RAMPS["ash"][1])                      # nose shadow
    put(im, [(33, 27), (34, 27), (35, 27), (36, 27), (37, 27)], RAMPS["ash"][0])   # mouth
    put(im, [(47, 22), (47, 23), (46, 24)], RAMPS["ash"][1])            # hollow cheek


parts["head"] = combine("head", head_layer, extra=head_extra)


def eyes(name, kind):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shapes = {
        "open": [(32, 17), (33, 18), (34, 19), (38, 19), (39, 19), (40, 18), (41, 18), (42, 17)],
        "half": [(33, 18), (34, 19), (39, 19), (40, 19), (41, 18)],
        "closed": [(32, 19), (33, 19), (34, 19), (38, 19), (39, 19), (40, 19)],
    }[kind]
    put(img, shapes, CRIMSON_DARK if kind == "closed" else CRIMSON)
    img.save(os.path.join(OUT, name + ".png"))


def mood_eyes(name, pixels, color, dark_pixels=()):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    put(img, dark_pixels, CRIMSON_DARK)
    put(img, pixels, color)
    img.save(os.path.join(OUT, name + ".png"))


BRIGHT = rgb("ff4a4a")
mood_eyes("eyes_wide",
          [(32, 16), (33, 16), (32, 17), (33, 17), (32, 18), (33, 18), (32, 19), (33, 19),
           (39, 15), (40, 15), (39, 16), (40, 16), (39, 17), (40, 17), (39, 18), (40, 18), (39, 19), (40, 19)],
          rgb("e0152e"), [(31, 17), (31, 18), (34, 17), (34, 18), (38, 16), (38, 17), (38, 18), (41, 16), (41, 17), (41, 18)])
mood_eyes_extra = Image.open(os.path.join(OUT, "eyes_wide.png"))
for xy in ((32, 17), (39, 16)):
    mood_eyes_extra.putpixel(xy, rgb("ff7a7a"))
mood_eyes_extra.save(os.path.join(OUT, "eyes_wide.png"))
mood_eyes("eyes_angry",
          [(31, 15), (32, 16), (33, 17), (34, 18), (35, 19), (36, 19),
           (37, 19), (38, 19), (39, 18), (40, 17), (41, 16), (42, 15), (43, 15)],
          BRIGHT, [(31, 16), (32, 17), (33, 18), (34, 19), (38, 18), (39, 17), (40, 16), (41, 15)])
mood_eyes("eyes_happy",
          [(32, 19), (33, 18), (34, 18), (35, 19), (38, 19), (39, 18), (40, 18), (41, 18), (42, 19)],
          rgb("ff8d8d"))

eyes("eyes_open", "open")
eyes("eyes_half", "half")
eyes("eyes_closed", "closed")

# ------------------------------------------------------------------ ground shadow
shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
for y in range(91, 96):
    for x in range(2, 70):
        dx, dy = (x - 38) / 33.0, (y - 93.5) / 2.2
        if dx * dx + dy * dy <= 1:
            shadow.putpixel((x, y), (0, 0, 0, 100))
shadow.save(os.path.join(OUT, "shadow.png"))

if __name__ == "__main__":
    # ------------------------------------------------------------------ preview
    order = ["cape", "thighL", "shinL", "thighR", "shinR", "footL", "footR", "sash", "tunic", "pauldronFar", "armFarUpper", "armFarFore", "cloak", "pauldronNear", "head", "sword", "armNearUpper", "armNearFore"]
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    canvas.alpha_composite(shadow)
    for n in order:
        canvas.alpha_composite(parts[n])
    canvas.alpha_composite(Image.open(os.path.join(OUT, "eyes_open.png")))
    scale = 6
    bg = Image.new("RGBA", (W * scale + 40, H * scale + 40), rgb("d9dce3"))
    bg.alpha_composite(canvas.resize((W * scale, H * scale), Image.NEAREST), (20, 20))
    preview = sys.argv[1] if len(sys.argv) > 1 else os.path.join(OUT, "..", "..", "previews", "preview.png")
    os.makedirs(os.path.dirname(preview), exist_ok=True)
    bg.save(preview)
    print("ok")
