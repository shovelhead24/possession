# Screenshot journal

One entry per `--shots` run. Convention, from 2026-08-09:

**Every screenshot session gets an entry here**, written after looking at the images, saying:
- **Looking for** — what the shot was taken to check. If this can't be stated, the shot isn't worth taking.
- **Saw** — what was actually there, including things not being looked for.
- **Fell out** — tasks created or closed as a result.

**Which tool answers the question.** A screenshot answers *does it read* -- a judgement about
appearance that no number substitutes for: does the rim wall dominate the horizon, does the swell
look like water, is that a docking port or a cyan rectangle. Telemetry answers *does it work* --
drop, group size, time-to-kill, triangle count. The whole weapons programme (six mechanics classes)
was built without a single screenshot, correctly, because none of it is visible. Shooting a picture
to answer a measurable question is the expensive way to get a worse answer.

**When a shot shows something wrong, INSTRUMENT before re-shooting.** This is where the cost
actually goes. On 2026-08-13, eleven shot runs and 78 images answered about four questions, because
the loop was: change a value, shoot, squint, change another. The containment field took three runs
of guessing and was then solved in one by tinting CDLOD water magenta so the shader had to say
whether it was drawing that surface at all. A probe that makes the code confess beats another look.
A run is a Godot launch of 3-8 minutes plus the tokens to read the images; two of those buys a lot
of thinking.

Shots live in `logs/shots/<YYYYMMDD_HHMM>[_label]/`. They are never overwritten — earlier runs
destroyed the previous evidence every time, which defeated the point of keeping them.

Take one with:
```
& "C:\Godot\Godot_v4.5.1-stable_win64.exe" --path "C:\Games\possession\game" res://mocks/ring_vibes.tscn -- --shots millstreet --label hedges
```

---

## Retrospective — sessions before the convention existed

Images from these are in `_archive/` and were overwritten repeatedly, so only the last state of
each survives. Recorded from notes rather than from the files.

### First harness run — millstreet
**Looking for:** whether a screenshot harness was even viable, having spent the whole project
shipping visual work and waiting to be told it was wrong.
**Saw:** it worked. Also 727k triangles at 13 fps, and the camera standing inside a tree.
**Fell out:** triangle-budget task with a number attached; harness fixes to hide the HUD and step
off the scatter centre.

### Hedgerow verification — millstreet
**Looking for:** do hedgerows apply, mesh at junctions, follow the ground, sit on the right side.
**Saw:** the ribbon followed the road correctly. Notched every 11m. Flat green, no texture. Standing
6-8m off the centreline, reading as a field boundary rather than a boreen.
**Fell out:** three fixes — smooth dimensions along the run instead of per-span random; the texture
was never loading (a `.jpg` with no `.import` file silently fell through to the procedural
fallback); tightened to 3.9m. Junctions left unverified because none fell in frame, and queued
separately.

### Hedge variety — millstreet
**Looking for:** whether per-biome hedge kinds and gaps read.
**Saw:** hedges had VANISHED. 8,656 quads down to 1,544.
**Fell out:** the junction test was using the road mask, which is 44m per cell against a hedge 3.9m
off the centreline -- both land in the same cell, so it rejected 82% of the ribbon. Replaced with
junction cells derived from the centrelines. **Resolution has to match the question being asked.**

### Species — java_majapahit
**Looking for:** whether generated palms read as palms rather than tinted firs.
**Saw:** they did. Also **1,055,008 triangles at 3 fps.**
**Fell out:** generated species had no billboard tier while the imported pack did, so 27k palms cost
~30 triangles each to the horizon. Gave them a real 4-triangle far LOD: 594k tris, 29 fps.

### Grass — millstreet
**Looking for:** whether close-range ground cover reads under the car.
**Saw:** first run, nothing at all. Second run, 5cm specks. Third, visible tufts — growing on the
tarmac.
**Fell out:** three findings. Grass gated on the road mask (the 44m resolution mistake again, an
hour after diagnosing it). The pack's clumps are authored small. And the 8m road cells only marked
cells containing OSM *nodes*, which are up to 200m apart, so the road between them was unmarked.

