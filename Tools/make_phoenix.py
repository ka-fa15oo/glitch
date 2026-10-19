"""previews/phoenix/concept.jpg (AI concept) -> pixel-art phoenix, 4 wing-flap frames as Glitch/Sprites/phoenix_flap1..4.png.

Each frame covers the whole window canvas (112x124 art px = Sprite 72x96 plus RobotView padding). Run from the repo root."""
import os
from collections import deque
from PIL import Image, ImageEnhance

SRC, OUT = "previews/phoenix/concept.jpg", "Glitch/Sprites"
SPRITE_W, COLORS = 90, 32
CANVAS = (112, 124)  # RobotView: 22+72+18 wide, 14+96+14 high
BODY_HALF = 13  # columns either side of the centre that stay put (head, torso, tail)
ANGLES = [12, 0, -14, 0]  # right wing, degrees counter-clockwise; the left wing gets the opposite
BOB = [2, 0, -2, 0]

im = Image.open(SRC).convert("RGB")
w, h = im.size
px = im.load()
bg = px[2, 2]


def is_bg(p):  # near the flat dark backdrop
    return max(abs(p[i] - bg[i]) for i in range(3)) < 22


# flood-fill the backdrop from the border so dark outline pixels inside the bird survive
alpha = Image.new("L", (w, h), 255)
ap = alpha.load()
q = deque()
for x in range(w):
    q += [(x, 0), (x, h - 1)]
for y in range(h):
    q += [(0, y), (w - 1, y)]
while q:
    x, y = q.popleft()
    if 0 <= x < w and 0 <= y < h and ap[x, y] == 255 and is_bg(px[x, y]):
        ap[x, y] = 0
        q += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]

rgba = im.copy().convert("RGBA")
rgba.putalpha(alpha)
rgba = rgba.crop(rgba.getbbox())
scale = SPRITE_W / rgba.width
sprite = rgba.resize((SPRITE_W, round(rgba.height * scale)), Image.LANCZOS)

# hard alpha + fixed palette, so every later rotation stays inside the palette
a = sprite.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
rgb = sprite.convert("RGB")
rgb = ImageEnhance.Brightness(ImageEnhance.Color(ImageEnhance.Contrast(rgb).enhance(1.25)).enhance(1.35)).enhance(1.25)
pal = rgb.quantize(COLORS, Image.MEDIANCUT, dither=Image.NONE).convert("RGB").convert("RGBA")
pal.putalpha(a)
sprite = pal
# drop stray specks: opaque pixels with fewer than 2 opaque neighbours
pp = sprite.load()
sprite_w, sprite_h = sprite.size
specks = [(x, y) for x in range(sprite_w) for y in range(sprite_h) if pp[x, y][3]
          and sum(0 <= x + dx < sprite_w and 0 <= y + dy < sprite_h and pp[x + dx, y + dy][3]
                  for dx in (-1, 0, 1) for dy in (-1, 0, 1) if dx or dy) < 2]
for p in specks:
    pp[p] = (0, 0, 0, 0)

sw, sh = sprite.size
cx = sw // 2
pivot_y = round(sh * 0.42)
ox, oy = (CANVAS[0] - sw) // 2, (CANVAS[1] - sh) // 2


cut = round(sh * 0.66)  # below this row (tail, talons) nothing flaps
base = sprite.copy()
for x in range(sw):
    if abs(x - cx) > BODY_HALF:
        for y in range(cut):
            base.putpixel((x, y), (0, 0, 0, 0))


def frame(i):
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    canvas.alpha_composite(base, (ox, oy + BOB[i] + 1))
    # wings: each half, with an overlap into the body band that the body then covers
    for side, ang in ((1, ANGLES[i]), (-1, -ANGLES[i])):
        box = (cx - BODY_HALF, 0, sw, cut) if side == 1 else (0, 0, cx + BODY_HALF, cut)
        wing = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
        wing.paste(sprite.crop(box), (box[0], 0))
        wing = wing.rotate(ang, resample=Image.NEAREST, center=(cx + side * BODY_HALF, pivot_y))
        canvas.alpha_composite(wing, (ox, oy + BOB[i]))
    body = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    body.paste(sprite.crop((cx - BODY_HALF, 0, cx + BODY_HALF, sh)), (cx - BODY_HALF, 0))
    canvas.alpha_composite(body, (ox, oy + BOB[i] + 1))
    return canvas


for i in range(4):
    frame(i).save(f"{OUT}/phoenix_flap{i + 1}.png")
print("sprite", sprite.size, "canvas", CANVAS)
