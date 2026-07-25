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
- ~~D9 substrate freeze vs. plain dimensions~~ **Resolved 2026-07-25** — 128 m power-of-two leaf tile divides 2,000 km exactly (15,625 around, zero remainder); width never needed power-of-two-ness since it doesn't wrap (edge tile ≠ seam tile). See `docs/terrain/substrate.md` "Dimensions — RESOLVED".

## Splice portfolio follow-ups

See `docs/terrain/splice-portfolio.md` for the full verified-candidate catalog (12 locations so far: millstreet, priests_leap, mizen_head, slea_head, loop_head, monument_valley, mongolia_steppe, costa_rica_jungle, ebro_delta, vermont, cork_city, savannah). Two new biome catalog entries came out of this batch (Jungle/volcanic-highland, Temperate pastoral hills) — both un-ranked in biomes.md's "author's cut" ranking list, which is your call, not something to auto-fill.
