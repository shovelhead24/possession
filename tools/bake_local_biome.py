"""Offline local biome colour controls; no runtime generation or source DEM edits."""
from pathlib import Path
import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parents[1] / 'game/assets/terrain/grass-study/biome-mask.png'
rng = np.random.default_rng(251025)
SIZE = 1024  # Covers 3200 metres: colour masks need far less resolution than blades.

def field(cells):
    values = rng.integers(0, 256, (cells, cells), dtype=np.uint8)
    return np.asarray(Image.fromarray(values).resize((SIZE, SIZE), Image.Resampling.BICUBIC), dtype=np.float32) / 255

broad = .65 * field(19) + .35 * field(43)
patch = .65 * field(89) + .35 * field(167)
# R: straw distribution; G: smaller colour/rock-edge variation; B: ground mottling.
fine = .55 * field(257) + .45 * field(613)
pixels = np.stack([broad, patch, fine], axis=-1)
Image.fromarray(np.uint8(np.clip(pixels, 0, 1) * 255)).save(OUT)
print(OUT)