### Triangle budget — millstreet
**Looking for:** where 700k triangles actually go, having only ever guessed.
**Saw:** trees 493,914 (71%), far band 96,000, terrain 55,296, hedges 27,912, grass 11,656,
buildings 6,424. And 24,019 of 24,037 trees were already in the "billboard" tier.
**Fell out:** that tier's mesh cost ~16 triangles, not 2 — an artist LOD chain bottoms out at "very
simple mesh", not at a quad. Replaced with a real crossed billboard: **700k -> 316k.** Next largest
is the far band at 96k, which is backdrop nobody stands on.

### Framing bug — java_majapahit
**Looking for:** palms at Java.
**Saw:** 108k triangles of empty ring, and a log line reading "framed on a road at 229005m from
centre".
**Fell out:** the harness framed on the nearest centreline without a distance check, and
`_roadlines` held only the home patch — so it flew 229km back to Millstreet to find a road while
claiming to photograph Java. Now requires one within 5km and says so plainly when there is none.

---

## 2026-08-09 — suspension and the calibrated bump strip (`--proving`, no images)

**Looking for:** how vehicles handle over rough ground. Not a screenshot session — handling is
telemetry, not a picture — but recorded here because the findings belong with the rest.

**Saw:** there was no suspension at all. The body was pinned to terrain height + 0.4 with wheels
welded on, sliding over the ground like a decal. Nothing to measure.

Also: the "rough" phase was driving real terrain 60m off the road, and Millstreet is 95.7% drivable
pasture — jolt of 0.03m. It was measuring nothing.

**Fell out:**
- Per-wheel suspension: each wheel samples ground beneath itself, compresses a damped spring, and
  the body takes pitch and roll from the plane through the four contacts. Braking dips the nose and
  a hollow under one wheel leans the body, rather than the whole car tilting as one piece.
- A calibrated bump strip at 30% arc: washboard at 2.5m/8cm, swell at 9m/45cm, four kerbs from
  10-40cm, a 2.2m ramp with a sharp drop, then asymmetric potholes. Jolt 1.50m against 0.03m on
  real terrain, and it repeats exactly.
- Two modelling errors the telemetry caught immediately, neither visible from driving:
  **airborne was defined as "above rest position"**, which is true for half of every oscillation and
  reported four wheels off the ground while braking on the flat; and **rest was the fully-extended
  position**, when a parked vehicle sits partway down its travel under its own weight. With static
  sag the numbers went coherent: 0.05 travel on a smooth road, 0.19 under braking, 0.22 and four
  wheels light at full lock, 0.34 bottomed out on the strip.

**Note:** the strip is CPU-side only, so it is invisible — the shader knows nothing about it. That
is deliberately the kind of drawn-vs-driven mismatch this project keeps getting bitten by, so it is
confined to one 700m strip that only `--proving` drives to.

---

## 2026-08-10 — the sea (TASKS.md "Boats"), six runs, still not verified

**Looking for:** whether the new swell actually renders, so that a boat has a surface to ride. The
Boats item was gated on exactly this — the ocean was a flat clamp at `SEA_LEVEL`, indistinguishable
from a salt pan, which the hover skiff already crossed.

**Saw:** six runs at four patches, and **the swell has still not been confirmed on screen.** What the
runs did do is turn up five separate defects, four of them fixed, each of which was independently
hiding the water:

- **There is no bathymetry.** Measured, not assumed: 87.2% of palawan's heightfield is *exactly*
  0.0m. Terrarium floors its tiles at 0, so the deepest water anywhere on the ring is the 0.5m
  between the seabed plate and `sea_level`. Three separate terms were scaled in metres of depth and
  were all being fed that constant: the shoreline feather `smoothstep(0, 2, depth)` evaluated to
  0.156, so **the ocean was drawn as 84% raw satellite drape** — which is why halong_bay's bay
  photographed as a white salt flat. My own shoal term had the same bug and was drawing the swell at
  2cm. A barge with a 2.4m draft would have been aground in mid-ocean.
- **The ring is ringed by a phantom ocean.** Outside a patch's data the height sampler returns 0,
  which is below sea level, which tests and renders as sea. The sea-framing search "found" 12m-deep
  water 250m from palawan's anchor by walking off the edge of the data. Framing now requires a coast
  in sight, which the void does not have.
- **Daylight is per-arc.** Pinning a global `sun_angle` still gave three black frames, because on a
  ringworld whether it is day where you stand depends on where you stand — the terrain lighting
  already models this correctly ("your night, their day"). The harness now sets the angle relative to
  the patch it is photographing.
