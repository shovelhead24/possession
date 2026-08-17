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
- [x] **FPS controls proper.** WALK mode is a camera with a speed. Needs: acceleration, crouch,
      sprint with a cost, jump, fall damage, stance affecting spread, and the ring frame handled
      correctly (up points at the axis, which the camera already does and the movement does not).
      Done in player.gd: move_toward accel/decel (ground+air), Ctrl-crouch (capsule shrink, camera
      drop, headroom-gated standup), Shift-sprint with stamina drain/regen + exhaustion lockout,
      jump blocked while crouched, impact-speed fall damage, stance-driven carbine spread. Ring
      frame: explicit up_direction=UP + constant gravity per the physbench decision (radial gravity
      would be wrong in this flat player-centred world). Not runtime-tested here — verify on laptop.
- [x] **HUD.** (Implemented by a queue tick at 18:37; the code is in commit 4d8cbd1, which is
      titled as a logging change because I swept it up with a blind `git add -A`. game/hud.tscn and
      game/player.gd are the actual work.) Currently a debug wall of text. Needs a real one -- and per
      `.decisions/design-laws.md#diegetic-tools-not-hud`, **information must be a physical ownable
      tool, not free overlay**. Ammo count comes from looking at the weapon; bearing comes from a
      compass you found. That law makes this design work, not just layout work.
      Done in hud.tscn + player.gd. Applied the law as a filter on what may appear at all, not a
      layout pass: the default HUD is now crosshair + vitals only (HP, and stamina which surfaces
      only when drained). The whole debug wall -- X/Y/Z position (the "bearing" the law hands to a
      found compass), FPS/memory/node-object-resource counts, chunk/pool stats -- moved into an
      F3-toggled DebugPanel, off by default, and its telemetry gather is skipped entirely while
      hidden. No new mechanics: ammo-on-weapon stays deferred to the Ammunition item, and the
      compass/scope tools to the tools work -- the law names them, it doesn't ask to build them here.
      Not runtime-tested here (main scene test_combat.tscn, not the --shots ring mock) -- verify on laptop.
- [x] **Damage model** — locational, on the player and on NPCs, shared with the creature system that
      already exists. Done in commit d7140a4: shared `game/damage.gd` (zone table + classify() by hit
      height + resolve() by zone), routed through player, enemy_controller, enemy_soldier, creature
      and bullet, with `game/tests/damage_test.gd`. Verified there via `--check-only`; could not
      re-run Godot this tick (execution permission-denied), but the code is committed and unbroken.
- [x] **Bake after assembly — the cost of kitbashing is object count.** Prerequisite for the recipe
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
      Done: new `game/pipeline/mesh_baker.gd` — `MeshBaker.bake(root)` walks the static kitbash,
      groups every MeshInstance3D descendant's surfaces by effective material (override > surface
      override > mesh material) into one ArrayMesh (one surface per material, transforms baked in via
      a parent-chain walk that matches ring_vibes._rel_xform), then discards the merged part nodes.
      Dynamic parts survive: a node in group `no_bake` (or meta `bake=false`) and its whole subtree
      are left untouched, so wheels/turrets/bone-attached parts stay separate. Collision baking is
      deferred to when a physics island actually lands. It is a standalone utility (not wired into
      recipes yet — those are the items below); the existing character assembler is untouched.
      Self-test at `game/tests/bake_test.gd` (surface-per-material, geometry preserved, nodes
      discarded, dynamic survives, no-op when all dynamic). NOT runtime-tested this tick: Godot
      execution is permission-denied in the queue-wake session (both the `-s` and the sanctioned
      `-- --selftest` scene forms were gated), same as the damage tick. Run on the attended laptop:
      `godot --headless --path game -s res://tests/bake_test.gd` — expect `BAKE SELFTEST: PASS`.
