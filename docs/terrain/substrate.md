# Substrate v0 — Ring Coordinates, Tiling, Resolution Pyramid

The frozen interface beneath L0 (see `.decisions/terrain.md#bake-architecture`: generous interfaces, naive engines — this is the most generous, most frozen one). Status: **v1 dimensions settled 2026-07-25** — the earlier power-of-two-circumference proposal below was superseded once real dimensions were decided from hands-on mock testing rather than tiling elegance.

## Dimensions — RESOLVED 2026-07-25

Ring is decided at **C = 2,000 km, W = 50 km** (`.decisions/world.md#ring-circumference-2000km`, `#ring-width-50km`) — plain numbers chosen from real testing, not the earlier power-of-two proposal (2,097.152 km / 32.768 km). This looked like a real loss at first (`.decisions/world.md` flagged it as an open tension); it mostly isn't:

**The wrap-seam constraint only binds the circumference axis** — width never wraps (two hard edges/walls, not a seam), so it never actually needed power-of-two-ness. An edge tile is an ordinary case; a seam-spanning tile is the thing that had to be prevented.

**Circumference (2,000,000 m) still has a usable power-of-two leaf size: 128 m** (2,000,000 = 2⁷ × 5⁶, so 128 m divides it exactly, 15,625 tiles around, zero remainder). Not as large as the old proposal's top-level tile, but still power-of-two — which is what preserves Morton-code/quadtree bit-packing efficiency (a plain divisor like 100 m would avoid the remainder too, but lose that property).

**Leaf tile size: 128 m, both axes**, using the same grid for width even though width doesn't strictly require it (390 full 128 m tiles + one 80 m partial tile at the wall edge — an ordinary boundary case, not a seam). Higher LOD levels batch multiple 128 m leaves together at render/stream time; those batches don't need to divide the ring evenly since batching is a runtime streaming choice, not a storage-addressing one.

This is a substrate/addressing decision (frozen interface), not a rendering tuning value — the actual mesh/LOD chunk sizes used for rendering remain free tuning per the usual rule, built by grouping N leaf tiles however performance testing wants.

## Logical Coordinates

- `lon` ∈ [0, C) meters along circumference, **all arithmetic mod C**; positive = spinward
- `lat` ∈ [−W/2, +W/2] meters across width; 0 = centerline
- `alt` meters above the builders' reference shell ("up" = toward the spin axis)
- **Storage is flat** — the world is the unwrapped cylinder; curvature enters geometry in exactly one place (the frame transform, below), never in stored data

## Wrap Seam

- Seam at lon = 0 by convention, but **unobservable by law**: no system may store or compare raw lon differences — only via helpers `lon_delta(a,b) → (−C/2, C/2]`, `lon_lerp`, `lon_dist`
- Tiles never span the seam (guaranteed by the 128 m leaf size dividing the circumference exactly)

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
