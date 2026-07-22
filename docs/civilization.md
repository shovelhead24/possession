# Possession — Civilization: Tech Recovery & City Cost

New area doc (2026-07-22). Answers two linked questions: how uneven post-collapse technology gets distributed across the ring without being random or hand-placed, and how a "city" is affordable in dev time, tokens, and potato-hardware budget. Companion to [factions.md](factions.md) (politics/identity) — this doc is representation/tech-level/rendering cost.

## The Reframe — PROPOSED

"Medieval tier" (vision.md) is not a genre — it's a **collapse curve.** Tier-2 humans are descendants of a prior colony that had real infrastructure (vehicles, firearms, boats, aircraft) and lost it *unevenly* over hundreds of years of isolation. What reads as a tech spectrum (spears/bows/baseball bats ↔ trucks/saloons/horses ↔ ferries/subs/drones/mortars/NVGs) is really 2-3 bands on one causal recovery curve, not a kitchen-sink fantasy setting. The ring's 2,000 km scale is what makes room for multiple genuinely different bands to coexist rather than one flattened average.

## Tech/Recovery Field — PROPOSED

New L5 field, computed like biome classification (L3), not rolled:

- **`tech_level`** (continuous) driven by: connectivity (road_graph reachability, pinch/wall isolation from world.md), resources (reuses `sediment` — surplus food frees labor for complexity; proximity to `ruin_sites`/salvage; proximity to a minor leftover ancient power source, a small cousin of the relay), collapse severity (how hard the initial catastrophe hit that region), and a syncopation-weight stochastic path-dependency term (two similarly-placed regions can still diverge by luck — same mechanism as the crater/pilgrimage cascade in layerbuf-v0.md).
- **`recovery_band`** = classifier over `tech_level` + inputs → a small number of discrete, legible bands. **Placeholder names only** (regressed / frontier / enclave, or similar) — actual naming held, same "names come last" logic as everything else.
- **Legible before arrival:** night-sky light density (knowledge.md) already signals a settlement's presence; it signals tech tier for free — smoke/radio towers vs. scattered cookfires vs. genuine dark.
- **Gates tool/vehicle availability** (tools.md): a region's band determines what's findable there — bows/improvised melee in regressed zones, trucks/horses/basic firearms in frontier zones, boats/aircraft/drones/mortars/NVGs only near a surviving enclave.

## City Affordability — PROPOSED

A city needs to *read* as dense, not *be* dense:

1. **Procedural exterior mass** — a modular building kit generated the way the character pipeline turns `PartDef` recipes into bodies (`game/pipeline/`) — a structure-pipeline sibling, not new invention.
2. **Ambient crowd at Tier 0–1 fidelity** (Fern Rule, terrain.md's mined brainstorm) — silhouettes and passive reactivity, no AI, no per-NPC cost.
3. **1–3 hand-authored pocket-reality interiors per city** (occlusion-funnel/context-swap technique, already in terrain.md unused) — the only bespoke-detail spend; this is where real dialogue and named NPCs live.

"Depth is a feeling, not a measurement" is the literal cost control, not just a nice line — it serves authoring time and the potato-hardware frame budget in the same direction, no tradeoff between them.

## Open Questions

- **How does a surviving enclave's economy actually work** — genuinely unresolved (flagged by user 2026-07-22). Candidate, not decided: anchored on a minor leftover ancient power source. Needs a real answer before that city is built.
- Exact band count (2? 3? more?) and their placeholder→real names.
- Does `recovery_band` ever change at runtime (a region recovering or collapsing further due to player/faction action), or is it bake-fixed like biome?
- Structure-kit scope: how many modular building pieces before variety looks the same everywhere?
