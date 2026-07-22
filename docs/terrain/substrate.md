# Substrate v0 — Ring Coordinates, Tiling, Resolution Pyramid

The frozen interface beneath L0 (see `.decisions/terrain.md#bake-architecture`: generous interfaces, naive engines — this is the most generous, most frozen one). Status: **PROPOSED v0** — freeze to v1 after the #9 mocks confirm circumference.

## Dimensions (power-of-two proposal — needs ratification)

Tiles must divide the circumference evenly (no tile spans the wrap seam), and 2,000,000 m = 2⁷ × 5⁶ breaks power-of-two tiling above 128 m. Proposal:

- **C = 2²¹ m = 2,097.152 km** (radius ≈ 333.8 km) — within the decided 1,500–3,000 band, ~5% over the logged 2,000 km; `.decisions/world.md` explicitly allows in-band tuning
- **W = 2¹⁵ m = 32.768 km nominal** (matches the 30–40 km width proposal; still awaiting D2b)

Every power-of-two tile size then divides both axes exactly; pyramid, Morton codes, and seam math are all trivial.

## Logical Coordinates

- `lon` ∈ [0, C) meters along circumference, **all arithmetic mod C**; positive = spinward
- `lat` ∈ [−W/2, +W/2] meters across width; 0 = centerline
- `alt` meters above the builders' reference shell ("up" = toward the spin axis)
- **Storage is flat** — the world is the unwrapped cylinder; curvature enters geometry in exactly one place (the frame transform, below), never in stored data

## Wrap Seam

- Seam at lon = 0 by convention, but **unobservable by law**: no system may store or compare raw lon differences — only via helpers `lon_delta(a,b) → (−C/2, C/2]`, `lon_lerp`, `lon_dist`
- Tiles never span the seam (guaranteed by power-of-two dimensioning)

## Tile Addressing

- `tile(ℓ, i, j)`: level-ℓ tile covers lon ∈ [i·2^ℓ, (i+1)·2^ℓ), lat likewise; ℓ in meters-as-power (tile edge = 2^ℓ m)
- Per-tile rasters at power-of-two sample counts (e.g. 256²) → sample spacing 2^(ℓ−8) m; **mixed resolution = per-region choice of finest ℓ** — regional high-res insertable without re-addressing (the day-one requirement)
- Seeds: `seed(layer, ℓ, i, j) = hash(world_seed, layer_id, ℓ, i, j)` — hierarchical, independent parallel tile bakes, same scheme `realize()` uses at runtime

## Runtime Frame (floating origin — R1 verdict)

- One active local frame per anchor A: `engine_pos = curve_transform(logical − A)`; re-anchor beyond threshold distance
- `curve_transform` is the **only** place curvature becomes geometry (honest near-field bend, per world decisions)
- Sky geometry camera-locked (April manifold lesson); re-anchor boundaries are the modern home of that bug class — test explicitly
- Co-op: shared frame + tether vs per-viewport frames — **unresolved, owned by D5**

## Axis Structures (added 2026-07-22 — backpropagated from the ending design)

The leave-ending portal (vision.md "The Choice", moments/the_return.md) sits at a fixed hub site reaching toward the spin axis — a location type the substrate didn't have a name for until the narrative needed one. It fits without new coordinate machinery: `alt` was already defined as extending toward the spin axis, so the hub is just a very tall `alt` value (approaching `R`, the full radius) at one specific `(lon, lat)`.

**But `alt → R` is a genuine coordinate singularity:** at the spin axis itself, every `lat` value converges to the same physical point (the pole problem, exactly as in lat/long sphere coordinates). Consequence: `lat` becomes meaningless in the immediate volume around the hub structure, and any system that assumes `lat` varies independently of physical position will misbehave there. Treat as a named exception zone, not something to discover as a bug later.

**Substrate gate 5 (added):** near-axis behavior — verify no system (movement, LOD selection, tile addressing) divides by `(R − alt)` or otherwise assumes non-degenerate `lat` within some small radius of the axis; the hub structure's own geometry should be authored directly, not derived from ring-surface tiling logic.

## Substrate Gates (the falsifiable part)

1. **Seam invariance:** rebake with seam convention shifted → bit-identical world
2. **Round-trip:** logical → engine → logical within ε everywhere, including across the seam and re-anchor boundaries
3. **Edge continuity:** adjacent tiles' shared-edge samples bit-equal at every level
4. **Unique addressing:** every (lon, lat) maps to exactly one tile per level
5. **Near-axis safety:** no division or tiling assumption breaks as `alt → R` (see "Axis Structures" above)

This module (wrap helpers + frame transform) is the sole candidate ever flagged for formal proof (see terrain.md verification ladder); exhaustive seam/property tests are the v0 requirement.
