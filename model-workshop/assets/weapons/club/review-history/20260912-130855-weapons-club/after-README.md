# Weapons — Club

This asset is a crude-realistic, two-handed industrial club: a human-scaled rubber grip and steel haft carry a dark, forward-weighted striking body with a single continuous replaceable impact rail. The form reads as a practical manufactured crowd-sweeping club at gameplay distance, not as a mace, hammer, oversized tool, or toy. Broad low-poly surfaces are retained only where they describe believable fabrication; edge breaks, fasteners, paint wear, and material contrast serve construction and use.

This direction replaces the previous README because its claimed `2.011 m` overall length and `1.499 m functional reach` incorrectly treated catalogue attack reach as a mesh dimension. That assumption produced the visibly bulbous pale mace head, compact grip, oversized facets, and peripheral impact hardware seen in the archived review images. Catalogue reach (`1.5 m`) includes the wielder and attack motion and is gameplay metadata, not physical model length. The measured mesh dimensions and production facts below describe the completed rebuild.

Catalogue intent: the club is slow and heavy, sweeps a crowd, and commits the wielder once the swing begins (`damage 62`, `reach 1.5 m`, `windup 0.58 s`, `commit 0.85 s`, `arc 120°`). These values inform weight distribution and silhouette only.

## Exported facts

The rebuilt evaluated mesh measures **0.154 m wide × 0.132 m deep × 1.287 m overall**. Its physical length is recorded separately from the catalogue's 1.5 m gameplay reach. The pommel is grounded at Z=0 and the maximum source height is Z=1.287 m.

The exported asset is **1,444 triangles across 17 closed mesh parts** and uses **5 materials**, below the 4,500-triangle and 12-material weapon ceilings. The deterministic build reports zero non-manifold edges and zero degenerate faces after evaluating bevel modifiers. Generated `metrics.json` is the machine-readable source for these facts.

Blender source is Z-up. The club stands along +Z with its pommel at Z=0; +X is the primary striking direction. Godot-compatible GLB export converts to Y-up while preserving +X as the striking direction. `CLUB_ROOT` is at the pommel contact point.

Named markers are `marker_grip_rear`, `marker_grip_lead`, `marker_strike`, and `marker_sweep_pivot`. Separate construction includes rear and lead grip sleeves, index band, pommel, haft, socket, weighted shell, continuous impact rail, rail clamps/through-bolts, and crown cap so useful attachment, damage, or animation variants remain possible.

The weapon ceiling is 4,500 triangles and 12 materials. No gameplay or animation integration is included beyond attachment markers.

Rebuild from this directory with:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 4.4\blender.exe' --background --python build.py
```
