# M3 — Blind Readability Probe: Run 1 (2026-07-29)

## Result

| Metric | Value |
|---|---|
| Overall accuracy | **10/24 = 42%** |
| Uniform-guess baseline | 20% |
| **Base-rate baseline** | **57%** ← the bar |
| Ford-town (temp 0.40, "cold") | 3/9 = 33% |
| Highland hold (temp 0.75) | 2/7 = 29% |
| Delta camp (temp 1.60, "hot") | 5/8 = 63% |
| High confidence | 10/21 = 48% |
| Low confidence | 0/0 — no data |

Player report: *"the events in the cycles and their relationship to the outcomes remains a mystery
to me for the most part. What I did figure out was that the same answers were grouped together."*

**Headline: inference lost to base rate by 15 points.** The reader found autocorrelation (momentum)
rather than meaning. Taken at face value this is evidence against inference-not-transmission
(`docs/consumers.md`) — the assumption the whole mid-game rests on.

## But the instrument is flawed, in ways that predict this result

Recorded before drawing conclusions, because a negative result from a broken probe is not evidence.
All of these are defects in the mock, not findings about the design:

1. **Statistically underpowered per faction.** 24 rounds split 3 ways ≈ 8 each. At n=8, 63% and 33%
   are indistinguishable from noise. The per-faction column — including the apparently *inverted*
   temperature dial — cannot support any conclusion.
2. **The period was unlearnable.** Dispositions cycle with period 8; the probe showed 6 cycles of
   history. You cannot infer an 8-phase pattern from a 6-phase window, so the single most learnable
   structure in the sim was hidden by construction.
3. **Faction randomised every round.** You never got a continuous run with one faction, so there was
   no chance to build and refine a model of *anyone*. Real players learn a faction over hours.
4. **Base rate was set far too high (57%).** One action dominates, which simultaneously makes
   base-rate guessing strong and signal-reading nearly pointless — the exceptions worth catching
   were too rare to be worth learning.
5. **No training phase.** This tested cold-read from a standing start, which is not the condition the
   design actually needs to hold under.
6. **Confidence produced no variance** (21 high, 3 medium, 0 low), so the actual success criterion —
   does confidence track correctness? — went untested.

**Momentum being the only detectable pattern is itself explained by (2) and (3):** with a period
longer than the window and no continuity, consecutive-cycle repetition was the only signal that fit
inside what the player could see.

## Tentative conclusion

**Not proven either way.** What run 1 does establish, and it is worth having:

- **Ambiguous observation pools alone are not readable.** Shared lines + noise + staleness, with no
  learnable period and no continuity, produce a mystery rather than an inference puzzle. Whatever
  else is true, *lossy channels are not automatically inferable* — legibility has to be designed in,
  not assumed to emerge from flavour text.
- **The base-rate bar is the right one and it is harsh.** A faction with a dominant action is
  readable without reading anything. Design consequence: **factions need genuine behavioural
  variance or their signals are decoration.** A world where everyone mostly does one thing needs no
  inference layer at all.

## Run 2 design

Fixes targeted at the defects above:

- **One faction per session.** Learn it properly; run others as separate sessions.
- **History window > disposition period** (e.g. 12 shown, period 8) so the pattern is *available*.
- **Training phase, then scored phase.** ~15 unscored rounds with immediate reveal, then 25 scored.
  This matches the real condition: players are not cold-reading strangers, they are reading
  neighbours they have watched for hours.
- **Flatten the base rate** to ~30–35% so signal-reading is necessary rather than optional.
- **Sharpen a subset of observations.** Keep ambiguity, but ensure at least one line per intent is
  strongly diagnostic — a real world has tells, not only fog.
- **Force confidence variance** (or drop confidence and infer it from response latency).
