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

## Batch 3 — Engineered Water Infrastructure

| Name | Location | Verified stats | Biome affinity | Notes |
|---|---|---|---|---|
| `guri_dam` | Embalse de Guri / Simón Bolívar Dam, Guiana Highlands, Venezuela | elev median 207m, 313m relief (p99-p1); **reservoir visually confirmed in-frame via Sentinel-2** (2026-07-25) | Engineered/reactivatable infrastructure | A dam+reservoir at scale, not natural terrain — direct grounding for lore.md's reactivatable ancient systems and civilization.md's open surviving-enclave-economy question. One open caveat remains: the -1048m raw elevation minimum is almost certainly a Terrarium decode artifact (same class as Savannah's), not real terrain — doesn't affect the confirmed reservoir framing, but shouldn't be trusted as a real depth reading. Note: this candidate exposed a real tooling bug (fixed same day) — `fetch_s2.py`/`fetch_osm_roads.py` weren't location-parameterized like `fetch_dem.py`, so this verification pass briefly overwrote `millstreet`'s live satellite asset before being caught and restored. |

## Batch 2 — Desert, Plateau, Jungle, Delta, Temperate Hills, Metro

| Name | Location | Verified stats | Biome affinity | Notes |
|---|---|---|---|---|
| `monument_valley` | Monument Valley, UT/AZ, USA | elev 1430-2063m, 632m relief, 0% sea | Desert (pinch rain-shadow) | clean read, no caveats |
| `mongolia_steppe` | Central Mongolia, east of the Khangai range | elev 1302-1749m, **326m relief (p99-p1)**, 0% sea | Grass steppe | **re-centered 2026-07-23** — original Orkhon Valley box had 1043m relief (river-valley hills); this box (open steppe clear of the foothills) is a genuine flat-sightlines read |
| `costa_rica_jungle` | Arenal area, Costa Rica | elev 73-2134m, 2061m relief, 0% sea | **Jungle (volcanic highland)** — new catalog entry, biomes.md | mountainous rainforest (Arenal volcano massif in-frame), not flat-basin jungle; Conifer night-forest was the wrong temperature/tone, so this got its own entry instead of a forced fit |
| `ebro_delta` | Ebro Delta plain, Spain | elev -8 to 100m, **p99 elev 37m**, 85% sea/wetland | Delta marsh | **re-centered 2026-07-23** — original box caught Els Ports foothills (p99 575m); this box sits on the actual delta plain, genuinely flat now |
| `vermont` | Stowe/Mad River Valley, VT, USA | elev 86-1338m, 1253m relief, 0% sea | **Temperate pastoral hills** — new catalog entry, biomes.md | settled/pastoral tone distinct from River Valley's frontier/ford-town grit; correlates with frontier/enclave recovery band (fertility → surplus → complexity) |
| `cork_city` | Cork City, Ireland | elev 1-176m, 175m relief, ~0% sea | Metro/city archetype | real hill relief around the center, organic (non-grid) street layout — contrast case to Savannah |
| `savannah` | Savannah, GA, USA | p99 elev 21m (confirmed flat — the 318m box max is a Terrarium decode artifact, not real terrain), ~11% sea/marsh | Metro/city archetype | historic planned grid, contrast case to Cork |

Road-grid character for the two metro candidates (Cork's organic layout vs. Savannah's planned squares) is asserted from well-documented real-world knowledge, not independently re-verified here — Overpass/OSM access wasn't reachable from this environment this session.

## Batch 4 — Portfolio Expansion Toward Tiling the Ring (2026-07-29)

**Why 20 at once:** at Millstreet's 84 km footprint, **36 patches** tile the 3,000 km ring edge-to-edge (the patch already spans the full 50 km width, so you only tile along the arc; 75 would be 40 km spacing with overlap for blending). Several arc stretches are deliberately *not* Earth — alloy barrens, hub spire, containment dome, and arguably the destroyed city are authored — leaving ~10 fetchable biomes. At ~3 variants each to avoid visible repetition, that's ~30 locations; the portfolio held 13.

All boxes below verified live via the new `tools/dem/scout_batch.py` (batch scout, shared tile cache). **Caveat: these are scout-sized boxes (~0.2° ≈ 22 km), not Millstreet's 84 km export box.** Widening any of them to a real ring patch needs re-verification — character can drift out of the biome at 4× the footprint.

| Name | Location | Verified stats (p1/p50/p99, relief, sea) | Biome slot | Notes |
|---|---|---|---|---|
| `schwarzwald` | Feldberg, Black Forest, Germany | 317/961/1318 m, relief 1001 m, 0% sea | **Conifer night-forest** | Whole box sits *below* the ~1400 m treeline — genuinely forested highland, not bare rock. The archetype. |
| `olympic_forest` | Hoh valley, Olympic Peninsula, WA | 141/771/1896 m, relief 1755 m, 0% sea | **Conifer night-forest** | Temperate rainforest under big relief; wetter/more dramatic variant of the same slot. |
| `wye_valley` | Tintern, Wales/England border | 1/81/253 m, relief 252 m, 8.8% water | River Valley | Tidal here — real river crossings, the ford-town read. |
| `dordogne` | Sarlat, France | 61/186/313 m, relief 252 m, 0% sea | River Valley | Same gentleness without tidal water; drier, more settled. |
| `great_plains` | Nebraska Sandhills, USA | 1036/1100/1182 m, relief 147 m, 0% sea | Grass steppe | Flatter than `mongolia_steppe` (147 m vs 326 m) — huge sightlines. |
| `camargue` | Rhône delta, France | 1/2/16 m, relief 15 m, 63.4% water | Delta marsh | Flattest in the portfolio bar the salar. Reed geometry = routes-as-knowledge. |
| `danube_delta` | Romania | 1/1/28 m, relief 27 m, 58.4% water | Delta marsh | Larger-channel character than the Camargue. |
| `dolomites` | Tre Cime, Italy | 896/1756/2744 m, relief 1848 m, 0% sea | Highland/crags | Most vertical candidate found (max 3139 m). Glider/hookshot grounding. |
| `cairngorms` | Scotland | 230/654/1179 m, relief 948 m, 0% sea | Highland/crags | Plateau-and-corrie rather than spire; the gentler highland read. |
| `tatra_spruce` | High Tatras, Slovakia/Poland | 687/1057/2250 m, relief 1563 m, 0% sea | Highland/crags | **Reclassified.** Scouted as conifer, but p50 1057 m against a ~1500 m treeline and a 2606 m max means most of the box is *above* the trees. Kept as crags rather than mislabelled. |
| `norwegian_fjord` | Geirangerfjord, Norway | 52/1078/1656 m, relief 1604 m, 5.8% water | Highland + sea | Strongest "wall meets water" candidate yet — beats `slea_head`. |
| `atacama` | San Pedro, Chile | 2335/2579/4132 m, relief 1797 m, 0% sea | Desert (preservation) | **Caveat:** floor at 2335 m, peaks 4629 m — this is Andean *altiplano* desert, not low desert. Still literally the driest place on Earth. |
| `namib_dunes` | Sossusvlei, Namibia | 519/684/914 m, relief 395 m, 0% sea | Desert (dunes) | Low-desert dune-field counterpart to Atacama's altiplano. |
| `borneo_highland` | Mount Kinabalu, Borneo | 99/779/3401 m, relief 3302 m, 0% sea | Jungle (volcanic highland) | Even more vertical than `costa_rica_jungle`; rainforest to alpine in one box. |
| `tuscany_hills` | Val d'Orcia, Italy | 137/334/730 m, relief 594 m, 0% sea | Temperate pastoral | Cultivated/sculpted read; drier counterpart to Vermont's wooded version. |
| `tepui` | Mount Roraima, Venezuela | 815/1287/2329 m, relief 1514 m, 0% sea | **Lost-world pocket** | The literal "Lost World" tepui — flat-topped mesa with sheer walls, a natural grounding for a sealed pocket ecology (geography.md ~80%). |
| `badlands_sd` | South Dakota, USA | 734/830/917 m, relief 183 m, 0% sea | Eroded badlands | Modest height, intensely dissected — erosion character, not mountain character. For the hub-spire approach's "most degraded *and* most ancient". |
| `iceland_highland` | Landmannalaugar, Iceland | 548/721/1097 m, relief 549 m, 0% sea | Volcanic/glacial | Least Earth-familiar of the natural candidates — rhyolite colour, no vegetation. |
| `scablands` | Palouse Falls, WA | 165/393/520 m, relief 354 m, 0% sea | *Alloy-barrens analogue* | Catastrophic-flood scour channels in basalt — erosion that looks engineered. |
| `salar_uyuni` | Bolivia | 3654/3659/3664 m, **relief 10 m**, 0% sea | *Alloy-barrens analogue* | Flattest by an order of magnitude. Dead-flat, featureless, wrong-looking — closest Earth gets to a builder-alloy plain. |

### Findings

1. **The conifer gap is closed.** Before this batch the portfolio had *zero* candidates for Conifer night-forest — despite it being one of only two biomes the first slice needs (`biomes.md`: "the slice needs exactly two — valley + night-forest edge") and #4 in the author's-cut ranking. `schwarzwald` and `olympic_forest` now cover it.
2. **Treeline is a real selection constraint, not a detail.** `tatra_spruce` looked like an obvious conifer pick by name and reputation and failed on the numbers — most of the box is above the trees. Any future forest candidate needs its p50 checked against the local treeline, not just its relief.
3. **The alloy barrens have Earth analogues after all** — not to splice, but to steal shape language from. The salar's 10 m relief over 22 km is the "wrong flatness" the barrens want; the scablands' scour channels are erosion that reads as engineering.
4. **Two "biome affinity" clusters from the Batch-1 finding hold up.** Highland and Coast/lagoon keep recurring together (`norwegian_fjord`, `slea_head`) — consistent with the working hypothesis in `biomes.md`'s Open Questions that both are *cross-ring (lat) bands* rather than long spinward stretches. Still not promoted to decided.

### Coverage after Batch 4

| Biome | Candidates |
|---|---|
| River Valley | millstreet, wye_valley, dordogne |
| Conifer night-forest | schwarzwald, olympic_forest |
| Grass steppe | mongolia_steppe, great_plains |
| Coast/lagoon | mizen_head, loop_head, slea_head |
| Delta marsh | ebro_delta, camargue, danube_delta |
| Highland/wall-foot crags | priests_leap, dolomites, cairngorms, tatra_spruce, norwegian_fjord |
| Desert | monument_valley, atacama, namib_dunes |
| Jungle | costa_rica_jungle, borneo_highland |
| Temperate pastoral | vermont, tuscany_hills |
| Metro/city | cork_city, savannah |
| Engineered infrastructure | guri_dam |
| Lost-world pocket | tepui |
| Eroded/ancient | badlands_sd |
| Volcanic/glacial | iceland_highland |
| Alloy barrens (analogues only) | scablands, salar_uyuni |

**Still thin:** Metro/city (2, and "THE city" at 3–8% arc is a *destroyed* megacity — likely authored rather than spliced), Engineered infrastructure (1), and the sea itself has no open-water candidate (all three coast picks are headlands).