- [x] **Unlock the assembler from Skeleton3D.** Socket becomes a Node3D by name, not a bone; the
      bone path stays as one implementation of it. This is the enabling change and everything below
      is cheap once it lands. `PartDef.bone_name` -> `socket`, `CharacterRecipe` -> `Recipe`.
      Done: `PartDef.bone_name` -> `socket`; `character_recipe.gd` -> `recipe.gd`, `CharacterRecipe`
      -> `Recipe`; assembler no longer requires a Skeleton3D — `_resolve_socket` finds a Node3D by
      name first, falls back to a (reused) BoneAttachment3D when the name is a bone, empty = root.
      Callers/.tres updated (pipeline_panel, cage_panel, placeholder parts). Self-test at
      `game/tests/assembler_test.gd`. NOT runtime-tested this session — Godot execution was
      permission-gated (Bash + PowerShell, every form denied). Run on the laptop:
      `godot --headless --path game -s res://tests/assembler_test.gd` — expect `ASSEMBLER SELFTEST: PASS`.
- [x] **Vehicle recipes.** `_make_car` builds a box with four wheels inline, and every row that has
      no bespoke mesh gets the identical shape -- twenty-one vehicles that photograph the same. A
      chassis with sockets (wheels, cab, bed, turret, tracks) plus a `recipe` field on VehicleDef
      turns the roster into visible variety for the cost of a few parts.
      Done: `VEHICLE_RECIPES` const (6 recipes -- flatbed/sport/tractor/turret/rotor/wing) + a
      `_recipe_mesh` generator (tinted box|cyl). `_make_car` now, when `d.recipe != ""`, builds named
      chassis sockets (`cab/bed/turret/nose/tail/wing`, body-relative so they scale with length),
      hangs the parts via the shared `CharacterAssembler.apply` (the payoff of the Skeleton3D unlock --
      one assembler, two consumers), marks the wheel pivots `no_bake`, and `MeshBaker.bake`s the
      chassis to one mesh while the wheels stay dynamic. `recipe` wired onto 8 rows: sportscar→sport,
      sixby+hauler→flatbed, tractor→tractor, crawler→turret, rotor→rotor, airplane+lifter→wing. Rows
      with no recipe are byte-for-byte the old box (boats/subs/hover/legged/bike/box/warthog untouched).
      NOT runtime-tested this session: Godot execution is permission-gated (Bash sandboxed+unsandboxed,
      PowerShell, cmd wrapper -- every form, even `--version`, returns "requires approval"), same as the
      bake/assembler/damage ticks. GDScript statically checked (indentation, the const Vector3/Color
      block parses like VEHICLE_ROWS, 8 recipe fields + 6 keys confirmed). VERIFY VISUALLY on the laptop:
      `& C:\Godot\Godot_v4.5.1-stable_win64.exe --headless --path C:\Games\possession\game res://mocks/ring_vibes.tscn -- --shots millstreet --vehicles`
      -- expect the sportscar/sixby/hauler/tractor/crawler/rotor/airplane/lifter frames in
      `logs/shots/` to show distinct silhouettes, not eight identical boxes, and `SHOT vehicle` tris to
      stay modest (baked chassis + 4 wheels).
