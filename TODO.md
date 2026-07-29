# Shared TODOs

Cross-session scratchpad for loose ends that don't have a natural home yet — not a duplicate of each area doc's own "Open Questions" section (those are design-space questions; this is "needs a next action"). Prune entries once they're resolved or promoted into a real doc/decision/issue.

## Needs your action (laptop/hardware-side)

- ~~Delete `.planning/`~~ **Done 2026-07-23** — issue #6 closed.
- ~~Re-center `ebro_delta`~~ **Done 2026-07-23** — verified flat (p99 37m), see splice-portfolio.md.
- ~~Flatter `mongolia_steppe` box~~ **Done 2026-07-23** — relief down from 1043m to 326m, see splice-portfolio.md.
- **Run `tools/dem/fetch_osm_roads.py`-style check for `cork_city` / `savannah`** — this laptop *does* have working Overpass access (proven earlier this session), so this is doable, just not yet done — the two metro splice candidates' road-grid character (organic vs. planned-grid) is still asserted from real-world knowledge, not independently verified against actual OSM data.

## Open design threads (unresolved mid-conversation)

- ~~D4 curvature — atmosphere shell question~~ **Resolved 2026-07-25** — deep-cross-section, surface-concentrated density falloff. See `.decisions/world.md#atmosphere-density-falloff`.
- ~~Ring width discrepancy~~ **Resolved 2026-07-25** — 50km promoted to decided, `.decisions/world.md#ring-width-50km` (D2b closed). Open tension flagged there with substrate.md's power-of-two proposal (D9), not yet reconciled.

## New follow-ups this round

- **Height-calibration pass, needed before D4's atmosphere decision has real numbers.** No haze/boundary-layer height has ever been tuned against the real DEM terrain — every value used in `ring_vibes.gd` so far was picked ad hoc against whichever terrain (noise or real) happened to be loaded that session. Needs a dedicated test pass once ring height-scale is otherwise settled.
- **Reputation must surface continuously, not just exist theoretically (2026-07-26).** Self-correction — the ending's fact-driven vignette (`.decisions/ending.md`) is necessary but not sufficient to fix Far Cry 2's "unreflected expression" failure (vision.md) by itself; a single terminal mirror doesn't fix 30+ hours of feeling unacknowledged along the way. Reputation-as-inverted-knowledge-pyramid (factions.md) is the mechanism for *continuous* reflection, but frequency/legibility of how often it actually surfaces to the player has never been specified. Needs real design attention, not just architectural possibility.
- **Craft/cinematography specification gap (2026-07-26).** The moment docs (What You See/Feel, Must/Must Not) are design-brief level, not shot-list level — they say what a moment should achieve, not the actual frame-by-frame craft (camera, cut rhythm, score presence, silence) that would let it bear the emotional weight the "intensity not valence" law assigns to style. This session has been systems-heavy and craft-light; closing this gap is directorial/aesthetic work (references, mood boards, actual staging decisions), not more architecture — needs the user's own sensibility leading, not delegated to more doc-writing.
- **Marketing/trailer reference, not core design:** Django Django's "Hail Bop" — ascending, repeating pattern (same device as Bach's Endlessly Rising Canon, see the GEB conversation) as a structural template for a progression-trailer: each visual beat steps up with the music through the tech-tree/transport ladder (walk → horse → truck → boat → hookshot), resolving into flight exactly where the ascending pattern wants to land. Distinct from the in-game ending's Cherry Lips staging (ambiguity/grief vs. momentum/scale) — different deliverable, don't conflate.
- ~~D9 substrate freeze vs. plain dimensions~~ **Resolved 2026-07-25** — 128 m power-of-two leaf tile divides 2,000 km exactly (15,625 around, zero remainder); width never needed power-of-two-ness since it doesn't wrap (edge tile ≠ seam tile). See `docs/terrain/substrate.md` "Dimensions — RESOLVED".

## Object-LOD branch threads (2026-07-27)

- **Scatter reads L4, not noise.** `mocks/cdlod.gd` `_scatter_trees` currently places trees from `_forest_noise` — a *placeholder* for L4 `tree_density` (layerbuf-v0.md: "runtime scatters deterministically from these"). When L4 bakes, swap noise → field sample; placement machinery (grid+jitter+seed) already correct.
- **"Fidelity" may be one axis, not two (user insight, 2026-07-27).** Data fidelity (L4 density-field resolution in the mixed-res pyramid) and render fidelity (terrain CDLOD + object LOD tiers) are separate knobs today but want unifying: *everything coarsens with distance/attention from the observer at once* — terrain mesh, object geometry, scatter density, and sim detail (R0–R5). Same family as the knowledge-pyramid / seeded-softmax realization law. Candidate unifying principle to develop; would let one fidelity driver govern all LOD in lockstep. Not yet a decision.

## Splice portfolio follow-ups (updated 2026-07-29)

- **CONFIRMED: widening to 84km drifted two patches out of character.** `ebro_delta` (scouted p99 37m flat delta) now measures 1..1209m — it has re-acquired the Els Ports foothills, the exact failure the 2026-07-23 re-centring fixed. `savannah` (scouted p99 21m) now 1..406m. Both are live in the ring serving terrain that doesn't match their catalogued biome. **Fix is re-centring at the 84km footprint, which is a scouting decision, not a re-fetch.** Rule: patches whose value is being *flat* or *small* don't survive widening; broad uniform landscapes (steppe, open coast, dunes) do. See splice-portfolio.md.
- **Still thin after Batch 4:** Metro/city (2 candidates, and "THE city" at 3–8% arc is a *destroyed* megacity — probably authored, not spliced), Engineered infrastructure (1: guri_dam), and **open water** — all three coast candidates are headlands, none is the open sea that geography.md's 18–25% stretch needs.
- **No multi-patch system exists yet.** `ring_vibes.gd` loads exactly one DEM (`millstreet`) and tiles its imagery for everything else. Actually placing different splices around the arc needs a patch-registry + streaming pass that hasn't been designed.

## Splice portfolio follow-ups

See `docs/terrain/splice-portfolio.md` for the full verified-candidate catalog (12 locations so far: millstreet, priests_leap, mizen_head, slea_head, loop_head, monument_valley, mongolia_steppe, costa_rica_jungle, ebro_delta, vermont, cork_city, savannah). Two new biome catalog entries came out of this batch (Jungle/volcanic-highland, Temperate pastoral hills) — both un-ranked in biomes.md's "author's cut" ranking list, which is your call, not something to auto-fill.
