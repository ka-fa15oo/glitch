"""previews/phoenix/ai_sheet.jpg (Canva AI pose sheet, 3/4 view) -> pixel-art phoenix frames in Glitch/Sprites:
phoenix_flap1..6 (one wing beat), phoenix_glide, phoenix_hover and phoenix_perch (the rock under it removed).

The sheet is shrunk to art pixels, each pose is cut out by its connected pixels, mirrored to face left like the other
characters, and placed so its beak tip sits on a fixed point of the window canvas (112x124 art px = Sprite 72x96 plus
RobotView padding), which keeps the head steady from frame to frame. Run from the repo root;
`python3 Tools/make_phoenix.py <dir>` writes elsewhere."""
import sys
from collections import deque
from PIL import Image, ImageEnhance

SRC = "previews/phoenix/ai_sheet.jpg"
OUT = sys.argv[1] if len(sys.argv) > 1 else "Glitch/Sprites"
SHRINK, COLORS = 5, 40  # source px per art px, palette size
CANVAS = (112, 124)
FLIGHT_BEAK = (34, 40)  # canvas px, the beak tip of every airborne pose

# pose: (beak tip in sheet px, where that beak goes on the canvas)
POSES = {
    "flap1": ((322, 232), FLIGHT_BEAK),
    "flap2": ((572, 240), FLIGHT_BEAK),
    "flap3": ((822, 243), FLIGHT_BEAK),
    "flap4": ((1068, 242), FLIGHT_BEAK),
    "flap5": ((1300, 248), FLIGHT_BEAK),
    "flap6": ((1505, 238), FLIGHT_BEAK),
    "glide": ((418, 670), FLIGHT_BEAK),
    "hover": ((880, 615), FLIGHT_BEAK),
    "perch": ((1283, 640), (34, 60)),   # feet just above the canvas ground (y 107), the tail hanging past them
}

sheet = Image.open(SRC).convert("RGB")
sw, sh = sheet.size
bg = sheet.getpixel((5, 5))
sp = sheet.load()


def is_rock(p):  # the brown rock under the perched bird: dull, with red barely above green
    return p[0] - p[1] < 35 and p[0] < 150 and max(abs(p[i] - bg[i]) for i in range(3)) > 28


# drop the backdrop and the rock in the full-size sheet, then shrink, so edges average to the bird only
alpha = Image.new("L", (sw, sh), 0)
ap = alpha.load()
for y in range(sh):
    for x in range(sw):
        p = sp[x, y]
        if max(abs(p[i] - bg[i]) for i in range(3)) > 28 and not (y > 780 and x > 1100 and is_rock(p)):
            ap[x, y] = 255
rgba = sheet.convert("RGBA")
rgba.putalpha(alpha)
small = rgba.resize((sw // SHRINK, sh // SHRINK), Image.BOX)
w, h = small.size

# hard alpha, livelier colours, one shared palette so no frame shifts colour
a = small.getchannel("A").point(lambda v: 255 if v >= 120 else 0)
rgb = ImageEnhance.Color(ImageEnhance.Contrast(small.convert("RGB")).enhance(1.15)).enhance(1.2)
art = rgb.quantize(COLORS, Image.MEDIANCUT, dither=Image.NONE).convert("RGBA")
art.putalpha(a)
pp = art.load()

# connected pieces (8-neighbour), each pose keeps the pieces whose pixels lie closest to its own beak
label = [[-1] * h for _ in range(w)]
pieces = []
for x0 in range(w):
    for y0 in range(h):
        if pp[x0, y0][3] and label[x0][y0] < 0:
            q, piece = deque([(x0, y0)]), []
            label[x0][y0] = len(pieces)
            while q:
                x, y = q.popleft()
                piece.append((x, y))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and pp[nx, ny][3] and label[nx][ny] < 0:
                            label[nx][ny] = len(pieces)
                            q.append((nx, ny))
            pieces.append(piece)

beaks = {name: (bx / SHRINK, by / SHRINK) for name, ((bx, by), _) in POSES.items()}


def owner(piece):
    cx = sum(p[0] for p in piece) / len(piece)
    cy = sum(p[1] for p in piece) / len(piece)
    # the beak is at the head's right edge, the body lies down and to the left of it
    return min(beaks, key=lambda n: (cx - (beaks[n][0] - 22)) ** 2 + (cy - (beaks[n][1] + 22)) ** 2)


owned = {name: [] for name in POSES}
for piece in pieces:
    if len(piece) >= 12:   # specks and stray ember flecks would land on a neighbour's frame
        owned[owner(piece)].extend(piece)

for name, ((bx, by), (tx, ty)) in POSES.items():
    frame = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    fp = frame.load()
    bx, by = round(bx / SHRINK), round(by / SHRINK)
    for x, y in owned[name]:
        cx, cy = tx - (x - bx), ty + (y - by)   # mirrored: it faces left
        if 0 <= cx < CANVAS[0] and 0 <= cy < CANVAS[1]:
            fp[cx, cy] = pp[x, y]
    frame.save(f"{OUT}/phoenix_{name}.png")
print("canvas", CANVAS, "frames", len(POSES))
