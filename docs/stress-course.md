# Directional SDF feature stress course

Open `game/world/sdf_stress_course.tscn`. The regular workshop scene is unchanged.
First opening copies the existing normal recipe in memory and adds 228 features:
curved spline ridges cut by matching curved tunnels, roadside ravines, and raised
bridge decks. Three increasing-density tiers run along -Z from z=-120 to -604m,
centred on x=-14m. The current Warthog starts near x=-28m, z=-34m;
steer toward the labelled centre lane. Each tier has four stations.
Spline curves use the existing deterministic eight-capsule evaluator; this does
not introduce a new spline editor. Features stay within the workshop's height range.

New geometry leaves the centre lane open beneath bridges. Existing terrain in
the copied recipe may still obstruct it. Fly/edit and F3 chunk outlines can help
inspect each tier; F8 records driving hitches. Labels mark the tier entrances.

Save/Load in this scene use only `user://sdf-stress-course.json`, never the normal
`sdf-authoring.json`. Subsequent openings reuse that separate save if it exists.
Without a separate save, it recreates the same additions atop the current normal
recipe. If the combined recipe would exceed 2048 features, it reports an error
instead of dropping existing work. Normal generated mesh caches remain intact;
feature-aware hashes separate changed chunks. No automatic cache purging.

Cold first traversal measures generation plus streaming; return traversal measures
cached loading. The coarse scenery startup also generates coarse versions, not
the fine driving collision meshes. Do not present a warmed return run as cold.
Benchmarks must be isolated to one local Godot instance.

`check_stress_course.gd` validates deterministic recipes, independent save paths,
lane clearance and overhead geometry. `check_stream_drive.gd -- --authoring-diagnostic
--stress-course` measures the straight feature route. Its stress mode reports speed
and brake demand rather than assuming a dense workload must already meet the simple
terrain baseline; missing-collision freeze/recovery is still checked.
It now records tier coverage and exits on failed safeguards; reaching only an
early tier is not a full-course performance pass. `check_stress_geometry.gd`
checks actual lane/floor/overhead and curved-bore collision at all 12 stations
using the copied user recipe, then captures three tier views.
