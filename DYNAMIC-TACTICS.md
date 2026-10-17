# Dynamic assault pairs and fleeing navigation — 2026-10-14

Restart Rebuild Demo. F4 toggles AI labels; F8 records roles, partner IDs,
route seeds, map counts and pending builds alongside the existing path data.

## Behavior
- Navigation maps cover separated survivors independently. A member more than
  32 m away requests coverage instead of restarting its squad's existing map.
  Completed maps remain usable during new builds; maps without a living squad
  member within 80 m retire. Cell sampling rotates across maps with the existing
  maximum 12 cells / approximately 1 ms per physics tick shared budget.
- Stable per-alien procedural spatial noise adds at most 18% to a cell's travel
  cost. This biases near-shortest routes and can choose different sides of a
  rock. It never changes blocked cells, destinations or slope checks, and does
  not change randomly every replan. This is procedural noise, not audio hearing.
- Sight/contact or incoming damage triggers assault pairing in combat. Greedy
  nearest available grunt pairs form within 18 m. Existing pairs remain stable
  until interrupted; the captain retains its existing behavior.
- PAIR ADVANCE moves toward the known threat in bounds of up to 8 m, selecting
  nearby cover where available and stopping advancement at roughly 12 m range.
  PAIR COVER stays in place and can use its existing line-of-sight firing.
  Arrival or a 6-second timeout exchanges roles. This is coordination, not a
  guarantee of suppressive fire when the target cannot be seen.
- Death/being held by Rex, more than 24 m pair separation, captain loss, or
  leaving the applicable combat/search state dissolves pairs. Fleeing overrides
  pairs. Patrol-only actors do not initiate combat pairs.
- Existing hunt-team alternation, captain rush/dodge and authored patrols remain.

## Validation
- check_dynamic_tactics.gd: separated map completion; retention of old usable
  maps; fair building; repeatable routes with both sides of a symmetric obstacle
  selected by different seeds; obstacle preservation; contact-triggered closest
  pairing; arrival and timeout handoffs; casualty cleanup; captain-loss flee.
- check_patrol_replan.gd: prior oscillation regression, destination arrival,
  blocked-start recovery, obstacle detour, cliff rejection, local-grid bounds.
- check_rebuild_rex_impacts.gd: existing collision punts, Rex and tactical alien
  suite passed.
- check_ai_crates.gd: actual actor role/partner telemetry, rendered labels, AI
  recording and crate physics passed. Focused fixture freezes actor movement
  while inspecting labels; its screenshot is not a movement performance test.
- Briefing rendered and visually inspected. Tests use standalone fixtures and
  do not edit player saves. No full-world FPS measurement was made this change.
