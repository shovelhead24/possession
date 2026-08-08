# Patch character review — first pass

Area doc, **2026-08-07**. Produced by `tools/dem/patch_census.py` (statistics) plus a read of each
patch's `out/<name>_s2_preview.jpg` (judgement). Re-runnable; this is the first pass.

## Why

Patches were scouted at ~22 km with a specific character in mind, then expanded to ~90 km for
uniform tiling — 16× the area. Several stopped being the place we picked, and `ebro_delta` and
`savannah` sat in TODO as "drifted" for weeks: not because the fix was hard, but because checking
means looking at 35 images and nobody does that.

Second and larger reason: **every biome parameter in `PATCHES` is a number I guessed from the place
name.** `tint`, `trees`, `tree_hi`, `weather` — all invented. The imagery can measure them.

## Method, and its first correction

Statistics propose, the image adjudicates. That division earned itself immediately:

**`mongolia_steppe` measured 80.2% vegetation.** The image is olive-brown semi-arid steppe, finely
dissected by dendritic drainage, with no tree anywhere in 93 km. The excess-green index
(`2g − r − b > 0.06`) fires on khaki, so it reads any warm-olive dryland as vegetated.
**`veg_pct` over-reads on semi-arid ground and cannot be trusted alone.**

**`dordogne` measured 97.9%** — and the image is genuinely dense dark forest with agricultural
clearings and a river. Same metric, correct this time.

No statistic distinguishes those two cases. That is the whole argument for the image pass, and it
means the threshold cannot simply be re-tuned: the metric is a *candidate flag*, not an answer.

## Findings

### Retired patches were correctly retired
`savannah` measures 25 m of relief and 32% sea — not savannah. `ebro_delta` measures 1,196 m of
relief — not a delta. Both were replaced by `big_sur` and `cape_peninsula` before this review ran,
so the census confirms a call already made rather than finding anything new. Worth noting the
census would have caught both, unprompted, weeks earlier.

### `trees` is set too low on the forested patches
Where the image confirms real canopy, the authored value is well under it:

| patch | measured veg | `trees` now | image says |
|---|---|---|---|
| dordogne | 97.9% | 0.5 | dense forest + clearings — **too low** |
| vermont | 99.0% | 0.6 | — |
| tatra_spruce | 98.0% | — | — |
| costa_rica_jungle | 98.3% | — | — |
| borneo_highland | 92.7% | — | — |
| schwarzwald | 91.9% | 1.0 | consistent |

Only dordogne has been image-checked so far. The rest are candidates, not conclusions.

### Mosaic seams are visible on some patches
`mongolia_steppe` shows clear rectangular blocks where scenes with different colour balance were
pasted together — it reads as patchwork, not ground. `dordogne` shows none. This is per-patch and
worth flagging in future passes; the fix is colour-matching scenes at paste time in `fetch_s2.py`,
which nothing currently does.

### Driving quality — new, and now load-bearing
Driving is going to be a big part of the game, so the census measures ground you could actually
drive on (slope < 12°, above sea level) and road length from the OSM centrelines.

**Best driving patches:**

| patch | drivable | road km | note |
|---|---|---|---|
| dordogne | 88.5% | 18,725 | densest road network in the portfolio |
| wye_valley | 84.8% | 13,899 | |
| millstreet | 95.7% | 8,450 | the home patch, and it holds up |
| schwarzwald | 71.8% | 11,310 | |
| tuscany_hills | 81.4% | 8,326 | |
| java_majapahit | 78.4% | 10,522 | |

**Worst — near-undrivable:** `palawan` 5.2%, `cape_peninsula` 7.8%, `lofoten` 9.7%,
`dolomites` 15.7%, `halong_bay` 18.0%. All the coastal/alpine ones, which is expected and fine —
but it means the coastal batch bought scenery, not driving, and the ring's drivable arc is
concentrated in the temperate European patches.

`namib_dunes` has 106 km of road across a 98 km patch. Effectively trackless.

### Marker displacement is not a usable drift signal as implemented
It takes the *worst* marker, so any patch with markers spanning a route scores badly by design —
`millstreet` reads 44.7 km because its markers are the two ends of a road. Should use the camera
anchor, or the mean. Not fixed yet.

## Pass 2 — patches 1–10 alphabetical (2026-08-08)

Imaged: `cairngorms`, `danube_delta`. The other eight measure consistent with their authored
values, so by the rule in TASKS.md ("read the image before changing a biome number") they were not
imaged and not changed.

