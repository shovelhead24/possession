# Work queue

Durable queue for scheduled/resumed sessions. The cron schedule dies with a session; this file
doesn't. A session that wakes takes the **top unchecked item**, does it, ticks it, commits.

Rules:
- One item per wake. Finish it or leave a note saying where it stopped.
- Read images before changing biome numbers. `tools/dem/patch_census.py` proposes; the image decides.
- **Every screenshot session gets an entry in `logs/shots/JOURNAL.md`** — what it was taken to
  check, what was actually there, what tasks fell out. Shots go in a timestamped folder and are
  never overwritten. A shot with no stated purpose is not worth taking.
- Never re-centre or refetch a patch unprompted — that destroys the old one.
- Don't write more docs unless the item asks for one.

---

Framing, because this only works one way. **40 vehicles is not 40 models.** It is a small set of
locomotion models, each parameterised, with generated or kitbashed meshes over the top. Done as
bespoke assets it is forty art tasks and it never ships; done as ~7 movement classes x parameters
it is a fortnight and the count falls out for free. Same argument as the tree species: the project
already generates its houses, hedges, palms and textures.

Prerequisite for everything below.

The vehicles framing generalises, and most of it is already built. `PartDef` (mesh + slot + offset
transform) and `CharacterAssembler` are a kitbash system whose ONLY coupling to characters is that
its socket is a bone. The cage editor already sculpts low-poly parts and bakes them to PartDef, so
there is an authoring tool feeding a part library that only one consumer can use.

Everything else reinvents it inline in ring_vibes.gd: `_make_car` welds boxes and cylinders,
`_build_buildings` does houses, the dock port was hand-authored as a spine and a collar and struts.
Each is "attach parts at offsets", written again.

BOUNDARY, so this does not eat things it should not: kitbash is for objects made of DISCRETE PIECES.
Trees, hedges and grass are parametric -- continuous variation from a seed -- and belong where they
are. The test is whether swapping a piece is the interesting axis of variation.

Same framing as the vehicles, for the same reason. **A tech tree from a sharpened stick to a
backpack MLRS is not 40 weapon models.** It is ~7 mechanics classes, each parameterised, with
placeholder shapes over the top. Mechanics first: a weapon that looks right and feels wrong is
worse than a grey box that feels right, and feel is measurable.

The carbine already exists as a model with FP arms (`.decisions/` and `assets/`), so this is about
behaviour, not art.

- 8192 refetch: running via the Startup task. ~36 patches left of awake time.
- Roads fetch: running. Hedgerows everywhere depends on it.

- Coastal batch, ring now 35/35 unique
- Atmosphere exit, star rotation on the sun's axis
- Roads: trees off carriageway, hedge ribbon, verge
- Height tier box-filtering; `--align` reports 0/4235 mismatches
- S3TC/BPTC compression, `[U]`
- `[Y]` probe, `patch_census.py`

---

**Completed items live in `TASKS-done.md`.** They were 88% of this file (679 of 768 lines) and the
tick re-read all of it every 30 minutes to find one unchecked line.

Which file to read depends on the question:
- **"What do I do next?"** — this file only. Grep for `^- \[ \]` and read that item. Do not load the
  archive; it cannot tell you anything about an unstarted task.
- **"What tasks should exist?"** — read `TASKS-done.md` in full, and it is worth the tokens. Planning
  needs the whole history: what was already tried, what turned out to be wrong, which findings
  generated follow-ups. Half this project's best items came out of something that had just been
  finished, and you cannot see those patterns from eight open lines.

Write the "what actually happened" notes into the commit message, and keep this file to the queue.

## Now — in the order the tick should take them

- [x] **Physics bake-off harness (`-- --physbench`).** Build the measuring device before choosing an
      engine, same as `--proving` and `--range`. Identical scripted scenario per engine, one
      comparable table. Switchable via `physics/3d/physics_engine`, so Godot Physics and Jolt are
      both testable with a project setting and no code.
      Six scenarios: **rest** (50-box stack, 60s, max drift/jitter) | **shift** (the same stack with
      the origin teleported 500m every 2s -- THE DECIDER, and the test no standard benchmark runs) |
      **terrain** (bodies dropped on the real heightfield: penetration, settling, is heightfield
      collision even supported) | **slope** (5/15/30 deg: do bodies creep) | **count** (ramp until
      frame time > 16ms on the Intel UHD target) | **repeat** (run twice, compare final transforms
      bitwise -- determinism, which every harness here depends on).
      WHY SHIFT IS THE DECIDER: measured on the ring, a local island is flat. Over 500m "up" rotates
      0.060 deg and gravity varies 0.105%; even at Box3D's 12km limit up rotates only 1.44 deg. So a
      player-centred island with a CONSTANT gravity vector is correct, not approximate, and both
      objections to using an engine here (float precision at 1.5e6 m, and spin gravity not being a
      vector) are answered by moving the origin with the player. What that costs is teleporting every
      body on each shift, which invalidates contact caches -- so the question is entirely "how much
      does this engine flinch when rebased", and nobody benchmarks that.
      Coriolis stays out of it: 0.19% of g at walking pace, 2.9% at 30 m/s, 8.7% at 90 m/s. Slow
      local props ignore it; fast movers (bullets, aircraft, vehicles at speed) stay analytic.
      Box3D is a paper candidate only until this exists -- no Godot binding, so it needs a GDExtension
      against a v0.1.0 C API, which is worth writing only if the table says Jolt is not good enough.
