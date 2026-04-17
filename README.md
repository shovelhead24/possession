# possession
Open and deep system gameplay and procedural rendering for low spec hardware

## Running on the laptop (watch-and-run)

The watcher polls GitHub every 15 seconds, auto-pulls new commits, and relaunches Godot automatically.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\watch-and-run.ps1
```

Run this once from the repo root (`C:\Games\possession`) and leave the window open. Godot will relaunch whenever new code is pushed.

**First-time setup:**
1. Edit the top of `scripts\watch-and-run.ps1` and set `$projectPath` and `$godotExe` to match your machine
2. Copy asset packs into `game\` (see Missing Asset Packs warning on first run)
3. Run the command above

**Shortcuts while running:**
| Key | Action |
|-----|--------|
| `L` | Push the current Godot log to the repo immediately |
| Auto | Log is also pushed every ~5 minutes automatically |

**In-game shortcuts:**
| Key / Button | Action |
|---|---|
| D-pad Up / `R` | Git pull latest commits and reload the scene |
| `F` | Toggle fly mode |
| `Escape` | Release mouse cursor |
| `1`–`7` | Switch biome |
| `F4` | Toggle LOD debug colours (white=LOD0, blue=1, green=2, red=3, yellow=4) |

## Performance architecture

This project targets potato hardware (Intel UHD integrated graphics). Every rendering and placement system uses adaptive strategies to keep draw calls and CPU work proportional to what the player can actually see.

### LOD system
Five LOD levels with distance thresholds (in chunk units, 1 chunk = 100m):

| LOD | Distance | Resolution | Sector scale | Material |
|-----|----------|------------|--------------|----------|
| 0 | 0–300m | 16 (adaptive) | 1× | Full shader + textures |
| 1 | 300–800m | 6 | 1× | Vertex colours, no textures |
| 2 | 800–2km | 3 | 2×2 megatile | Vertex colours |
| 3 | 2–5km | 2 | 4×4 megatile | Vertex colours |
| 4 | 5–10km | 1 | 8×8 megatile | Vertex colours |

### Megatile merging (LOD 2–4)
Distant chunks are combined into single large meshes. LOD2 groups 2×2 chunks into one 200×200m mesh, LOD3 uses 4×4 (400m), LOD4 uses 8×8 (800m). This reduces draw calls from ~19k to ~1.2k at full view distance.

### Adaptive LOD0 resolution
Before generating each close-range chunk, a 5×5 probe grid estimates the terrain height range. Flat chunks (range < 20m) use resolution 12 instead of 16, rolling terrain (< 60m) uses 14. This reduces collision mesh complexity for plains without affecting visual quality on mountains.

### Adaptive prop placement
Trees and grass are only spawned within 800m of the player (`tree_spawn_distance = 8 chunks`). Spawn count scales with a `quality_multiplier` (0.3–1.0) that adjusts each frame based on whether the frame time is within the 60fps budget. Prop instances are recycled via an object pool rather than created and destroyed per chunk.

### Shadow casting
LOD1+ chunks have shadow casting disabled. Coarse-resolution normals at chunk edges cause visible banding seams at low sun angles — shadows from LOD0 geometry are sufficient and correct.
