"""Convert 6 cubemap face PNGs to a single equirectangular panorama."""
import numpy as np
from PIL import Image

FACE_DIR = "game/skybox"
OUT_PATH = "game/skybox/panorama.png"
OUT_W    = 4096
OUT_H    = 2048

def load_face(name):
    return np.array(Image.open(f"{FACE_DIR}/{name}").convert("RGB"), dtype=np.float32) / 255.0

ft = load_face("Installation05_01ft.png")
bk = load_face("Installation05_01bk.png")
lf = load_face("Installation05_01lf.png")
rt = load_face("Installation05_01rt.png")
up = load_face("Installation05_01up.png")
dn = load_face("Installation05_01dn.png")
FS = ft.shape[0]

# Build direction grid
xs = np.linspace(0, 1, OUT_W, endpoint=False)
ys = np.linspace(0, 1, OUT_H, endpoint=False)
xx, yy = np.meshgrid(xs, ys)

lon = xx * 2.0 * np.pi - np.pi   # -pi .. pi
lat = yy * np.pi - np.pi * 0.5   # -pi/2 .. pi/2

dx =  np.cos(lat) * np.sin(lon)
dy =  np.sin(lat)
dz = -np.cos(lat) * np.cos(lon)

ax, ay, az = np.abs(dx), np.abs(dy), np.abs(dz)

def sample(face, u, v):
    px = np.clip((u * FS).astype(np.int32), 0, FS - 1)
    py = np.clip((v * FS).astype(np.int32), 0, FS - 1)
    return face[py, px]

out = np.zeros((OUT_H, OUT_W, 3), dtype=np.float32)

# +X right face
m = (ax >= ay) & (ax >= az) & (dx > 0)
u = np.where(m, -dz / np.where(ax > 0, ax, 1) * 0.5 + 0.5, 0)
v = np.where(m, -dy / np.where(ax > 0, ax, 1) * 0.5 + 0.5, 0)
out[m] = sample(lf, u, v)[m]

# -X left face
m = (ax >= ay) & (ax >= az) & (dx <= 0)
u = np.where(m,  dz / np.where(ax > 0, ax, 1) * 0.5 + 0.5, 0)
v = np.where(m, -dy / np.where(ax > 0, ax, 1) * 0.5 + 0.5, 0)
out[m] = sample(rt, u, v)[m]

# +Y up face — with rotation applied (CCW, matching shader fix)
m = (~((ax >= ay) & (ax >= az))) & (ay >= az) & (dy > 0)
u = np.where(m, -dz / np.where(ay > 0, ay, 1) * 0.5 + 0.5, 0)
v = np.where(m,  dx / np.where(ay > 0, ay, 1) * 0.5 + 0.5, 0)
out[m] = sample(up, u, v)[m]

# -Y down face
m = (~((ax >= ay) & (ax >= az))) & (ay >= az) & (dy <= 0)
u = np.where(m,  dx / np.where(ay > 0, ay, 1) * 0.5 + 0.5, 0)
v = np.where(m, -dz / np.where(ay > 0, ay, 1) * 0.5 + 0.5, 0)
out[m] = sample(dn, u, v)[m]

# -Z front face
m = (~((ax >= ay) & (ax >= az))) & (~((~((ax >= ay) & (ax >= az))) & (ay >= az))) & (dz < 0)
u = np.where(m,  dx / np.where(az > 0, az, 1) * 0.5 + 0.5, 0)
v = np.where(m, -dy / np.where(az > 0, az, 1) * 0.5 + 0.5, 0)
out[m] = sample(ft, u, v)[m]

# +Z back face
m = (~((ax >= ay) & (ax >= az))) & (~((~((ax >= ay) & (ax >= az))) & (ay >= az))) & (dz >= 0)
u = np.where(m, -dx / np.where(az > 0, az, 1) * 0.5 + 0.5, 0)
v = np.where(m, -dy / np.where(az > 0, az, 1) * 0.5 + 0.5, 0)
out[m] = sample(bk, u, v)[m]

result = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8))
result.save(OUT_PATH)
print(f"Saved {OUT_PATH} ({OUT_W}x{OUT_H})")
