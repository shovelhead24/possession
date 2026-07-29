# Design Laws (cross-system)

Laws a future session could violate silently — the core reason this log exists. Each independently supersedable.

### decomplect — Ask what's braided together that doesn't need to be
**Date:** 2026-07-26
**Status:** active
**Decision:** A standing review question for every future system: what independent concerns have been braided ("complected," Rich Hickey's term — from Latin *complectere*, to weave together) into one piece that could instead be kept separate and composed? Not a new mechanic — a naming of a discipline already practiced without a name.
**Why:** Every clean split this project has made was this question answered correctly in advance: tempo kept separate from perception (perception.md) rather than folded into TempoBuf; the fine rendering tile grid kept separate from the coarse simulation grid rather than forced to share one resolution; dialogue's baked content kept separate from its runtime selection (dialogue.md). Every real bug caught this session was an accidental braid nobody noticed (fetch_s2.py's output path braided to "millstreet" regardless of input; terrain winding braided to an unverified assumption about Godot's culling convention). Hickey's value-vs-place distinction is the same principle at the data level: a value (immutable, freely shareable) versus a place (mutable, silently drifting) is deliberately how "observation never rerolls the world" already works — the world's state is a value, not a place.

### principles-ratified — The six brainstorm principles are law
**Date:** 2026-07-19
**Status:** active
**Decision:** Ratified as a set (closes brief D1): (1) simulate the player's relationship to the world, not the world; (2) we do not simulate detail — we acknowledge it; (3) the Fern Rule — interaction fidelity ≤ visual fidelity × system importance; (4) a low-fidelity cell is a promise of possibility, not a place; (5) encounters are not content — they are consequences; (6) the world never rewards the player directly — it reshapes opportunity gradients.
**Why:** Proposed April 2026, they silently governed everything designed in the July restart (bake pipeline, realization, tempo, knowledge). Two days of building on them without strain is the ratification test passed.

### no-missions — No mission/quest layer, ever
**Date:** 2026-07-19
**Status:** active
**Decision:** No mission system in any form. Player goals are self-authored (journal pins); the world responds with opportunity gradients (bone-thrower) and scheduled inevitabilities (arc director), never assignments. See simulation.md.
**Why:** Architecturally, bake produces space and runtime produces time — missions fit neither. Thematically, a mission is the world orienting around the player, which deletes witnessing-over-heroism. The moment docs repeat "no quest trigger" like a drumbeat.

### intensity-not-valence — The conductor budgets intensity, never valence
**Date:** 2026-07-19
**Status:** active
**Decision:** No "good/bad for player" labels as control inputs anywhere in tempo/direction. The conductor reads intensity (post-hoc scalar from player-side observables) to avoid monotony; it never helps. Relief arrives only as tilted opportunity gradients. Valence labels are legal in telemetry dashboards only.
**Why:** Valence is contextual in a composed world (labels lie on composition), flattens co-op asymmetry, and a fairness-optimizing director makes the world secretly caring — the missions sin re-entering through the pacing door.

### observation-never-rerolls — Only events re-sample the world
**Date:** 2026-07-19
**Status:** active
**Decision:** Realization is a pure function: seed = hash(world_seed, entity_id, fact_version, time_bucket). Revisits, reloads, and save-scums reproduce identical realizations; fact_version increments on world events only, never on observation.
**Why:** Statistical inevitability without farmable randomness. What the player witnessed was *the* state of the world, not a dice roll they happened to catch — witnessing stays honest, and save-scumming dies by construction.

### layer-backpropagation — A blocker or ambiguity in one layer amends the layer beneath it
**Date:** 2026-07-22
**Status:** active
**Decision:** When a decision at one layer (narrative, R-stack, any consumer) creates a blocker or ambiguity that only a lower layer (substrate, bake, LayerBuf) can resolve, that lower layer gets amended immediately — not worked around, not deferred. First instance: the leave-ending portal needed a hub location reaching toward the spin axis; the substrate didn't have one, so `docs/terrain/substrate.md` was amended same-day with the axis-singularity gate (see "Axis Structures" there) rather than the portal being hand-waved as "just floats somewhere."
**Why:** This is the design-time expression of "generous interfaces, naive engines" (`.decisions/terrain.md`) — cost-of-change stays cheap only if lower layers are actually kept current when upper layers expose a gap, rather than accumulating silent debt the substrate doc doesn't know about.

### diegetic-tools-not-hud — QoL/information systems must be physical, ownable tools, not HUD
**Date:** 2026-07-22
**Status:** active
**Decision:** Any convenience that would normally be a free HUD element (zoom, bearing-to-waypoint, dialect legibility, night vision) is instead represented as a found, ownable, losable in-world tool. See docs/tools.md.
**Why:** Extends the Fern Rule (interaction fidelity must be earned) and the knowledge-pyramid's no-omniscient-map precedent (already true of the journal before this was named) into a general UI law. Side effects, all desirable: tools become collectibles, form a natural acquisition tree (a third ladder alongside transport and progression tiers), and are the concrete substrate of the replay-value thesis — mastery as route/acquisition-order knowledge, which only works because same-seed NG+ keeps the world knowable.

### world-never-reads-knowledge — The knowledge pyramid has exactly two consumers
**Date:** 2026-07-19
**Status:** active
**Decision:** Player knowledge (knowledge.md) is read by the bone-thrower and dialogue selection only. World simulation and realization never read it.
**Why:** The ring doesn't know you're watching. Indifference enforced by API surface, not by discipline.

### no-authored-graphs — Content is precondition-tagged pools, never authored trees or graphs
**Date:** 2026-07-29
**Status:** active
**Decision:** No dialogue trees, quest graphs, or behaviour trees-as-content. Content is authored as a **pool of fragments tagged with preconditions**, selected at runtime by a seeded pick against live facts. No nodes, no edges, no traversal.
**Why:** Hand-authoring cost scales with branch count, and this project is bounded by what one person plus AI assistance can build — a branching structure large enough to feel alive is exactly the thing the budget cannot pay for, and the failure is silent (you find out late, having built half of it). The pool pattern is already established in two places rather than being new: the dialogue bake and the ending-vignette assembly both do precisely this. Pools also degrade gracefully — an under-populated pool yields repetition, whereas an under-populated tree yields dead ends.
**Corollary:** consequence systems inherit this. "The world returns your actions to you" (`docs/draws.md` returning draws) must be pools + preconditions + provenance, never an authored consequence graph.

### consumer-audit — Every simulated quantity names a consumer, or is coarsened or cut
**Date:** 2026-07-29
**Status:** active
**Decision:** Every simulated quantity must be traceable to at least one named **player consumer** (`docs/consumers.md`) — or be explicitly classified as a cheap hidden driver, coarsened until it costs nothing, or cut. The rule is not "everything must be visible"; it is "we must know which of the three each thing is."
**Why:** The scope failure this project is most exposed to is not too few features but **simulation nobody perceives** — state computed, propagated and conserved that never reaches a player. It is invisible in playtesting by construction, so it cannot be caught by looking at the game; only an explicit audit catches it. Generalises the reasoning already used in `world-never-reads-knowledge` ("exactly two consumers") from knowledge to everything. Claimed consumers are hypotheses until a mock shows a player consuming them — same evidentiary standard the terrain work used.

### interaction-fidelity — Tiers 0-4 ratified as a constraint, not a system
**Date:** 2026-07-19
**Status:** active
**Decision:** Closes brief D1b. Every object's allowed interaction is capped by `Interaction Fidelity ≤ Visual Fidelity × System Importance`. Five tiers, by purpose: 0 static signal (read-only, e.g. distant skyline) · 1 passive reactivity (1-2 non-persistent animation states, e.g. fern bends and resets) · 2 binary interaction (2-3 states, may persist locally, e.g. door open/closed) · 3 stateful system node (multiple states, memory, feeds other systems, e.g. generator, camp) · 4 narrative/system anchor (rare, highly legible, e.g. relay pylon). The Fern Rule is tier 1's worked example: low-poly + background-importance means bend/rustle/shadow-disturb only — never health, damage, harvesting, or AI attention hooks. Frame budget scales with tier (0 frames at tier 0 up through richer blending at tier 3+, detailed in research/chatgpt-brainstorm-2026-04.md).
**Why:** Already load-bearing before ratification — it's the reasoning behind "no harvestable ferns" and every "acknowledge, don't simulate" call so far. Ratifying it as a constraint (not a system to build) costs nothing now and forecloses scope leaks later: an artist can't accidentally promise interactivity a background asset can't back up.
