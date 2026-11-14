# Wall of bad ideas

Ideas we may want later, kept so they aren't lost. Nothing here is decided or
specified: an idea leaves the wall when it gets an OpenSpec change (or is struck off).
Add freely; date each entry and say who had it.

---

## Natural step sequencers (user, 2026-11-13)

The aim: mimic a small hardware step sequencer (a KORG SQ-1 or volca-style row of
steps) with a natural object, and then let the player use it like the real thing. Four
steps first. The first use is lighting the campfire: a flint strike on beats 2 and 4,
like a hi-hat on the backbeat.

What a KORG-style step sequencer does, and what a natural one must keep:

| Hardware | What it does | Must keep |
| --- | --- | --- |
| Steps (4 here; SQ-1 has 2 × 8) | one slot per beat of the bar | yes |
| Step button | gate on or off for that step | yes |
| Step knob | that step's CV (pitch, or anything patched) | yes, later |
| Active-step LED | shows where the playhead is | yes |
| Clock in, sync | steps on an external clock | yes: the master grid |
| Direction modes | forward, reverse, ping-pong, random | later |
| Step count / length | 1–N steps before it wraps | later |
| Gate length | how long each gate stays open | later |
| CV and gate outs | patch into other modules | yes: it should be patchable |

Engine side, whatever the object: a step sequencer module that counts beats from the
master clock (step 1 is always the bar's first beat, no reset cable), with a gate per
step and a CV per step. Port the logic from ML_modules' 8-step sequencer (BSD-3) or
Peaks' `mini_sequencer` (MIT) (`docs/research/module-library.md` §7). The flint voice is
a CC0 flint-strike recording on the existing sampler first, then noise → high-pass →
short envelope when the module library has noise and filters.

### Ring of stones (draft, the favourite)

The campfire sits in a ring of four stones, one per beat of the bar.

- **Steps:** the four stones, clockwise from the one nearest the stream (step 1).
- **Playhead:** the spark the player caught (the square wave) runs round the ring, one
  stone per beat of the clock that feeds it (the burbler's beat, carried by the water).
  The stone it sits on glows: the active-step LED.
- **Gate (step button):** a flint shard set on a stone. When the spark reaches a stone
  with flint, it strikes: a short, hat-like scrape and a spray of sparks, at the beat's
  heard instant. Flint on stones 2 and 4 is the backbeat. The player sets or lifts
  flint by pressing E at a stone (or touching it in VR).
- **Step CV (step knob), later:** the stone's height or how far it's turned. Taller
  stones, higher CV. Patched to the burbler's VCO, the ring plays a four-note bass line.
- **Lighting the fire:** a full bar of strikes in time, sheltered from the wind,
  catches the reeds in the pit. Unsheltered, the sparks blow away.
- **Patching:** the ring has a gate out (the strikes) and a CV out (the stones'
  heights) on a small rack face, so the player can use it as a real sequencer: drive a
  VCO's pitch, trigger an envelope, clock something else.
- **Growing it:** more stones (8, then 16 in two rings); direction modes as the way the
  spark runs (clockwise, back and forth, jumping); gate length as how long a strike
  burns.
- **Why it works:** readable at a glance (stones, spark, flint), diegetic (no 2D panel;
  good for VR), and it ties the camp's steps together: the spark from the bugs, the
  beat from the burbler, the shelter from the tree.

### From natural repeating structures (user, 2026-11-13)

Repeating structures are already sequencers: identical cells in a row or lattice, each
one a step. The idea is to copy one closely enough that the player recognises the
structure, then let it behave like a hardware step sequencer.

**Honeycomb (wild comb).** Hexagonal wax cells.
- **Step:** a cell. Four in a row first.
- **Gate:** a cell filled with honey sounds; an empty cell is a rest.
- **Step CV:** how full the cell is (a little honey low, brimming high).
- **Mute / skip:** a cell capped with wax is skipped, like a step switched off.
- **Playhead:** a bee walking the comb, one cell per beat. It glows faintly, like the
  bugs, and the cell under it lights amber: the active-step LED.
- **Direction modes come free from the hex lattice:** a cell has six neighbours, so the
  bee can walk a straight row (forward, reverse), zig-zag between two rows (ping-pong),
  circle a seven-cell rosette (a centre and a six-step ring), or wander (random).
- **Growing it:** 4 cells → a 7-cell rosette (six-step ring plus an accent in the
  centre) → a full comb as a 2D grid. A large comb could also be a pitch lattice (a
  Tonnetz, where neighbouring cells are fifths and thirds) for chords.
- **Where it lives:** in the hollow of a scrub oak once it blooms. Blooms bring bees,
  bees build comb: the sequencer is earned by growing the tree. Later than the campfire.

**Mud-crack polygons.** The opening is a cracked desert mudflat, and drying mud splits
into polygons (often four to six sided) that repeat across the ground.
- **Step:** a polygon of the crust near the camp.
- **Gate:** a polygon the player wets or stamps.
- **Step CV:** its size or the depth of the crack around it.
- **Playhead:** the water, or the spark, running from cell to cell along the cracks.
- **Why:** the nearest structure to the player, under their feet from the first second,
  and it needs nothing to grow. It depends on the terrain work (the ground is still a
  flat plane).

**Mud dauber nest.** Solitary wasps build rows of mud tubes, cell after cell, on any
sheltered surface: a desert-native honeycomb, made of the mudflat itself.
- **Step:** a tube.
- **Gate:** a sealed tube sounds.
- **Step CV:** the tube's length, which also sets its pitch as a closed pipe
  (f = c / 4L), so it is tuned the same way as the reed pipes below.
- **Playhead:** the wasp.
- **Where it lives:** under the oak's shelter or on the burbler, once there's shade.

**Proposed:** the first one, a four-whorl high-spired snail shell as a four-step
sequencer, is now `openspec/changes/add-snail-shell-sequencer/`.

**Seashells, plugged into a rack (user, 2026-11-13).** Shells are segmented, and the
segments come in counts that suit a sequencer: 4, 8 or 16.
- **In this world:** fossil shells in the dried lakebed. The mudflat was once water,
  so shells turn up in the mud, found by eye or uncovered by wind and rain.
- **Kinds, by step count:** a small cockle with 4 ribs, a young ammonite with 8
  chambers, an adult ammonite or a scallop with 16. Which shell you find decides the
  length of the sequence.
- **Into the rack:** a shell is an item that mounts as a module, as a square wave
  mounts as the VCO today (inventory → the rack's Relevant strip → a place in the
  rack). Its panel is drawn from the shell: each rib or chamber is a step with a gate
  button and a light, plus clock in, reset, gate out and CV out jacks.
- **Step CV:** a small knob per segment, shown as the rib's height on the panel.
- **Playhead:** the light walks the segments. On an ammonite it spirals: inside out is
  forward, outside in is reverse, which gives the direction modes a shape.
- **Patching:** the burbler's clock (or the master grid) into clock in. Gate out to an
  envelope, a flint strike, or the campfire. CV out to a VCO's pitch for a 4-, 8- or
  16-note line.
- **Its own sound, later:** a shell's cavity resonates (the "sea in a shell" is a
  cavity filtering the air around it; Helmholtz formula from its opening and volume),
  so held up to the field recorder, or as a filter module, it colours what passes
  through.
- **Why it works:** it's a collected, physical thing that becomes a real module, which
  matches how the rack already works, and the step counts map straight onto hardware
  sequencers (4, 8, 16).

**Others to remember:**
- **Columnar basalt** (hexagonal columns, Giant's Causeway): column height as step CV,
  stepping-stone steps. Needs rock the mudflat doesn't have.
- **Sunflower and pinecone spirals:** the 8/13/21 seed spirals spread hits evenly round
  a circle, the same idea as Euclidean rhythms. The reticle is already a sunflower.
- **Saguaro ribs:** repeating pleats down a cactus; a strummed rib sequence.
- **Chambered nautilus:** chambers that grow along a spiral, steps of growing length
  and falling pitch.

### Other natural sequencers

- **Reed pipes (pan flute).** Four reeds cut to different lengths, stood in a row. The
  length sets the pitch by the quarter-wave formula (f = c / 4L, a closed pipe), so the
  player tunes a step by cutting a reed. Wind or a passing spark sounds them in turn.
  Fits the acoustic-ecology brief closely; the steps are pitches more than gates.
- **Flint wheel turned by the stream.** A small water wheel, one turn per bar, with
  notches that strike flint as they pass, like a music-box barrel. Ties the fire to the
  water; harder to read and to change than the ring.
- **Stepping stones across the stream.** Stones laid in the water click as the notes
  pass over them. The stream already shows beats and bar lines, so stones placed by
  beat in the bar would be steps, but every note passes every stone, so choosing beats
  is awkward.
- **Bug lanterns.** Four jars, each with a lightning bug, lit in turn: the bugs are the
  LEDs. The jars hold the bugs' own square waves as the step's voice.
- **Rack module.** A plain four-step module with step buttons in a camp rack, set in
  the rack screen. Most literal, quickest to build, least magical; maybe the "inside"
  view of whichever natural object wins.

---

## Elsewhere

- **Compass bar** across the top of the screen, as in Satisfactory: on the backlog in
  CLAUDE.md, not here.
