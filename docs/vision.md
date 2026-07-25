# Possession — Vision

High-level and mostly-static. Changes rarely, and only deliberately. The working entry point for planning is [brief.md](brief.md); this doc holds what's *fixed*.

## Theme

**You arrived late to something enormous.**

The ring is indifferent to your presence. It was here before you. It will be here after you. You are a witness, not a protagonist. The world does not reward you directly — it reshapes opportunity gradients.

## Non-Negotiables

These can be changed, but only by mutual agreement.

- **The landing sequence is unbroken.** No cuts, no loading screens, no fade to black. The player watches the ring rush up from the pilot's seat the entire way down. Mouse look only. No thrust.
- **Fully explorable terrain.** If you can see it, you can reach it. No invisible walls, no locked zones.
- **Scale without fanfare.** The ring's size is shown, not announced. No music sting. No UI callout.
- **Witnessing over heroism.** The world's biggest moments happen whether you're ready or not. You don't outrun the disaster. You watch it.
- **Couch co-op first.** Two players, one screen. All design decisions are tested against this.
- **Potato hardware target.** GL Compatibility renderer. Intel UHD. If it doesn't run on a Dell Latitude, it doesn't ship.

## The Two Players

**Protagonist One** — crashed in the wilderness. Stripped on landing. Knows nothing.

**Protagonist Two** — was near the city. Witnessed it from a distance. Already moving. Knows what the lights going out meant.

RE2 structure: same world, asymmetric knowledge, shared grief. Names TBD — names come last.

**Opening premise (2026-07-22):** a distress beacon transmits from the ring — unanswered for centuries. The player's ship answers it and is shot down on approach; the crash *is* the answer, the escape pod is how you survive it. Rhymes with the ending: the game opens with answering someone else's call and closes with the player becoming one — see "The Choice" below. **Answered 2026-07-22:** the ring's own automated air defense — one system that fully survived a ring-wide degradation event, doing exactly what it was built to do to an unrecognized approach, with no awareness it might be a returning descendant. See [lore.md](lore.md) "The Displacement." Whether it connects to who woke the relay stays deferred.

**Open tension — companions/survivors (2026-07-22, undecided):** does Protagonist One encounter other human survivors from the same ship or mission? For: justifies a player base (or bases), gives the player their own faction dynamic. Against: dilutes the solitary "stripped, alone, prey" framing of tier 1. Not resolved — one synthesis worth weighing, not adopted: if the beacon was answered by a small response mission rather than a lone ship, scattered crew could be found *later*, during tier 2, recontextualizing "discover people" as sometimes discovering your own people among the natives — without softening tier-1 solitude.

## Layer Stack (high to low)

- **Thematic** — you arrived late to something enormous. The ring is indifferent. Witnessing over heroism.
- **Narrative Arc** — crash → stripped → hunted → survivor → discover people → climb toward ancient tech → relay already on → armada arrives → choice.
- **World** — the ring. Fully explorable. Curves upward. Far side visible and reachable. Cities, villages, wilderness, ruins. The world was here before you.
- **Co-op** — two players, asymmetric starting position and knowledge. Shared world, different grief.
- **Progression** — metroidvania shape. Stripped on landing. Tech tree climbs: survival → medieval → ancient alien. Bow before carbine. Hookshot unlocks vertical traversal.
- **Terrain as Strategy** — ridges, valleys, sight lines. Layered on top of everything, interferes with nothing, amplifies all of it. Terrain is the game.
- **Squad** — light. Stay/follow. AI fills vehicle roles naturally. World feels inhabited without micromanagement.
- **Combat** — Halo golden triangle: grenades, movement, power weapon control. Vehicles: drive, fly, boat. Squadmates fill roles without being asked.
- **Moment-to-Moment Feel** — couch co-op Halo essence. Two people on a couch, something enormous happening around them.

## Progression Tiers

1. **Survival** — hunting to live, no power, prey not predator
2. **Medieval** — people, factions, bows, horses, politics
3. **Ancient Alien** — tech that changes what the world is, stakes that change what the game is

## The Choice

The relay was already on when you found it. You didn't wake it. Something else did.

The armada arrives because someone tried to contact home using ancient tech on the ring. They are not looking for you. They want the ring.

- **The good ending:** destroy the relay. Stay.
- **The other ending:** ring the bell. Leave. The game lets you go back after the credits and ring it anyway.

Ringing the bell is not cowardly. But it tests your courage in a suddenly much more dramatic way.