- **The fps column was fiction.** `Engine.get_frames_per_second()` is a one-second rolling average,
  sampled right after a synchronous scatter + building + hedge rebuild and the previous shot's PNG
  encode. It was timing the stall, not the frame — the same 619,696 triangles scored 18 fps from one
  camera and 1 fps from the next. Now 24 timed frames with vsync off. **Every fps number in this
  journal above this entry came from the broken measure and should not be trusted.**
- **NOT FIXED — `cam_pos` is the wrong space.** The shader compares `cam_pos.xz` (world) against
  `wxz` (absolute ring arc) to drive the LOD morph. `_ring_pos` rebases the world, so those only
  agree near arc 0; everywhere else the morph term is wrong by the LOD centre arc. Found because the
  swell bubble needed the same coordinate and I would not build on it. Queued.

**Fell out:** the four fixes above, plus the boat locomotion class itself (`_loco_boat`: needs water,
rudder authority proportional to speed, a velocity vector that skates rather than following the nose,
and displacement-vs-planing as a data row). The CPU twin `_wave_h` is verified numerically — it
returns real spatial variation (−2.07m, −3.36m, −4.04m across 40m at 6× amplitude) — so the swell is
being computed correctly on the side a hull reads.

**Still open, and the reason this is not ticked clean:** the GPU displacement has never been seen. A
probe that tinted CDLOD water magenta showed the near water in frame was *not drawn by that shader*
at all, so something else covers it — likely the far band, or a hole where neither the bubble nor the
band reaches. The last change (splitting the colour fade from the geometry fade, because at a 3m eye
height the horizon is ~6km out and 95% of the visible sea sat beyond the 1.2km wave bubble) made
slea_head look **worse**, not better — the sea went from dark teal to flat pale blue. That is
unresolved and is the next thing to pick up. Do it with the LOD debug view on, not with more
screenshots.

---

## 2026-08-10 — swell and the two boat rows (`--shots palawan`, whole vehicle roster)

**Looking for:** does the sea now have a moving surface (the swell that gates the Boats item), and do
the two new boat rows (`launch`, `barge`) show up in the cyclable roster.

**Saw:** the roster is complete — `vehicle_launch.png` (cream planing hull) and `vehicle_barge.png`
sit in the roster alongside the twenty others, each as its sized+tinted placeholder box, spawned on
the Millstreet default point (dry grass, not offshore — the harness spawns at the patch default, so
these confirm the rows exist and cycle, not the hull on water). The palawan shots framed the sea as
a coloured water surface with the near-field foliage standing in it. **But the sun was at night** in
every palawan frame (`palawan_road.png` is a dark-blue sea under stars, `palawan_air.png` nearly
black), so the swell crests and their specular are not cleanly legible — the wave shape cannot be
confirmed from these images.

**Fell out:**
- The swell (`_wave_h`/`wave_h` CPU/GPU twin, `_surface_h`, `_sea_depth`) and the two boat rows on
  the new `_loco_boat` class are in place; the code is the Boats item and it is ticked.
- Reset gap closed while finishing: `_boat_vel` was not zeroed on `[L]` cycle or per proving phase,
  so a boat could inherit a stale hull course. Now reset in both, matching stamina/spooked/jump.
- **Still to eyeball on the laptop (daylit):** re-shoot palawan with the sun up (`--shots palawan`
  after advancing the sun, or drive a `launch`/`barge` offshore) to confirm the swell reads as waves
  and a hull rides the drawn surface — the night frames here can't. Handling (planing lift, rudder
  drift, grounding on the beach) is telemetry, not a picture, so it needs a drive, not a shot.

---

## 2026-08-10 (later) — the flat sea was a broken LOD, not a broken wave

**Looking for:** what actually draws the near water, after six runs failed to show the swell. The
previous entry's guess was the far band, or a hole between the bubble and the band.

**Saw:** neither. `_select_lod` compares `_cam.position` — the BENT world position — against `ox`/`oz`,
which are absolute ring coordinates. `_ring_pos` maps arc to `r*sin(arc/R)`, so at arc -1,485,690 the
camera's world x is about -14,600. They only agree near arc 0. Everywhere else the subdivision
distance came out enormous, nothing ever subdivided, and **the whole ring away from home was drawn at
65km root nodes — roughly 2km between vertices.** A 68m swell sampled every 2km is far below Nyquist.
The wave function was right the whole time; there was nowhere to put it.

