# Shared TODOs

Cross-session scratchpad for loose ends that don't have a natural home yet — not a duplicate of each area doc's own "Open Questions" section (those are design-space questions; this is "needs a next action"). Prune entries once they're resolved or promoted into a real doc/decision/issue.

## Needs your action (laptop/hardware-side)

- ~~Delete `.planning/`~~ **Done 2026-07-23** — issue #6 closed.
- ~~Re-center `ebro_delta`~~ **Done 2026-07-23** — verified flat (p99 37m), see splice-portfolio.md.
- ~~Flatter `mongolia_steppe` box~~ **Done 2026-07-23** — relief down from 1043m to 326m, see splice-portfolio.md.
- **Run `tools/dem/fetch_osm_roads.py`-style check for `cork_city` / `savannah`** — this laptop *does* have working Overpass access (proven earlier this session), so this is doable, just not yet done — the two metro splice candidates' road-grid character (organic vs. planned-grid) is still asserted from real-world knowledge, not independently verified against actual OSM data.

## Open design threads (unresolved mid-conversation)

- **D4 curvature — atmosphere shell question, still unanswered:** does the ring have a confined atmosphere shell (thin band near the surface, vacuum/space above it) or does atmosphere fill the whole cross-section? This decides whether angle-dependent haze (airmass-style, like real atmospheric extinction) is the right frame for the near/far seam + night-sky-reveal tension, or whether that's importing physics nobody intended. Was mid-discussion when the session moved to DEM/biome work.
- **Ring width discrepancy:** `game/mocks/ring_vibes.gd` has width locked to widest (50km) as of 2026-07-23 per its code comment, but `.decisions/world.md` still lists width as open (D2b, pending #9 vibe-check). Worth reconciling — either promote the mock default to a real decision, or note explicitly that it's provisional.

## Splice portfolio follow-ups

See `docs/terrain/splice-portfolio.md` for the full verified-candidate catalog (12 locations so far: millstreet, priests_leap, mizen_head, slea_head, loop_head, monument_valley, mongolia_steppe, costa_rica_jungle, ebro_delta, vermont, cork_city, savannah). Two new biome catalog entries came out of this batch (Jungle/volcanic-highland, Temperate pastoral hills) — both un-ranked in biomes.md's "author's cut" ranking list, which is your call, not something to auto-fill.
