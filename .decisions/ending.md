# Ending (leave branch)

Covers only the "ring the bell, leave" ending (vision.md "The Choice"). The stay/destroy-relay ending is untouched by these entries.

### ending-mechanism — Proximity-easy mechanism; content is procedurally assembled, not fixed
**Date:** 2026-07-22
**Status:** active
**Decision:** The leave-ending mechanism requires no puzzle or skill check once the player is in close proximity — all difficulty is in the journey to reach it. What plays over the act is a vignette montage assembled at that moment from R0 persistent facts and the ringing player's knowledge pyramid (`assemble_ending`, see docs/simulation.md and docs/operators.md), not a fixed cutscene. A consistency gate forbids any vignette contradicting a current fact.
**Why:** Matches "witnessing over heroism" applied to the game's final verb — no boss fight at the finish line. Reuses the dialogue bake's precondition-tagged pool pattern rather than inventing new machinery, and makes the ending honestly reflect what the specific playthrough did.

### ending-presentation — Fixed authored sequence; delayed title card; long black screen close
**Date:** 2026-07-22
**Status:** active
**Decision:** Once triggered, the ending is a fixed, authored, song-scored sequence — off the runtime tempo director's authority entirely, symmetric with the landing sequence's fixed opening (the game is authored at both ends, alive in the middle). The game's title card appears for the first time during this sequence, timed to a musically-marked moment ("the bell section" of the reference track) — same withholding logic as "names come last." The game closes on an extended held black screen before any credits UI.
**Why:** Reference track (Garbage, "Cherry Lips (Go with the Flow)") set the emotional register: bittersweet, ambiguous, not triumphant. A real licensed track is a production/rights question for later, not a design blocker now — treat as reference/temp-track per standard practice. Delaying the title mirrors character names being withheld; the held black screen extends "scale without fanfare" to the closing frame.
