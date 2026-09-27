# Blade — crude-realism rebuild

This asset is a compact, one-handed full-tang utility/fighting knife built with economical early-2000s real-time geometry. It must read as a practical manufactured tool: hand-scale rubber grip scales, restrained guard, thin steel blade, exposed fasteners, and a low-profile lanyard opening. Catalogue attack reach is gameplay data, not physical knife length.

## Direction correction recorded before rebuild

The archived `before-preview.png` and `before-side.png` in `review-history/20260912-012351-weapons-blade` show a recognizable, physically plausible full-tang knife with a slim point, hand-scale grip, compact guard, and economical construction. Their strongest failure is finish: grip, fittings, blade, and bevel wash into nearly the same pale grey despite the previous README's unsupported claim that their materials were visibly distinct. The modeled grind reads mostly as a narrow line instead of a clear planar wedge, especially in the side view.

This revision therefore preserves the credible proportions and restrained guard, repairs or replaces the evidence-render path so exported materials are respected under neutral lighting, and strengthens the blade's actual planar grind/spine transition. The required target is a decisively dark matte grip, blackened fittings, satin blade body, and brighter ground edge. These are rebuild targets, not claims about the current export. Approval remains pending until new clean-import renders are opened and visibly demonstrate those finishes.

## Catalogue context

- Catalogue id: `blade`
- Purpose: the blade — quick and forgiving, but you have to be close enough to be hit back
- Class: melee; damage: 38; gameplay reach: 1.3 m; windup: 0.22 s; commit: 0.28 s; arc: 70 degrees; cycle: 0.55 s
- Gameplay values remain integration data and do not directly set mesh dimensions.

## Production facts

- Built and exported with Blender 4.4.3. Clean GLB envelope: 0.4130 m long × 0.0479 m wide × 0.0270 m thick. The 1.3 m catalogue value remains gameplay attack reach, not physical length.
- Source measurements: each contoured grip scale is 0.125 m long × 0.036 m wide × 0.010 m thick; the blade body is approximately 0.270 m long with 0.006 m maximum stock thickness; the complete blade silhouette is 0.044 m wide; the compact guard is 0.0478 m wide; the tucked lanyard eye is 0.020 m across with a real 0.007 m opening.
- Clean GLB import: 616 triangles across 11 mesh objects, 4 materials, and 0 degenerate polygons. This is below the 4,500-triangle and 12-material ceilings. The deterministic source audit and welded clean-import topology audit found 0 non-manifold edges, no negative mesh scales, and no missing material assignments. Welding is performed only on a temporary validation copy to discount glTF's flat-shading vertex splits; it does not alter the export.
- `metrics.json` `passed: true` records these technical validation checks and required-node presence only. It is not independent visual approval.
- Prior post-export material review failed: the archived clean-import renders wash all four finishes into similar pale grey and do not support the earlier successful visual claim. The replacement `preview.png` and `side.png` were rendered from a clean re-import of the current GLB and actually opened after export; under neutral lighting they visibly show the dark matte grip, blackened fittings, satin blade body, and brighter ground edge. The widened sloped primary grind and full-stock spine transition are also legible as modeled planes. Supervisor-side independent visual approval remains pending.
- Useful separate parts: full-stock blade spine, sloped primary grind, thin ground cutting bevel, ricasso, full tang, upper and lower grip scales, two grip pins, compact guard, and integrated lanyard eye.
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
