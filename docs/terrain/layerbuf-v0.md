# LayerBuf v0 — Field Registry Draft

First detail sub-doc under [terrain.md](../terrain.md)'s D3 sketch. Working names: **LayerBuf** = the additive-only field registry; **syncopations** = anomaly seeds in foundational layers (cheap upstream notes, outsized downstream power — the music intuition, 2026-07-18 session).

Rules recap: fields are named rasters (or sparse lists) with units + metadata; adding fields is non-breaking; removing/retyping is a versioned migration; engines stay naive — this doc specifies *what layers say to each other*, not how they compute it.

## S — Substrate (frozen early, beneath L0)

- `ring_lon` — meters along circumference, wraps at 2,000,000 m
- `ring_lat` — meters across width, 0 at ring centerline
- Tile addressing + resolution pyramid: TBD in `substrate.md` (next sub-doc; mixed-res from day one)

## L0 — Builders' Shape

| Field | Type/Units | Notes |
|---|---|---|
| `height_base` | f32 m | designed macro terrain |
| `wall_profile` | f32 m (per-lon curve) | rim wall height/shape |
| `bedrock_class` | u8 enum | granite / sediment / regolith / **builder-alloy** (erodibility ~0) |
| `anomaly_list` | sparse {type, lon, lat, radius, params} | **the syncopations** — see below; the growing anomaly-*type* registry lives in docs/locations.md (types are content, not schema) |

Params: macro noise octaves, mountain-intent maps, authored + sparse-procedural anomaly seeds, `splice_dem` patches (real-Earth DEM cuts — source/rect/blend-margin; sources + licensing in research/r8-real-dem-sources.md; diegetically sound per lore.md's Earth zoo — the builders sampled Earth). L1 erosion welds splice seams; downstream layers are splice-agnostic.

## L1 — Hydrology / Erosion

Naive-engine note: one erosion pass driven by a *prior* rain map (uniform + wall-shadow guess); L2 computes real climate afterward. (Circular rain↔terrain dependency deliberately not iterated in v0.)

| Field | Type/Units | Notes |
|---|---|---|
| `height` | f32 m | carved result |
| `flow_acc` | f32 m² | drainage area — rivers are where this is big |
| `river_order` | u8 | Strahler order |
| `water_level` | f32 m | seas/lakes surface |
| `water_table` | f32 m depth | hoarded: wells, oases, cave wetness |
| `sediment` | f32 m depth | **soil thickness — future arable land** |
| `ford_candidates` | sparse points | hoarded: shallow wide crossings, for L5 roads |

Params: rain prior, erosion iterations, sea volume target, carve strength.

## L2 — Climate

| Field | Type/Units | Notes |
|---|---|---|
| `temp_mean` | f32 °C | altitude lapse + designed bands |
| `moisture` | f32 [0,1] | advected from water bodies by spinward wind |
| `wind_exposure` | f32 [0,1] | hoarded: tree shape, snow drift, sailing |
| `wall_shadow_hours` | f32 h | parameterized by designed day length |

Params: `spinward_wind` (vector + strength — a ring has one prevailing wind and it's a *design* choice), lapse rate, advection distance.

## L3 — Biomes

| Field | Type/Units | Notes |
|---|---|---|
| `biome_id` | u8 | classified from climate × sediment × slope |
| `biome_blend` | u8×4 weights | transition bands |
| `info_opacity` | f32 [0,1] | information topology (backprop 2026-07-22 — referenced by knowledge.md and softmax temperature since day one, never registered until the biome catalog forced it) |
| `signal_amplification` | f32 [0,1] | how far information propagates; drives rumor decay and acoustic reach |

Params: the classification matrix (biome × thresholds), adjacency-legality table (bake gate input), transition widths.

## L4 — Scatter Fields (densities, never instances)

| Field | Type/Units | Notes |
|---|---|---|
| `tree_density`, `grass_density`, `rock_density` | f32 [0,1] | runtime scatters deterministically from these |
| `deer_habitat` | f32 [0,1] | meadow × water proximity — **the deer moment is a field** |
| `wolf_range` | f32 [0,1] | forest edge × deer_habitat — **so is the wolves moment** |
| `fish_density` | f32 [0,1] | rivers/lagoons/sea — food economy + water readability (wildlife.md) |
| fauna habitat fields, general | f32 [0,1] each | boar/horse/flock/megafauna added per species as wildlife.md solidifies — additive-only, same pattern as deer/wolf |

## L5 — Civilization

Consumes: `sediment` (arable), `ford_candidates`, pinch topology (from `wall_profile` + `height`), biomes, water.

| Field | Type/Units | Notes |
|---|---|---|
| `settlement_sites` | sparse {size, culture_seed, age} | placed by water/arable/defensibility/pinch logic |
| `road_graph` | sparse polylines | pathfound over cost surface; crossings snap to fords |
| `landuse_mask` | u8 | fields, pasture, quarry |
| `ruin_sites` | sparse | history pass: prior epochs, some settlements rolled back/abandoned |
| `tech_level` | f32 [0,1] | connectivity × resources × collapse severity × syncopation noise — see civilization.md |
| `recovery_band` | u8 enum | classified from `tech_level` (same pattern as L3 biome classification); placeholder names only |

Params: population budget, spacing, road cost weights, history epoch count, recovery-band classification thresholds.

## L6 — Narrative Anchors

The 12 moment sites as constraint stamps; some push requirements upstream (city bay → L1 sea; reveal ridge → L0 profile). Fields: `anchor_sites` sparse + per-site precondition set (bake-gate inputs).

## L7 — Hand Edits

Per-field brush deltas (height, biome override, densities). The April editor's per-vertex offsets are the v0 of this layer.

---

## Syncopations — worked cascades

One line in `anomaly_list`, whole regional character out the far end:

1. **Impact crater** (900 m bowl at lon 412 km) → L1: crater lake + springs → L2: local humidity plume → L3: oasis forest ring in steppe → L4: deer habitat spike → L5: rim settlement, pilgrimage road → a region with a myth. Cost: one list entry.
2. **Builder scar** (exposed alloy seam, erodibility 0) → L1: rivers deflect, waterfalls at its edges → L3: knife-edge vegetation line → L5: all roads funnel through the one gap → natural fortress + battlefield. A medieval-army-moment site the generator *earned*.
3. **Dead transit pylon row** along a lon line → L5: ancient roadbed = low path cost → roads shadow it → civilization grows along the bones of the builders. The theme, made mechanical.

Syncopation writing rule: anomalies only *perturb inputs* to later layers (a bedrock class, a hole, a cost modifier). They never script outcomes — the cascade must be earned through the layers, or the world stops being coherent.
