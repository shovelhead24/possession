# Possession — Design Brief

The single entry point for design and technical planning. Everything here is one of: **FIXED** (non-negotiable, see [vision.md](vision.md)), **PROPOSED** (usually from the April 2026 brainstorm, needs ratification), or **OPEN** (no candidate answer yet).

## How This Document Works

Decisions cascade downward:

1. **This brief** — the why and the what. Holds proposals and the decision backlog.
2. **`docs/<area>.md`** — the shape of each system: what exists, what's settled, open questions.
3. **`.decisions/<area>.md`** — settled technical choices, dated, supersedable.
4. **`docs/<area>/`** sub-docs — detailed sketches, code examples, prototype notes, as an area gets hydrated.

When a decision lands: record it in `.decisions/`, update the area doc, tick it off the backlog here. Tuning values (distances, LOD tables, thresholds) never get recorded during planning — only after an implementation pass settles them.

Sources: the May 2026 design session ([vision.md](vision.md), [moments/](moments/)) and the April 2026 architecture brainstorm ([research/chatgpt-brainstorm-2026-04.md](research/chatgpt-brainstorm-2026-04.md)).

---

## 1. Design Principles — RATIFIED 2026-07-19 (`.decisions/design-laws.md`)

From the April brainstorm, ratified as law after two days of load-bearing use — along with four session-coined laws (no missions; intensity not valence; observation never rerolls; world never reads knowledge):

