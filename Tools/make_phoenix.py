"""previews/phoenix/concept.jpg (AI concept) -> pixel-art phoenix frames in Glitch/Sprites:
phoenix_flap1..8 (one wing beat), phoenix_glide (wings held open) and phoenix_perch (wings folded at its sides).

The wings are bent, not just turned: each wing pixel swings round its shoulder by an angle that grows towards the tip,
so the tips trail the stroke like real feathers. Each frame covers the whole window canvas (112x124 art px = Sprite
72x96 plus RobotView padding). Run from the repo root; `python3 Tools/make_phoenix.py <dir>` writes elsewhere."""
import math
import sys
from collections import deque
from PIL import Image, ImageEnhance

SRC = "previews/phoenix/concept.jpg"
OUT = sys.argv[1] if len(sys.argv) > 1 else "Glitch/Sprites"
SPRITE_W, COLORS, UP = 90, 32, 4  # art width, palette size, supersampling of the warp
CANVAS = (112, 124)  # RobotView: 22+72+18 wide, 14+96+14 high
BODY_X, WING_BOTTOM = 17, 112  # concept px: |x - centre| beyond this and above this row is wing
SHOULDER_Y = 78

# (root angle, extra angle at the tip, span, thickness, body bob); degrees, + = wing up
POSES = {
    "flap1": (18, 10, 1.00, 1.00, 2),     # top of the beat
    "flap2": (6, 14, 1.02, 1.00, 1),
    "flap3": (-12, 18, 1.00, 0.96, -1),   # sweeping down, tips trailing up
    "flap4": (-32, 20, 0.92, 0.92, -2),
    "flap5": (-48, 14, 0.84, 0.90, -2),   # bottom of the beat
    "flap6": (-34, -10, 0.80, 0.88, 0),   # pulling back up, tips trailing down
    "flap7": (-14, -20, 0.84, 0.92, 1),
    "flap8": (6, -12, 0.92, 0.96, 2),
    "glide": (-8, 10, 1.04, 1.00, 0),     # held open, tips curling up
    "perch": (-105, -25, 0.68, 0.90, 3),   # folded down along its sides
}

im = Image.open(SRC).convert("RGB")
w, h = im.size
px = im.load()
bg = px[2, 2]


def is_bg(p):  # near the flat dark backdrop
    return max(abs(p[i] - bg[i]) for i in range(3)) < 22


# flood-fill the backdrop from the border so dark outline pixels inside the bird survive
alpha = [[True] * h for _ in range(w)]
q = deque([(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] + [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)])
while q:
    x, y = q.popleft()
    if 0 <= x < w and 0 <= y < h and alpha[x][y] and is_bg(px[x, y]):
        alpha[x][y] = False
        q += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]

xs = [x for x in range(w) for y in range(h) if alpha[x][y]]
ys = [y for x in range(w) for y in range(h) if alpha[x][y]]
left, top, right, bottom = min(xs), min(ys), max(xs) + 1, max(ys) + 1
cx = (left + right) / 2
scale = SPRITE_W / (right - left)  # concept px -> art px, the same for every frame so the body never moves
ox = (CANVAS[0] - SPRITE_W) / 2
oy = (CANVAS[1] - (bottom - top) * scale) / 2


def to_canvas(x, y, bob):
    return (ox + (x - left) * scale) * UP, (oy + (y - top) * scale + bob) * UP


def render(pose):
    root, tip, span, thick, bob = pose
    big = Image.new("RGBA", (CANVAS[0] * UP, CANVAS[1] * UP), (0, 0, 0, 0))
    bp = big.load()
    W, H = big.size
    step = 1 / (UP * scale * 1.6)  # sample the concept finer than the output grid, so the warp leaves no holes

    def splat(fx, fy, colour):
        X, Y = int(fx), int(fy)
        if 0 <= X < W and 0 <= Y < H:
            bp[X, Y] = colour

    reach = max(cx - left, right - cx)
    for wing in (False, True):  # wings first, the body is drawn over their roots
        n = int((right - left) / step)
        for j in range(int(h / step)):
            sy = j * step
            for i in range(n):
                sx = left + i * step
                ix, iy = int(sx), int(sy)
                if ix >= w or iy >= h or not alpha[ix][iy]:
                    continue
                is_wing = abs(sx - cx) > BODY_X and sy < WING_BOTTOM
                if is_wing != wing:
                    continue
                colour = px[ix, iy] + (255,)
                if not wing:
                    splat(*to_canvas(sx, sy, bob), colour)
                    continue
                side = 1 if sx > cx else -1
                shx = cx + side * BODY_X
                dx, dy = sx - shx, sy - SHOULDER_Y
                r = math.hypot(dx, dy)
                a = math.atan2(dy, dx)
                turn = math.radians(root + tip * min(1, r / reach))
                a2 = a - side * turn
                fx = shx + math.cos(a2) * r * span
                fy = SHOULDER_Y + math.sin(a2) * r * span
                fx = shx + (fx - shx) * (0.5 + 0.5 * thick)  # a thinner wing hugs the body
                splat(*to_canvas(fx, fy, bob), colour)
    return big


def finish(big, palette=None):
    small = big.resize(CANVAS, Image.BOX)
    a = small.getchannel("A").point(lambda v: 255 if v >= 110 else 0)
    rgb = small.convert("RGB")
    rgb = ImageEnhance.Brightness(ImageEnhance.Color(ImageEnhance.Contrast(rgb).enhance(1.25)).enhance(1.35)).enhance(1.25)
    pal = rgb.quantize(COLORS, Image.MEDIANCUT, dither=Image.NONE) if palette is None else rgb.quantize(palette=palette, dither=Image.NONE)
    out = pal.convert("RGBA")
    out.putalpha(a)
    pp = out.load()  # drop stray specks: opaque pixels with fewer than 2 opaque neighbours
    cw, ch = out.size
    specks = [(x, y) for x in range(cw) for y in range(ch) if pp[x, y][3]
              and sum(0 <= x + ex < cw and 0 <= y + ey < ch and pp[x + ex, y + ey][3]
                      for ex in (-1, 0, 1) for ey in (-1, 0, 1) if ex or ey) < 2]
    for p in specks:
        pp[p] = (0, 0, 0, 0)
    return out, pal


_, palette = finish(render(POSES["flap2"]))  # one shared palette, so no frame shifts colour
for name, pose in POSES.items():
    finish(render(pose), palette)[0].save(f"{OUT}/phoenix_{name}.png")
print("canvas", CANVAS, "frames", len(POSES))