- [x] **Building recipes.** `_build_buildings` welded two hand-authored unit meshes (`_house_mesh`,
      `_joglo_mesh`, `_plinth`) inline. Replaced with the same recipe pattern as the vehicles:
      `BUILDING_RECIPES` (index = style: 0 gable, 1 meru) is a list of parts, each a shape (box |
      gable | joglo) hung on a named socket (wall/roof/door/chimney/veranda) at an offset.
      `_bake_building_mesh` builds a unit chassis with those five sockets, hangs the parts via the
      SHARED `CharacterAssembler.apply` (the payoff of the Skeleton3D unlock -- now three consumers:
      characters, vehicles, buildings), then `MeshBaker.bake`s the kitbash to ONE ArrayMesh which the
      existing MultiMesh path instances per building -- so a settlement of that style is still a
      handful of draw calls, and the per-building tint keeps working because every part material is
      `vertex_color_use_as_albedo`. Wall/roof colours moved from vertex-colour to material albedo,
      which is byte-identical on screen (albedo * instance-tint == old vertex-colour * instance-tint).
      Per-biome part SETS are the actual variety: gable gains a door + a chimney, meru gains a front
      veranda -- that is "java stops looking like cork". `_house_mesh`/`_joglo_mesh`/`_plinth` deleted.
      Two small deliberate changes: the plinth top sits at y=0 (was 0.02) and the gable-end triangles
      are roof-coloured (were wall-coloured) since the roof part is one material -- both negligible.
      NOT runtime-tested this session: Godot execution is permission-gated -- every form (Bash
      sandboxed + unsandboxed, PowerShell, the verbatim `-- --selftest` example, with and without
      redirection) returns "requires approval", same gate as the bake/assembler/vehicle ticks. The
      GDScript was reviewed statically: recipes parse like VEHICLE_RECIPES, no slot name collides with
      a socket name, roof windings are copied vertex-for-vertex from the originals (normals unchanged),
      and every socket a part names is created. VERIFY VISUALLY on the laptop:
      `& C:\Godot\Godot_v4.5.1-stable_win64.exe --headless --path C:\Games\possession\game res://mocks/ring_vibes.tscn -- --shots millstreet,java_majapahit --only ground`
      -- expect millstreet gables with visible doors + chimneys and java_majapahit joglos with a
      veranda, both still tinted per-building, and no inside-out roofs.
- [x] **Shot framing for silhouettes (`_shot_run`).** FELL OUT of the 2026-08-16 vehicle-recipe
      review (`logs/shots/JOURNAL.md`, `logs/shots/20260816_1134_vehicle_recipes/`). The `--vehicles`
      parade cannot answer the question it is used for. Every one of the 22 frames is rear-quarter,
      at distance, with the subject about 5% of frame in failing light -- and the same fir tree sits
      dead centre, directly in front of the vehicle, in most of them. The silhouettes were *just*
      legible; that is not good enough for a judgement call that is entirely about appearance.
      A silhouette question wants: close, side-on, unobstructed, against clean sky, sun not behind
      the subject. Suggest a `--silhouette` framing that parks the camera at a fixed offset from the
      subject's bounding box (so every vehicle fills the frame the same regardless of length),
      shoots side-on and three-quarter, and either lifts above the canopy or clears scatter within a
      small radius first. This is a MULTIPLIER -- every recipe item after it is a "does it read"
      judgement, and they are all currently being reviewed through this framing.
      Do NOT re-shoot the vehicles to judge them until this exists; instrument first, per the
      journal's own standing note.
      DONE + VERIFIED THIS TICK. The `--silhouette` branch was already implemented in ring_vibes.gd
      (flag at 2452, `_shoot_silhouette` at 2487, `_shot_hold_cam` pin at 92/6639) -- built but never
      run. Ran it: `scripts/godot.cmd --path game res://mocks/ring_vibes.tscn -- --shots millstreet
      --silhouette --label silhouette`. The wrapper worked and the shots
      (`logs/shots/20260816_1625_silhouette/`) confirm the framing does its job: each subject fills
      the frame off its own bounding sphere, side-on + three-quarter, 30m scatter cleared so nothing
      stands in front, clean daylit sky, sun-lit flank. sixby/warthog read instantly; the rotor's
      disc-on-stalk failure is now unarguable. Journal entry written. Scope is vehicles/roster only,
      per the item text; the single-instance BUILDING framing (2026-08-16 journal note) stays a
      separate open item.
