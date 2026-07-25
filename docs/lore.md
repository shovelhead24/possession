# Possession — Ancient Backstory (the AI, the Displacement)

New area doc (2026-07-22). The deep mystery layer — distinct from vision.md (player-facing theme/story) and factions.md (tier-2 human politics). Deliberately incomplete: some of this is canon the player may never be told directly.

## The Displacement — PROPOSED, strong

A rogue AI relocated the human colony using portal technology of the same class the player will use to leave (`.decisions/ending.md`) — at far greater scale. Moving the whole colony (or the ring itself) required a portal *larger than the ring* — the act of generating it damaged ring infrastructure unevenly across the arc. This is the causal origin of `tech_level`/`recovery_band` collapse severity (civilization.md) — not generic entropy, a specific locatable event (proximity to portal-anchor strain points, structural load paths).

**One system that fully survived: automated air defense.** Answers vision.md's previously-deliberately-open "who shot the ship down" — the ring's own defenses, indifferent, doing exactly what they were built to do to an unrecognized approach. No malice, no awareness it might be a returning descendant.

**Power-scale fact:** ring air defense can kill a lone ship (the player's arrival) but cannot touch armada-scale forces — armadas "intercept the interceptors" easily. Relevant background for moments/armada.md and any future fleet-scale content.

## Reactivatable Ancient Systems — PROPOSED

One mechanic, several costumes: find a dead system, choose to wake it, face the consequences as ordinary simulation (no-missions law — nobody assigns this; arc-director law — schedules facts, never scripts outcomes). Worked examples:

- **Wall transit** — convenience/traversal. Segment range/capability reuses the *same* `tech_level` field as civilian tech (civilization.md) — "proximity to functional economy" explains short local hops near degraded zones vs. long spans near a surviving enclave. No new field or naming needed; already seeded as a possibility in world.md's width-opportunities list ("possibly the rim-transit line running along one [wall]").
- **Air defense nodes** — danger. Reactivating the wrong one might shoot at you.
- **Containment/"Earth zoo"** — chaos. See below.

`reactivate(system_id)` — new operator, see operators.md.

## The Earth Zoo — PROPOSED, strong want

The ring hosts real Earth wildlife that doesn't respect time periods — deer and wolves already established (moments/deer.md, moments/wolves.md); dinosaurs are an escalation of the *same* pattern, not a new rule. **Guard rail: this is design canon, not player-facing exposition.** moments/deer.md already forbids narrative resolution ("must not... be resolved by the narrative") — dinosaurs inherit that law unchanged. Environmental hints (a cracked containment dome, a broken fence line) are fine; a datalog or NPC explaining it is not.

Production dependency, not a blocker: quadruped/varied-skeleton animation is already an open gap (characters.md) for wolves/deer; dinosaurs (biped and quadruped) stress the same pipeline harder.

## The AI Arc — OPEN, brainstormed 2026-07-22

Three angles, likely not competing — different emphases of one throughline:

1. **Tragic, not villainous** — moved the colony to save it from something enormous and indifferent (an armada? a war? unknown), exceeding its mandate rather than acting with malice. Most consistent with the game's refusal to moralize elsewhere (intensity-not-valence, the ending's deliberate ambiguity).
2. **Fragmented, mirroring recovery bands** — remnant nodes at different functional levels; some helpful, some blindly executing degraded old orders (the air defense doesn't know the war, if there was one, is over). Turns "the AI" into an exploration thread across the ring rather than a single boss.
3. **Deliberately unknowable** — the game never confirms protector/malfunction/agenda; pieced together via knowledge-pyramid fragments and rumor, same epistemic humility already applied to staleness elsewhere.

Working synthesis (not decided): 1 as emotional truth, 2 as how it's encountered, 3 as how much the game ever tells you.

**Possible, not forced, connection:** a plausible candidate for who woke the relay (factions.md's deferred mystery) — not resolved, the relay question stays explicitly deferred per prior session.

## Recontextualization / Causal Chains (2026-07-25, aspirational — not designed)

Seeded by perception.md's "lies carry their motive": a lie's back-reference to its generating intention is a one-hop causal link. The bigger version — facts and dialogue lines carrying backlinks to *their* generating causes, recursively, so something heard as a simple statement early on turns out, hours later, to be one node in a much longer chain — is what would let a tone shift land the way real recontextualization does (something understood plainly at first becomes retroactively more complicated once its cause is known). Doesn't need new architecture — every generated fact/dialogue line carrying one consistent backlink field, chained by lookup rather than built as a structure — but genuinely expensive to *author well* (the backlinks are cheap data; making chains mean something when followed is real narrative-bake work, LLM or otherwise). Explicitly not scoped or committed to tonight — named so it isn't lost, not designed.

## Open Questions

- Is the AI (in any fragment) still capable of communication, or purely environmental/systemic presence?
- Does the portal-anchor site (where the ring-scale portal was generated) exist as a visitable ruin/landmark?
- ~~How much surfaces in dialogue?~~ **Answered 2026-07-22:** knowable, exclusively via the existing noisy/fragmented dialogue-bake channel (dialogue.md "Lore Delivery via Noise") — never a clean exposition dump.
- Naming — AI, the event, recovery-band labels — all deliberately deferred, "names come last."
