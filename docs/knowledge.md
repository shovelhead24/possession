# Possession — Knowledge Pyramid

Area doc (2026-07-19 session). The player's knowledge of the world is itself stored at fidelity levels over the same tile addressing as bake and simulation — the third pyramid (see progression.md "Fidelity & realization"). Per-player.

## The Ring-Specific Foundation

Inside a cylinder every point sees every other point — **there is no horizon; the air is the horizon.** Atmospheric haze gates distance knowledge, and haze is weakest against night lights. Therefore:

- **The night sky is the world map.** Remote coarse knowledge is acquired by stargazing; the day sky hides what the night sky reveals.
- **No omniscient map screen.** The "map" renders the knowledge pyramid: sky-sketch silhouettes, rumor annotations with provenance, found fragments, aged direct observation. Game start is not a void — it's the sky you've watched. Pinning = pointing at the sky.

## K-Levels

| Level | Name | Acquired by | Content |
|---|---|---|---|
| K1 | Seen | stargazing, vistas | silhouette, light clusters — shape, no substance |
| K2 | Heard | NPC rumor pools, found writing | *claims with provenance*, accuracy decayed by SignalAmplification; can be wrong; verification reconciles |
| K3 | Mapped | fragments, trade, routes traveled nearby | navigable: landmarks, paths |
| K4 | Visited | direct traversal/observation | detailed — **and timestamped** |

**Staleness:** K4 records the `fact_version` seen; the world moves on. Staleness = computed gap, never stored. "You knew this place" ≠ "you know this place." Rendered as aging (sepia/fade), never as an alert.

## Acquisition Operators (see operators.md)

- `observe(vantage, time, weather)` — line-of-sight over baked heightfield + haze model; night multiplies far-light detection; K-gains flood visible tiles. **Ridges are honest towers:** climbing genuinely reveals, because geometry says so — no unlock ceremony.
- `hear(rumor)` — inserts K2 claim with provenance + decayed accuracy
- `traverse(tile)` — K4 + freshness stamp
- InfoOpacity governs refinement *rate* everywhere (forest resists knowing; ridges give it away)

## Consumers — the theme boundary

Knowledge is read by exactly two systems: the **bone-thrower** (pins + staleness select information leaks) and **dialogue selection** (which rumor an NPC surfaces). **The world simulation never reads the knowledge pyramid.** Realization doesn't care what you know. The ring doesn't know you're watching — indifference, enforced by API surface.

## Co-op

Two pyramids, one world, **no in-game knowledge-transfer UI** — the merge protocol is two humans on a couch talking. Asymmetric knowledge becomes shared grief out loud, exactly where the design wants it.

## Open Questions

- Journal UI shape: how K2 claims with conflicting provenance render (two NPCs, two versions)
- Does K3 include player-drawn annotation (sketching on your own map)?
- Staleness pacing: how fast should the world outrun a player's knowledge at each tier?
- Does any ancient tech touch the pyramid (tier-3 remote sensing) without breaking "the air is the horizon"?
