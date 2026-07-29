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
