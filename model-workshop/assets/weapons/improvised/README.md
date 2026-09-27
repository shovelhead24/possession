# Weapons — Improvised

Finished low-poly improvised melee weapon for Possession: a short wrecking bar made from one visibly load-bearing bent plumbing pipe, a folded road-sign impact shoe, wrapped handgrip, and a splayed two-tine nail-puller claw. The deep diagonal V-slot and bright cut tips keep both sharpened tines readable in profile and three-quarter views. The thin, rear-open sign fold exposes the pipe; uneven bends, torn raw lips, localized paint loss, mismatched fasteners, and weld burn make its weak salvaged construction readable at gameplay distance.

Catalogue intent: “whatever was to hand — short, weak, and better than open palms” (`damage 18`, `reach 1.0 m`, `windup 0.30 s`, `commit 0.45 s`, `arc 50°`).

The Blender source is Z-up and grounded at Z=0. The primary impact direction is +X; the weapon length is +Z in Blender and becomes +Y in the exported Y-up GLB. `IMPROVISED_ROOT` is the meaningful floor-contact root. Evaluated dimensions and budget counts are regenerated in `metrics.json` by every build.

Named markers: `marker_grip_rear`, `marker_grip_lead`, `marker_strike`, `marker_hook`, and `marker_swing_pivot`. The continuous pipe, separate tape layers, cut-sign shoe, raw impact face and tooth, fasteners, weld beads, paint remnants, claw bridge, and individual pry tines remain useful separate parts for attachment, damage, or material variants. No gameplay or animation integration is included.

Built dimensions are `0.580 x 0.146 x 0.980 m` in Blender, with `844` triangles and `7` materials, below the 4,500-triangle and 12-material ceilings. Rebuild deterministically with Blender 4.4 and no third-party dependencies:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 4.4\blender.exe' --background --python build.py
```
