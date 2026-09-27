# World foundation integration

Branch: integration/world-foundation, based on preserved game 567876f.

Run game/world/foundation_viewer.tscn in Godot 4.5.1. F1/F2/F3/F4
select ground, vehicle-height, flight and space viewpoints. F5-F8 select
quarter-ring positions. Existing G map/warp, O tuning, P sun pause, mouse
look, WASD, Space/Ctrl flight controls remain available.

The viewer reuses ring_vibes: original geography, DEM splices, CDLOD,
curved ocean, clouds and haze. It does not substitute a new procedural map.
Its parent still includes optional gameplay systems; extraction is incremental.

## Coordinate contract

RingFrame uses arc metres, altitude metres toward the axis, and lateral metres.
Ring circumference is 3,000,000 m; width is 50,000 m, per the ratified world
decisions. The old render-space convention remains: origin at home sea level,
spinward +X, lateral +Z. Local up varies with arc. Sky gradient and star horizon
fade now use that same local up; celestial star rotation remains in world space.
Sun direction is shared by the viewer lighting path. Space ambient fade no
longer gets overwritten by the later day/night ambient assignment.

relative_position evaluates differences in scalar double precision before
converting to Vector3. This is a tested interface for floating-origin work,
NOT a claim that the existing terrain/shader/collision pipeline has been
converted to floating origin. Render geometry still uses global float vectors.

## Earlier highlights recovered for comparison

- April: game/sky_shader.gdshader, game/sky_dome_shader.gdshader,
  game/water_shader.gdshader. Water includes shallow/deep colours, foam,
  waves, Fresnel, sun glitter and underwater caustic/ray treatments.
  Commit d069490 (16 April) corrected water level and rendering issues.
- July: game/mocks/ring_sky.gdshader and ring_clouds.gd; genuine ring geometry,
  starfield, tilted sun path, clouds and haze. Local tag ring-vibes-halo-aesthetic
  at 9507e27 identifies a reference version; remote publication of that tag
  has not been confirmed (the earlier inventory claimed this too strongly).
- August: cdlod_ring.gdshader and ring_vibes CPU wave sampler provide curved
  moving water integrated with DEM sea masks and camera-distance wave fading.
- September: prototypes/first-operation/baseline_sky.gdshader and
  painterly_sky.gdshader retain the theatre-scale direction for later comparison.

These are source references, not yet a user-approved visual selection.
Do not drop the April flat-world shader unchanged into a curved ring:
its position, normal, sun and underwater assumptions need adaptation.

## Dataset and backup limitation

The existing game/mocks/dem dataset is ignored by Git: 296 top-level files,
5,786,024,367 bytes at inspection. This integration checkout has a local
directory junction to C:/Games/possession/game/mocks/dem. Runtime reads it;
do not run dataset export tools against that junction.
The preservation branch pushes did NOT preserve ignored files. A clean clone
alone cannot reproduce the map. Dataset manifest and independent backup remain
required, along with investigation of other ignored dependencies.

## Verification

Headless script: --script res://world/test_ring_frame.gd
Viewer references: res://world/foundation_viewer.tscn -- --foundation-check
Numeric tests cover five arc positions, four altitudes, wraparound, local up,
sun direction and centimetre offsets. Visual approval, shoreline/underwater
review, full floating origin migration and terrain authoring remain open.

Results: numeric tests passed in Godot 4.5.1. Eight viewpoint checks passed with
--foundation-lite --foundation-check (the explicit lite flag skips DEM loading).
Full-map headless smoke exited successfully after loading 35 splices, 13,674
road centrelines and 143,141 OSM buildings. Tree and grass asset packs are absent
in this checkout, so their rendering was not verified. Headless results do not
establish visual quality or GPU shader correctness.
