# Weapons — Club

This asset was rebuilt toward a crude-realistic, two-handed industrial club. It must not be accepted as a completed practical club unless independent rendered review confirms all three essentials without relying on this description: an obvious structural load path from haft deep into the head, one recognizable continuous striking edge, and two visible human-scale grip zones with strong material separation. The head should read as a compact mass made to hit with, not a strapped housing, paddle, sign, or pale plastic shell.

This direction replaces earlier misleading guidance twice over. The first version treated catalogue reach as mesh length and produced a bulbous mace; the next version correctly shortened the mesh but still called a pale housing-like head, weak exposed neck, and unclear rail a finished club. The correction was made before rebuilding so those claims could not rationalize the rejected silhouette. Catalogue reach (`1.5 m`) includes the wielder and attack motion and is gameplay metadata, not physical model length.

Catalogue intent: the club is slow and heavy, sweeps a crowd, and commits the wielder once the swing begins (`damage 62`, `reach 1.5 m`, `windup 0.58 s`, `commit 0.85 s`, `arc 120°`). These values inform weight distribution and silhouette only.

## Exported facts

The evaluated mesh measures **0.202 m wide × 0.140 m deep × 1.190 m overall**. Its physical overall length is distinct from the catalogue's **1.5 m gameplay reach**. The pommel is grounded at source Z=0 and the maximum source height is Z=1.190 m.

The export contains **2,372 triangles across 25 closed mesh parts** and uses **5 materials**, below the 4,500-triangle and 12-material ceilings. All evaluated parts have positive signed volume; the audit found zero non-manifold edges and zero degenerate faces.

The construction retains separate pommel, two rubber grip sleeves and wrap ridges, ferrules, full-tang steel haft, reinforced socket, painted forged head mass, twin external structural spine plates, continuous impact rail, two retaining bolts, and crown cap. The haft intentionally overlaps the socket and head internally as a load-bearing tang; this is functional reinforcement rather than unused hidden geometry. Dark rubber, blackened steel, oxide-painted steel, fastener steel, and the brighter exposed impact surface are separate materials.

Blender source is Z-up. The club stands along +Z with its pommel at Z=0; +X is the primary striking direction. Godot-compatible GLB export converts to Y-up while preserving +X as the striking direction. `CLUB_ROOT` is at the pommel contact point.

Named markers are `marker_grip_rear`, `marker_grip_lead`, `marker_strike`, and `marker_sweep_pivot`. A clean Blender re-import of the actual GLB verified all four as exported empty nodes. Grip and pivot local +Z follow the haft; strike local +Z points outward along source +X. Their re-imported transforms are recorded in `metrics.json`.

The weapon ceiling is 4,500 triangles and 12 materials. No gameplay or animation integration is included beyond attachment markers.

Rebuild from this directory with:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 4.4\blender.exe' --background --python build.py
```