**`cairngorms` — corrected.** Heather moor throughout, forestry confined to the straths, bare
granite plateau in the middle. `trees` 0.5 → 0.25 (roughly double the real canopy); `tree_hi`
700 → 550 m (plantations stop well below the old ceiling); tint browner.

**`danube_delta` — holds, with two defects.** The census's 92.2% vegetation is reed bed, not
canopy, so `trees: 0.1` is correct and stays. But:

1. **64% of it renders as ocean.** Delta land sits at 0–2 m and `SEA_LEVEL` is 0.5 m, so most of
   the marsh is below the clamp. The heightfield says 63.8% sea; the imagery shows roughly 25%
   water. In game this patch is mostly sea when it should be reed bed. Needs a per-patch sea
   offset, which is a change beyond a biome number — not made.
2. **Severe mosaic seams**, worse than mongolia's — whole rectangular blocks at different
   exposure, very visible over the water. Same root cause: `fetch_s2.py` colour-matches nothing.

## Pass 3 — patches 11–20 alphabetical (2026-08-08)

`ebro_delta` and `great_plains` are retired; `millstreet` is the home patch. Imaged: `dolomites`,
`guri_dam`, plus `dordogne` from pass 1.

**`dordogne` — corrected.** `trees` 0.5 → 0.85, tint darker green. Confirmed dense forest.

**`dolomites` — tint corrected.** `trees` 0.7 and `tree_hi` 2000 m both check out against a hard,
clearly visible treeline. But the tint was pale limestone grey when conifer dominates the frame and
the rock is only on the massif tops. Now dark green.

**`guri_dam` — worst drape in the portfolio.** A hard vertical seam splits two entirely different
scenes: dry brown scrub west, green forest and reservoir east, different seasons, different
exposure, cloud over the eastern half. `trees` 0.4 averages the halves fairly and stays; tint was
green where the dominant half is brown.

### Seams are systemic, not incidental
Four of four multi-scene patches inspected now show them: `mongolia_steppe`, `danube_delta`,
`dolomites`, `guri_dam` — worst first. Only `dordogne`, which is covered by a single scene, is
clean. This is no longer a per-patch note; **any patch needing more than one Sentinel-2 scene will
be visibly patchworked** until `fetch_s2.py` normalises scenes before pasting. Already queued.

## Pass 4 — patches 21–30 alphabetical (2026-08-08)

Imaged: `salar_uyuni`, `palawan`, plus `mongolia_steppe` from pass 1. Only one biome number moved,
because this pass found something bigger.

**`mongolia_steppe` — tint nudged** to the measured mean. `trees: 0.05` confirmed by eye: no tree
in 93 km. The census's 80% "vegetation" is excess-green firing on khaki, as established in pass 1.

### The drapes are in worse shape than the biome numbers
Three of the four patches inspected this pass have imagery that is unusable, each for a different
reason, and **none of it is visible in any statistic we currently record**:

| patch | defect | biome numbers |
|---|---|---|
| `salar_uyuni` | **pure white, no detail at all** — clipped to 1.0/1.0/1.0 across the whole frame | fine |
| `palawan` | **~55% cloud sheet** over the western half, with diagonal scene edges | fine (`trees: 0.9` holds where land shows) |
| `guri_dam` | seam, two seasons, cloud (pass 3) | fine |

The pattern: **coverage is not quality.** `fetch_s2.py` records `coverage` in the sidecar, but that
counts *filled* pixels — a fully cloud-covered scene fills 100% of the canvas and reports success.
Scene selection sorts on the STAC `eo:cloud_cover` field, which is a scene-wide figure: a scene can
be 5% cloudy overall and completely clouded over our particular bbox.

`salar_uyuni` is a separate failure — a salt flat is genuinely near-white, and `sat_gain = 1.35` in
the terrain shader then pushes it past 1.0. So it will render as a white void even if the fetch is
sound.

Neither is fixable by editing a biome number, so nothing was changed for those two.

## Open

- Re-run after the 8192 refetch completes; several previews are still the old canvas.
- `veg_pct` needs a companion metric that separates khaki from canopy — saturation, or the
  variance of green, would probably do it. Until then every high reading needs an eye on it.
- Nothing here has been applied to `PATCHES`. This proposes; changing a biome or re-centring a
  patch (33 minutes and destroys the old one) stays a decision.
