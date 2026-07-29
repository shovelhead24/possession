# Possession — Draws

Running inventory, started 2026-07-29.

**Why this doc exists.** With no mission system (`.decisions/design-laws.md#no-missions`), a *draw* is
the only thing that converts "the world exists" into "I am going somewhere." Draws were being
designed incidentally, scattered across area docs, and never counted — so nobody could answer
whether they are distributed sensibly along the arc or clustered, or whether they arrive at the
right *times*. This is the count.

**What qualifies.** A draw must be **knowable without being told**. The player has to be able to
perceive it, infer it, or hear it through rumor — never be assigned it. A thing that is merely
interesting once you arrive is not a draw; it is a reward. The test: *could a player point at it and
say "I'm going there" before anyone explains why?*

**Layers that can produce a draw** (`docs/simulation.md`):
- **Visible** — you can see it from where you stand (night sky, silhouette, light, smoke)
- **Audible/sensed** — signal, tremor, weather
- **Rumor (K2)** — someone told you, distorted by distance and time
- **Trace** — physical evidence with provenance (a tool, a body, a ruin)
- **Inevitability (R5)** — the director scheduled a fact whose *approach* is perceivable

## Inventory

| Draw | Arc | How it is knowable | Layer | Timing | Status |
|---|---|---|---|---|---|
| **The enclave's lights** | 40–55% | Visible on the first night; dominates a whole quadrant of sky | Visible | Night 1 | Decided (`geography.md`) — the game's first self-authored goal, baked into the sky itself |
| **The reveal ridge** | ~0% | Visible from the crash region; the terrain money shot | Visible | Tier 1 | Decided (`moments/ring_curve.md`) |
| **THE city dying** | 3–8% | Witnessable from the crash-region ridge — lights go out | Visible, one-shot | Early | Decided (`moments/city_destruction.md`) |
| **The relay, already on** | 60–75% (high) | Humming before you arrive; someone else's transmission | Sensed / rumor | Mid | Decided (`.decisions/factions.md#relay-woken-by-living-faction`) |
| **The hub spire** | 90–100% | Visible from everywhere by construction | Visible | Always | Decided (`moments/the_return.md`) |
| **Second crash site (survivors)** | far from start, TBD | Proposed: wreck visible/inferable; people who share your frame | Visible + rumor | Tier 2 | **Proposed 2026-07-29** — see below |
| **Lit lighthouses** | 18–25% | Burning along the coast at night, purpose forgotten | Visible | Any | **Proposed** — `factions.md` slate #4, fills an empty stretch |
| **The barrens scar** | ~30% | Visibly wrong terrain; explains the world to anyone paying attention | Visible | Any | **Proposed** — `factions.md` slate #5 |
| **The armada** | sky | Arrives; theological catastrophe per culture | Inevitability | Mid | Decided (`moments/armada.md`) — and it answers the *survivors'* relay (`.decisions/lore.md`) |
| **Night sky as map** | all | The sky *is* the map; K1 acquisition | Visible | Always | Decided (`.decisions/knowledge.md`) |

## Two kinds of draw — PROPOSED 2026-07-29

Listing the inventory exposed that every decided draw is the same *kind*: an authored landmark,
perceivable from the start, that stops pulling once reached. That is why the middle sagged. The fix
is not more landmarks — it is a second kind:

**Standing draws** — authored, visible from far away, mostly available night one. The enclave's
lights, the spire, the ridge, the lighthouses, the barrens scar. They orient. They are the map.
They are also *spent* on arrival, and no amount of them fixes the mid-game.

**Returning draws** — emergent, produced by the dynamics catalog (`factions.md`), and they exist
*because the player acted*. They cannot appear early because there is no history yet:

- **Misattributed reactivation** — you wake something; rumor physics assign it to whichever faction
  the tellers already fear. A region becomes newly hostile, or newly interested, *in you*. → a place
  you now have reason to go, that did not exist before you touched anything.
- **Stolen-tool provenance** — the binoculars you traded turn up on a raider's body two regions on.
  → a trail with your own fingerprints on it.
- **Refugee wave → pinch camps** — the director schedules one fact; chain topology does the rest.
  → a new settlement where there was none, made of consequence.
- **Pinch-toll smuggler paths** — tolls rise, caravans reroute, a path forms through worse terrain.
  → an opportunity gradient nobody authored.

The mid-game is not under-supplied with landmarks. It is the phase where **the world starts
returning the player's own actions to them**, and those returns *are* the draws. This also answers
the decay question below for free: standing draws are spent on arrival, returning draws are
generated continuously by play, so the pull does not run out.

**Consequence for build order:** the dynamics catalog is not flavour to add after the simulation
works. It is the mid-game's entire pull. Rumor propagation, fact provenance, and the refugee/toll
pressure loops are load-bearing content systems, not polish.

## Open shape questions

- ~~Distribution gap at 18–36%~~ — **addressed** by the proposed lighthouse chain and barrens scar
  (`factions.md` slate). Confirms the gap was a *faction* gap, not a landmark gap: the stretch had
  no one living in it, so it emitted nothing.
- ~~Timing / mid-game sag~~ — **addressed** by the standing-vs-returning split above.
- ~~Decay~~ — **addressed**: standing draws are spent on arrival by design; returning draws are
  generated continuously by play.
- **Do returning draws need to be legible as consequences?** If the player cannot tell that the
  hostile region is hostile *because of something they did*, the draw still works mechanically but
  loses its whole thematic point (the possession theme wearing politics). Rumor already carries
  provenance — the question is whether the player ever gets close enough to the chain to read it.
- **Can a standing draw be re-charged?** The enclave stops pulling once reached. Could a returning
  draw re-target an old landmark (the enclave now under siege, the spire now lit)? Cheaper than new
  geography if it works.

## Standing habit

When any design discussion produces a draw, add it here — arc position, how it is knowable, which
layer produces it, and whether it is decided or proposed. Draws are load-bearing in a no-missions
game and are cheap to lose track of.
