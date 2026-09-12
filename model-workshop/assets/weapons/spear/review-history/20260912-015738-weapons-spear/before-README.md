# Spear

Finished low-poly weapon asset for Possession. This revision targets crude realism: a practical, human-scaled thrusting spear with a slim ash haft, a modest stitched-leather hand area, a socketed forged-steel leaf head, and a small steel butt shoe. Early-2000s economy comes from the mesh and restrained material treatment, not exaggerated proportions or decorative faceting.

## Direction correction recorded before rebuild

The previous README incorrectly tied the physical mesh length to the 2.6 m gameplay reach and described its thick metal shaft, oversized bright collars, and raised helical grip as desirable silhouette features. The saved review views instead read as a short toy-like fantasy staff. Gameplay reach includes the wielder's arm and attack motion, so it is now recorded only as catalogue data. This rebuild uses independently plausible spear dimensions, slimmer practical joints, subdued materials, and a grip that does not resemble wire wound around a handle.

## Production facts

- Catalogue id: `spear`; melee damage: 55; gameplay reach reference: 2.6 m (not mesh length).
- Exported envelope after clean GLB re-import: 2.1200 m long x 0.1020 m wide x 0.0495 m high. The 2.6 m gameplay reach remains deliberately independent.
- Blender source uses Z-up. The weapon points along local/world +X in the source and exported GLB. GLB export is Y-up; preserve +X as the forward gameplay direction.
- Source placement is a stable horizontal display pose. `WEAPON_SPEAR` is the integration origin; the butt shoe is the negative-X end.
- Useful separate parts: `Haft_Ash`, `Grip_Leather_Sleeve`, front/rear grip bindings, `Head_Socket`, `Head_Rivet`, `Spearhead_Blade`, `Butt_Shoe`, and `Butt_Shoe_Rim`. The fitted sleeve, socket, and butt shoe intentionally overlap the haft; other components meet without purposeless hidden geometry.
- Attachment markers: `ATTACH_GRIP`, `ATTACH_TIP`, and `ATTACH_SPEARHEAD`. `ATTACH_MUZZLE` is retained as a compatibility alias at the tip even though this is a melee weapon.
- Exported triangle count: 472 of the 4,500-triangle weapon ceiling.
- Authored/exported material count: 6 of the 12-material ceiling.
- Validation: clean GLB re-import confirmed the stated dimensions, all nine named mesh parts, root and four attachment empties, positive closed volumes, outward normals, no degenerate faces, and no non-manifold topology after welding glTF's expected hard-normal/material vertex splits.

## Rebuild

From the repository root:

```text
"C:\Program Files\Blender Foundation\Blender 4.4\blender.exe" --background --python model-workshop/assets/weapons/spear/build.py
```

This deterministically regenerates `source.blend`, `model.glb`, and neutral-light review renders using Blender's bundled Python with no downloads or third-party modules.

## Integration notes

The asset is static art only. Thrust timing, 25-degree attack arc, 55 damage, 0.70 s commitment, and recovery remain catalogue/gameplay responsibilities. Use the named empties for grip placement, thrust direction, and spearhead attachment. No animation is included.
