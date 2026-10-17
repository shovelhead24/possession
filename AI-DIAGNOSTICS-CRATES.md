# AI labels, recording and heavy crates — 2026-10-14

## Troubleshooting routes

Labels are enabled by default. **F4** toggles them; **Tab** hides the whole HUD. They use 16-pixel screen text rather than shrinking with distance. Labels show up to 220 m away, with connecting lines to identify actors when labels overlap. They are diagnostic overlays and can appear through scenery.

Each label identifies the authored actor and squad slot, its current mode, waypoint, health and measured speed. Modes include Patrol, Guard, Combat, Hold, Hunt, Flee, Bite, Attack Recovery, Parked and Player. Movement status distinguishes navigation-grid construction, no current path, waypoint waits, completed routes, suspension, pauses and suspected stalls. A suspected stall means requested movement with less than 0.15 m/s progress for two seconds; it is evidence to investigate, not proof of a specific pathfinding bug.

**Press F8 before reproducing the problem, then F8 again to save.** The recorder includes the preceding five seconds. The console prints `DRIVE_TRACE_SAVED` and the full JSONL path. Default folder:

`%APPDATA%/Godot/app_userdata/Tree Demo/terrain-drive-traces/`

Files retain the `jitter-…jsonl` name because this extends the existing motion recorder. AI labels can be hidden while recording continues.

New log events:

- `ai_preroll`: up to twenty preceding AI snapshots and recent transitions.
- `ai_snapshot`: four samples per second containing actor identity, position, mode, movement status, actual speed, target, waypoint/wait information and stall duration.
- `ai_transition`: timestamped mode/movement changes.
- Alien samples also contain destination, remaining path count, up to eight next path points, repath timer, grid build/open-cell counts, whether the destination is outside the current local grid, last-known threat and latest collision body.
- Rex samples retain bite, animation, held-target and blocker details. Warthog samples include throttle, steering, braking and unloaded-terrain waits.

AI sampling is cached at 4 Hz. Detailed snapshots are written at that rate, rather than repeated in every rendered-frame record. Pre-roll is bounded. Logging uses the existing background writer.

## Heavy crates

Open **F1 → Actors + patrol routes → Heavy crate** and click terrain. Repeat to place a second crate, or use Copy. These are 1.8 m metal-banded boxes weighing 160 kg, with real rigid-body collision. A Warthog can push them; both **G combat frags** and **B terrain grenades** can move/tip them. Blast force falls with distance and is blocked by walls. Ordinary walking does not deliberately apply a pushing impulse.

Crates sleep when settled, pause with the editor, and suspend when terrain collision is unavailable. Settled movement refreshes nearby AI navigation through the existing bounded grid rebuild. Up to eight authored crates activate nearby; the actor budgets remain unchanged.

Crates use the actor save, undo/redo, move, copy and delete controls. They have no patrol route. **Ctrl+S** saves their authored spawn layout; **F7** returns them to their authored spawns along with the encounters. Gameplay displacement is retained across distance unloading during a run, but saving does not replace authored spawn positions with simulated positions.

## Verification

Focused rendered checks passed for fixed screen-size labels, mode/path diagnostics, stall-versus-idle classification, bounded pre-roll and log events; crate spawning, blast shielding, grenade displacement, editor pause/resume and an 800 kg Warthog-chassis impact. Full-scene checks also passed for placing two crates, saving/reloading them, F4 toggling and reading back an actual F8 capture with AI pre-roll/snapshots and zero dropped batches, using isolated copies of all four saves and an isolated recording folder. No new 60/120 FPS guarantee is implied.
