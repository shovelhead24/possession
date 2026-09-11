# Blade

Finished low-poly melee weapon for Possession. The design is an original one-handed close-range military cleaver: a broad faceted single edge, short tapered spine reinforcement, swept bronze hand guard, and compact dark rubber grip. The restrained industrial palette, economical detail, and broad face breaks follow Halo CE-era readability while keeping the silhouette distinct from a spear or two-handed sword.

## Production facts

- Catalogue id: `blade`; purpose: quick and forgiving, but the wielder must be close enough to be hit back. Reach reference: 1.3 m; damage: 38; cycle: 0.55 s.
- Clean GLB import envelope: 1.2975 m long x 0.4424 m wide x 0.1899 m high. The mesh runs from X -0.2975 m at the pommel to X +1.0 m at the blade tip, directly within the 1.3 m gameplay reach.
- Blender source uses Z-up. The weapon points along local/world +X in source and exported GLB. GLB export is Y-up; preserve +X as forward gameplay direction.
- Source placement is a stable horizontal display pose with the grip centre at Z 0.18 m. `WEAPON_BLADE` is the integration root; the pommel is the negative-X end and the cutting tip is positive-X.
- Useful separate parts: grip core, three grip ribs, pommel cap/tip, swept guard and central block, blade assembly, blade collar, and tapered spine rail.
- Attachment markers: `ATTACH_GRIP`, `ATTACH_MUZZLE` (forward blade-tip direction), and `ATTACH_BLADE`.
- Materials: 5. Clean GLB import measures 1,000 triangles across 12 mesh objects, below the 4,500-triangle weapon ceiling; validation found no degenerate polygons.

## Rebuild

From the repository root:

```text
"C:\Program Files\Blender Foundation\Blender 4.4\blender.exe" --background --python model-workshop/assets/weapons/blade/build.py
```

This deterministically regenerates `source.blend` and `model.glb` using Blender's bundled Python only.

## Integration notes

Static art only. Melee timing, arc, damage, and recovery remain catalogue/gameplay responsibilities. No animation is included; keep the named empties available for grip and blade attachment placement.