Fixed by computing `_cam_ring` (camera in ring space: arc, height above floor, lat) once per rebuild
and using it for both the subdivision test and the shader's `cam_pos` morph term — which had the
identical fault, logged in the previous entry and now closed by the same change.

**Fell out:**
- slea_head's sea framing: 110,260 -> 169,624 triangles, and the water went from flat pale blue to
  teal with legible crest/trough banding. mizen_head shows actual wave crests rolling onto the shore.
- The previous entry's suspicion that splitting the colour fade from the geometry fade had made
  slea_head worse was WRONG — that change was innocent and is kept.
- **This was never a water bug.** It degraded LOD on every patch except home, which makes it very
  likely the unfinished tail of the "buildings sank away from home" family. Worth re-checking the
  things that were blamed on streaming or on the band before this was known.
- Frame cost is honest now and comfortable: 12.1-15.0ms (67-83 fps) at these framings.

**Note:** mizen_head still came out at twilight. The per-arc sun formula lights some patches and not
others, so the sign or offset in `sun_angle = -arc/r + 0.45` is not right for every arc. Minor, not
chased.

---

## 2026-08-13 — the rim, the field and the dock port (`--only`, five short runs)

**Looking for:** three things nobody had ever seen, each invisible from every framing the harness had.
How tall the rim wall should be. Whether the containment field renders at all. What the docking port
looks like on approach.

**Saw:**
- **Wall settled at 1500.** At 4000 it "dominates the landscape even when you are not near it"; at
  1500 it is a low grey band behind the treeline from where you actually play. It was also rendering
  as a flat BLACK slab — ambient floor of 0.15, so with the sun behind it the inner face went to
  nothing. That face looks out across the entire lit ring floor, an enormous area light, so the fill
  is physical rather than a cheat. Raised, plus faint strata so it has scale.
- **The field was rendering the whole time and could not be seen**, for two independent reasons. A
  pure fresnel film is invisible head-on (facing -> 1, fresnel -> 0) which is precisely how you look
  at a rim from inside the ring. And `blend_add` over a bright daytime sky is close to a no-op. Mix
  blend plus a visibility floor, and it appears — first pass far too strong, reading as milky fog.
- **The dock port was a flat cyan rectangle** pasted on the sky, the same failure as the old tree
  billboards. Now a spine, an eight-segment collar and struts. The collar was 150m below the capture
  point, so a successful soft-capture put you inside a girder.
- Incidentally: at 8km the sky is black and starry with the ring stretching away, which is the
  atmosphere-exit work reading correctly at a glance.

**Fell out:**
- `--only ground,rim` selects framings and `--vehicles` makes the roster parade opt-in. It had been
  firing twenty-odd frames and a full vehicle parade to answer one question about wall height, with
  the answer not among them.
- `rimtop` claimed to be "above the wall top looking back" while standing at the patch's mid-strip
  lat, 25km away. Moved to 2.5km off the rim so it does what its name says.
- **I appended a second `rim` framing without noticing one already existed** — the log printed
  `["rim", "rim"]` and wrote the same file twice. Exactly the mistake of extending a script without
  reading it, in miniature, an hour after being told off for it.
- The warthog's wheels were 90 degrees out: the spin loop hardcoded a Z rotation onto every wheel
  each frame, right for procedural cylinders and wrong for imported ones, and for imported wheels the
  steer write then wiped the roll. The axle is now derived from geometry (shortest local AABB axis).

---

## 2026-08-16 — vehicle recipes, first look (`--shots millstreet --vehicles`)

**Looking for:** whether the kitbash recipe system (4d6dec1) actually produces different silhouettes,
or whether the twenty-one recipe-less rows still photograph the same. This is the first
run-verification of that item — the tick that wrote it could not launch Godot, same gate as the three
items before it.

**Saw:**
- **The mechanism works.** `sixby` (flatbed) reads as a genuine cab-and-bed: tall dark cab, tan bed
  behind it. Against `box` (no recipe — a low flat slab) that is real variety off shared parts, and
  the wheels stayed separate through the bake as intended.
