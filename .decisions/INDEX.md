# Decision Index

One line per area file — decisions are the source of truth, this is just a map. Load this, then open only the file(s) you need. Don't grep the whole directory.

- design-laws.md — cross-system laws: six ratified principles; no missions; intensity not valence; observation never rerolls; world never reads knowledge; decomplect (ask what's braided together unnecessarily); layer-backpropagation; diegetic tools not HUD; interaction-fidelity tiers 0-4 (Fern Rule)
- civilization.md — ordinary building interiors are real/continuous (window combat, fire spread); dungeons keep pocket-reality
- coop.md — drop-in co-op possesses an existing NPC (proximity-weighted), not a new spawn
- dialogue.md — LLM dialogue is bake-time only, zero runtime LLM
- factions.md — living instrumental faction woke the relay; human-survivor faction exists as its own class (with an anti-"default good guys" guard); chain topology stays linear with rare/expensive sea crossings; THE city and the enclave are distinct classes; player is known, never enrolled
- ending.md — leave-ending mechanism (proximity-easy, vignette-assembled) + presentation (fixed sequence, delayed title, black screen close)
- engine.md — Godot-level gotchas: reload via quit(), not reload_current_scene()
- knowledge.md — no omniscient map; the knowledge pyramid is the map, the night sky acquires it
- lore.md — the Displacement (rogue AI, ring-scale portal, explains degradation + the shootdown); two signals (pre-game beacon vs the survivors' relay — the armada answers THEM); reactivatable ancients; Earth zoo
- rendering.md — texture fidelity baseline: deliberately ~2001/Halo-CE; modern budget spent on scale/lighting, never texels
- terrain.md — prebaked layered world: bake DAG + gates, recipe-versioned; render-authoritative object placement; CDLOD morphing quadtree (clipmap rejected on measurement) + object-LOD trees; real-DEM splices tiling the ring in three resolution tiers, shader-clamped ocean
- world.md — ring scale: 3,000 km circumference × 50 km width (2,000 km superseded by the vibe-check mock); day length stays a design value; deep-cross-section surface-concentrated atmosphere
