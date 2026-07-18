# Possession — World & Scale

The world design doc: the ring as a place. Grown by hydration from [brief.md](brief.md) sessions — settled facts reference `.decisions/world.md`; everything else is tagged PROPOSED or OPEN.

## The Ring — SETTLED 2026-07-18

**Circumference 2,000 km, radius ~318 km** (`.decisions/world.md#ring-circumference-2000km`). Chosen so every sky promise is geometrically honest and interior/space flight can never catch the world lying:

| What you see | Honest value at 2,000 km |
|---|---|
| Far side overhead at night (10 km band) | ~0.9° — almost two full moons; scales with width (30 km → 2.7°, 50 km → 4.5°) |
| Terrain rise 20 km ahead | ~630 m — ridges sit visibly "up" |
| Terrain rise 50 km ahead | ~3.9 km — mountains above you, ocean above that |
| A 1 km city on the far side | a distinct light cluster, naked-eye readable |

**Day length is a designed value, not physics** (`#cosmology-honest-sky-cheated-day`): honest spin-days would be ~19 minutes; nothing in-game can witness that lie, so pacing wins. Tuned later, not now. Fiction options if ever needed: shadow squares (visible ancient machinery — very on-theme), or silence.

**Vibe check pending:** [issue #9](https://github.com/shovelhead24/possession/issues/9) mocks the two money shots at 1,500/2,000/3,000 km and width variants. Number may tune inside the band; the scale class is settled.

## Width & Geography — PROPOSED (D2b, after mocks)

Width stopped being a file-size tradeoff when the circumference shrank (even 50 km wide ≈ 1 GB compressed bake, recipe-versioned). Current proposal: **nominal 30–40 km, effective 8–40 km** —

- **Physical band uniform** (reads clean in the night sky), but wall-adjacent mountain ranges pinch the habitable floor per region: corridor drama here, open plain there.
- **Pinch points are the gating system:** passes, faction borders, tolls, ambush terrain, where medieval armies meet — regional progression gates with zero invisible walls.
- **Cross-ring axis:** coast against one wall, plains mid-ring, wall-shadow ranges opposite — biome variety per region, not just along the ring.
- **Lostness:** at 30+ km, forest/night/fog can hide both walls; navigation can fail, which is what makes it gameplay. At 10 km you always see both walls and always know where you are.
- **Walls as destinations:** 20+ km away, the rim wall is an expedition — wall-foot cultures, the climb, hookshot territory, possibly the rim-transit line.
- **A sea worth a boat:** vision.md commits to drive/fly/boat; a 40 km region can host a 20 km-wide sea with a far shore and islands. In a 10 km band every sea is a strait.
- **Co-op spatially asymmetric:** same arc position, different worlds — one player coastal, one inland.

Content-dilution counterweight: wide regions are wilderness-sparse *by design*; authored density lives at pinches and moment sites.

## Traversal & Transport — PROPOSED

Walking 360° = **~2.3 days nonstop** at the current 10 m/s (a month of real sessions) — expedition-scale, not commute-scale. The transport ladder is the progression ladder's shadow; each tier redefines "far":

| Tier | Mode | Full 360° | Meaning of distance |
|---|---|---|---|
| 1 | Walk (10 m/s) | 2.3 days | the valley you're in |
| 2 | Horse (~15 m/s) | 1.5 days | the region |
| 2–3 | Vehicle/boat (~25 m/s) | ~22 h | neighboring regions |
| 3 | Flyer (~250 m/s) | ~2.2 h | the ring as map |
| 3 | Ancient rim transit (~2 km/s) | **~17 min** | the ring as a place you *own* |

Transport is always tied to navigation: each tier also changes what you can *know* (walking = landmarks, riding = roads, flying = the curve itself as your map).

## Still Open

- **Width number** — after the #9 mocks (D2b).
- **Day/night length** — tuning value, deliberately unrecorded until an implementation pass.
- **Water system** — where seas/rivers sit; interacts with width proposal. Deferred since April.
- **Authored vs procedural composition** — how story-placed sites (crash, settlements, relay, city) anchor into the baked world; part of D3.
- **Settlement/moment placement on the ring** — where the 12 moments live on 2,000 km of arc.
- **The "climb" in the narrative arc** — literal vertical traversal? Ties to walls and hookshot.
- **Structures in progression tiers** — visible at tier 1, enterable at tier 3?

## Hard Lessons (not decisions — things that bit us)

- Skybox geometry clipping at the view-distance boundary produces artifacts indistinguishable from z-fighting (was manifold/clip errors, April 2026). Re-check whenever view distance, sky geometry, or origin-shift boundaries change.

---
*Hydrated from the 2026-07-18 planning session. Next hydration: width decision after issue #9 mocks.*