**The leave ending, staged (2026-07-22):** the mechanism itself is simple to operate — the entire difficulty is the journey to reach it, not solving it once there; no puzzle, no skill check, you just ring it. What plays over ringing it is a procedurally assembled vignette montage built from the actual world state at that moment (see simulation.md "Ending Vignette Assembly") — what you did, who you helped or didn't, what you still believe that's gone stale. Staged to a reference track (Garbage, "Cherry Lips (Go with the Flow)" — bittersweet, ambiguous, not triumphant) with the game's own title card appearing for the first time at the song's bell section — three bells at once: the song's, the diegetic one, the name. Same withholding logic as "names come last," applied to the game's own name. Closes on an extended held black screen before any credits — reflection, not a cut. See [moments/the_return.md](moments/the_return.md); decisions in `.decisions/ending.md`. (The stay/destroy-relay ending is untouched by any of this.)

**Structural bookend:** the landing sequence (opening) and this ending are both fixed, authored, non-systemic sequences — everything between them is emergent simulation. The game is authored at both ends and alive in the middle.

**The mechanism, concretely (2026-07-22):** a portal, generated at a fixed hub location — a spire or structure reaching from the ring floor toward the spin axis. You fly through it. That is "ringing the bell." (Substrate consequence: the axis is a coordinate singularity — see `docs/terrain/substrate.md`.)

**Post-credits (2026-07-22, tentative — timing may move earlier if needed):** the humans of the player's own world arrive at the ring with their own armada, following the signal the player's return created. Distinct from [The Armada](moments/armada.md) (mid-game, an unrelated ancient civilization arriving because someone used ring tech to call home, indifferent to the player) — this one exists *because of* the player, and is a deliberate content-deferral device: a sequel/DLC hook, not built now. See [moments/human_armada.md](moments/human_armada.md).

**Save continuation & replay (2026-07-22, tentative):** an ended playthrough's save (solo or co-op) stays loadable — when DLC content ships, play resumes from the same position rather than restarting. A subsequent run offers carrying a few chosen inventory items forward, and reuses the same world seed so early terrain/behavior is genuinely recognizable — divergence should come from the non-linear systems responding differently to new choices, not from a reshuffled map. Exercises the additive-only LayerBuf/field-registry laws already in place (`.decisions/terrain.md`) rather than requiring new architecture.

## Tone References

- 2001: A Space Odyssey — something was already happening
- Terminator 2 nuclear dream — cold, distant, the world changes and you just watch
- Halo CE — couch co-op, the golden triangle, terrain as strategy
- Metroid — alone, stripped, climbing back
- RE2 — two people, same world, different experience
- Apocalypse Now / No Country for Old Men (2026-07-26) — proof that unresolved moral ambiguity and emotional devastation aren't in tension: neither film answers its own darkness, both land because the craft (score, silence, restraint) is generous exactly where the meaning refuses to be

**Cautionary, not aspirational: Far Cry 2 (2026-07-26).** Same Heart-of-Darkness-shaped indifference we're reaching for, but it fails in two separable ways worth naming so we don't repeat them: (1) **indifference without awe** — pure cynicism, no sublime counterweight, whereas our tone list above is awe-first indifference (the ring is indifferent *and* beautiful); (2) **systemic expression with no reflection** — decades of emergent player behavior, and the ending barely acknowledges the specific shape of what you did.

(1) is answered by the awe-heavy moment list below. **(2) is only partly answered, and this needs honesty, not a victory lap (2026-07-26 self-correction):** the ending's fact-driven vignette assembly (`.decisions/ending.md`) is necessary but not sufficient by itself — a single mirror at the very end, however well-built, doesn't fix 30+ hours of feeling unacknowledged along the way. The actual fix requires *continuous* reflection throughout play, not a terminal one. The mechanism for that already exists (reputation as the knowledge pyramid inverted — factions.md) but we have not specified that it must surface *often enough and legibly enough* to function as an ongoing mirror. Until that's explicit, the ending is still carrying the whole burden alone. Open gap, tracked in TODO.md.

## Moments

Individual moment docs live in [moments/](moments/). Each is a short director's note: what you see, what you feel, what the game must and must not do.

1. [The Landing](moments/landing.md)
2. [The Ring Curve](moments/ring_curve.md)
3. [The Wolves](moments/wolves.md)
4. [The Deer](moments/deer.md)
5. [The Settlement at Night](moments/settlement_night.md)
6. [The City Destruction](moments/city_destruction.md)
7. [The Night Sky](moments/night_sky.md)
8. [The Relay](moments/relay.md)
9. [The Armada](moments/armada.md)
10. [The Pilot](moments/pilot.md)
11. [The Medieval Army](moments/medieval_army.md)
12. [The Hookshot](moments/hookshot.md)

---
*Living document. No review schedule — revisit when something feels wrong.*
