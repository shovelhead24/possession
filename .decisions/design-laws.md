# Design Laws (cross-system)

Laws a future session could violate silently — the core reason this log exists. Each independently supersedable.

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

### world-never-reads-knowledge — The knowledge pyramid has exactly two consumers
**Date:** 2026-07-19
**Status:** active
**Decision:** Player knowledge (knowledge.md) is read by the bone-thrower and dialogue selection only. World simulation and realization never read it.
**Why:** The ring doesn't know you're watching. Indifference enforced by API surface, not by discipline.
