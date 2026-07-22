# The Return (leave ending)

Companion to vision.md's "The Choice" — the "ring the bell, leave" branch, staged. Not one of the numbered 12 (those are witnessed beats on the way up); this is the terminal player-chosen act. 2026-07-22 session; decisions in `.decisions/ending.md`.

## What You See

A portal, generated at a fixed hub location — a spire or structure reaching from the ring floor toward the spin axis. You reach it; proximity is the whole journey, nothing about the site itself is a puzzle. You fly through. The screen doesn't cut. A song plays (reference: Garbage, "Cherry Lips") scored over a montage assembled from what actually happened in *your* playthrough — not a fixed cutscene. At the song's bell section, the game's title appears for the first time. It ends on a long held black screen. (Post-credits: [The Human Armada](human_armada.md) — tentative, may move earlier.)

## What You Feel

Ambiguous, not triumphant. Bittersweet. You don't know if you did the right thing, and the game doesn't tell you. The black screen is space to sit with that before anything else happens.

## Mechanic

- **Mechanism:** a portal at a fixed hub site (spire/structure toward the spin axis) — trivial to operate once in close proximity, no skill check. All difficulty was reaching it. (A real bell doesn't test your dexterity; you just pull the rope.) Substrate note: the axis is a coordinate singularity (all `lat` values degenerate to one point at `alt = R`) — see `docs/terrain/substrate.md`.
- **Vignette assembly:** runtime selects from a precondition-tagged pool against R0 persistent facts (and per-player knowledge — see knowledge.md) at the moment of ringing. Same pattern as dialogue's arc-phase branch selection (dialogue.md) — reused, not reinvented. A consistency gate must hold: no vignette may contradict a current fact (the runtime sibling of the bake gates, one more rung on the same verification ladder).
- **Staging:** once triggered, this is a fixed authored sequence, off the tempo director's leash — symmetric with the landing sequence's fixed opening.
- **Title card:** first appearance of the game's title, timed to the song's bell section. Same withholding logic as "names come last."
- **Close:** extended black screen before any credits UI — no immediate cut to a menu.

## What It Must Do

- Let the mechanism be reached, not solved.
- Assemble content that's honestly different across different playthroughs — the montage must be able to look genuinely different, or it's not really reading world state.
- Hold the black screen longer than feels comfortable.

## What It Must Not Do

- Gate the mechanism behind a puzzle, timer, or combat encounter.
- Explain the vignettes or caption them with judgment (good/bad ending framing).
- Cut straight to a credits crawl or main menu from the black screen.
- Reuse this staging for the stay/destroy-relay ending — that ending is untouched by this design.

## Co-op: unilateral shared trigger (2026-07-22)

**Either player rings the bell alone; it ends the session for both.** No split ending, no consent gate, no vote UI — resolves the earlier open question by rejecting the split. Consistent with every other refusal-to-accommodate in the design (no missions, no valence, arc never waits): the partner who reaches it first *is* a second, human arc director, indifferent the same way the world is. The negotiation ("wait, not yet") happens entirely at the couch, off-system — the strongest version of "couch co-op first."

Falls out of existing systems for free:
- **Physical blocking:** if players collide, one can stand between the other and the mechanism — no new mechanic, pure emergence from movement/collision already required anyway.
- **Merged vignette threads:** R0 facts are shared/global; knowledge pyramids are per-player. The montage interleaves both players' witnessed fragments around the one shared fact set — "same world, asymmetric knowledge, shared grief" made literal in the credits.

**Honest risk, not fully resolved:** unilateral ending can read as thrilling or as robbed-of-an-ending depending on execution; mitigated by the mechanism being reachable only after the whole journey (never a five-second impulse), but this wants a real co-op playtest before it's load-bearing.

## Open Questions

- **Telegraphing:** should either player have any signal their partner is nearing the mechanism (environmental/visual only, never a UI prompt — consistent with "no UI, no hint" elsewhere), or is discovering it happened only when the screen changes part of the point?
- Whether the reference track's shape (structure, tempo, the bell section's timing) gets formalized into an original score brief now, or waits until content exists to score.
