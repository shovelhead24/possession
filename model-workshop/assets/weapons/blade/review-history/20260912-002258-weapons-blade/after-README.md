# Blade — crude-realism rebuild

This asset is being rebuilt as a believable one-handed military utility/fighting knife: a thin full-tang steel blade, compact guard, human-sized contoured grip scales, exposed fasteners, and a functional lanyard opening. The silhouette and construction should read as a practical manufactured cutting tool under an economical Halo CE-era real-time art budget, without fantasy ornament or toy proportions.

## Direction correction recorded before rebuild

The rejected export was approximately 1.30 m long because its mesh length was incorrectly matched to the catalogue's 1.3 m attack reach. Its broad thick blade, oversized bronze/gold guard, pale segmented grip, and large bevels made it read as a fantasy toy cleaver. Gameplay reach includes the wielder's arm and attack motion; it is not a physical model dimension. This rebuild targets roughly 0.43 m overall with a roughly 0.13 m grip, restrained steel/rubber materials, and practical knife construction. Historical aesthetic approval of the rejected mesh is not carried forward.

The rebuilt files were generated with Blender 4.4.3 and checked by importing `model.glb` into a clean Blender scene.

## Catalogue context

- Catalogue id: `blade`
- Purpose: the blade — quick and forgiving, but you have to be close enough to be hit back
- Class: melee; damage: 38; gameplay reach: 1.3 m; windup: 0.22 s; commit: 0.28 s; arc: 70 degrees; cycle: 0.55 s
- Gameplay values remain integration data and do not directly set mesh dimensions.

## Measured production facts

- Clean GLB envelope: 0.4425 m long × 0.0897 m wide × 0.0270 m thick. The blade itself is approximately 0.286 m long with 0.006 m maximum stock thickness; the contoured grip scales span approximately 0.118 m.
- Clean GLB import: 584 triangles across 10 mesh objects, 4 materials, 0 degenerate polygons, and 0 non-manifold edges after welding import-time vertex splits. This is below the 4,500-triangle and 12-material ceilings.
- Materials: satin carbon steel, brighter ground cutting edge, black-oxide fittings/tang, and charcoal rubber grip scales.
- Useful separate parts: primary blade, cutting bevel, ricasso, full tang, upper and lower grip scales, two grip pins, guard, and pommel lanyard eye. The lanyard eye has an actual open centre.
- Attachment markers: `ATTACH_GRIP` at the hand centre, `ATTACH_BLADE` at the blade/guard junction, and `ATTACH_TIP` at the physical point. `WEAPON_BLADE` is the integration root.
- Blender source is Z-up. The blade points along local/world +X. Exported GLB is Y-up and retains +X as the forward/tip direction.
- The asset rests horizontally with its lowest surface approximately at Z = 0.0005 m, providing stable floor clearance without burying geometry.
- Normals were recalculated outward before export. The clean re-import contained no degenerate or open mesh topology after welding glTF's normal-driven vertex splits.

## Rebuild

From the repository root:

```text
"C:\Program Files\Blender Foundation\Blender 4.4\blender.exe" --background --python model-workshop/assets/weapons/blade/build.py
```

The script uses Blender's bundled Python only and deterministically regenerates `source.blend` and `model.glb`.

## Integration notes

Static art only. Melee timing, arc, damage, recovery, collision, and animation remain gameplay/integration responsibilities. No attack animation or gameplay collision shape is included. Preserve the named root, separate constructed parts, and attachment markers during integration.
