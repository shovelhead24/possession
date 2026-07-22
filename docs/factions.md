# Possession — Factions

Area doc (2026-07-19 session). Tier-2's "people, factions, bows, horses, politics" (vision.md), built entirely from existing machinery — factions are consumers of the bake, the R-stack, the knowledge system, and tempo. No new systems.

## Chain Topology — PROPOSED

On a 2,000 km × ~30 km band, faction adjacency is a **chain**, not a map: at most two arc-neighbors each, plus wall/coast variation. Consequences:
- Wars have *fronts*, and fronts sit at pinch points (world.md's gating terrain)
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

## The No-Missions Boundary

NPCs may *ask* for help — honest simulation, people ask. But: no quest log entry, no reward contract, no tracking UI. The ask is an encounter (R4); caring is the player's journal pin. Factions never court the player as a content dispenser.

## Open Questions

- Faction count/scale: bounded by communication speed on the ring (rumor decay × horse range) — tuning, not planning; L5 should derive it
- Who woke the relay — a live faction, a dead one, or neither? (Narrative decision, upstream of history-pass authoring)
- City-states: the night-sky cities vs THE city (protagonist two's) — same faction class or distinct?
- **Human survivor faction?** vision.md flags an open tension: scattered crew from the player's own beacon-response mission, found later, could be its own faction class distinct from native ring cultures — undecided, not adopted.
- Player faction membership: can you *join*, or only be known? (Witnessing lean says: known, never enrolled — but tier-2 politics may want more)
- Do factions war across the walls/sea, or is the chain strictly linear?
