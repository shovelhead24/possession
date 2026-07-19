# Decision Index

One line per area file — decisions are the source of truth, this is just a map. Load this, then open only the file(s) you need. Don't grep the whole directory.

- design-laws.md — cross-system laws: six ratified principles; no missions; intensity not valence; observation never rerolls; world never reads knowledge
- dialogue.md — LLM dialogue is bake-time only, zero runtime LLM
- engine.md — Godot-level gotchas: reload via quit(), not reload_current_scene()
- knowledge.md — no omniscient map; the knowledge pyramid is the map, the night sky acquires it
- terrain.md — prebaked layered world: bake DAG + gates, recipe-versioned, generous interfaces / naive engines
- world.md — ring scale: 2,000 km circumference (honest sky geometry); day length stays a design value
