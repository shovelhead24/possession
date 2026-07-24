# Cost Ledger v0 — Function Classes & Cost Regimes

**Status: PROPOSED, first pass.** Answers a gap none of the architecture docs cover yet: as terrain.md/simulation.md/layerbuf-v0.md accumulate systems, how do we quickly check the running total, and spot which new system duplicates a cost pattern an existing one already pays for? This doc labels every named node from those docs by **function class** (what kind of computation it is) and **cost regime** (when/how often it's paid), instead of just the field-registry's "ingredients in, ingredients out" view. Same content the other docs describe — this is a second index over it, for spotting shared-cost opportunities the dependency-only view can't show.

Not a decision, not tuning values (per CLAUDE.md's rule against locking numbers early) — a working tool. Update it whenever a new system gets named in terrain.md/simulation.md/layerbuf-v0.md; prune/merge classes if the taxonomy stops earning its keep.

## Three Currencies, Not One

"Processing cost" means three different budgets depending on regime — conflating them is the actual risk this ledger exists to prevent:

| Regime | Paid | Budget it competes for | Who already owns this budget |
|---|---|---|---|
| **Bake-once** | Per recipe-version, at bake time, amortized to ~zero after (content-addressed caching per `.decisions/terrain.md`) | Dev/CI iteration time — does a rebake fit in a coffee break? | nobody yet — no bake-time budget exists |
| **Runtime-continuous** | Every tick, everywhere, **regardless of player distance** | Background CPU headroom — the "world stays honest while unwatched" budget | nobody yet — this is the gap the FC2 comparison surfaced |
| **Runtime-local** | Every frame, only within the realized ~2-5km bubble | Intel UHD frame budget | issue #8 (performance budget) — already the assigned owner |

Runtime-continuous is the one to watch hardest: it's the only regime whose cost scales with total world population/entity count rather than draw distance, and it's exactly the mechanism that has to hold up "battles resolve unwatched" (factions.md) without becoming either frozen-behind-you (Far Cry 2's checkpoint-respawn failure mode) or an unbounded simulation bill.

## Function Classes

A small fixed vocabulary, not one class per system — the point is that unrelated-looking nodes sharing a class are candidates for a shared implementation:

- **Composite** — pointwise arithmetic over already-computed fields. Cheap, embarrassingly parallel.
- **Classifier** — stacked fields → discrete/continuous label via thresholds or a small decision matrix.
- **Diffusion/advection** — iterative spatial spread. The expensive bake-time class; the one class with a plausible *live* cousin (fire-spread).
- **Graph/pathfind** — cost-surface route-finding over a built graph.
- **Stochastic scatter** — seeded procedural placement/sampling; cheap and specifically designed to stay cheap (deterministic reseed instead of simulation).
- **Agent tick** — per-entity state update (pressures/intentions/actions). The only class native to runtime-continuous.
- **Clock/tempo mix** — scalar signal combination, tiny compute cost but high fan-out (read by nearly everything) — a coordination risk, not a compute risk.
- **Realize/instance** — seeded-softmax sample → actual geometry/NPCs. Bursty, distance-gated.
- **Rasterize/I-O composite** — vector-to-raster, real-data (DEM/imagery) compositing. Bake-only, I/O-bound not compute-bound.
- **Render pass** — GPU, per-frame. Already issue #8's territory.

## Ledger — First Pass

| Node | Source | Function class | Regime | Rough cost order | Notes |
|---|---|---|---|---|---|
| L0 macro terrain + `splice_dem` | layerbuf-v0.md | Rasterize/I-O composite | Bake-once | O(tiles) | I/O-bound (DEM fetch), not compute |
| L1 erosion (`height`, `flow_acc`) | layerbuf-v0.md | Diffusion/advection | Bake-once | O(cells × iterations) | most expensive bake-time node so far |
| L2 `moisture` advection, `wind_exposure` | layerbuf-v0.md | Diffusion/advection | Bake-once | O(cells × iterations) | **same class as L1** — candidate for one shared solver instead of two bespoke ones |
| L3 `biome_id`, `biome_blend` | layerbuf-v0.md | Classifier | Bake-once | O(cells) | |
| `info_opacity`, `signal_amplification` | layerbuf-v0.md (L3) | Composite | Bake-once | O(cells) | |
| L4 density fields (tree/grass/rock/deer/wolf/...) | layerbuf-v0.md | Stochastic scatter | Bake-once (fields) / runtime (instancing reads them) | O(cells) bake; O(visible) instance | field itself is bake-once; the *scatter* that reads it at runtime is Realize/instance, see below |
| L5 `settlement_sites`, `ruin_sites` | layerbuf-v0.md | Stochastic scatter | Bake-once | O(candidates) | |
| L5 `road_graph` | layerbuf-v0.md | Graph/pathfind | Bake-once *if* `recovery_band` never changes at runtime (open question, civilization.md) — else runtime-continuous | O(nodes log nodes) | flip risk: if roads change live, this jumps regime entirely |
| L5 `tech_level`, `recovery_band` | layerbuf-v0.md / civilization.md | Classifier | Bake-once (same open-question flip risk as `road_graph`) | O(cells) | |
| L6 narrative anchors | layerbuf-v0.md | Composite (constraint stamp) | Bake-once | O(sites) | tiny, sparse |
| L7 hand edits | layerbuf-v0.md | Composite | Bake-once | O(edits) | |
| R0 persistent facts | simulation.md | Composite (append-only log) | Runtime-continuous | O(events) | trivial — this is a log, not a solve |
| R1 pressures | simulation.md | Agent tick | Runtime-continuous | O(pressure sources) | decay+propagate every tick, **everywhere** |
| R2 intentions (factions + player) | simulation.md | Agent tick | Runtime-continuous | O(intention-holding entities) | the one that scales with total faction population |
| R3 actions | simulation.md | Agent tick | Runtime-continuous | O(acting entities) | |
| R4 encounters | simulation.md | Realize/instance | Runtime-local | O(entities in bubble) | issue #8's territory |
| R5 arc director | simulation.md | Clock/tempo mix (schedules facts) | Runtime-continuous | O(1) — sparse, scheduled | cheap by design, per simulation.md |
| TempoBuf (4 clocks + mixing rule) | simulation.md | Clock/tempo mix | Runtime-continuous | O(writers) per clock, O(readers) fan-out | compute is trivial; **fan-out is the actual risk** — nearly everything reads it |
| Realization softmax sample | simulation.md | Realize/instance | Runtime-local | O(candidates at site) | seeded, deterministic — reroll-proof by construction |
| Fire spread | civilization.md | Diffusion/advection | **undetermined** — bake-only scar vs. live spread is still open engineering per civilization.md | O(cells × iterations) if live | the one node whose regime isn't decided yet; decide this before estimating its cost at all |
| Terrain/haze/curvature shaders | rendering.md | Render pass | Runtime-local | GPU, per-frame | issue #8 owns this |

## Optimization Opportunities This Surfaces

1. **L1 erosion and L2 moisture/wind advection are the same function class** (Diffusion/advection) solving structurally similar problems (iterative spatial spread with a boundary condition) — worth one shared naive solver instead of two bespoke ones. Matches "naive engines" — the shared naive solver is still naive, just written once.
2. **L3 biome classification and L5 tech/recovery classification are the same function class** (Classifier over stacked upstream fields) — a generic threshold-matrix classifier, parameterized per layer, could replace two hand-rolled ones.
3. **TempoBuf's mixing rule turns out to already be the cost-control mechanism for the Agent-tick class**, not just the pacing mechanism — regional clocks ticking slower in cold/unpressured regions (simulation.md) is literally variable-rate simulation, which is exactly how a runtime-continuous budget gets kept bounded. Worth naming this connection explicitly rather than leaving it implicit: tempo and cost-budgeting are the same lever, so tuning one tunes the other.
4. **`road_graph`/`tech_level`/`recovery_band` share a regime flip-risk**: civilization.md's open question ("does recovery_band ever change at runtime?") isn't just a design question, it's a cost-regime question — answering it either keeps three nodes bake-once-cheap or moves all three into runtime-continuous territory together. Worth resolving before, not after, someone starts implementing.

## Open Questions

- Fire spread's regime (bake-only scar vs. live diffusion) needs an answer before it can even get a cost estimate.
- No bake-time budget currently exists (unlike issue #8's frame budget for runtime-local, and this doc's flag for runtime-continuous) — is "fits in a coffee break" good enough, or does solo+AI development (many small rebakes) need a harder number?
- Should this ledger live alongside layerbuf-v0.md/substrate.md as a third terrain sub-doc, or stay top-level since it now spans simulation.md and rendering.md too? Filed top-level for now because of that span.