- [x] **Rotor recipe does not read.** FELL OUT of the same review. The `rotor` recipe renders as a
      solid octagonal plate on a stalk above the body -- a patio table or a mushroom, not a
      helicopter. It is the one recipe in the set that actively misleads about what the vehicle is.
      Silhouette-first (aesthetic.md): what says "rotorcraft" is a THIN horizontal line held well
      above a body, plus a mast -- not a filled disc, and not one that wide relative to the chassis.
      Two or four thin blade boxes on a short mast, at a smaller radius. Cheap: it is a change to one
      entry in `VEHICLE_RECIPES`, not to the recipe system.
      DONE + VERIFIED THIS TICK. Rewrote the `rotor` entry only: the 7.0-wide flat disc is gone,
      replaced by two crossed THIN blade boxes (5.5 span, 0.06 thick, 0.3 chord) on a short 0.9 mast,
      held ~1m above the body top; the tail disc became a small crossed blade pair. Ran the silhouette
      harness (`scripts/godot.cmd --path game res://mocks/ring_vibes.tscn -- --shots millstreet
      --silhouette --label rotor_read`, wrapper accepted). `logs/shots/20260816_1635_rotor_read/
      sil_rotor_{side,tq}.png` read unambiguously as a rotorcraft -- a thin blade line aloft on a mast
      plus a tail-rotor cross, not a plate. (The cyan box in-frame is the harness's selection marker,
      on every vehicle; not part of the recipe.)
      Tractor sub-note left as-is: under this clean framing the tractor's tall cab + exhaust stack +
      rear implement bar DO read as a distinct shape (the "told apart by tint" call came from the old
      dusk parade where the shapes weren't legible), so no change was warranted.
- [x] **Weapon recipes.** A receiver with barrel/stock/sight/magazine sockets. Fourteen weapons
      currently share zero geometry; the tech tree is a shape argument as much as a stats one, and
      a musket and an SMG should read as related-but-not-the-same at a glance.
      DONE + VERIFIED THIS TICK. Same pattern as the vehicle/building recipes (fourth consumer of the
      Skeleton3D-unlocked assembler): `_add_weapon_sockets` builds a receiver Node3D carrying the named
      body/barrel/sight/magazine/grip/stock mounts (local frame: muzzle -Z, up +Y); `WEAPON_RECIPES`
      hangs tinted box|cyl parts via the shared `CharacterAssembler.apply`, then `MeshBaker.bake`s each
      gun to ONE mesh. Recipes keyed by mechanics class (chemical/energy/melee/thrown/tensioned/guided)
      with name-level overrides where the SHAPE differs from its class-mate (musket, smg, lmg,
      autocannon, spear, club, blade, bow, crossbow, mortar, mlrs); `_weapon_recipe_key` aliases
      javelin→spear and speargun→crossbow. WEAPON_ROWS stays pure mechanics — shape is derived from it,
      not stored on it. A `--weapons` silhouette parade (`_weapon_parade`) floats each of the 22 rows
      above home terrain and shoots it side-on + three-quarter off its own bounding sphere.
      Ran it: `scripts/godot.cmd --path game res://mocks/ring_vibes.tscn -- --shots millstreet --only
      ground --weapons --label weapons` (wrapper accepted; parse pre-checked with --check-only). Read
      the shots in `logs/shots/20260816_1657_weapons/`: carbine/musket/smg read as related-but-not-the-
      same (the item's named test PASSES), and bow/crossbow/grenade/mlrs/etc. all read distinct. Tris
      36–300, one baked mesh each. Journal entry written. Minor cosmetic notes (musket wrist gap; parade
      backdrop is distant terrain not clean sky) logged in the journal, not worth a follow-up item.
- [x] **Structure recipes.** The dock port, and whatever else gets hand-built next. It is already
      spine + collar + struts; that is a recipe written in GDScript instead of data.
      The conversion was written by a prior tick (committed as wip 232ce38 when that run died dirty)
      but never RUN — item left unticked for verification. This tick ran it. `STRUCTURE_RECIPES` (the
      fourth consumer of the Skeleton3D-unlocked assembler) holds the `dock` entry as data: spine +
      collar + struts, with a `ring` field that radially repeats a part `count` times at `radius`
      facing outward and alternates `alt_mat` on odd segments (the lit-panel run on the collar).
      `_build_structure` assembles via the shared `CharacterAssembler.apply` and bakes to one mesh
      (two surfaces: hull + lamp); the old inline weld in `_build_walls` is gone, replaced by
      `_build_structure("dock")`. Geometry data matches the old weld exactly. VERIFIED VISUALLY via
      `scripts/godot.cmd --path game res://mocks/ring_vibes.tscn -- --shots millstreet --only dock
      --label structure_dock` (wrapper accepted): `logs/shots/20260816_2148_structure_dock/
      millstreet_dock.png` shows the spine reaching toward the axis, the collar with cyan lamp panels
      alternating with hull, and the struts between — identical to the hand-welded port, no scene-load
      error. Journal entry written. Forward half ("whatever else gets hand-built next") is groundwork;
      nothing else is hand-built to convert right now.
- [x] **Deployable** — mines, sensors, a tripod turret. Placed, then persistent.
      Already built by a prior tick (`game/pipeline/deployables.gd`, fifth consumer of the
      Skeleton3D-unlocked assembler) with a selftest and a `--deployables` parade, but never RUN --
      left unticked for verification, same as Structure recipes. This tick RAN it. Selftest PASS
      (`scripts/godot.cmd --headless --path game -s res://tests/deployables_test.gd`): every recipe
      builds to one baked mesh with geometry; a placement list survives save/load byte-for-byte; a bad
      key is filtered so it never resurrects. Visual proof via
      `scripts/godot.cmd --path game res://mocks/ring_vibes.tscn -- --shots millstreet --deployables
      --label deployables` (wrapper accepted): parade prints `placed 3 ... reloaded 3` and frames the
      RELOADED nodes -- so it is evidence of the round-trip, not just that meshes exist. The three read
      as three distinct silhouettes: mine = low disc, sensor = tall thin mast + glowing dish, turret =
      tripod + barrel (`logs/shots/20260816_2218_deployables/`, journal entry written).
      One fix made this tick: the parade CLAIMED the clean silhouette device but had only copied the
      camera offset, not the scatter-clear -- so the first run shot the sensor and turret straight
      through a fir. Added the same `_shoot_silhouette` scatter-clear (mark near trees down within 30m,
      rebuild LOD buckets) to `_deployable_parade`; second run clean. Player-placement input/HUD is a
      gameplay item, not part of this one.
- [x] **Progression rules.** The player ARRIVES from a spacefaring civilisation and gets stripped of
      it (`the-toll` in docs/vignettes.md). The tree is therefore about RECOVERING capability, not
      inventing it -- a spear is what you use when they took your rifle. That inverts the usual
      shape and is worth exploiting.
      DONE. Design/rules item -- no code surface, so no harness applies (nothing to run; not a
      "NOT runtime-tested" gap). Ratified the rule in `.decisions/progression.md#recovery-not-invention`
      (new decision file, added to INDEX): progression RECOVERS capability the player already had,
      never invents it -- the three tiers are a climb back to a baseline already seen, and the player
      keeps the KNOWLEDGE of the top of the tree while losing the means (which is what makes the-toll's
      irony load-bearing). Corollaries recorded: tiers gate on re-acquisition (found/salvaged/traded/
      taken -- the next queue items) not a research tree; no deep craft-from-scratch layer; the FP
      carbine is dev-only test loadout; knowledge leads capability. Distinguished from the WORLD's
      recovery (`recovery_band`/`tech_level`, civilization.md/lore.md) -- same story at one-person
      scale. Updated the `docs/progression.md` planning surface: folded the rule into What's Settled
      and resolved the two Open Questions it answers (tier gating shape, inventory/crafting, stripped
      start), leaving the genuinely-open sub-parts flagged. Did NOT invent mechanics or build a
      progression system in code -- the item states a principle, so the deliverable is the ratified
      principle, not a system.
- [x] **Ammunition and scarcity** as the real balance lever, not damage numbers.
      DONE + VERIFIED THIS TICK. Two deliverables: (1) ratified the balance philosophy in the decision
      log — new `.decisions/combat.md#ammunition-is-the-balance-lever` (added to INDEX): tune
      mag/reload/supply, reach for the `damage` field last, because two weapons with the same ttk are
      not the same weapon if one dries in three kills and the other in thirty. Ties to the-toll
      deprivation (progression.md), satisfies consumer-audit (named consumers: the shooter watching the
      mag go dry, diegetically off the weapon; the balance table at design time), and protects the
      "mobile not mighty" tone guard against a damage-number arms race. (2) Made scarcity a MEASURABLE
      lever, not a claim: `--range` now prints `rd/kill` (rounds a kill costs at that range's hit rate)
      and `kill/mag` (kills a full magazine buys before the reload window), computed from existing
      weapon_def fields — no new economy invented. `mag`/`reload_s` had existed unconsumed-as-a-lever;
      now they're first-class dials. Ran it: `scripts/godot.cmd --headless --path game
      res://mocks/ring_vibes.tscn -- --range carbine,smg,lmg,musket,bolt_action,autocannon` (wrapper
      accepted; RANGE done, exit 0, self-check delta 0.000m; output in logs/_range_out.txt). The columns
      read the scarcity story straight off: musket 0.5 kill/mag (one round doesn't finish a kill) vs
      bolt_action 2.5 vs lmg 33.3 vs autocannon 20.0 — wildly different supply profiles at similar ttks,
      which is the whole point. Blank for no-reach ranges and for mag-0 classes (bows/launchers pay per
      shot; energy pays heat; guided pays bulk). Total carried rounds + resupply deliberately deferred
      to the "where weapons come from" item (same acquisition hook), not invented here.
- [ ] **Where weapons come from** — found, salvaged, traded, taken. Same hook as the vehicles;
      ties into draws.
      BLOCKED (2026-08-17): same blocker as the vehicles item below. This "rides the same
      acquisition hook as vehicles (draws)" and combat.md#ammunition-is-the-balance-lever explicitly
      defers total carried rounds/resupply "downstream of the acquisition work, not invented here."
      Verified: `docs/draws.md` exists as design only; grep of `game/` for draw/salvage/loot/
      acquire/ownership/settlement finds only rendering `_draw` calls — no draws or salvage/trade/
      ownership system in the engine. Doing this now would mean inventing that economy from scratch.
      Needs the draws work first.
- [ ] **Where vehicles COME from.** Found, salvaged, stolen, traded. Ties into the draws work:
      a vehicle two valleys away is a reason to go there.
      BLOCKED (2026-08-13): `docs/draws.md` exists as design but there is no draws or settlement
      system in the engine at all, so this would mean inventing salvage/trade/ownership from scratch
      rather than wiring up something that exists. Needs the draws work first.

## Queued 2026-08-16 — decided by the user, in answer to a direct ask

- [x] **Extend `--silhouette` to buildings and structures.** The framing built for vehicles is the
      only thing in the harness that can answer a "does this read" question about an object, and it
      only knows about the vehicle roster. Buildings and structures have the same problem and no
      such framing: `building recipes` shipped with a door, a chimney and a veranda that **nobody
      has ever seen** -- the `ground` framing it recorded to verify itself contains no buildings at
      all, and from `air` a door is sub-pixel (`logs/shots/JOURNAL.md`, 2026-08-16).
      Same treatment: close, side-on and three-quarter, camera offset from the subject's bounding
      box so every subject fills the frame regardless of size, scatter cleared, clean sky.
      Subjects: one instance of each building style (gable, meru) and each structure (the dock port).
      Then USE it -- confirm the gable's door and chimney and the meru's veranda are actually there,
      and write the entry.
      DONE (2026-08-17): `_structure_parade(dir)` behind a new `--structures` shots flag (sibling of
      `--weapons`/`--deployables`, reusing the bounding-sphere silhouette device). Builds one of each
      BUILDING_RECIPE (gable, meru) and each STRUCTURE_RECIPE (dock), floats it above home, shoots
      side + front three-quarter off its own sphere (front is local +Z, so tq offsets +Z to face the
      door). RAN: `scripts/godot.cmd --path game res://mocks/ring_vibes.tscn -- --shots --structures
      --label structures` (wrapper accepted via the Bash tool; the PowerShell form prompted for
      approval, so it went through Bash). Six frames in logs/shots/20260817_0249_structures, all read:
      gable door + chimney CONFIRMED, meru veranda CONFIRMED, dock spine+collar+struts read.
      Journal entry written. Fell out: meru's tiered joglo roof reads as a flat cap (follow-up below).
- [x] **Rotor fuselage.** The blade fix (5afe963) worked: mast, main blades and tail rotor read as
      rotorcraft parts. The body under them did not change, so the whole still reads as a flatbed
      truck with a propeller bolted on rather than a helicopter. Silhouette-first: a rotorcraft is a
      SHORT, TALL fuselage sitting on skids, not a long low bed on four wheels. Give the `rotor`
      recipe its own body proportions and swap the wheels for skids.
      Scoped deliberately to the rotor. The `tractor` has a milder version of the same problem --
      told apart from the plain box by tint rather than shape -- and is NOT part of this item.
      DONE + VERIFIED THIS TICK. The code was written by a prior tick (committed in the wip ffc3422)
      but never run or ticked: `_make_car` now branches on `is_rotor` to a SHORT/TALL fuselage box
      (2.0, 2.2, 4.6) with `_add_skids` (two fore-aft skid tubes on struts) in place of the four
      wheels, and the `rotor` recipe hangs mast + crossed main blades on the raised top plus a tail
      boom + tail-rotor cross. Parse-checked clean, then ran the vehicle silhouette parade:
      `scripts/godot.cmd --path game res://mocks/ring_vibes.tscn -- --shots millstreet --silhouette
      --label rotor_fuselage` (wrapper accepted). `logs/shots/20260817_0325_rotor_fuselage/
      sil_rotor_{side,tq}.png` read unambiguously as a helicopter from both angles -- tall cabin, main
      blades aloft on the mast, tail boom + tail rotor, skids not wheels -- the "flatbed with a
      propeller" read is gone. tris=300, one baked mesh. Journal entry written.
- [x] **Meru roof reads as a flat cap, not tiers.** Fell out of the `--structures` silhouette run
      (`logs/shots/JOURNAL.md`, 2026-08-17): the meru's veranda reads, but its `joglo` roof
      (`_joglo_roof_mesh`, roof_j material) shows as a single pale block on top rather than the
      stacked pagoda tiers it is meant to be -- so a meru is a box-with-a-plank, not a tiered temple.
      Silhouette-first, same as the rotor: give the joglo form real stepped tiers (or fix why the
      existing ones don't read), then re-shoot with `-- --shots --structures` and confirm.
      DONE + VERIFIED THIS TICK. Rebuilt `_joglo_roof_mesh` as three overhanging hip tiers to a finial
      (each tier slopes up-and-in, the next eave flares back out -> the pagoda zigzag), reusing the old
      skirt's winding so generate_normals lands them outward. But the re-shoot showed the roof STILL
      missing (meru tris=36) -- so I found the actual cause: the meru roof was NEVER rendering. The
      roof shares material roof_j with the veranda (a BoxMesh), and `MeshBaker` used
      `SurfaceTool.append_from`, which SILENTLY DROPS a surface whose vertex format differs from the
      bucket's (roof = pos+normal, box = pos+normal+tangent+uv). The gable roof only worked because its
      material is unshared; the "flat pale cap" seen before was the sky-lit wall top, not the roof.
      Fixed in `game/pipeline/mesh_baker.gd`: replaced `append_from` with `_merge_surface`, re-adding
      every vertex by hand at a fixed (pos, normal, uv) format -- immune to source-format differences,
      and general (closes the same trap for any future hand-built part sharing a material with a box).
      `bake_test` still PASS (geometry preserved; other consumers are single-format so unchanged). After
      the fix meru tris=80; `logs/shots/20260817_0738_meru_tiers/building_meru_{side,tq}.png` read as a
      three-tier pagoda, correctly lit both angles. Journal entry written.
- [ ] **Verification sweep of every "NOT runtime-tested" note.** For most of this project's life the
      tick could not launch Godot (the allowlist granted a command spelling nobody types -- fixed in
      764bf46), so item after item shipped with a note saying it had not been run. Those notes are
      now checkable for the first time. Go through `TASKS.md` and `TASKS-done.md`, collect every item
      carrying "NOT runtime-tested" / "NOT run-verified" / "verify on laptop", run the harness or
      selftest each one names, and record the result against it -- passed, failed, or no longer
      applicable because the code moved.
      This is not busywork: the first three such notes checked on 2026-08-16 turned up a HEAD that
      did not compile at all (31e0132), which had been shipped past by three consecutive items.
      Fix what is cheap and obviously broken; raise a new item for anything that is not.
- [ ] **Replace `ebro_delta` and `savannah` with candidates that survive 84 km.** Both are live in
      the ring serving terrain that contradicts their catalogued biome: `ebro_delta` was scouted as a
      flat delta (p99 37 m) and now measures 1..1209 m, having re-acquired the Els Ports foothills --
      the exact failure the 2026-07-23 re-centring already fixed once. `savannah` was p99 21 m and is
      now 1..406 m.
      **THIS ITEM CARRIES EXPLICIT AUTHORISATION** to drop those two, which the standing rule at the
      top of this file otherwise forbids ("never re-centre or refetch a patch unprompted"). The
      authorisation covers `ebro_delta` and `savannah` ONLY. Do not touch any other patch.
      THE TRAP, which is the whole difficulty: `docs/terrain/splice-portfolio.md` establishes that
      small tightly-framed features -- delta plains, city footprints, single valleys -- do not
      survive a 4x widening, because the surrounding region reasserts itself. So swapping in another
      delta and another city REPRODUCES THE BUG. The real question is whether an 84 km patch of a
      "Metro/city" biome means a city, or a city and its hinterland -- and if it is the latter, the
      catalogue entry is what needs rewriting, not the location. Answer that before scouting.
      Note the coverage cost: Metro/city has only two candidates (`cork_city`, `savannah`) and is
      already flagged thin, so dropping `savannah` leaves one. Delta marsh has `camargue` and
      `danube_delta` cataloged but unscouted -- and both are subject to the same widening trap.
      Scout at the 84 km footprint, not at 22 km. Propose with `tools/dem/patch_census.py`; the image
      decides.
- [ ] **Edge feathering at patch boundaries.** The known fix for the remaining boundary steps: near a
      boundary, sample both patches and lerp by edge proximity. Never attempted because it needs
      visual iteration to judge blend width, and the last attempt at it was unattended.
      DEPENDS ON the `--silhouette`-style close framing work above -- a blend width cannot be judged
      from a landscape framing at altitude. Produce a comparison strip at several blend widths and
      put it in the journal for a human to choose from. **Do not pick the width unattended.**
      Related and separate: patches OVERLAP by ~7 km (91.3 km average width, 84 km spacing) and
      `patch_at()` returns the first match by index, so the lower-indexed patch wins the whole
      overlap band. That is the same seam problem in its sharpest form.
- [ ] **OSM roads for `cork_city`.** `pipeline.py` deliberately skips `fetch_osm_roads.py` because
      Overpass is rate-limited and 33 unattended queries risks an IP ban. Do this one deliberately
      and throttled. Cork's organic (non-grid) street character is currently asserted from real-world
      knowledge, never verified against actual OSM data.
      `savannah`'s roads were part of this task and are DEFERRED: the replace item above may delete
      that patch entirely, and fetching roads for a patch that is about to be dropped spends a
      rate-limited budget on nothing.
- [ ] **Height calibration against real DEM terrain.** No haze or boundary-layer height has ever been
      tuned against the real terrain -- every value in `ring_vibes.gd` was picked ad hoc against
      whichever terrain, noise or real, happened to be loaded that session. This is the missing
      groundwork under the atmosphere-density decision (`.decisions/world.md`), which has a shape but
      no real numbers. Needs a dedicated pass with the ring height-scale otherwise settled.
