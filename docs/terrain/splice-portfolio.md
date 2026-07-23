# Real DEM Splice Portfolio

Living catalog of real-world locations verified as candidate `splice_dem` inputs (R8 — [research/r8-real-dem-sources.md](../research/r8-real-dem-sources.md)) for L0. Each entry has been fetched live against Terrarium/Copernicus and checked for genuine relief/character before being added to `tools/dem/fetch_dem.py`'s `LOCATIONS` dict — this is a verification log, not a placement plan; where each one lands on the ring is geography.md's job, not this doc's.

Per R8: splicing is an L0 *input option*, composited with noise/intent — this portfolio is stocking the shelf, not proposing the whole ring be wall-to-wall Earth.

## Verified

| Name | Location | Verified stats | Biome affinity | Notes |
|---|---|---|---|---|
| `millstreet` | Cork/Kerry border, Ireland | existing production splice | River Valley | the original near-field test patch |
| `priests_leap` | Caha Mountains over Bantry Bay, Cork/Kerry, Ireland | peak 690m (≈ Hungry Hill 685m); bay inlet in-frame | Highland/wall-foot crags | mountain pass, genuine pinch-point geometry |
| `mizen_head` | SW tip of Ireland | peak 456m; 82% sea in-frame | Coast/lagoon | real signal station on site — lighthouse archetype grounding |
| `slea_head` | Dingle Peninsula, Kerry, Ireland | peak 771m; 69% sea in-frame | Highland/wall-foot crags *or* Coast/lagoon (both — mountains dropping straight into sea) | strongest "wall meets water" candidate so far |
| `loop_head` | Shannon Estuary mouth, Clare, Ireland | peak 655m (likely inland hills within the padded box, not the headland cliffs themselves — re-verify with a tighter bbox before use); 78% sea in-frame | Coast/lagoon | real lighthouse on site |

## Biome-Arrangement Finding

The first five candidates split into two clusters, not a spread — mountain-pass/highland (`priests_leap`, `slea_head`) and headland/coast (`mizen_head`, `loop_head`, and `slea_head` again). That's suggestive for biomes.md's open "lat vs lon" question: highland and coast read as **cross-ring (lat) bands** — a wall-foot crag and a coastal fringe recurring around the whole circumference — rather than long spinward stretches you walk through once. Recorded as a finding, not a ratified answer; more candidates should stress-test it before it's promoted to biomes.md's decided section.

## Geography/Locations Cross-Refs

- `mizen_head` and `loop_head` both have real lighthouse/signal-station infrastructure on site — direct grounding for [locations.md](../locations.md)'s Lighthouse/beacon-tower archetype and geography.md's ~18–25% "the sea" stretch (lighthouse chain).
- `priests_leap` is a real mountain-pass pinch point — candidate grounding for geography.md's ~60–75% highland/wall country stretch.

## Batch 2 — Desert, Plateau, Jungle, Delta, Temperate Hills, Metro

| Name | Location | Verified stats | Biome affinity | Notes |
|---|---|---|---|---|
| `monument_valley` | Monument Valley, UT/AZ, USA | elev 1430-2063m, 632m relief, 0% sea | Desert (pinch rain-shadow) | clean read, no caveats |
| `mongolia_steppe` | Orkhon Valley, Mongolia | elev 1312-2355m, 1043m relief, 0% sea | Grass steppe | more relief than the "huge flat sightlines" catalog description implies — a flatter sub-box nearby is probably the truer steppe read; this one leans hill-country-with-steppe-floor |
| `costa_rica_jungle` | Arenal area, Costa Rica | elev 73-2134m, 2061m relief, 0% sea | **not yet in the biome catalog** | mountainous rainforest (Arenal volcano massif in-frame), not flat-basin jungle; closest existing entry (Conifer night-forest) is the wrong temperature/tone — candidate for a new tropical entry rather than a forced fit |
| `ebro_delta` | Ebro Delta, Spain | elev 1-735m, sea 73%, **p99 elev 575m** | Delta marsh | **not verified-flat** — p99 this high means a real chunk of the box is nearby upland (Els Ports foothills), not delta plain. Needs re-centering further SE (~40.62, 0.80) and a smaller pad before treating as a clean flat-marsh reference. Left in `LOCATIONS` as a first pass, flagged in its code comment. |
| `vermont` | Stowe/Mad River Valley, VT, USA | elev 86-1338m, 1253m relief, 0% sea | **not yet in the biome catalog** | temperate rolling hills, pastoral/settled tone — River Valley is the nearest existing entry but that one's tuned toward frontier/ford-town flavor, not this. Candidate for its own entry if the pastoral-Americana tone is wanted distinct from River Valley. |
| `cork_city` | Cork City, Ireland | elev 1-176m, 175m relief, ~0% sea | Metro/city archetype | real hill relief around the center, organic (non-grid) street layout — contrast case to Savannah |
| `savannah` | Savannah, GA, USA | p99 elev 21m (confirmed flat — the 318m box max is a Terrarium decode artifact, not real terrain), ~11% sea/marsh | Metro/city archetype | historic planned grid, contrast case to Cork |

Road-grid character for the two metro candidates (Cork's organic layout vs. Savannah's planned squares) is asserted from well-documented real-world knowledge, not independently re-verified here — Overpass/OSM access wasn't reachable from this environment this session.
