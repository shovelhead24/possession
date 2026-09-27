# Weapons — Club

Finished low-poly crowd-control club for Possession. The original design uses a rubber two-hand grip, indexed ferrules, a long forward-biased striking body, replaceable sweep rail, clipped crown shoe, and rear balance spine. Broad deliberate facets, restrained military olive/gunmetal, bright worn steel, and one safety-colour break follow Halo CE-era visual principles while keeping the silhouette clearly club-like.

Catalogue intent: the club is slow and heavy, sweeps a crowd, and the swing owns the wielder once it starts (`damage 62`, `reach 1.5 m`, `windup 0.58 s`, `commit 0.85 s`, `arc 120°`).

Evaluated dimensions are 0.710 m wide × 0.450 m deep × 2.011 m overall, including the pommel. Functional reach from the operative rear-hand marker to the crown is 1.499 m, matching the catalogue's 1.5 m reach. These values are regenerated in `metrics.json` and embedded on `CLUB_ROOT`, eliminating hand-maintained scale metadata. Blender source is Z-up with the pommel grounded exactly at Z=0. The broad striking side points +X; after Y-up GLB export, +X remains the strike direction and the long axis becomes +Y. The meaningful origin is `CLUB_ROOT` at floor/pommel contact.

Named markers: `marker_grip_rear` is the operative hand, `marker_grip_lead` is the second hand, `marker_strike` identifies the broad +X contact rail, and `marker_sweep_pivot` shares the rear-hand axis for the committed sweep. Geometry is separated into grip ribs, collars, weighted shell, sweep-rail plates, crown shoe, wear gauge, rear spine, inset, and fasteners so useful damage or animation variants remain possible.

Triangle count and materials are written to `metrics.json` by the build. The asset uses 6 materials and is budgeted below the 4,500-triangle weapon ceiling. No gameplay or animation integration is included beyond the attachment markers.

Rebuild from this directory with:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 4.4\blender.exe' --background --python build.py
```
