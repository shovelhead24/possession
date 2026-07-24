# Possession — Civilization: Tech Recovery & City Cost

New area doc (2026-07-22). Answers two linked questions: how uneven post-collapse technology gets distributed across the ring without being random or hand-placed, and how a "city" is affordable in dev time, tokens, and potato-hardware budget. Companion to [factions.md](factions.md) (politics/identity) — this doc is representation/tech-level/rendering cost.

## The Reframe — PROPOSED

"Medieval tier" (vision.md) is not a genre — it's a **collapse curve.** Tier-2 humans are descendants of a prior colony that had real infrastructure (vehicles, firearms, boats, aircraft) and lost it *unevenly* over hundreds of years of isolation. What reads as a tech spectrum (spears/bows/baseball bats ↔ trucks/saloons/horses ↔ ferries/subs/drones/mortars/NVGs) is really 2-3 bands on one causal recovery curve, not a kitchen-sink fantasy setting. The ring's 2,000 km scale is what makes room for multiple genuinely different bands to coexist rather than one flattened average.

## Tech/Recovery Field — PROPOSED

New L5 field, computed like biome classification (L3), not rolled:

- **`tech_level`** (continuous) driven by: connectivity (road_graph reachability, pinch/wall isolation from world.md), resources (reuses `sediment` — surplus food frees labor for complexity; proximity to `ruin_sites`/salvage; proximity to a minor leftover ancient power source, a small cousin of the relay), collapse severity (how hard the initial catastrophe hit that region), and a syncopation-weight stochastic path-dependency term (two similarly-placed regions can still diverge by luck — same mechanism as the crater/pilgrimage cascade in layerbuf-v0.md). Real-DEM splice candidates (terrain/splice-portfolio.md) are already sorting themselves along this axis for free: an isolated mountain-pass geography (`priests_leap`) reads low-connectivity/regressed by the same logic real isolation drives `tech_level` down; a real signal-station coastal site (`mizen_head`) reads as surviving found-infrastructure, closer to frontier/enclave. Suggestive, not a placement decision.
- **`recovery_band`** = classifier over `tech_level` + inputs → a small number of discrete, legible bands. **Placeholder names only** (regressed / frontier / enclave, or similar) — actual naming held, same "names come last" logic as everything else.
- **Legible before arrival:** night-sky light density (knowledge.md) already signals a settlement's presence; it signals tech tier for free — smoke/radio towers vs. scattered cookfires vs. genuine dark.
- **Gates tool/vehicle availability** (tools.md): a region's band determines what's findable there — bows/improvised melee in regressed zones, trucks/horses/basic firearms in frontier zones, boats/aircraft/drones/mortars/NVGs only near a surviving enclave.

## City Affordability — PROPOSED

A city needs to *read* as dense, not *be* dense:

1. **Procedural exterior mass** — a modular building kit generated the way the character pipeline turns `PartDef` recipes into bodies (`game/pipeline/`) — a structure-pipeline sibling, not new invention.
2. **Ambient crowd at Tier 0–1 fidelity** (Fern Rule, terrain.md's mined brainstorm) — silhouettes and passive reactivity, no AI, no per-NPC cost. Most buildings stay this tier — shells only, not enterable at all.
3. **A small number of REAL, physically continuous interiors per city (2026-07-22, revised)** — *not* pocket-reality. See `.decisions/civilization.md#building-interiors-real-not-pocket`: ordinary buildings need to be in the same coordinate space as the street outside, so you can shoot through a window from either side and a fire visibly consumes the structure from the outside. Cost stays bounded the same way as before — this tier is reserved for the handful of buildings the game actually wants combat/fire interaction in, not applied to the whole city.

**Dungeons are the opposite case and keep the pocket-reality treatment** (occlusion-funnel/context-swap/spatial-lie — docs/research/chatgpt-brainstorm-2026-04.md "Interiors as Pocket Realities," brief.md R6): they *want* to be bigger than their entrance suggests and have no need for ext/int visual continuity. Real buildings tell the truth about their size; dungeons are allowed to lie, because nobody's shooting out of a cave mouth into the street.

**Fire as a stateful system node:** a burning building is the same Tier-3 pattern already named in the interaction-fidelity tiers (generator/camp/alert-state examples, terrain.md's mined brainstorm) — a burn-state fact with a spread clock (TempoBuf-adjacent), not a new category. The taxonomy fit is real; the fire-spread/structural-collapse engineering itself is still open work, not solved by naming it. Cost-wise (cost-ledger.md), it's the one node whose regime isn't decided — bake-only scar vs. live diffusion spread are wildly different cost profiles, and that call should come before any engineering estimate.

"Depth is a feeling, not a measurement" is the literal cost control, not just a nice line — it serves authoring time and the potato-hardware frame budget in the same direction, no tradeoff between them.

## Open Questions

- **How does a surviving enclave's economy actually work** — genuinely unresolved (flagged by user 2026-07-22). Candidate, not decided: anchored on a minor leftover ancient power source. Needs a real answer before that city is built.
- Exact band count (2? 3? more?) and their placeholder→real names.
- Does `recovery_band` ever change at runtime (a region recovering or collapsing further due to player/faction action), or is it bake-fixed like biome?
- Structure-kit scope: how many modular building pieces before variety looks the same everywhere?
