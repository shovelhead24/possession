# Factions

Ratified from `docs/factions.md`'s Open Questions (2026-07-29). The area doc stays the design-space
record; these are the settled calls. Faction *count/scale* is deliberately not here — it stays a
tuning value the L5 history pass derives from communication speed (rumor decay × horse range).

### relay-woken-by-living-faction — A living instrumental faction woke the relay
**Date:** 2026-07-29
**Status:** active
**Decision:** The relay was reactivated by a **living** faction on the instrumental end of the cosmology axis — not a dead one, and not self-reactivation by the ancient system.
**Why:** The cosmology axis (`docs/factions.md`) was built partly to supply a suspect pool for exactly this mystery; a living culprit is the only option that actually uses it, since a dead faction turns the question into archaeology and self-reactivation removes the political thread entirely. It also makes the relay a fact with an *owner* — findable, arguable, exposable — and rhymes with the player's own arc: someone already did what you are going to do. That converts **misattributed reactivation** (the author's-cut #1 dynamic) from a one-off gag into a pattern the world was already running before you arrived.
**Open follow-up:** whether that instrumental faction is the human-survivor faction below. The survivors are the most plausible candidates — they would know what a relay *is* — and the convergence is elegant enough to be worth deciding deliberately rather than drifting into. Not decided here.

### human-survivor-faction — Scattered mission crew exist as their own faction class
**Date:** 2026-07-29
**Status:** active
**Decision:** Survivors of the player's own beacon-response mission exist on the ring as a **distinct faction class**, not folded into native ring cultures. Resolves the tension `docs/vision.md` flagged as undecided.
**Why:** They are the only people on the ring who share the player's frame of reference — who remember Earth, know what the ancient systems are, and can have a fundamentally different kind of conversation than any native culture. That is a category of scene nothing else in the design can produce, and it gives co-op (`coop.md`: possess an existing NPC) a fiction that costs nothing to justify.
**Guard — this decision has a known cost, design against it:** the core aesthetic (`docs/aesthetic.md`, and the user's repeated "shouting at someone in a foreign language" framing) depends on ring cultures reading as genuinely *other*. A faction that shares the player's frame dilutes that by existing, and carries a strong pull toward becoming the default good guys — the trusted quest-givers the no-missions law exists to prevent. Neither is automatic, but neither is avoided by accident. Survivors must not be the faction that *explains* the ring to the player.

### chain-topology-rare-crossings — Chain stays linear; sea crossings are events, not strategy
**Date:** 2026-07-29
**Status:** active
**Decision:** Faction adjacency remains a **chain** (at most two arc-neighbours each). Crossing the walls/sea is possible but rare and expensive — a raid or an exodus, never a supply line or a front.
**Why:** Everything downstream of the chain depends on its linearity: fronts sit at pinch points, trade is caravan chains, refugees flow along the arc, and rumor propagates linearly so that politics and the knowledge system share one physics rather than two. A routinely sea-crossing faction turns the topology into a graph and costs all of that. But a hard ban makes the sea (18–25% arc) politically inert and boats merely traversal. Rare-and-expensive keeps chain physics for everyday politics while leaving one dramatic exception the player can witness — or cause.

### city-states-distinct-classes — THE city and the enclave are different faction classes
**Date:** 2026-07-29
**Status:** active
**Decision:** THE city (~3–8% arc, protagonist two's start, dies witnessably) and the night-sky/enclave cities (~40–55%) are **distinct faction classes**, not one class in different states.
**Why:** They do different jobs. THE city's death is the inciting image — P1 watches the lights go out from the crash-region ridge (`moments/city_destruction.md`) — and it needs to be authored for that. The enclave is a living high-recovery polity, dominates a whole quadrant of the night sky, and is the player's first self-authored goal (`geography.md`: "the K1 lights you mark on night one are the enclave"). Forcing one class to serve both compromises each: the set piece gains simulation it never uses, and the living polity inherits a death it should not be shaped around.

### player-known-never-enrolled — The player is known by factions, never a member
**Date:** 2026-07-29
**Status:** active
**Decision:** The player can never *join* a faction. Standing with a faction is expressed entirely through reputation — decaying, distorting claims about you in the same rumor machinery.
**Why:** Two existing laws already converge on this, so it is a consequence rather than a fresh choice. `no-missions` forbids assignments, and enrollment without duties is hollow — membership that obliges nothing is a label. Meanwhile `reputation = the knowledge pyramid inverted` (`docs/factions.md`) already carries the whole relationship: being *known as one of ours* **is** membership, in machinery that exists. A separate membership flag would duplicate it, which `decomplect` argues against. Recorded explicitly because "can I join?" is a question that will keep being asked.
