# Possession — Operator Glossary

The pseudo-code operators coined across design sessions, gathered so they don't drift. One line each; the linked doc owns the semantics. These are the API sketch the eventual code pass implements.

| Operator | Signature (informal) | Semantics | Owner doc |
|---|---|---|---|
| field expressions | `deer_habitat = meadow × water_proximity` | LayerBuf fields composed by arithmetic over rasters | terrain/layerbuf-v0.md |
| syncopation | `anomaly(type, pos, radius, params)` | perturbs *inputs* to later bake layers; never scripts outcomes | terrain/layerbuf-v0.md |
| `classify_recovery(tech_level, connectivity, resources)` | continuous field → discrete band | same pattern as L3 biome classification, reused for tech-recovery bands | civilization.md |
| `bake(layer, inputs, seed, params)` | pure fn → fields + content hash | cache hit iff input hash unchanged | terrain.md |
| `gate(artifact) → violations[]` | bake-time validator | fails with coordinates + debug map; non-negotiables as computable tests | terrain.md |
| `realize(fact, seed)` | `softmax_T(site_scores)` sample, seed = `hash(world_seed, entity_id, fact_version, time_bucket)` | coarse fact → concrete entities; observation never rerolls, only events do | simulation.md |
| `summarize(realization)` | collapse-up | conservation law: `summarize(realize(f)) ≈ f ⊕ events` — counts survive fidelity transitions | simulation.md |
| temperature | `T = f(InfoOpacity)` | readable zones realize predictably (cold); info-poor zones diffuse (hot) | simulation.md |
| clock mixing | `rate = clamp(Π registered_modifiers)` | few writers, many readers; writer set grows additively | simulation.md |
| intention join | `intent = commit(read_space, read_time)` | the intention boundary — bufs never talk buf-to-buf; entities join them | simulation.md |
| null write | *(deliberate absence)* | a system's refusal to write tempo/intensity is a designed, testable act (the deer) | simulation.md |
| `schedule(fact, +cycles)` | arc director | defaults not outcomes; causality stays simulated → hail marys exist unadvertised | simulation.md |
| intensity | scalar from player-side observables, post hoc | conductor budgets intensity, never valence; valence labels = telemetry only | simulation.md |
| `observe(vantage, time, weather)` | LoS over heightfield + haze; night boosts lights | K-gains flood visible tiles; ridges are honest towers | knowledge.md |
| `hear(rumor)` | K2 claim insert, accuracy ~ SignalAmplification decay | claims carry provenance, may be wrong | knowledge.md |
| `traverse(tile)` | K4 + freshness stamp | staleness = computed `fact_version` gap, never stored | knowledge.md |
| `assemble_ending(facts, knowledge)` | precondition-tagged pool → montage | one-shot at the leave ending; reuses dialogue's branch-selection pattern; consistency-gated against current facts | simulation.md, moments/the_return.md |
| `select_possession_host(candidates, proximity, eligibility)` | proximity-weighted softmax over eligible R2 entities | drop-in co-op join target; same family as `realize()` — no new machinery | co-op.md, .decisions/coop.md |
| `reactivate(system_id)` | player-triggered, no scripted outcome | wall transit / air defense / containment — one verb, several consequences | lore.md |

Registry rule: new operators get a row here when coined; renames are migrations, not edits.
