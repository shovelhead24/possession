# The Return (leave ending)

Companion to vision.md's "The Choice" — the "ring the bell, leave" branch, staged. Not one of the numbered 12 (those are witnessed beats on the way up); this is the terminal player-chosen act. 2026-07-22 session; decisions in `.decisions/ending.md`.

## What You See

A portal, generated at a fixed hub location — a spire or structure reaching from the ring floor toward the spin axis. You reach it; proximity is the whole journey, nothing about the site itself is a puzzle. You fly through. The screen doesn't cut. A song plays (reference: Garbage, "Cherry Lips") scored over a montage assembled from what actually happened in *your* playthrough — not a fixed cutscene. At the song's bell section, the game's title appears for the first time. It ends on a long held black screen. (Post-credits: [The Human Armada](human_armada.md) — tentative, may move earlier.)

## What You Feel

Ambiguous, not triumphant. Bittersweet. You don't know if you did the right thing, and the game doesn't tell you. The black screen is space to sit with that before anything else happens.

## Mechanic

- **Mechanism:** a portal at a fixed hub site (spire/structure toward the spin axis) — trivial to operate once in close proximity, no skill check. All difficulty was reaching it. (A real bell doesn't test your dexterity; you just pull the rope.) Substrate note: the axis is a coordinate singularity (all `lat` values degenerate to one point at `alt = R`) — see `docs/terrain/substrate.md`.
- **Vignette assembly:** runtime selects from a precondition-tagged pool against R0 persistent facts (and per-player knowledge — see knowledge.md) at the moment of ringing. Same pattern as dialogue's arc-phase branch selection (dialogue.md) — reused, not reinvented. A consistency gate must hold: no vignette may contradict a current fact (the runtime sibling of the bake gates, one more rung on the same verification ladder).
- **Staging:** once triggered, this is a fixed authored sequence, off the tempo director's leash — symmetric with the landing sequence's fixed opening.
- **Title card:** first appearance of the game's title, timed to the song's bell section. Same withholding logic as "names come last."
- **Close:** extended black screen before any credits UI — no immediate cut to a menu.

## What It Must Do

- Let the mechanism be reached, not solved.
- Assemble content that's honestly different across different playthroughs — the montage must be able to look genuinely different, or it's not really reading world state.
- Give the ending room to land; tune the held black screen in playtests rather than using discomfort or a fixed duration as the success criterion.

## What It Must Not Do

- Gate the mechanism behind a puzzle, timer, or combat encounter.
- Explain the vignettes or caption them with judgment (good/bad ending framing).
- Cut straight to a credits crawl or main menu from the black screen.
- Reuse this staging for the stay/destroy-relay ending — that branch needs its own staging and costs under `.decisions/ending.md#ending-choice-without-verdict`.

## Co-op: shared agency; unilateral trigger remains a candidate

Revised 2026-09-10; `.decisions/ending.md#ending-shared-agency` supersedes the old settled unilateral rule. Either player initiating a shared departure remains a proposal to test. Both must be able to recognise the approach to a consequential departure and have time to negotiate at the couch. Activation must be deliberate, not an accidental proximity trigger. The mechanism still needs no puzzle, skill test or boss once reached.

Do not use indifference as sufficient justification for taking away a partner's ending. Physical blocking is not the sole safeguard. Whether consent, another physical interaction or the legible approach alone provides adequate agency remains open. No vote menu is prescribed. Test what each player understood and whether both experienced meaningful participation.

The vignette montage continues to interleave both players' knowledge around shared facts. Asymmetric knowledge should enrich the shared conclusion, not privilege the activating player.

## Open Questions

- **Telegraphing and agency:** what physical cues make departure legible to both players, and what deliberate activation lets them negotiate? Test the unilateral candidate before fixing the interaction.
- Whether the reference track's shape (structure, tempo, the bell section's timing) gets formalized into an original score brief now, or waits until content exists to score.
