# Possession — Progression

Three tiers, from prey to power (docs/vision.md). Least-developed system — nothing in code yet; this doc is the planning surface.

## What's Settled

1. **Survival** — prey, no power. Crash, stripped, hunted at night. Player starts with nothing, including weapons.
2. **Medieval** — people, factions, bows. Settlements, the army, human-scale conflict.
3. **Ancient Alien** — tech that changes everything. The hookshot (Moment 12) is the flagship: first swing across a canyon.

The arc runs crash → stripped → hunted → survivor → discover people → climb → relay → armada → choice.

## Open Questions

- **What gates the tiers?** Story beats, found tech, faction trust, geography? Is tier progression per-player in co-op?
- **Is there an inventory/crafting layer,** or is progression purely about acquired capabilities (weapon, bow, hookshot)? Survival-tier "prey" implies at least fire/shelter/food questions — how deep does that go before it fights the witnessing tone?
- **Traversal as progression** — "if you can see it you can reach it" (terrain non-negotiable) may be *earned*: reachable at tier 1 by walking, at tier 3 by hookshot. Or must everything be walkable from the start? Directly shapes the terrain plan (issue #1).
- **Death and saves** — what does dying cost at each tier? Couch co-op revive vs solo?
- **The stripped start vs the FP carbine** — current game hands you a carbine immediately (dev convenience). Tier 1 has none. When does the real arc replace the test loadout?
- **Asymmetric progression** — protagonist two starts "already moving" with knowledge protagonist one lacks. Do they also differ in capabilities?

## Runtime Layer Stack — the player-POV sandbox (PROPOSED 2026-07-18)

No missions, architecturally enforced: the bake DAG (terrain.md) produces *space* and ends where player time begins; a mirror stack runs at runtime and produces *time*:

- **R0 — persistent facts:** player impact, deaths, taken objects — the only durable world mutations (the brainstorm's selective persistence)
- **R1 — pressures:** derived from facts, decay and propagate
- **R2 — intentions:** factions, key NPCs, **and the player as just another intention-holding entity** — not a special customer of a content system
- **R3 — actions:** world-side moves to reduce pressure
- **R4 — encounters:** only where actions intersect a player's bubble — views into the simulation, never content
- **R5 — arc director:** the authored spine (city destruction, relay state, armada) scheduled as *inevitabilities on world logic*, indifferent to player readiness, minimally gated for finishability only. Not missions — weather.

Player-facing surface: a **self-authored journal** — the player pins their own goals (rumors, a marked far-side light, the pilot's object); the bone-throwing system reads pins as signal for where to leak information and tilt generation. The world never assigns; it answers in gradients. Per-player in co-op (asymmetric knowledge → two journals over the same terrain).

### Tempo — pacing as shared clocks (PROPOSED 2026-07-19)

LayerBuf's twin in time ("the conductor"): systems are *consumers* of shared tempo signals, never directly wired to each other. Few writers (player-state model, arc phase, biome, regional pressure), many readers (AI tick rates, spawn budgets, rumor frequency, weather, music).

Clock hierarchy: **arc clock** (global, counts in day/night *cycles* — day length tuning now has a consumer) → **regional clocks** (statistical-tier tick rates, pressure-heated) → **encounter clocks** (combat tempo/threat rhythm) → **micro clocks** (AI decision ticks — grenade timing, "cleverness tick"). Example: aggressive play → encounter tempo → slower/worse enemy decisions, reading as *morale under pressure*, not a difficulty dial — because the connection is laundered through the clock. Biome tempo is InfoOpacity's temporal sibling (forest slow and dreadful, ridge fast and legible).

**Intensity, never valence (2026-07-19):** tempo signals and events are never labeled "good/bad for player" as control inputs — valence is contextual in a composed world (labels lie on composition), it flattens co-op asymmetry (good for *which* player?), and a director optimizing fairness makes the world secretly caring — the missions sin re-entering through the pacing door. The conductor budgets *intensity*: a scalar measured from player-side observables after the fact (health lost, resources drained, time-since-event). It avoids monotony; it never helps. Needed relief arrives as tilted opportunity gradients (bone-thrower), never as outcomes. Valence labels are permitted in exactly one place: telemetry/playtest dashboards — observability, never consumed by the director.

**TempoBuf structure (2026-07-19):** no mirrored L0–L9 stack — space composes ahead of time (bakeable DAG), time is live. TempoBuf = the four nested clocks + a **mixing rule**: writers register named modifiers (biome base, pressure heat, player-state) per clock; a fixed clamped combinator resolves them. Writer set grows additively (LayerBuf field discipline); clock structure stays fixed. The **intention boundary** is where the bufs meet — never buf-to-buf: an entity reads space (where is possible) + time (when is ripe) and commits an intention. Score, beat, musician.

**Worked example — the deer (2026-07-19):** bake writes habitat, never animals (L1 spring → L2 moisture → L3 meadow pocket → L4 `deer_habitat`; L6 stamps the crash corridor near deer habitat, making "deer before wolves" a placement bias, not a trigger). Runtime realizes a herd from habitat × a coarse persistent herd fact; deer micro-clock runs slow. **The deer's key TempoBuf integration is a null write** — zero intensity, no encounter-clock touch, no music wake: silence is systems refraining, not absent. Stagnation detection reads progress observables, not event rate, so pastoral quiet never triggers a bone. The wolves later realize from the *same* fields (`wolf_range = forest edge × deer_habitat`) at night with hunger pressure and write the encounter clock hard — same substrate, opposite tempo signature; the corruption is mechanical, not scripted.

### Fidelity & realization — seeded softmax (PROPOSED 2026-07-19)

*(Growing candidate for extraction into its own simulation.md area doc.)*

- **Realization = seeded softmax over coarse facts:** candidate sites scored from LayerBuf fields, softmaxed, sampled with seed `hash(world_seed, entity_id, fact_version, time_bucket)`. Re-visits, reloads, and save-scums reproduce the same realization — **observation never rerolls the world; only events do** (fact_version increments on migration/predation/season, never on being looked at). Statistical inevitability without farmable randomness; witnessing stays honest.
- **Temperature = readability:** softmax temperature driven by information topology — readable zones (low InfoOpacity) run cold: sharp, learnable patterns (the herd at the spring at dawn); information-poor zones run hot and diffuse. Biome legibility and sampling math are one mechanism.
- **Conservation gate:** `summarize(realize(fact)) ≈ fact` plus event deltas — realize 6 deer, 2 die, collapse-up writes 4, never resamples 6. Counts/resources conserved across fidelity transitions; runtime sibling of the bake gates, same verification ladder.
- **Three pyramids, one addressing scheme:** storage (bake tiles), simulation (fidelity cells), and **knowledge** — the player's journal/map is a personal fidelity pyramid over the same tiles (rumor = coarse, map fragment = medium, visited = fine), with InfoOpacity governing refinement rate. Exploration = pulling regions up your own resolution pyramid; co-op asymmetric knowledge = two knowledge pyramids, one world.

### Arc director rules (PROPOSED 2026-07-19)

- Director and intentions stay separate: intentions are distributed/bottom-up, the director is sparse/top-down. The director **schedules facts and sets tempo, never commands entities** — the simulation reacts honestly as deadlines approach (scheduled city burn → prices, rumors, refugees, shifted faction intentions).
- **Inevitabilities are scheduled as defaults, never scripted as outcomes.** Causality must run through simulated preconditions, so interception is possible in principle — the *hail mary* is a property of honest causality, never designed, never advertised (no UI, no timer, no hint). Default fires in ~99% of playthroughs; theme intact.
- **Fixed beats vs negotiable inevitabilities:** the crash, THE city (protagonist two's origin), the relay being on, the armada's arrival are load-bearing drumline — not interceptable. Negotiable inevitabilities (a second city, a settlement, the medieval battle) are where hail marys live.

**Slice consequence:** the first slice (brief §9) runs with zero of this stack — it is the cheapest possible test of the no-mission bet. If task-free walking through the world is compelling, the thesis holds before we build R0–R5 at all.

## Tone Guard

Progression serves witnessing, not power fantasy — the biggest things still happen without you (docs/vision.md). Tier 3 makes you mobile, not mighty.
