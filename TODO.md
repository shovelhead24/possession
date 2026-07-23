# Shared TODOs

Cross-session scratchpad for loose ends that don't have a natural home yet — not a duplicate of each area doc's own "Open Questions" section (those are design-space questions; this is "needs a next action"). Prune entries once they're resolved or promoted into a real doc/decision/issue.

## Needs your action (laptop/hardware-side)

- **Delete `.planning/`** (issue #6) — everything worth salvaging is already mined (snow bug → issue #5, terrain editor spec → issue #7 backlog, quit()-reload gotcha → `.decisions/engine.md`). The remote session's bulk-delete got blocked by its permission classifier; trivial for you to `git rm -r .planning/` locally.
- **Run `tools/dem/fetch_osm_roads.py`-style check for `cork_city` / `savannah`** — the remote session couldn't reach the Overpass API (proxy blocked it), so the two metro splice candidates' road-grid character (organic vs. planned-grid) is asserted from real-world knowledge, not independently verified against actual OSM data yet.
- **Re-center `ebro_delta`** (`tools/dem/fetch_dem.py`) — current box still catches nearby upland (Els Ports foothills, p99 elev 575m), not a clean flat-marsh reference. Try centering further SE (~40.62, 0.80) with a smaller pad.
- **Try a flatter sub-box for `mongolia_steppe`** — current box has more relief (1043m) than the "huge flat sightlines" Grass steppe read wants; a truer steppe patch is probably nearby.

## Open design threads (unresolved mid-conversation)

- **D4 curvature — atmosphere shell question, still unanswered:** does the ring have a confined atmosphere shell (thin band near the surface, vacuum/space above it) or does atmosphere fill the whole cross-section? This decides whether angle-dependent haze (airmass-style, like real atmospheric extinction) is the right frame for the near/far seam + night-sky-reveal tension, or whether that's importing physics nobody intended. Was mid-discussion when the session moved to DEM/biome work.
- **Ring width discrepancy:** `game/mocks/ring_vibes.gd` has width locked to widest (50km) as of 2026-07-23 per its code comment, but `.decisions/world.md` still lists width as open (D2b, pending #9 vibe-check). Worth reconciling — either promote the mock default to a real decision, or note explicitly that it's provisional.

## Splice portfolio follow-ups

See `docs/terrain/splice-portfolio.md` for the full verified-candidate catalog (12 locations so far: millstreet, priests_leap, mizen_head, slea_head, loop_head, monument_valley, mongolia_steppe, costa_rica_jungle, ebro_delta, vermont, cork_city, savannah). Two new biome catalog entries came out of this batch (Jungle/volcanic-highland, Temperate pastoral hills) — both un-ranked in biomes.md's "author's cut" ranking list, which is your call, not something to auto-fill.
