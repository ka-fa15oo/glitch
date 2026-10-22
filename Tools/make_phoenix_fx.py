"""Free CC0 effect animations -> one horizontal strip of square frames each, in Glitch/Sprites:
phoenix_fx_embers (a low fire with smoke, looping), phoenix_fx_column (a column of flame, looping),
and phoenix_fx_burst (flames bursting up off the ground).

Source (CC0, no credit required): "Pixel simulations" by Limofeus (https://limofeus.itch.io/pixel-simulations).
Usage: python3 Tools/make_phoenix_fx.py <PixelSimulations dir> [out dir]"""
import os
import sys
from PIL import Image

LIMOFEUS = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else "Glitch/Sprites"

EFFECTS = {
    "embers": os.path.join(LIMOFEUS, "Flame3[64x64]Loop"),
    "column": os.path.join(LIMOFEUS, "Flame1Loop"),
    "burst": os.path.join(LIMOFEUS, "Explosion1"),
}


def frame_number(name):
    digits = "".join(c for c in os.path.splitext(name)[0].split("_")[-1] if c.isdigit())
    return int(digits)


for name, folder in EFFECTS.items():
    files = sorted((f for f in os.listdir(folder) if f.endswith(".png")), key=frame_number)
    frames = [Image.open(os.path.join(folder, f)).convert("RGBA") for f in files]
    size = frames[0].width
    assert all(f.size == (size, size) for f in frames), name
    strip = Image.new("RGBA", (size * len(frames), size))
    for i, f in enumerate(frames):
        strip.paste(f, (i * size, 0))
    strip.save(os.path.join(OUT, f"phoenix_fx_{name}.png"), optimize=True)
    print(name, len(frames), "frames of", size)