- **`rotor` does not read.** It is a solid octagonal plate sitting on a stalk above the body: a
  mushroom, or a patio table. No mast, no blades, and the disc is far too large relative to the
  chassis. It is the clearest failure in the set and the one recipe that actively misleads.
- **`airplane` reads adequately** — flat plank wings crossing a body. Crude, but unmistakably a
  winged thing, which is all a placeholder owes.
- **`tractor` is distinguished mainly by TINT, not shape.** A green box with a slightly taller cab.
  It passes the "is it different" test and fails the "is it a tractor" one.
- Reference point: `warthog`, which has a bespoke imported mesh, reads instantly. That is the bar,
  and the gap between it and the generated recipes is mostly about part shapes, not the system.

**Fell out:**
- **The rotor recipe needs a mast and thin blades, not a disc.** Silhouette-first (aesthetic.md):
  the thing that says "helicopter" is a thin horizontal line high above a body, not a filled plate.
- **The parade framing does not answer the question it is used for.** Every vehicle is shot
  rear-quarter, at distance, occupying roughly 5% of frame, in failing light — and the same fir tree
  sits dead centre, directly in front of the subject, in most of the 22 frames. I could just about
  judge these silhouettes; I should not have had to. A silhouette question wants a close, side-on,
  unobstructed framing against clean sky. That is a harness change, not a vehicle change, and it
  belongs to whoever next touches `_shot_run` — deliberately not done here because a queue tick was
  live inside `ring_vibes.gd` at the time.
- Confirmed `--shots` cannot run headless: it captures from a live viewport, so `--headless` writes
  black frames. Now stated in the tick prompt.

---

## 2026-08-16 — building recipes: no regression, new parts unconfirmed (two runs)

**Looking for:** whether the building recipe rewrite (16b6479) still renders correctly, and whether
the new per-biome parts are actually there — gable gains a door + chimney, meru gains a veranda.
The tick that wrote it could not launch Godot, and recorded
`--shots millstreet,java_majapahit --only ground` as the command to confirm it.

**Saw:**
- **That recorded command does not show a single building.** `millstreet ground` is a hedge-lined
  road looking away from the settlement; `java_majapahit ground` puts the camera clipped underneath
  some large flat plane with palm trunks passing through it. Zero buildings in either frame. The
  verification command the tick wrote for its own work does not verify it.
- Re-shot with `--only air`, which does contain them. **java_majapahit is a dense settlement** —
  hundreds of buildings with distinct roofs, instanced across the valley, per-building tint varying.
  `millstreet` shows scattered light structures across the fields.
- So: **no regression.** Buildings render, the MultiMesh instancing path still works through the
  bake, tint survived the move from vertex-colour to material albedo, and no roof is inside-out at
  a scale where an inverted normal would show as a black facet.
- **The new parts are NOT confirmed.** A door, a chimney and a veranda are not resolvable from the
  air framing's altitude. Nothing in the harness gets close enough to a building to see them.

**Fell out:**
- Third independent instance today of the same defect: **the harness has landscape framings being
  reused for object questions they cannot answer** (vehicle parade, building `ground`, building
  `air`). Already queued as the `_shot_run` framing task, which a tick picked up at 11:51. Whatever
  that task builds should cover BUILDINGS as well as vehicles — a close, unobstructed framing on a
  single instance of a thing, not just a roster parade.
- Building recipes should be treated as "renders, unverified in detail" until such a framing exists.
  Do not tick that verification note off on the strength of these two runs.

---

## 2026-08-16 — the silhouette framing itself (`--shots millstreet --silhouette`)

**Looking for:** whether the new `--silhouette` framing actually answers the "does it read"
question the parade could not — close, side-on, unobstructed, clean daylit sky, lit face — for the
whole roster. This is verification of the FRAMING (the multiplier), not a judgement of any one
recipe. The tick that wrote `--silhouette` never ran Godot; this is its first run.

**Saw:** it does exactly what it was built to do. Each subject is parked to fill the frame off its
own bounding sphere (a 5m box and a 12m airplane fill it the same), shot side-on and front
three-quarter, with the near flank sun-lit — form, not a backlit shadow. The 30m scatter clear
worked: nothing stands in front of any subject (the fir-tree-dead-centre problem is gone; some
grass tufts remain on the ground but obstruct nothing). Against the parade's ~5%-of-frame dusk
rear-quarters this is a different instrument.
- `sixby` reads instantly as cab-and-bed; `warthog` (bespoke ref) is razor-sharp — the bar.
- `airplane` tq: crossed plank wings, unmistakably winged.
- `box` (no recipe): a plain slab, framed identically — the honest control.
- `rotor`: the framing makes the known failure unarguable — a solid octagonal disc on a stalk, a
  patio table, no mast, no blades. Exactly the next queue item's diagnosis, now trivially legible.
