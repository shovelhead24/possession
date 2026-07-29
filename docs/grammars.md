# Possession — Generative Grammars

Area doc, PROPOSED 2026-07-29. **A scope instrument.** The project cannot hand-author at volume
(`.decisions/design-laws.md#no-authored-graphs`), so structure has to be *generated*. This doc
collects the small set of generative grammars the design borrows from, what each is good for, and —
critically — the test that decides whether a generated structure is kept.

The through-line is the GEB intuition already threaded through this project: **cheap structural
notes with outsized downstream consequence**, and *braiding* as the mark of quality.

## Instruments and scores

- **Instruments** = the things that act and are perceived: people, objects, locations, events.
  (The player's status as an instrument is deliberately unresolved — see Open Questions.)
- **The score** = what is likely at a given time and place: `spacebuf` says where is possible,
  `timebuf` says when is ripe, and a faction's baked time-varying disposition says what it is
  inclined toward (`simulation.md`, pre-biased-not-pre-decided).
- **The performance** = live. Entities read both bufs at the intention boundary and commit.

### Polyphony — how an instrument plays two tunes

**It doesn't, and that is the answer.** A voice is monophonic; counterpoint emerges from *many*
instruments, not from one playing two lines. An entity holds one intention at a time. An entity
belonging to several overlapping songs — a settlement's market cycle, its faction's war tempo, a
seasonal raid rhythm — does not play them all: its bias is their **superposition**, and it plays the
single line that results.

This is already specified. TempoBuf is *"writers register named modifiers per clock; a fixed clamped
combinator resolves them"* — many writers, one resolved clock. **The mixing rule is the counterpoint
engine**, and its exact combinator is `simulation.md`'s first open thread. Polyphony and that open
spec are the same problem; solving the combinator solves both.

Consequence: **counterpoint is a property of the ensemble, never of an entity.** Any design that
wants an entity to "do two things at once" is really asking for two entities, or for a richer
resolved bias — not for a second voice.

### Crossfade and decoherence — CORRECTION 2026-07-29

The above describes the *endpoints* and discards the interesting part. A DJ crossfades; an improviser
quotes another tune mid-phrase. An entity is not always cleanly on one line — and the transitional
state is where most of the readable character lives.

**Perturbation is the width of the commit.** An entity does not merely pick the argmax line; it
strays within a space around it. Where two songs are co-located in *both* space and time with
comparable weight, that space overlaps both — and what is emitted is a **crossfade**: a settlement
half on market rhythm and half on mobilisation, a faction drifting between trade and raid posture
without ever cleanly switching.

**This is softmax temperature, already ratified — no new mechanism.** Temperature is the decoherence
dial:
- **Cold** — sharp, near-deterministic commit. One tune, clearly played. Readable, predictable.
- **Hot** — flat distribution, high entropy. The entity strays; lines blur; the pattern *decoheres*
  and may re-cohere into a different tune. Ambiguous, hard to read, alive.

`simulation.md` already ties temperature to readability ("readable zones run cold, information-poor
zones run hot"). Extending it to intention makes legibility, characterisation and musical ambiguity
one dial rather than three systems.

**Guard — decoherence must not become observation-collapse.** It is tempting to say the player's
attention resolves the ambiguity. It must not: `.decisions/design-laws.md#observation-never-rerolls`
is ratified. Decoherence is a property of the **bias distribution over time**, and it resolves
through **events**, never through being watched. Watching means the commit is realized in detail;
not watching means it is computed coarsely and conserved — the same outcome, which is exactly what
`factions.md`'s battles-resolve-unwatched already asserts. "Sometimes resolving by themselves" is
therefore correct and already law; what the player's presence changes is *fidelity*, never outcome.

**What the player's intuition is actually for:** not collapsing the state, but **anticipating** it.
Reading a hot, decohering faction and guessing which way it will re-cohere is the skill — and being
wrong is `consumers.md`'s unintention, earned honestly.

## Grammar families

Music is the richest source but not the only one. Each family is a *generator plus a fit criterion*,
not a metaphor.

| Grammar | Domain | Generates | Fit criterion |
|---|---|---|---|
| **Counterpoint (Bach)** | time | overlapping cycles at different periods/phases; syncopation as phase offset | do the lines stay independently readable while combining? |
| **Tessellation / recursive loop (Escher)** | space | lattice and near-lattice placement, self-similar layouts, structures that close on themselves | does it read as *made* rather than grown? |
| **Self-reference (Gödel)** | both | structures that refer to themselves — a rumor about rumor, a ruin built from an older ruin | does it braid (below)? |

**Escher example (user, 2026-07-29):** a beehive-style loop grammar prebaking tree positions around
ancient structures — a lattice that decays into natural scatter with distance. Attractive because it
makes the boundary between *made* and *grown* legible at a glance, and it costs one generator rather
than hand-placement. **Caution:** real vegetation is not tessellated, so the lattice must be the
*exception* that reads as artificial — the signal only works while ordinary forest stays irregular.
A ring where every forest is subtly hexagonal loses the very contrast that made it worth doing.

## The braid test

The proposed criterion for keeping generated structure: **extrapolate the theme; keep it if it
braids, discard it if it doesn't.**

To be usable this has to mean something operational, or it is taste wearing a formal hat. Working
definition: *a generated structure braids if it creates a loop through at least two other systems and
returns changed.* The crater syncopation is the reference case — crater → lake → humidity → oasis →
deer habitat → pilgrimage road → a region with a myth. It leaves the terrain layer, passes through
hydrology, climate, wildlife and civilization, and comes back as *meaning*.

A structure that terminates — pretty, self-contained, consumed by nothing — is discarded regardless
of how good it looks in isolation.

**This is the same test as the consumer audit, arrived at from the other side.** The consumer audit
asks "does this reach a player?"; the braid test asks "does this reach other systems?". Both reject
work that terminates. Where they disagree is instructive and worth watching: a structure can braid
richly and still reach no consumer (invisible depth — the genre's characteristic failure,
`consumers.md`), or reach a consumer while braiding nothing (a set piece).

### Removing an instrument, and emergent songs — PROPOSED 2026-07-29

**Subtraction is agency.** If the player removes an instrument — kills a figure, burns a granary,
takes an object out of circulation — the song continues, but with **changed character**, and may
resolve differently. This is the cleanest form of player agency the architecture offers: it requires
no special-casing (the ensemble simply has one fewer writer), it cannot be pre-decided, and it is
legible in exactly the way the inference framing wants — you hear that something is missing before
you can name it. It also inverts the usual power fantasy: the player's most reliable lever is not
*adding* force but **taking a voice out**.

**Some songs only exist at high entropy.** Not every pattern is reachable from a cold, ordered state.
A chaotic clash of circumstances can weight the softmax toward a rhythm that combines instruments
from *both* colliding songs — a new tune that neither faction was disposed toward, arising only
because the region decohered first. The EDM-from-chaos case: a driving, unified rhythm emerging out
of a mess, not despite it.

Mechanically this is a **precondition on entropy**, and it needs nothing new: some song templates
require high local temperature and the co-presence of two specific songs before they can be
selected at all. Consequences worth noting:
- It makes decoherence *productive* rather than merely a legibility cost — chaos is a **generator**,
  not just noise. The hot end of the temperature dial earns its place.
- It gives the player a reason to *cause* chaos deliberately, which is a verb the design otherwise
  lacks — and a very on-theme one.
- It is the strongest argument yet that the braid test matters: an emergent song that combines two
  factions' instruments is, by construction, a braid.

## Practical mocks — PROPOSED 2026-07-29

None of these need terrain, art, or the ring. They are pure systems mocks — a few entities, a few
clocks, text or 2D output — which makes them an order of magnitude cheaper than the terrain work and
testable in isolation. Listed with **what each decides**, because a mock that decides nothing is a
demo.

### M1 — Combinator bake-off *(most blocking)*
Run one fixed scenario — an entity under three competing clock modifiers — through each candidate
combinator (clamped product, sum-then-clamp, max, softmin) and plot the resolved bias over time.
**Decides:** TempoBuf's one frozen interface, currently `simulation.md`'s oldest open thread and
— per the polyphony finding above — the counterpoint engine. Precedent for settling it by
measurement rather than argument: the LOD stress test overturned a reasoned recommendation
(`mocks/LOD-STRESS-FINDINGS.md`).
**Watch for:** combinators that look fine on one modifier and collapse to a single dominant writer
on three. That failure is invisible until you test the many-writer case.

### M2 — Crossfade / decoherence visualiser
Two or three songs co-located in space and time; a handful of entities carrying superposed bias;
a temperature slider. Plot each entity's distribution and its committed line.
**Decides:** whether temperature actually produces *readable crossfade* rather than mush — i.e.
whether the hot end of the dial is expressive or just noise. Also whether a decohered entity
re-coheres into something legible or wanders.
**Watch for:** the possibility that there is no useful middle — that entities are either boringly
sharp or uselessly random, with nothing in between. That would be a real finding.

### M3 — Blind readability probe *(highest stakes)*
Emit **only** diegetic signal — patrol counts, market open/closed, refugee direction, a rumor line
or two — as plain text, with no UI, no labels, no internal state shown. A human reads a few cycles
and predicts what the faction does next. Score the predictions.
**Decides:** whether **inference-not-transmission** works at all (`consumers.md`). This is the
assumption the entire mid-game rests on, and the one the prior-art table says four comparable
projects got wrong.
**Success criterion is deliberately not accuracy:** it is *"did the reader form a confident belief,
and was it wrong in an interesting way?"* A probe where predictions are always right has failed as
badly as one where they are random.

### M4 — Doomed-city tempo lever
One settlement, a scheduled collapse fact, three or four coupled pressures, and two or three player
levers. Play it repeatedly; measure the spread in time-to-collapse.
**Decides:** whether **fixed in outcome, negotiable in tempo** (`simulation.md`) is actually
playable, and — the harder half — whether the levers are *findable* from emitted signal without
being told. Both directions must work: prolonging and hastening.
**Watch for:** levers that move the number but that no player would ever locate. That is agency in
the simulation and not in the player's hands, which is the failure `consumers.md` exists to catch.

**Suggested order:** M1 (unblocks the interface everything else uses) → M3 (highest stakes; kill or
confirm the core bet early) → M2 → M4. M3 could arguably go first — it is the one that could
invalidate the framing, and it needs almost nothing built.

## Open questions

- **Is the player an instrument?** They emit into R0, hold intentions at R2, and consume at the top
  (`consumers.md` topology). If they are an instrument, the score biases them — which brushes hard
  against no-missions. Deferred deliberately; the honest answer is probably that the player is the
  only *unbiased* instrument, and that asymmetry is the game.
- **Combinator spec.** Unchanged from `simulation.md`, now with more riding on it: it is the
  counterpoint engine, not just a tempo detail.
- **How many grammars is too many?** Each is a generator to build and tune. Three families named
  here; the discipline is to add one only when an existing one demonstrably cannot cover the domain.
- **Does the braid test have false negatives?** Some good content is legitimately terminal — a joke,
  a view, a grave. Blanket discard may be too strong.
