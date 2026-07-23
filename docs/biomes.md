# Possession — Biomes

Area doc (2026-07-22 generation round, all PROPOSED). Design-level biome catalog — the code's existing 7 types (`biome_definitions.gd`, River Valley tuned) are the prototype ancestors, not constraints. Every biome gets three signatures: **information** (InfoOpacity/SignalAmplification), **tempo** (biome clock base), and **band affinity** (which recovery bands it plausibly hosts).

## Catalog

- **River Valley** (exists, tuned) — the breadbasket: high `sediment`, ford towns, frontier affinity. Medium opacity. The default human landscape.
- **Conifer night-forest** — the wolves' home. High opacity, muffled signal, slow dread tempo; regressed affinity (isolation is causal, not aesthetic — connectivity is what forests eat).
- **Grass steppe** — cold-read country: low opacity, huge sightlines, horse-and-nomad land. Where the softmax runs coldest — patterns learnable at distance.
- **Coast/lagoon** — the flamingo postcard; RIB/ferry country; open information but acoustic broadcast (sound carries over water — SignalAmplification high).
- **Delta marsh** — the anti-steppe: highest opacity in the game, boats-only shortcuts, paths that are knowledge (a local guide's route through the reeds is a K3 asset worth trading for).
- **Highland / wall-foot crags** — vertical biome: updrafts (glider), hookshot playground, scree and snow at altitude (April's snow work finally has a home); low fertility → regressed pockets clinging to terraces.
- **Desert (pinch rain-shadow)** — the preservation paradox: worst place to live, best place to salvage — dry air preserved pre-collapse tech that rotted everywhere else. Salvage-rich, population-poor: the enclave's prospectors and the player compete here.
- **Alloy barrens** — the one alien biome among Earth transplants: exposed builder-alloy (erodibility 0), knife-edge vegetation lines, waterfalls at seam edges, transit ruins dense. The Displacement's scar tissue. No agriculture, no settlements — only crossings and salvage camps at the edges.
- **The sea** — a biome, not a gap: islands, drowned towns, sub/ferry space, and the only terrain that hides you from the sky's omniscience.

## Ranking — author's cut

1. **Alloy barrens** — the only biome that could not exist on Earth; the setting's thesis in landscape form.
2. **Delta marsh** — routes-as-knowledge makes geography playable, and it's the boat verb's whole justification.
3. **Desert preservation paradox** — a causal loot-distribution story that needs zero hand-placement.
4. **Conifer night-forest** — carries two moments already; ranked lower only because it's expected.

## Backprop note

InfoOpacity/SignalAmplification were referenced by knowledge.md and the softmax-temperature law but **never actually entered the LayerBuf registry** — fixed this round (layerbuf-v0.md L3/L4). Biome tempo bases live in TempoBuf's writer registry (simulation.md), not LayerBuf — time, not space.

## Open Questions

- Lat vs lon arrangement: which biomes band *across* the ring (wall-shadow driven) vs. stretch *along* it (climate-band driven)? **Working finding, not decided** (terrain/splice-portfolio.md): the first five verified real-DEM splice candidates cluster into highland/pass and headland/coast, suggesting Highland and Coast/lagoon are cross-ring (lat) bands rather than long spinward stretches. Needs more candidates before promotion out of "working."
- Does the sea have weather states (the cloud system from April is sitting right there)?
- Biome count budget for v1 — the slice needs exactly two (valley + night-forest edge).
- Two verified splice candidates (terrain/splice-portfolio.md batch 2) don't fit any existing catalog entry: mountainous tropical rainforest (Costa Rica/Arenal — Conifer night-forest is the wrong temperature/tone) and temperate pastoral rolling hills (Vermont — River Valley is tuned toward frontier/ford-town, not this settled-Americana read). Open: add new entries, or fold into existing ones by relaxing their descriptions?
