# Spear

Finished low-poly weapon asset for Possession. The original design follows early-console military-fantasy principles: a long blackened-steel shaft, dark leather handhold with a continuous helical wrap, restrained bronze hardware, and a narrow diamond-section leaf blade. Broad facets and the raised central ridge keep the point legible at gameplay distance. Its forward-weighted silhouette communicates the catalogue purpose: hit first from outside their reach; miss and you are wide open.

## Production facts

- Catalogue id: `spear`; melee damage: 55; gameplay reach reference: 2.6 m.
- Exported envelope: 2.6037 m long x 0.3000 m wide x 0.2274 m high.
- Blender source uses Z-up. The weapon points along local/world +X in the source and exported GLB. GLB export is Y-up; preserve +X as the forward gameplay direction.
- Source placement is a stable horizontal display pose with the shaft centre at Z 0.16 m. The `WEAPON_SPEAR` root is the integration origin; the rear pommel is the negative-X end.
- Useful parts remain separate: `Shaft_Main`, `Shaft_Rear_Tang`, `Grip_Core`, `Grip_Wrap_Helix`, grip ferrules, `Head_Collar`, `Head_Collar_Retainer`, `Spearhead_Assembly`, head lugs, butt cap, and pommel.
- Attachment markers: `ATTACH_GRIP`, `ATTACH_MUZZLE` (tip/thrust direction), and `ATTACH_SPEARHEAD`.
- Exported triangle count: 1,280 of the 4,500-triangle weapon ceiling.
- Authored material count: 7 of the 12-material ceiling.
- Validation: exported dimensions/materials/markers checked after clean GLB import; source mesh components have zero non-manifold edges, zero degenerate polygons, and no negative signed volumes.

## Rebuild

From the repository root:

```text
"C:\Program Files\Blender Foundation\Blender 4.4\blender.exe" --background --python model-workshop/assets/weapons/spear/build.py
```

This deterministically regenerates `source.blend` and `model.glb`. It uses Blender's bundled Python and needs no downloads or third-party modules.

## Integration notes

The asset is static art only. Thrust timing, 25-degree attack arc, damage, commitment, and recovery remain catalogue/gameplay responsibilities. Use the named empties for grip placement, thrust direction, and spearhead attachment. No animation is included or required by this workshop asset.
