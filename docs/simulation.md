# Possession — Simulation Architecture

The runtime half of the world: bake layers produce *space* (terrain.md), this stack produces *time*. Extracted from progression.md 2026-07-19. Sibling docs: [knowledge.md](knowledge.md) (the player's pyramid), [dialogue.md](dialogue.md) (baked voice), [operators.md](operators.md) (operator registry).

## Runtime Layer Stack — the player-POV sandbox (PROPOSED 2026-07-18)

No missions, architecturally enforced: the bake DAG ends where player time begins; this mirror stack runs live:

- **R0 — persistent facts:** player impact, deaths, taken objects — the only durable world mutations (selective persistence). **Datomic precedent (2026-07-26):** independently reinvented Rich Hickey's Datomic model — facts as immutable, accretive tuples (entity, attribute, value, cause, transaction), never updated/deleted, only superseded. `.decisions/`'s SUPERSEDED-not-deleted discipline and K4 staleness (a timestamped observation vs. current `fact_version`) are already exactly Datomic's "as of" time-travel query, independently arrived at. Worth borrowing explicitly: **one universal fact tuple shape across every system** (terrain edits, faction events, inventory, not just knowledge/rumor) rather than bespoke per-system fact representations — a uniform shape means one generic "why"/"since when" query mechanism works everywhere. Also generalizes staleness beyond the player: any entity with a personal as-of pointer into the fact log can honestly disagree with another (two guards in the same room, one just back from months away) for free, same mechanism as K4.
- **R1 — pressures:** derived from facts, decay and propagate
- **R2 — intentions:** factions, key NPCs, **and the player as just another intention-holding entity** — not a special customer of a content system
- **R3 — actions:** world-side moves to reduce pressure
- **R4 — encounters:** only where actions intersect a player's bubble — views into the simulation, never content
- **R5 — arc director:** the authored spine scheduled as *inevitabilities on world logic*, indifferent to player readiness, minimally gated for finishability only. Not missions — weather.

Player-facing surface: the **self-authored journal** — pins are player-authored goals; the bone-thrower reads pins as signal for where to leak information and tilt generation. The world never assigns; it answers in gradients. Per-player in co-op.

## Tempo — pacing as shared clocks (PROPOSED 2026-07-19)

LayerBuf's twin in time ("the conductor"): systems are *consumers* of shared tempo signals, never directly wired to each other. Few writers (player-state model, arc phase, biome, regional pressure), many readers (AI tick rates, spawn budgets, rumor frequency, weather, music).

Clock hierarchy: **arc clock** (global, counts in day/night *cycles*) → **regional clocks** (statistical-tier tick rates, pressure-heated) → **encounter clocks** (combat tempo/threat rhythm) → **micro clocks** (AI decision ticks). Example: aggressive play → encounter tempo → slower/worse enemy decisions, reading as *morale under pressure*, not a difficulty dial — the connection is laundered through the clock. Biome tempo is InfoOpacity's temporal sibling.

**Naming note (2026-07-29):** informally these are **spacebuf** and **timebuf**, which reads better than LayerBuf/TempoBuf and makes the pairing obvious. Keep the asymmetry in view when using the shorthand: spacebuf is a composable bakeable **DAG**; timebuf is deliberately **not** a mirrored stack (four nested clocks + a mixing rule) because space composes ahead of time and time cannot. Also distinct from `.decisions/design-laws.md#no-authored-graphs`, which bans authored *content* graphs (dialogue/quest trees) — spacebuf is a *computation* DAG and is unaffected.

**Is intention ever baked? No — never.** `factions.md`'s "Identity Baked, Behavior Live" is the rule: L5 bakes *who* a faction is (watersheds seed polities; grievances are facts with coordinates), runtime intention stays live. It has to, by definition of the intention boundary: intention is the thing that reads space (where is possible) **and** time (when is ripe). Baking it freezes the half that cannot be precomputed. You can write the score in advance; you cannot pre-decide when the musician plays.

**TempoBuf structure:** no mirrored L0–L9 stack — space composes ahead of time (bakeable DAG), time is live. TempoBuf = the four nested clocks + a **mixing rule**: writers register named modifiers per clock; a fixed clamped combinator resolves them. Writer set grows additively; clock structure stays fixed. The **intention boundary** is where the bufs meet — never buf-to-buf: an entity reads space (where is possible) + time (when is ripe) and commits. Score, beat, musician.

**Temporal syncopation — PROPOSED 2026-07-29.** Syncopations currently exist only in *space*: anomaly seeds perturbing foundational bake layers, cheap upstream and outsized downstream (`terrain/layerbuf-v0.md`). The music intuition was never applied to the other buf. The temporal twin: sparse baked notes that perturb **clock inputs** — a region whose market cycle runs against its neighbours' beat, a seasonal raid that lands off the arc clock's downbeat, a hold whose patrol rhythm is a half-cycle out of phase with the caravans it preys on.

The governing law transfers unchanged and is what keeps this honest: `operators.md`'s syncopation contract is *"perturbs inputs to later bake layers; never scripts outcomes."* A temporal syncopation therefore perturbs **clock rates and phases**, never schedules events. Interleaving, phase offset and syncopation are prepared; what actually happens is still emitted live by entities reading both bufs. Score prepared, performance live.

### Pre-biased, not pre-decided — the operative distinction (2026-07-29)

Intention **is** baked — as *bias*, never as outcome. The distinction carries the whole design:

- **Pre-decided** — faction does X at time T. Fixes the outcome, so preconditions become decoration and interception becomes impossible. This is what breaks the architecture: it contradicts bottom-up intentions against a sparse top-down director, kills the hail mary that interceptable defaults exist to permit, and makes the world a script wearing simulation's clothes (the no-missions sin through the pacing door).
- **Pre-biased** — faction is *disposed toward* X, and more so at certain phases. Shapes the distribution; leaves the outcome live, precondition-gated, and interceptable.

Pre-biasing needs **no new mechanism** — it is the machinery already ratified, pointed at intention instead of placement:

| | Realization (existing) | Intention (this) |
|---|---|---|
| Baked input | LayerBuf fields score candidate sites | faction repertoire + time-varying weights over it |
| Selection | seeded softmax, `hash(world_seed, entity_id, fact_version, time_bucket)` | same |
| Sharpness | temperature = readability | temperature = how *legible* this faction's disposition is |
| Guarantee | observation never rerolls | same |

So a faction's baked identity carries a **time-varying prior over its repertoire** — a seasonal raid disposition that rises and falls, a trade posture that peaks on market cycles. Temporal syncopations perturb those priors (phase-shifting one region's raiding against its neighbour's harvest). The entity still reads space and time at the intention boundary, still checks preconditions, still commits live.

**That is literally a prepared song:** the score says what is *likely* at each bar; the performance is still played. And it strengthens the inference framing (`consumers.md`) rather than competing with it — a bias is a **pattern**, and patterns are what a player can learn. Pre-decided outcomes would be unlearnable in principle (nothing to generalise from until it happens); pre-biased dispositions are exactly what "reading" a faction means. Softmax temperature becomes a per-faction legibility dial: cold factions are predictable and readable, hot ones erratic and opaque.

**What is baked, in full:** identity and history (L5), repertoire (which intentions are available, with preconditions), a **time-varying prior** over that repertoire, and a **rhythmic signature** — how the faction emits when acting (market-day shape, patrol cadence, the tempo of a build-and-release border dispute). `factions.md`'s "Identity Baked, Behavior Live" extended with a *temporal* identity. Baked instrument, repertoire and inclination; live performance.

**Intensity, never valence:** events and tempo signals carry no "good/bad for player" labels as control inputs — valence is contextual in a composed world, flattens co-op asymmetry, and a fairness-optimizing director makes the world secretly caring (the missions sin via the pacing door). The conductor budgets *intensity* — a scalar from player-side observables, post hoc. It avoids monotony; it never helps. Relief arrives as tilted opportunity gradients, never outcomes. Valence labels live in telemetry only.

## Fidelity & Realization — seeded softmax (PROPOSED 2026-07-19)

- **Realization = seeded softmax over coarse facts:** candidate sites scored from LayerBuf fields, softmaxed, sampled with seed `hash(world_seed, entity_id, fact_version, time_bucket)`. **Observation never rerolls the world; only events do** — re-visits, reloads, save-scums reproduce the same realization; fact_version increments on migration/predation/season, never on being looked at. Statistical inevitability without farmable randomness; witnessing stays honest.
- **Temperature = readability:** softmax temperature driven by information topology — readable zones run cold (sharp, learnable patterns), information-poor zones run hot. Biome legibility and sampling math are one mechanism.
- **Conservation gate:** `summarize(realize(fact)) ≈ fact ⊕ events` — realize 6 deer, 2 die, collapse-up writes 4, never resamples 6. Runtime sibling of the bake gates, same verification ladder.
- **Three pyramids, one addressing scheme:** storage (bake tiles), simulation (fidelity cells), knowledge (per-player — see knowledge.md).

## Arc Director Rules (PROPOSED 2026-07-19)

- Director and intentions stay separate: intentions distributed/bottom-up, director sparse/top-down. The director **schedules facts and sets tempo, never commands entities** — the simulation reacts honestly as deadlines approach.
- **Inevitabilities are scheduled as defaults, never scripted as outcomes.** Causality runs through simulated preconditions, so interception is possible in principle — the *hail mary* is a property of honest causality, never designed, never advertised. Default fires in ~99% of playthroughs.
- **Fixed beats vs negotiable inevitabilities:** the crash, THE city, the relay being on, the armada's arrival are load-bearing drumline — not interceptable. Negotiable inevitabilities (a second city, a settlement, the medieval battle) are where hail marys live.

## Ending Vignette Assembly (PROPOSED 2026-07-22)

The "leave" ending (vision.md, moments/the_return.md) reuses the dialogue bake's pattern rather than needing a new system: a **precondition-tagged content pool**, selected at runtime against actual state — here, R0's persistent facts plus the ringing player's knowledge pyramid, sampled once at the moment of ringing (`assemble_ending`, see operators.md). Consistency gate: no selected vignette may contradict a current fact — the runtime sibling of the bake gates and the fidelity conservation gate, same verification ladder, one more rung. Once assembled, the sequence is fixed and authored (song-scored) — off the tempo director's leash entirely, symmetric with the landing sequence's fixed, non-systemic opening. The game is authored at both ends, alive in the middle.

## Worked Example — the deer

Bake writes habitat, never animals (L1 spring → L2 moisture → L3 meadow pocket → L4 `deer_habitat`; L6 stamps the crash corridor near deer habitat — "deer before wolves" as placement bias, not trigger). Runtime realizes a herd from habitat × a coarse persistent herd fact; deer micro-clock runs slow. **The deer's key TempoBuf integration is a null write** — zero intensity, no encounter-clock touch, no music wake: silence is systems refraining, not absent. Stagnation detection reads progress observables, not event rate, so pastoral quiet never triggers a bone. The wolves later realize from the *same* fields at night with hunger pressure and write the encounter clock hard — same substrate, opposite tempo signature; the corruption is mechanical, not scripted.

**Slice consequence:** the first slice (brief §9) runs with zero of this stack — the cheapest test of the no-mission bet. The deer clearing's null write is an assertable acceptance test: if anything twitches when the player meets the herd, the implementation violated the moment.

## Open Questions (warm threads)

- **Mixing-rule combinator spec:** TempoBuf's one frozen interface — exact combinator (clamped product? sum-then-clamp?), modifier registration schema, per-clock bounds. Deserves the substrate treatment before any consumer code exists.
- **Precondition audit for negotiable inevitabilities:** for each scheduled default, verify an honest causal chain exists in the sim (interceptable preconditions) — else it's a cutscene in simulation clothes. This is a bake-gate for *time*; define the audit checklist.
- **Player-state model shared by conductor + bone-thrower:** aggression and stagnation are read by both — design the observable set once, not twice.
- **Cycle length bounds:** the arc counts in day/night cycles; pacing math and moment staging both constrain day length — capture bounds when #9 mocks test the terminator sweep.