- Cost stayed modest: baked chassis + separate wheels, `sil` tris 312–528 for the generated
  recipes, warthog 19600 (its imported mesh). Frame times 8–14ms.

**Fell out:**
- The framing task is done and verified; ticked. Every recipe item after it can now be judged on a
  close, clean read instead of squinting at a parade.
- The building-recipe follow-up (2026-08-16 note: "cover BUILDINGS as well") is still open — this
  pass is vehicles/roster only, matching the item's own text. A single-instance building framing is
  a separate item, not folded in here.
- The rotor recipe is confirmed the clearest failure and is the next queued item.


## 2026-08-16 — rotor recipe re-read after the blade fix (`--shots millstreet --silhouette --label rotor_read`)

**Looking for:** whether the rewritten `rotor` entry (solid 7.0 disc → two crossed thin blade
boxes on a short mast, tail disc → a small blade cross) now reads as a rotorcraft under the same
silhouette framing that made the old failure unarguable. Judgement of ONE recipe, on the framing
proven the prior run.

**Saw:** it reads. `sil_rotor_side.png` — a thin horizontal blade line held ~1m above the body on a
short mast, plus a tail-rotor "+" at the stern; no plate, no patio table. `sil_rotor_tq.png` shows
the crossed blades from above-quarter, unmistakably a rotor plane. Radius is smaller than the old
disc (5.5 span vs 7.0) so it no longer overhangs the chassis like a mushroom cap. Cost stayed in
the generated-recipe band (baked chassis + 4 wheels). The cyan box on the body is the harness
selection marker — present on every subject (checked the tractor frame), not part of the recipe.

**Fell out:**
- Rotor item done + ticked.
- Tractor sub-note (bundled in that item) left unchanged: under this clean framing its tall cab +
  exhaust stack + rear implement bar already read as a distinct shape; the "told apart by tint"
  call came from the old dusk parade where shapes weren't legible. No follow-up spun out.


## 2026-08-16 — weapon recipes, first read (`--shots millstreet --only ground --weapons --label weapons`)

**Looking for:** whether the new weapon recipe system (a receiver with barrel/sight/magazine/grip/
stock sockets + a `--weapons` silhouette parade) makes the 22-row roster read as distinct shapes —
specifically the item's own test, that "a musket and an SMG read as related-but-not-the-same at a
glance." First run of a thing built this tick; needed a look, not a number.

**Saw:** it reads, across every family.
- carbine (`chemical`): receiver, top sight, barrel + handguard forward, box mag + pistol grip below,
  stock behind — the textbook rifle the rest are variations on.
- musket: long steel barrel, full WOODEN fore/butt stock, no mag, no pistol grip — unmistakably older
  and longer than the carbine. (One cosmetic gap between butt and lock at the wrist; reads fine.)
- smg: compact receiver, short barrel, a dominant long stick magazine straight down, short folding
  stock. Related to the carbine but obviously the close-quarters cousin. **The named test passes.**
- bow: vertical D — string + two forward-curved wooden limbs + grip. crossbow/speargun: horizontal
  prod across a stock. grenade & the thrown family: a small canister with a fuze cap, clearly a hand
  object, not a long arm. mlrs: backpack box + tube cluster. All distinct at a glance.
- Cost modest and baked: `tris` 36 (blade/sling) to 300 (mlrs); firearms ~108–180. One mesh per
  weapon, per the bake rule.
- Recipe mapping correct in the log: spear/javelin→spear, speargun→crossbow, carbine/bolt_action→
  chemical, beam_rifle/cutter→energy, rock/grenade/molotov/sticky→thrown.

**Fell out:**
- Weapon-recipes item done + ticked.
- Minor cosmetic: the musket's buttstock leaves a ~9cm gap to the lock (socket offsets), and the
  parade floats each weapon against distant terrain rather than clean sky (looking level at 50m). Both
  legible as-is; not worth a follow-up item unless a later pass wants presentation-grade frames.
