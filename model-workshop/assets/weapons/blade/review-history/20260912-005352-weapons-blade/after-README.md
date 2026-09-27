# Blade — crude-realism rebuild

This asset is a compact, one-handed full-tang utility/fighting knife built with economical early-2000s real-time geometry. It must read as a practical manufactured tool: hand-scale rubber grip scales, restrained guard, thin steel blade, exposed fasteners, and a low-profile lanyard opening. Catalogue attack reach is gameplay data, not physical knife length.

## Direction correction recorded before rebuild

The saved pre-rebuild renders show an implausibly broad spear-point blade, a short and swollen grip, an oversized guard, and a snag-prone exposed pommel loop. The 286 mm blade is roughly 75 mm wide and the 118 mm grip roughly 54 mm wide. The separate edge strip incorrectly enlarges the blade silhouette instead of describing a ground bevel. Nearly all exported finishes also appear pale grey, so material names and shader settings are not evidence of visible separation.

This revision therefore targets a 125–135 mm usable grip with a 32–38 mm width, a roughly 40–50 mm wide utilitarian drop/clip-point blade, a guard no larger than needed for index-finger protection, and a lanyard hole integrated into a low-profile exposed tang extension. The grip must read dark and matte, fittings blackened, the blade metallic, and the cutting bevel modestly brighter under neutral lighting. These are rebuild targets, not claims about the current export. Measured facts and actual post-export visual findings are recorded only after the build and clean-import review.

## Catalogue context

- Catalogue id: `blade`
- Purpose: the blade — quick and forgiving, but you have to be close enough to be hit back
- Class: melee; damage: 38; gameplay reach: 1.3 m; windup: 0.22 s; commit: 0.28 s; arc: 70 degrees; cycle: 0.55 s
- Gameplay values remain integration data and do not directly set mesh dimensions.

## Production facts

- Built and exported with Blender 4.4.3. Clean GLB envelope: 0.4270 m long × 0.0479 m wide × 0.0270 m thick. The 1.3 m catalogue value remains gameplay attack reach, not physical length.
- Source measurements: each contoured grip scale is 0.125 m long × 0.036 m wide × 0.010 m thick; the blade body is approximately 0.270 m long with 0.006 m maximum stock thickness; the complete blade silhouette is 0.044 m wide; the compact guard is 0.0478 m wide; the integrated lanyard eye is 0.030 m across with a real opening.
- Clean GLB import: 584 triangles across 10 mesh objects, 4 materials, and 0 degenerate polygons. This is below the 4,500-triangle and 12-material ceilings. The saved source audit found 0 non-manifold edges, no negative mesh scales, and no missing material assignments.
- `metrics.json` `passed: true` records these technical validation checks and required-node presence only. It is not independent visual approval.
- The fresh oblique and plan renders were opened after clean GLB import. They show a dark matte grip, darker blackened tang/guard, blue-grey satin blade body, and a restrained brighter ground edge. The narrower drop/clip-point silhouette, longer usable grip, reduced guard, and low-profile tang eye read as a practical one-handed knife rather than the prior broad spear-point. Supervisor-side independent render approval remains outstanding.
- Useful separate parts: primary blade body, ground cutting bevel, ricasso, full tang, upper and lower grip scales, two grip pins, compact guard, and integrated lanyard eye.
- Integration hierarchy: `WEAPON_BLADE` root with `ATTACH_GRIP` at the hand centre, `ATTACH_BLADE` at the guard/blade junction, and `ATTACH_TIP` at the physical point.
- Blender source is Z-up. The knife points along local/world +X. The exported GLB is Y-up and retains +X as the forward/tip direction.
- The source rests horizontally with its lowest grip surface at Z = 0.001 m. Normals are recalculated outward before save/export.

## Rebuild

From the repository root:

```text
"C:\Program Files\Blender Foundation\Blender 4.4\blender.exe" --background --python model-workshop/assets/weapons/blade/build.py
```

The script uses Blender's bundled Python only and deterministically regenerates `source.blend` and `model.glb`.

## Integration notes

Static art only. Melee timing, arc, damage, recovery, collision, and animation remain gameplay/integration responsibilities. No attack animation or gameplay collision shape is included. Preserve the named root, separate constructed parts, and attachment markers during integration.
