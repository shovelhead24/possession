# Possession — Seven Souls: the multi-playthrough architecture

Area doc, **PROPOSED 2026-07-30**. Structural bet, recorded with its conflicts visible because it
collides with two ratified laws and should be adopted knowingly or not at all.

## The frame

Burroughs reads the Egyptian seven souls on *Seven Souls* (Material / Bill Laswell, 1989), text from
**The Western Lands** (1987) — a novel about the journey to the Egyptian afterlife. The souls
separate at death and leave in sequence, "second one off the sinking ship."

The fit is not decorative. Burroughs describes Ren as **"my Director… he directs the film of your
life from conception to death"**, and Khaibit as **"your whole past conditioning from this and other
lives."** Those are an arc director and cross-playthrough memory, named in 1987. The novel's
destination — the Western Lands — is also the game's ending: **leaving the ring**. Ka is the soul
that guides you there.

(Structural sibling worth noting despite the eye-roll: Hades is Greek underworld-escape-by-
repetition. Same shape, different pantheon. It solved narrative-across-runs and characters who
remember, and is worth studying for exactly that.)

## The mapping

| Soul | Burroughs | System |
|---|---|---|
| **Ren** — the Secret Name | "my Director… directs the film of your life" | **The arc director** (R5). Schedules facts, sets tempo, never commands entities. |
| **Sekem** — Energy, Power | "The Director gives the orders, Sekem presses the right buttons" | **timebuf** (TempoBuf). The clocks that execute the director's intent. |
| **Khu** — the Guardian Angel | the Historical Guide | **The bone-thrower.** Reads journal pins, tilts opportunity gradients. Never assigns. |
| **Ba** — the Heart, "often treacherous" | a hawk's body with your face on it | **The self-interested co-author.** Wants to make *its* version of your playthrough — and wants you to love it. See the conflict below. |
| **Ka** — the Double | "the only reliable guide through the Land of the Dead to the Western Lands" | **The model of you that becomes accurate enough, by the end, to speak truly about you.** This is the ending's vignette assembly (`ending.md`). |
| **Khaibit** — the Shadow | "your whole past conditioning from this and other lives" | **Cross-playthrough memory.** Literally stated. |
| **Sekhu** — the Remains | the corpse; the inert leftover | **Traces.** Bodies, ruins, objects with provenance — what you leave that outlasts the run. *(User proposed "the loss function"; recorded as an alternative, but the Remains are the passive leftover while a loss function is the most active part of a learner. Traces are already a consumer channel and are literally remains.)* |

## The recursion

- **First playthrough is short.** A more-or-less straight shot: finishable relatively quickly, high
  energy, fun. Its brevity is intended to catch players off guard.
- **Restart closes the biggest skips.** Routes that let you bypass the most are shut — though
  several large skips should remain, taking *different* paths to the end, for variety.
- **Difficulty escalates per consecutive completion.** Finishing many in a row is a flex.
- **Each run surfaces more subtle systems**, each conferring a diminishing edge alone — the depth is
  in *combining* them, not in any single unlock.

### The ending reflects; it does not report

**Corrected 2026-07-30.** An earlier draft proposed that a thin ending should tell the player what
they missed, as the replay hook. That is wrong: **the ending is a place to reflect on the run you
had, not to enumerate the runs you didn't.** `ending.md` assembles vignettes from actual R0 facts
and the player's own knowledge pyramid — pointing at absences turns that into a completion checklist
and makes the ending about content rather than about the player.

A fast run should still produce a *sparse* ending — fewer facts, fewer vignettes, honestly. But
sparse-because-that-is-what-happened is different from a list of doors you did not open. The ending
stays a mirror.

**So the replay incentive is not the ending.** It may not need to be anything: if the first run is
genuinely good and unexpectedly short, that is its own pull. Teasing or incentivising is available
if needed, but should be considered a failure mode to fall back on, not the plan.

### Escalation is LOCAL, and writes into the grids

Not a global difficulty dial. **The regions you got through are the ones that get harder** — the
cross-run model raises pressure *locally*, in the same spatial fields everything else already reads.

