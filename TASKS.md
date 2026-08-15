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

## Vehicles — the 40+ programme

Framing, because this only works one way. **40 vehicles is not 40 models.** It is a small set of
locomotion models, each parameterised, with generated or kitbashed meshes over the top. Done as
bespoke assets it is forty art tasks and it never ships; done as ~7 movement classes x parameters
it is a fortnight and the count falls out for free. Same argument as the tree species: the project
already generates its houses, hedges, palms and textures.

Prerequisite for everything below.

### Cross-cutting
- [ ] **Where vehicles COME from.** Found, salvaged, stolen, traded. Ties into the draws work:
      a vehicle two valleys away is a reason to go there.
      BLOCKED (2026-08-13): `docs/draws.md` exists as design but there is no draws or settlement
      system in the engine at all, so this would mean inventing salvage/trade/ownership from scratch
      rather than wiring up something that exists. Needs the draws work first.
## Weapons, HUD and on-foot — the tech-tree programme

Same framing as the vehicles, for the same reason. **A tech tree from a sharpened stick to a
backpack MLRS is not 40 weapon models.** It is ~7 mechanics classes, each parameterised, with
placeholder shapes over the top. Mechanics first: a weapon that looks right and feels wrong is
worse than a grey box that feels right, and feel is measurable.

The carbine already exists as a model with FP arms (`.decisions/` and `assets/`), so this is about
behaviour, not art.

### Mechanics classes (each is a parameter set, not a weapon)
- [ ] **Deployable** — mines, sensors, a tripod turret. Placed, then persistent.

### The tree itself
- [ ] **Progression rules.** The player ARRIVES from a spacefaring civilisation and gets stripped of
      it (`the-toll` in docs/vignettes.md). The tree is therefore about RECOVERING capability, not
      inventing it -- a spear is what you use when they took your rifle. That inverts the usual
      shape and is worth exploiting.
- [ ] **Ammunition and scarcity** as the real balance lever, not damage numbers.
- [ ] **Where weapons come from** — found, salvaged, traded, taken. Same hook as the vehicles;
      ties into draws.

### On foot
- [ ] **FPS controls proper.** WALK mode is a camera with a speed. Needs: acceleration, crouch,
      sprint with a cost, jump, fall damage, stance affecting spread, and the ring frame handled
      correctly (up points at the axis, which the camera already does and the movement does not).
- [ ] **HUD.** Currently a debug wall of text. Needs a real one -- and per
      `.decisions/design-laws.md#diegetic-tools-not-hud`, **information must be a physical ownable
      tool, not free overlay**. Ammo count comes from looking at the weapon; bearing comes from a
      compass you found. That law makes this design work, not just layout work.
- [ ] **Damage model** — locational, on the player and on NPCs, shared with the creature system that
      already exists.

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
