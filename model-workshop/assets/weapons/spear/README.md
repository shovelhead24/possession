# Spear

Finished low-poly weapon asset for Possession. This revision targets crude realism: a practical, human-scaled thrusting spear with a slim ash haft, a modest plain leather hand area, a socketed forged-steel leaf head, and a small steel butt shoe. Early-2000s economy comes from the mesh and restrained material treatment, not exaggerated proportions or decorative faceting.

## Direction correction recorded before rebuild

The previous README incorrectly tied the physical mesh length to the 2.6 m gameplay reach and described its thick metal shaft, oversized bright collars, and raised helical grip as desirable silhouette features. The saved review side view reads as a short toy-like fantasy staff; the paired angled image already shows a different ash-haft revision, so those two images cannot be treated as one coherent validation set. Gameplay reach includes the wielder's arm and attack motion, so it is recorded only as catalogue data. The rebuild uses independently plausible spear dimensions, slim practical joints, subdued materials, and a low-profile grip. "Stitched leather" was also removed because the mesh has no visible seam: documentation must describe visible construction rather than invent detail.

## Production facts

- Catalogue id: `spear`; melee damage: 55; gameplay reach reference: 2.6 m (not mesh length).
- Exported envelope after clean GLB re-import: 2.1200 m long x 0.1020 m wide x 0.0495 m high, with bounds X -1.0450 to 1.0750 m and Z 0.0000 to 0.0495 m in the authored horizontal pose. The 2.6 m gameplay reach remains deliberately independent.
- Blender source uses Z-up. The weapon points along local/world +X in the source and exported GLB. GLB export is Y-up; preserve +X as the forward gameplay direction.
- Source placement is a horizontal display pose with the low face of the head socket on Z=0. `WEAPON_SPEAR` is the integration origin; the butt shoe is the negative-X end.
- Useful separate parts: `Haft_Ash`, `Grip_Leather_Sleeve`, front/rear grip bindings, `Head_Socket`, `Head_Rivet`, `Spearhead_Blade`, `Butt_Shoe`, and `Butt_Shoe_Rim`. The fitted sleeve, socket, and butt shoe intentionally overlap the haft; other components meet without purposeless hidden geometry.
- Attachment markers: `ATTACH_GRIP`, `ATTACH_TIP`, and `ATTACH_SPEARHEAD`. `ATTACH_MUZZLE` is retained as a compatibility alias at the tip even though this is a melee weapon.
- Exported triangle count: 472 of the 4,500-triangle weapon ceiling.
- Authored/exported material count: 6 of the 12-material ceiling.
- Validation: an independent clean GLB re-import confirmed the stated bounds, 472 triangles, six materials, all nine named mesh parts, root and four attachment empties, positive closed volumes, outward winding, no degenerate faces, and no non-manifold topology after welding glTF's expected hard-normal/material vertex splits.

## Rebuild

From the repository root:

```text
"C:\Program Files\Blender Foundation\Blender 4.4\blender.exe" --background --python model-workshop/assets/weapons/spear/build.py
```

This deterministically regenerates `source.blend`, `model.glb`, and neutral-light review renders using Blender's bundled Python with no downloads or third-party modules.

## Integration notes

The asset is static art only. Thrust timing, 25-degree attack arc, 55 damage, 0.70 s commitment, and recovery remain catalogue/gameplay responsibilities. Use the named empties for grip placement, thrust direction, and spearhead attachment. No animation is included.
