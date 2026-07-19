# Possession — Simulation Architecture

The runtime half of the world: bake layers produce *space* (terrain.md), this stack produces *time*. Extracted from progression.md 2026-07-19. Sibling docs: [knowledge.md](knowledge.md) (the player's pyramid), [dialogue.md](dialogue.md) (baked voice), [operators.md](operators.md) (operator registry).

## Runtime Layer Stack — the player-POV sandbox (PROPOSED 2026-07-18)

No missions, architecturally enforced: the bake DAG ends where player time begins; this mirror stack runs live:

- **R0 — persistent facts:** player impact, deaths, taken objects — the only durable world mutations (selective persistence)
- **R1 — pressures:** derived from facts, decay and propagate
- **R2 — intentions:** factions, key NPCs, **and the player as just another intention-holding entity** — not a special customer of a content system
- **R3 — actions:** world-side moves to reduce pressure
- **R4 — encounters:** only where actions intersect a player's bubble — views into the simulation, never content
- **R5 — arc director:** the authored spine scheduled as *inevitabilities on world logic*, indifferent to player readiness, minimally gated for finishability only. Not missions — weather.

Player-facing surface: the **self-authored journal** — pins are player-authored goals; the bone-thrower reads pins as signal for where to leak information and tilt generation. The world never assigns; it answers in gradients. Per-player in co-op.

## Tempo — pacing as shared clocks (PROPOSED 2026-07-19)

LayerBuf's twin in time ("the conductor"): systems are *consumers* of shared tempo signals, never directly wired to each other. Few writers (player-state model, arc phase, biome, regional pressure), many readers (AI tick rates, spawn budgets, rumor frequency, weather, music).

Clock hierarchy: **arc clock** (global, counts in day/night *cycles*) → **regional clocks** (statistical-tier tick rates, pressure-heated) → **encounter clocks** (combat tempo/threat rhythm) → **micro clocks** (AI decision ticks). Example: aggressive play → encounter tempo → slower/worse enemy decisions, reading as *morale under pressure*, not a difficulty dial — the connection is laundered through the clock. Biome tempo is InfoOpacity's temporal sibling.

**TempoBuf structure:** no mirrored L0–L9 stack — space composes ahead of time (bakeable DAG), time is live. TempoBuf = the four nested clocks + a **mixing rule**: writers register named modifiers per clock; a fixed clamped combinator resolves them. Writer set grows additively; clock structure stays fixed. The **intention boundary** is where the bufs meet — never buf-to-buf: an entity reads space (where is possible) + time (when is ripe) and commits. Score, beat, musician.

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

## Worked Example — the deer

Bake writes habitat, never animals (L1 spring → L2 moisture → L3 meadow pocket → L4 `deer_habitat`; L6 stamps the crash corridor near deer habitat — "deer before wolves" as placement bias, not trigger). Runtime realizes a herd from habitat × a coarse persistent herd fact; deer micro-clock runs slow. **The deer's key TempoBuf integration is a null write** — zero intensity, no encounter-clock touch, no music wake: silence is systems refraining, not absent. Stagnation detection reads progress observables, not event rate, so pastoral quiet never triggers a bone. The wolves later realize from the *same* fields at night with hunger pressure and write the encounter clock hard — same substrate, opposite tempo signature; the corruption is mechanical, not scripted.

**Slice consequence:** the first slice (brief §9) runs with zero of this stack — the cheapest test of the no-mission bet. The deer clearing's null write is an assertable acceptance test: if anything twitches when the player meets the herd, the implementation violated the moment.
