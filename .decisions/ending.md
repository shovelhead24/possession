# Ending (leave branch)

Covers only the "ring the bell, leave" ending (vision.md "The Choice"). The stay/destroy-relay ending is untouched by these entries.

### ending-mechanism — Proximity-easy mechanism; content is procedurally assembled, not fixed
**Date:** 2026-07-22
**Status:** active
**Decision:** The leave-ending mechanism requires no puzzle or skill check once the player is in close proximity — all difficulty is in the journey to reach it. What plays over the act is a vignette montage assembled at that moment from R0 persistent facts and the ringing player's knowledge pyramid (`assemble_ending`, see docs/simulation.md and docs/operators.md), not a fixed cutscene. A consistency gate forbids any vignette contradicting a current fact.
**Why:** Matches "witnessing over heroism" applied to the game's final verb — no boss fight at the finish line. Reuses the dialogue bake's precondition-tagged pool pattern rather than inventing new machinery, and makes the ending honestly reflect what the specific playthrough did.

### ending-coop-unilateral — Either player rings the bell alone; ends the session for both
**Date:** 2026-07-22
**Status:** active (adopted direction — wants a real co-op playtest before treated as unchangeable)
**Decision:** No split ending, no consent gate. Either player reaching proximity and ringing the mechanism ends the game for both players immediately. Physical blocking (if player collision exists) is the only in-fiction way to contest it. The assembled vignette montage (`ending-mechanism`) interleaves both players' knowledge-pyramid threads around the shared R0 fact set — neither player's ending is privileged.
**Why:** Rejects a negotiated/split ending as inconsistent with every other refusal to accommodate the player (no missions, no valence, arc director never waits) — a consent gate on the ending would be that same softening aimed at the co-op layer. Unilateral makes the co-op partner a second, human arc director; the negotiation happens at the couch, not in a menu. Risk: could read as robbed-of-content rather than dramatic depending on execution — mitigated by proximity already requiring the whole journey, but genuinely untested.

### ending-presentation — Fixed authored sequence; delayed title card; long black screen close
**Date:** 2026-07-22
**Status:** active
**Decision:** Once triggered, the ending is a fixed, authored, song-scored sequence — off the runtime tempo director's authority entirely, symmetric with the landing sequence's fixed opening (the game is authored at both ends, alive in the middle). The game's title card appears for the first time during this sequence, timed to a musically-marked moment ("the bell section" of the reference track) — same withholding logic as "names come last." The game closes on an extended held black screen before any credits UI.
**Why:** Reference track (Garbage, "Cherry Lips (Go with the Flow)") set the emotional register: bittersweet, ambiguous, not triumphant. A real licensed track is a production/rights question for later, not a design blocker now — treat as reference/temp-track per standard practice. Delaying the title mirrors character names being withheld; the held black screen extends "scale without fanfare" to the closing frame.
