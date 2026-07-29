# Possession — Factions

Area doc (2026-07-19 session). Tier-2's "people, factions, bows, horses, politics" (vision.md), built entirely from existing machinery — factions are consumers of the bake, the R-stack, the knowledge system, and tempo. No new systems.

## Chain Topology — PROPOSED

On a 2,000 km × 50 km band (`.decisions/world.md`), faction adjacency is a **chain**, not a map: at most two arc-neighbors each, plus wall/coast variation. Consequences:
- Wars have *fronts*, and fronts sit at pinch points (world.md's gating terrain) — `priests_leap` (terrain/splice-portfolio.md) is a verified real-world example of exactly this geometry: a single mountain-pass chokepoint, not a hand-authored one
- Trade is caravan chains; refugees flow along the arc
- Rumor propagates linearly with SignalAmplification decay — politics and the knowledge system share physics
- **Placename gradients:** culture seeds drift dialect-by-dialect along the arc (dialogue bake) — walking spinward sounds like language changing

## Identity Baked, Behavior Live — PROPOSED

- **L5 history pass generates faction identity from geography:** watersheds seed polities; grievances are baked facts with coordinates (the battlefield ruin between two factions is *why* they hate each other); borders follow bake terrain.
- **Tech/recovery level is a sibling field, not a faction property** — see [civilization.md](civilization.md). A faction's territory has whatever `recovery_band` its geography earned; two factions at war can be at genuinely different tech levels, which is itself a source of conflict asymmetry.
- **Runtime factions are ordinary R2 entities:** pressures → intentions → actions. Regional clocks heat during wars (tempo). Armies are counted (conservation gate).

## Reputation = the Knowledge Pyramid Inverted — PROPOSED

Factions know the player the way the player knows them: **decaying, distorting claims** propagating through the same rumor machinery. No reputation meter — reputation *is* K2-style claims about you, with provenance, distance-decay, and staleness. Near the crash you're "the one who fell from the sky"; three factions down the arc, a garbled myth. One system, both directions. (Design-law compliant: factions hold their *own* coarse knowledge models; nothing reads the player's pyramid.)

## Battles Resolve Unwatched — PROPOSED

Faction conflicts resolve on the statistical tier whether or not any player realizes them: casualties and border changes are conserved facts either way. A player's bubble arriving realizes the battle as actual AI combat (seeded, reroll-proof); absence means the same outcome, computed coarsely. **Witnessing is choosing to realize.** This is the medieval-army moment's "it resolves without you" as literal machinery.

## Cosmology Axis — PROPOSED

Every tier-2 culture holds a cosmology *about the ring*: relationship to the ancient on a taboo ↔ cargo-cult ↔ instrumental axis. This:
- Differentiates factions beyond geography
- Gives the relay-already-on mystery a suspect pool (an instrumental faction *did something*)
- Makes the armada a theological catastrophe per-culture, not just a plot beat — baked arc-phase dialogue branches diverge by cosmology

## Dynamics Catalog (2026-07-22 generation round, PROPOSED)

Patterns the R-stack should be able to produce — each is pressures/intentions machinery plus one existing system, no new mechanics:

- **Pinch-toll escalation** — toll rises → caravans reroute → smuggler paths form through worse terrain → an opportunity gradient nobody authored (the player finds the smuggler path *because* politics made it).
- **Stolen-tool provenance** — tools are facts with histories: the binoculars you traded in one settlement turn up on a raider's body two regions later. Your past decisions literally circulate.
- **Misattributed reactivation** — you wake an ancient system (lore.md); rumor physics attributes it to whichever faction the tellers already fear. Your action becomes *their* politics — reputation machinery generating wars you caused but don't own.
- **Refugee wave** — a scheduled inevitability fires → refugees flow along the chain → host-settlement pressure spikes → camps form at pinches → new friction. The director schedules one fact; the chain topology does the rest.
- **Upstream dam** — water rights along a shared river: pressure propagation that is *literally* downstream. Hydrology as casus belli.
- **Herd-following nomads** — a faction whose territory is a moving herd fact; their arrival anywhere is market + friction in one caravan.
- **Post-armada schisms** — the mid-game armada breaks every cosmology differently (taboo faction vindicated, instrumental faction shattered, cargo-cult faction *converts*) — one event, per-culture consequences, all via the cosmology axis.

**Ranking — author's cut:** 1. Misattributed reactivation (the player as unwitting political author — the possession theme wearing politics). 2. Stolen-tool provenance (consequence you can hold in your hands). 3. Refugee-wave-to-pinch-camps (the director and the chain topology shaking hands). 4. Pinch-toll smuggler paths (opportunity gradients from pure economics).

## Pulse — faction life runs on cycles (PROPOSED 2026-07-26)

Factions (sparse islands of humanity — aesthetic.md's emptiness reconciliation) are not static dioramas triggered by the player's arrival; they run on *rhythms* whether watched or not, via TempoBuf's regional clocks (simulation.md) given a pulse rather than a flat rate: market days, patrol/caravan schedules, seasonal raids, the build-and-release arc of a border dispute. Design payoff: the same node feels different depending on *when* you arrive (market day vs. dead of night vs. the eve of a raid) — variety on revisit with no new authored content, and a stronger witnessing beat (you catch a living thing mid-breath). Musical model: "The Riddle" — a riff that builds, resolves, rebuilds. This is the temporal anti-boredom lever; see aesthetic.md.

## The No-Missions Boundary

NPCs may *ask* for help — honest simulation, people ask. But: no quest log entry, no reward contract, no tracking UI. The ask is an encounter (R4); caring is the player's journal pin. Factions never court the player as a content dispenser.

## Settled 2026-07-29 → `.decisions/factions.md`

- **Who woke the relay** — a **living instrumental faction**. Uses the cosmology axis's suspect pool as intended, gives the relay an owner you can find and argue with, and makes misattributed reactivation a pattern the world was already running before you arrived.
- **Human survivor faction** — **yes, a distinct class**. The only people who share the player's frame of reference. Carries a recorded guard: they must not become the faction that *explains* the ring, or they dilute the alienness the aesthetic depends on and drift into default-good-guys.
- **Chain topology** — stays **linear**; wall/sea crossings are **rare and expensive** (a raid or an exodus, never a supply line), so chain physics hold for everyday politics while the sea still matters.
- **City-states** — **distinct classes**. THE city is a set piece authored around its death; the enclave is a living polity and the player's first self-authored goal.
- **Player membership** — **known, never enrolled**. A consequence of `no-missions` + reputation-as-inverted-pyramid rather than a fresh call: being known as one of theirs already *is* the relationship.

## Open Questions

- Faction count/scale: bounded by communication speed on the ring (rumor decay × horse range) — tuning, not planning; L5 should derive it
- **Is the instrumental faction that woke the relay the human-survivor faction?** They are the most plausible candidates — they would know what a relay *is* — and the convergence is elegant enough to decide deliberately rather than drift into. Opened by the two 2026-07-29 decisions together.
- Where do the survivors sit on the ring? They are the one faction whose position is *not* derivable from geography (L5 seeds polities from watersheds; a crashed crew lands where it lands), so the history pass needs an authored placement rule for them.
- Does the survivor faction hold a cosmology at all? The axis (taboo ↔ cargo-cult ↔ instrumental) assumes a culture that grew up under the ring. People who arrived knowing what it is may need a fourth position — or may be the purest instrumentalists on it.
