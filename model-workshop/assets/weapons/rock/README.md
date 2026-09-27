# Rock

Finished low-poly thrown rock for Possession. The form is a deliberately asymmetric slate-like field stone with a flattened heel for stable placement, a pale chipped impact face, and a few raised quarry scars that remain readable at gameplay distance. It is intentionally plain: free, silent, always available, and barely a weapon.

## Conventions and placement

- Blender source: Z-up, +Y forward toward the impact face.
- Exported GLB: Godot/glTF Y-up; the documented forward reference is the exported +Z axis after Godot import.
- World origin is the placement origin at the underside/contact area; the stone rests on Z=0 in Blender.
- `grip_marker` is the palm/release reference, `release_marker` is the throw release point, and `muzzle_marker` is the forward/impact reference for the thrown-weapon interface.
- Approximate dimensions: 0.17 m long x 0.10 m wide x 0.14 m high; catalogue mass is 400 g.

## Budget and build

- Four materials, custom faceted mesh, comfortably below the 4,500-triangle weapon ceiling.
- Rebuild with Blender 4.4 bundled Python:

  `"C:\Program Files\Blender Foundation\Blender 4.4\blender.exe" --background --python build.py`

The build is deterministic and writes `source.blend` and `model.glb` beside this README. No gameplay integration or animation is required for this static thrown object.