Why this is the right shape:
- **It is the syncopation law again** (`operators.md`: "perturbs *inputs* to later bake layers;
  never scripts outcomes"). Khaibit writes syncopations. Cross-run learning therefore cannot script
  anything — it can only weight what was already possible, which is exactly the guarantee needed to
  keep interception and honest causality intact. *(Third distinct design question this law has
  settled; it is earning its place.)*
- **It does not break the region's interaction with everything else.** A pressured region still
  trades, still raids, still sits in the chain — it is simply running hotter. Nothing is walled off.
- **Second-order consequences are the payoff, not a side effect.** Raise pressure in one link of the
  chain and it propagates: refugees, tolls, reroutes, a neighbour emboldened. The most interesting
  difficulty is the difficulty you did not directly cause.
- **It is diegetically legible.** That valley is harder *because of what happened there*, which the
  player was present for. Compare a global multiplier, which is unreadable and unearned.

### Weaknesses are earned, never the default verb

Tribes carry exploitable biases — a cosmology that can be leaned on, a grievance that can be
inflamed, a dependency that can be cut. These remain usable even at high local pressure, so a
skilled reader is never locked out.

**But they must not be the obvious first interaction, nor the only one.** Constraints:
- A tribe's exploitable bias is **earned knowledge** — inferred from watching (see the inference
  framing in `consumers.md`), not offered on approach. It is a deep read, not a menu option.
- **Shallow interactions must exist and must work.** Trade, pass through, ignore. A player who never
  reads deeply still has a game.
- Consistent with the earlier note that later systems confer a **diminishing edge individually** —
  the depth is in combining several reads, so no single discovered weakness becomes the answer to a
  tribe. Otherwise every playthrough collapses into speedrunning known exploits, and the surface
  layer is wasted content.

## The collision — read before adopting

Two ratified laws say no to this as literally described:

1. **`intensity-not-valence`** names this exact failure: *"a fairness-optimizing director makes the
   world secretly caring (the missions sin via the pacing door)."* A director that "sets a fair
   trial" **is** a fairness optimiser. And Ba "wanting you to love it" is valence optimisation
   stated outright.
2. **The indifference aesthetic.** `moments/landing.md`: "the ring is enormous and you are very
   small and it does not care that you're falling toward it." A game that learns you across
   playthroughs cares about you enormously.

## The resolution — make the learner diegetic

**It is not the game adapting. It is the AI.**

`.decisions/lore.md#the-displacement` establishes a rogue AI that relocated the colony, and
explicitly leaves its "current status and goals" open. Bind the recursion to it:

- **The ring stays indifferent.** Its air defence still fires on anything unrecognised, still does
  not care. The aesthetic is untouched.
- **The AI cares intensely — and it is a character, so it is allowed to.** It may be self-interested,
  may want to be loved, may cheat. That is Ba, and Ba is a *person*, not a pacing system. No law
  forbids an antagonist from optimising for your attention; they forbid the *architecture* from
  doing it silently.
- **Escalating difficulty is not balancing. It is something patching the holes you used**, because
  it watched you use them. Diegetic, motivated, and legible.
- **Khaibit is the AI's dossier on you**, accreted across lives.

This converts a law violation into the setting's central open question being answered *by the
structure of play*. The thread was already there waiting.

## Risks

- **Review risk is real.** Reviews are written on first playthroughs. A deliberately short first run
  can read as *thin* rather than *tight* to someone who never restarts. Mitigation: the first ending
  must feel **complete and chosen** — an ending, not a truncation. Sparse is fine; unfinished is not.
- **Punishing efficiency.** "Closing the routes you skipped with" can feel like being penalised for
  playing well. The diegetic frame is the fix — an adversary patching exploits reads as respect,
  where a system nerfing your route reads as spite.
- **Mastery treadmill vs narrative game.** Escalating heat is a roguelike idiom; this is not a
  roguelike. If the interesting material is gated behind run five, most players never see it.
- **It makes cross-run persistence load-bearing**, which is a real engineering commitment (R0 must
  survive and version across playthroughs, and the Datomic-style universal fact tuple now has to
  span *lives*, not just sessions).

## Open questions

- **Does the AI know it is doing this?** An adversary who is aware it is being watched playing
  against you is a different character from one that is simply a process.
- **Is the player told?** The strongest version probably never states it — you notice on run three
  that a door you used is bricked up, and nobody explains.
- **How does this interact with `observation-never-rerolls`?** Within a run, seeded determinism must
  hold. Across runs, the seed presumably changes — but the fact log persists. That boundary needs
  specifying before anything is built.
- **Does co-op share a Khaibit?** (`coop.md` — possess an existing NPC.) Two players with different
  dossiers in one world is either very rich or incoherent.
- **Sekhu:** traces, or the loss function? Recorded unresolved above.