- [ ] **FPS controls proper.** WALK mode is a camera with a speed. Needs: acceleration, crouch,
      sprint with a cost, jump, fall damage, stance affecting spread, and the ring frame handled
      correctly (up points at the axis, which the camera already does and the movement does not).
- [ ] **HUD.** Currently a debug wall of text. Needs a real one -- and per
      `.decisions/design-laws.md#diegetic-tools-not-hud`, **information must be a physical ownable
      tool, not free overlay**. Ammo count comes from looking at the weapon; bearing comes from a
      compass you found. That law makes this design work, not just layout work.
- [ ] **Damage model** — locational, on the player and on NPCs, shared with the creature system that
      already exists.
- [ ] **Bake after assembly — the cost of kitbashing is object count.** Prerequisite for the recipe
      items below, and the thing that makes them safe. A building of 12 parts kept as 12
      MeshInstance3D nodes is 12 draw calls; a settlement of 200 is 2,400, on a GL Compatibility
      Intel UHD target. This project has already been eaten once from the other direction -- 24k
      trees at ~30 tris each, fixed with billboards and MultiMesh -- and a Box3D dev describes the
      same wall from the physics side: kitbashed strongholds reaching 50,000 separate collision
      meshes, solved by cooking them into a single pre-optimised uber shape.
      THE RULE: assemble from parts, then bake. What must move independently stays a node; what is
      static relative to its parent gets merged into one ArrayMesh, one surface per material, and the
      part nodes discarded. A building's walls and roof merge. A vehicle's wheels must steer and roll
      so they stay separate while the chassis bakes. A character's parts must follow bones, which is
      why the existing assembler is correct FOR CHARACTERS and would be wrong copied wholesale.
      Bake collision the same way if a physics island ever lands — one cooked shape, not 12.
- [ ] **Unlock the assembler from Skeleton3D.** Socket becomes a Node3D by name, not a bone; the
      bone path stays as one implementation of it. This is the enabling change and everything below
      is cheap once it lands. `PartDef.bone_name` -> `socket`, `CharacterRecipe` -> `Recipe`.
- [ ] **Vehicle recipes.** `_make_car` builds a box with four wheels inline, and every row that has
      no bespoke mesh gets the identical shape -- twenty-one vehicles that photograph the same. A
      chassis with sockets (wheels, cab, bed, turret, tracks) plus a `recipe` field on VehicleDef
      turns the roster into visible variety for the cost of a few parts.
- [ ] **Building recipes.** `_build_buildings` places one box with a roof. Sockets for wall, roof,
      door, chimney, veranda, plus per-biome part sets, is how java stops looking like cork.
- [ ] **Weapon recipes.** A receiver with barrel/stock/sight/magazine sockets. Fourteen weapons
      currently share zero geometry; the tech tree is a shape argument as much as a stats one, and
      a musket and an SMG should read as related-but-not-the-same at a glance.
- [ ] **Structure recipes.** The dock port, and whatever else gets hand-built next. It is already
      spine + collar + struts; that is a recipe written in GDScript instead of data.
- [ ] **Deployable** — mines, sensors, a tripod turret. Placed, then persistent.
- [ ] **Progression rules.** The player ARRIVES from a spacefaring civilisation and gets stripped of
      it (`the-toll` in docs/vignettes.md). The tree is therefore about RECOVERING capability, not
      inventing it -- a spear is what you use when they took your rifle. That inverts the usual
      shape and is worth exploiting.
- [ ] **Ammunition and scarcity** as the real balance lever, not damage numbers.
- [ ] **Where weapons come from** — found, salvaged, traded, taken. Same hook as the vehicles;
      ties into draws.
- [ ] **Where vehicles COME from.** Found, salvaged, stolen, traded. Ties into the draws work:
      a vehicle two valleys away is a reason to go there.
      BLOCKED (2026-08-13): `docs/draws.md` exists as design but there is no draws or settlement
      system in the engine at all, so this would mean inventing salvage/trade/ownership from scratch
      rather than wiring up something that exists. Needs the draws work first.