1. **You do not simulate the world. You simulate the player's relationship to the world.**
2. "We do not simulate detail — we acknowledge it."
3. **The Fern Rule:** interaction fidelity ≤ visual fidelity × system importance. Nothing may invite more interaction than it can meaningfully express.
4. "A low-fidelity cell is a promise of possibility, not a place."
5. "Encounters are not content. They are consequences."
6. "The world never rewards the player directly. It reshapes opportunity gradients." (Already echoed in vision.md's theme.)

## 2. World Architecture — PROPOSED

- **World = function, not data:** `WorldState = f(global_seed, lat, lon, t)`. No baked worlds. Persist only player impact, rare anomalies, narrative anchors — as overlays on the function. (The April terrain editor's per-vertex edit overlays are already this pattern.)
- **Three-tier representation:**
  - **Tier 0 — mathematical:** climate bands, biomes, faction flows; functions + low-res grids.
  - **Tier 1 — statistical:** settlements, factions, ecosystems; ticked at hours/days.
  - **Tier 2 — realized:** geometry, NPCs, physics; exists only ~2–5km around each player. Collapses upward when unloaded.
- **Fidelity cells** carry summaries (terrain class, faction influence, pressures, anomaly probabilities) plus information topology (`InfoOpacity`, `SignalAmplification` — dense forest is information-poor, ridges are information-rich).
- **Floating origin + local frames** — absolute position is fake at ring scale.
- **Interiors are pocket realities** — narratively continuous, not spatially continuous. Occlusion funnel → context swap → spatial lie. "Depth is a feeling, not a measurement."

**⚠ Conflict to resolve (D4):** the brainstorm says *"curvature is mathematical, not geometric"*, but [moments/ring_curve.md](moments/ring_curve.md) and [moments/night_sky.md](moments/night_sky.md) demand the curve be **geometrically honest — explicitly not a skybox trick**, with far-side city lights that are *reachable*. The resolution is probably "honest in what it renders and where you can walk, mathematical in how it's stored" — but that's exactly what issue [#2](https://github.com/shovelhead24/possession/issues/2) has to pin down with a prototype.

## 3. Ring Dimensions — DECIDED 2026-07-18 (circumference), width OPEN with new latitude

**Circumference: 2,000 km** (radius ~318 km) — see [.decisions/world.md](../.decisions/world.md#ring-circumference-2000km). Superseded a same-day 20,000 km decision once it became clear the oversized-far-side cheat can't survive a player flying toward it: at 2,000 km, *all* sky geometry is honest — far side ~0.9°+ overhead, terrain 50 km ahead risen ~4 km — and interior/space flight stays consistent. Walking 360° ≈ 2.3 days nonstop, so transport still matters (walk → horse → vehicle/boat → flyer → rim transit). Day length remains a free tuning value (honest spin-days would be ~19 min; nothing in-game can witness the lie).

**Vibe check pending (issue #9):** skybox mock demos — far-off city on the upcurve + mountains 50 km ahead — at 1,500 / 2,000 / 3,000 km configs, plus night-sky band at candidate widths. Number may tune within the band; scale class is settled.

**Width is now a live design axis, not a file-size tradeoff.** The old 10 km was chosen to cap storage at megastructure scale; at 2,000 km circumference even 50 km width is ~100,000 km² (bake ~1 GB compressed at 8 m/px, less with multi-res). Candidates 10–50 km; opportunities and costs of width are a D2b decision after the mocks.

## 4. Systems Map

| Area | Doc | State | Next decision | Issue |
|---|---|---|---|---|
| Terrain/landscape | [terrain.md](terrain.md) | April prototype works | D2 dimensions, D3 data model | #1 |
| Rendering/curve | [rendering.md](rendering.md) | clouds/sky built; curve unsolved | D4 curvature approach | #2, #5, #8 |
| Co-op | [co-op.md](co-op.md) | nothing built | D5 what co-op means mechanically | #3 |
| Combat/AI | [combat.md](combat.md) | most-built system | squad layer shape (post-slice) | — |
| Characters | [characters.md](characters.md) | pipeline + cage editor built | quadruped support (wolves/deer) | — |
| Progression/RPG | [progression.md](progression.md) | nothing built | D7 how much of the RPG stack the slice needs | — |
| Simulation/runtime | [simulation.md](simulation.md) | architecture proposed | graduation to .decisions (see backlog) | — |
| Dialogue/NPCs | [dialogue.md](dialogue.md) | proposal only | LLM bake pipeline (local vs API), voice consistency | — |
| Knowledge/journal/map | [knowledge.md](knowledge.md) | proposal only | journal UI shape, staleness pacing | — |
| Moments | [moments/](moments/) | 12 director's notes | which moment the slice proves | #4 |

## 5. Progression & the RPG Stack — PROPOSED, scope warning

The brainstorm's full stack — Facts → Pressures → Intentions → Actions → Encounters, plus "throwing a bone" stagnation detection and competence-vector player modeling — is coherent and matches the theme. It is also **enormous**. The scope question (D7) isn't "is this good" but "how much does the first playable slice need" — plausibly *none of it*: deer/wolves are ambient AI, the first settlement can be static, and pressures can arrive with the medieval tier.

**2026-07-18 refinement (see simulation.md):** no mission layer, ever — architecturally (bake produces space, runtime produces time) and thematically (missions violate witnessing-over-heroism). Instead: the runtime mirror stack R0–R5 with the player as an ordinary intention-holding entity, a self-authored journal the bone-throwing system reads as signal, and an *arc director* that schedules the authored spine as world-logic inevitabilities, not tasks.

## 6. Interaction Fidelity — PROPOSED, cheap to ratify

Interaction tiers 0–4 (static signal → passive react → binary → stateful node → narrative anchor) with the frame-budget table from the brainstorm. This is a *constraint*, not a system — it costs nothing now and prevents scope leaks later (no harvestable ferns). Candidate for ratifying alongside D1.

## 7. Research Agenda

| # | Question | Informs |
|---|---|---|
| R1 | ✅ Done — [research/r1-godot-large-worlds.md](research/r1-godot-large-worlds.md). Verdict: floating origin mandatory; double-precision builds ruled out (custom compile + perf penalty + undocumented GL Compat support); precision no longer constrains ring size, but co-op needs a player tether or per-viewport origins | D2, D3, D5 |
| R2 | Ring curvature rendering precedents: vertex-bend shaders, how Halo faked its ring, planet renderers; what "geometrically honest" costs | D4 |
| R3 | Split-screen cost on Intel UHD in GL Compat — measured, not guessed | D5, D6 |
| R4 | Statistical world sim precedents: Dwarf Fortress army abstraction, Kenshi, Mount & Blade battles, RimWorld storyteller pacing | D7 |
| R5 | Streaming under a fast-falling camera (the landing) — async mesh generation limits in Godot | #4 |
| R6 | Pocket-reality interiors: occlusion-funnel implementations (Metro tunnels, GoW boat corridors) | later |
| R7 | LLM dialogue baking: batch pipeline cost/quality (local vs API) per 100k grounded lines, voice-consistency techniques, validation-gate patterns | dialogue.md |

## 8. Decision Backlog (ordered)

- [x] **D1** — Six principles + four session laws ratified (2026-07-19, `.decisions/design-laws.md`)
- [ ] **D1b** — Ratify interaction-fidelity tiers (§6) — still open, mechanical, low-risk
- [x] **D2 (part)** — Circumference: 2,000 km (2026-07-18, `.decisions/world.md`; superseded same-day 20,000 km). Sky geometry honest, day length free
- [ ] **D2b** — Ring width (10–50 km candidates) ← needs skybox vibe mocks (issue #9) + width-opportunity call
- [x] **D3 (architecture)** — Prebaked layer DAG + gates, recipe-versioned (2026-07-19, `.decisions/terrain.md`); substrate spec + streaming detail remain in issue #1
- [x] **Dialogue boundary** — baked-only, zero runtime LLM (2026-07-19, `.decisions/dialogue.md`); pipeline open pending R7
- [x] **Knowledge/map** — no omniscient map, sky-as-map (2026-07-19, `.decisions/knowledge.md`; ratified ahead of UI sketch)
- [ ] **D4** — Curvature rendering approach (issue #2) ← needs R2, D2
- [ ] **D5** — What couch co-op means mechanically (issue #3) ← needs R3
- [ ] **D6** — Performance budget + benchmark scene (issue #8) ← needs R3
- [ ] **D7** — RPG-stack scope for the first slice (§5) ← needs D8
- [ ] **D8** — Define the first playable slice (§9)

## 9. First Slice — PROPOSED

**Crash site → wilderness → the deer → the wolves at night → crest the ridge → the ring curve reveal.**

One unbroken stretch of walking that tests: terrain streaming, the curve render, day/night, ambient animal AI (both flavors — peaceful and predator), terrain-as-savior (wolves resolve through navigation, not combat), and the tone (no HUD noise, no fanfare). Requires **zero** combat systems, zero settlements, zero RPG stack — and it's three of the twelve moments, including the one that defines the game. If the slice doesn't produce awe on a Dell Latitude, the numbers change until it does.

---
*Living document. Sections get hydrated down into area docs as decisions land.*
