# Possession — World & Scale

The ringworld itself. This is the biggest, least-settled part of the project — expand this doc as we plan, don't leave it stale like the old `.planning/PROJECT.md` did.

## What's Settled

- It's a ringworld (Halo-style) — terrain curves upward and is visible in the sky at distance/night
- Fully explorable — if you can see it, you can reach it (non-negotiable, see `docs/vision.md`)
- Biome variety exists (River Valley is the one built/tuned so far)
- Ancient structures scattered across the terrain, alien, unexplained
- Scale is a deliberate theme, not just a tech flex — see "Scale without fanfare" non-negotiable

## Open Questions (fill in as we plan)

- ~~How big is the playable ring?~~ **Answered 2026-07-18:** circumference 2,000 km (honest sky geometry; supersedes a same-day 20,000 km call). Width open, 10–50 km candidates — see `.decisions/world.md` and brief D2b. Day length stays a designed value.
- How many distinct biomes, and how do they read as regions of a ring rather than a flat map?
- What's the relationship between the "medieval army" / "settlement" moments and where they sit on the ring — is settlement placement authored or procedural?
- Where do the ancient/alien structures sit in the progression tiers (Survival → Medieval → Ancient Alien) — are they visible from tier 1 but only enterable later?
- What does "climb" in the narrative arc (crash → stripped → hunted → survivor → discover people → **climb** → relay) mean in terrain terms — is there a literal vertical traversal system needed?

## Known Hard Lessons (not decisions — things that bit us)

- Skybox geometry can clip against view-distance boundaries and produce manifold errors that visually look identical to z-fighting — cost real time to diagnose during the April terrain work. Worth checking early whenever view distance changes again.

---
*Started 2026-07-18. This doc should grow a lot before the landscape planning pass.*
