# Possession — Characters & Asset Pipeline

Infrastructure built at the end of the April sprint so characters stop being one-offs.

## What Exists

- **Character pipeline** (`game/pipeline/`, `game/addons/char_pipeline/`): `PartDef` resource → `CharacterRecipe` → `CharacterAssembler` builds BoneAttachment3D per part on a skeleton; editor dock scans `res://pipeline/parts/` for .tres files
- **Cage mesh editor** (`game/addons/cage_editor/`): sculpt low-poly cages with live Catmull-Clark preview — vertex/face handles, X-symmetry, extrude/inset/scale, bake to PartDef (workflow details in root CLAUDE.md)
- Mixamo animation stack on the soldier skeleton (position tracks stripped to fix root-motion stutter)

## Open Questions

- **The two protagonists** — no player-visible body exists (FP arms only). Co-op/split-screen means each player sees the other's full character.
- **People of the settlements** — tier 2 is factions, settlements, a medieval army. That's crowds of humanoids; is the pipeline + cage editor actually fast enough in practice to produce that variety? Needs a real dogfooding pass.
- **Animals** — wolves (Moment 3) and deer (Moment 4) need quadruped skeletons and animation; nothing in the pipeline handles non-biped rigs yet. The Earth-zoo/dinosaur idea (lore.md) stresses this same gap harder, not a new one.
- **The armada / ships** — Moments 1 and 9 need a dying ship interior/exterior and fleet silhouettes. Different pipeline entirely (hard-surface, not characters).
- **Perf per character** — potato budget per skinned mesh, and how many the Medieval Army moment can afford (ties to docs/combat.md sim question).

## Constraints

- Large 3D asset packs are local-only, not in git (.gitignore) — anything pipeline-generated should stay small and committable.
