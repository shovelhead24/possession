# Possession — Design Document

## Theme

**You arrived late to something enormous.**

The ring is indifferent to your presence. It was here before you. It will be here after you. You are a witness, not a protagonist. The world does not reward you directly — it reshapes opportunity gradients.

---

## Non-Negotiables

These can be changed, but only by mutual agreement.

- **The landing sequence is unbroken.** No cuts, no loading screens, no fade to black. The player watches the ring rush up from the pilot's seat the entire way down. Mouse look only. No thrust.
- **Fully explorable terrain.** If you can see it, you can reach it. No invisible walls, no locked zones.
- **Scale without fanfare.** The ring's size is shown, not announced. No music sting. No UI callout.
- **Witnessing over heroism.** The world's biggest moments happen whether you're ready or not. You don't outrun the disaster. You watch it.
- **Couch co-op first.** Two players, one screen. All design decisions are tested against this.
- **Potato hardware target.** GL Compatibility renderer. Intel UHD. If it doesn't run on a Dell Latitude, it doesn't ship.

---

## The Two Players

**Protagonist One** — crashed in the wilderness. Stripped on landing. Knows nothing.

**Protagonist Two** — was near the city. Witnessed it from a distance. Already moving. Knows what the lights going out meant.

RE2 structure: same world, asymmetric knowledge, shared grief. Names TBD — names come last.

---

## Layer Stack (high to low)

### Thematic
You arrived late to something enormous. The ring is indifferent. Witnessing over heroism.

### Narrative Arc
Crash → stripped → hunted → survivor → discover people → climb toward ancient tech → relay already on → armada arrives → choice.

### World
The ring. Fully explorable. Curves upward. Far side visible and reachable. Cities, villages, wilderness, ruins. The world was here before you.

### Co-op
Two players, asymmetric starting position and knowledge. Shared world, different grief.

### Progression
Metroidvania shape. Stripped on landing. Tech tree climbs: survival → medieval → ancient alien. Bow before carbine. Hookshot unlocks vertical traversal.

### Terrain as Strategy
Ridges, valleys, sight lines. Layered on top of everything, interferes with nothing, amplifies all of it. Terrain is the game.

### Squad
Light. Stay/follow. AI fills vehicle roles naturally. World feels inhabited without micromanagement.

### Combat
Halo golden triangle: grenades, movement, power weapon control. Vehicles: drive, fly, boat. Squadmates fill roles without being asked.

### Moment-to-Moment Feel
Couch co-op Halo essence. Two people on a couch, something enormous happening around them.

---

## Progression Tiers

1. **Survival** — hunting to live, no power, prey not predator
2. **Medieval** — people, factions, bows, horses, politics
3. **Ancient Alien** — tech that changes what the world is, stakes that change what the game is

---

## The Choice

The relay was already on when you found it. You didn't wake it. Something else did.

The armada arrives because someone tried to contact home using ancient tech on the ring. They are not looking for you. They want the ring.

- **The good ending:** destroy the relay. Stay.
- **The other ending:** ring the bell. Leave. The game lets you go back after the credits and ring it anyway.

Ringing the bell is not cowardly. But it tests your courage in a suddenly much more dramatic way.

---

## Tone References

- 2001: A Space Odyssey — something was already happening
- Terminator 2 nuclear dream — cold, distant, the world changes and you just watch
- Halo CE — couch co-op, the golden triangle, terrain as strategy
- Metroid — alone, stripped, climbing back
- RE2 — two people, same world, different experience

---

## Moments

Individual moment docs live in `.design/moments/`. Each is a short director's note: what you see, what you feel, what the game must and must not do.

- [The Landing](moments/landing.md)
- [The Ring Curve](moments/ring_curve.md)
- [The Wolves](moments/wolves.md)
- [The Deer](moments/deer.md)
- [The Settlement at Night](moments/settlement_night.md)
- [The City Destruction](moments/city_destruction.md)
- [The Night Sky](moments/night_sky.md)
- [The Relay](moments/relay.md)
- [The Armada](moments/armada.md)
- [The Pilot](moments/pilot.md)
- [The Medieval Army](moments/medieval_army.md)
- [The Hookshot](moments/hookshot.md)

---

*Living document. No review schedule — revisit when something feels wrong.*
