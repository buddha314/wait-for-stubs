## Context

The burbler's rack (`add-burbler-rack-screen`, archived in `openspec/specs/`) has three
places: a fixed clock (`burbler_clock`: GATE and PHASE out, BPM knob), a VCO place that
takes a `square_wave` as `square_vco` (V/OCT in, OUT), and a fixed volume (TRIG, IN,
OUT, gain). Items mount through `accepts` (item → module). `RackState.is_complete()`
needs every place mounted and every suggested cable (`configure.cables`) joined
exactly; `sounding`, the stream's flow and the goals follow it. `RackLink` mirrors the
state into stubby-rack (kinds from `engine.json`). The rack screen has knobs and jacks,
no buttons. The engine (stubby-rack) has clocks, VCOs, envelope, VCA, sampler, no
sequencer; it reports clock ticks as events (`clock_ticked`), and per-module lights
(`add-rack-audio-engine` 8.2) aren't built.

stubby-music had no sequencer. Its module list planned one; `add-module-library`
(proposed, here) lists sequencers among about 90 modules, with logic to port from
Peaks `mini_sequencer` (MIT) and ML_modules (BSD-3) (`docs/research/module-library.md`
§7). The user's reference (2026-11-13): a high-spired land-snail shell (a turreted
spire of whorls, glossy brown) and KORG's SQ-1 (per-step knob, gate button and light;
clock-synced; CV and gate outs).

**Rule (user, 2026-11-13): when in doubt, follow real Eurorack interactions.** The
reference instruments are Intellijel's Steppy (a clocked gate sequencer: clock in, one
lit button per step) and KORG's SQ-1 (a knob and a lit button per step, CV and gate
out). Wherever this design has a choice, it does what they do.

## Goals / Non-Goals

**Goals:**
- Collect a shell, mount it, patch it, hear a pattern: a playable first sequencer.
- Behaviour a hardware user recognises: step on each clock edge, gate per step, CV per
  step, active-step light, reset.
- Routing through the sequencer still counts as a configured burbler.

**Non-Goals:**
- More steps (8, 16: other shells later), direction modes, gate length, slide,
  quantised CV, saving patterns. All on the wall or in `add-module-library`.
- The campfire's flint (it will be a gate destination later).
- Live snails, shell breeding, or crafting shells.

## Decisions

**D1. One shell, four steps, its whorls.** The shell is a high-spired spiral of four
whorls, generated in Blender (`create_snail_shell.py`) by a helicospiral (Raup's coiling
model: whorl expansion, translation down the axis, aperture shape), glossy translucent
brown with sutures between whorls, about 3 cm tall, scaled up 3× in the world so it's
findable (as the bugs are). The module's panel echoes it: the four step controls sit
along a spiral motif, one per whorl.
- Rejected: an ammonite or scallop first. The user picked this shell; the others come
  with 8 and 16 steps.

**D2. Shells in the world.** A `snail_shell` resource (yields one `snail_shell` item;
replenishment `never`, so each shell is a find) on a seeded scatter of a few shells on
the mud at the edges of the reed beds, each with its own `instance_id`. E collects one
with an empty hand (not a sound: no `waveform` or `sample`). The item's description
says what it does in the rack.
- Rejected: shells that return next night. A sequencer is a tool, not a fuel; finding
  a few is enough, and later shells come from new places.

**D3. The engine module, written, not vendored.** `step_sequencer` in stubby-rack
(`core/modules/sequencers.h`): params `steps` (4), `cv_1…cv_N` (volts, 0–2 V, two
octaves on V/OCT), `gate_1…gate_N` (0/1); inputs `clock`, `reset`; outputs `gate`,
`cv`. A rising edge at `clock` (above 1 V after below) advances the step and wraps; a
rising edge at `reset` returns to step 1 so the next clock edge plays step 1. `gate`
outputs the clock input's level while the current step's gate is on (so gate length
follows the clock's pulse), else 0; `cv` holds the current step's voltage. Each advance
is reported as a tick event whose index is the step (0-based), so the game receives it
through the existing `RackServer.clock_ticked(module, sample, index)`: no new signal.
The step changes on the sample the edge is seen, one sample after the clock's (the
engine's one-sample cable delay, as in VCV Rack).
- Rejected: vendoring Peaks' `mini_sequencer` (MIT). Its logic is the same few lines,
  bound to Peaks' fixed-point CV and UI state; porting it costs more than writing it.
  It stays the reference for 8 and 16 steps.
- Rejected: ML_modules' sequencer (BSD-3). Written against VCV's API; same reason.
- Rejected: stepping from the master transport instead of a clock input. A sequencer
  that follows whatever is patched into CLOCK is what the player expects from hardware,
  and the clocks already sit on the master grid.

**D4. One light per step, as on the hardware.** Each step button has one light, as on
Steppy and the SQ-1: steady when the step is on, dark when it's off. The playhead is
shown by the same light as it passes: a lit step blinks dark and an unlit step blinks
on for the step's duration. It changes at the step's heard instant, from
the sequencer's `clock_ticked` (index = step) converted with `sample_to_ticks_usec`, as the bugs' flashes and the
clock lamp are. When per-module lights (`add-rack-audio-engine` 8.2) exist, the light
moves to them.
- Rejected: a separate row of active-step lights. Not how either reference works, and
  it doubles what the player has to read.

**D5. Step buttons are a control.** The panel's step buttons are `Button_<n>` nodes
with a param (`gate_<n>`, 0/1, default 0: a new sequencer starts with every step dark,
as Steppy does) and their light. In the rack screen, a click toggles the param, which
is how the player "lights" each step, and the value is stored in `RackState` like a
knob's (`"place/gate_1"`). Picking works like knobs and jacks (projected nodes,
no physics). New module assets list them under `buttons`.

**D6. An optional place in the burbler's rack.** The burbler's `configure.places` gains
a fourth place, `seq` (8 HP, `optional: true`, accepts `snail_shell` →
`snail_sequencer`). Optional places don't count toward "configured". The rack frame
widens if 8 HP more doesn't fit. No new comb cable: the player patches the sequencer
with their own cables (10 at the start). `create_burbler.py` writes the configure
block, so the change goes in the generator.

**D7. "Configured" is a signal path.** A suggested cable `from → to` is satisfied when
`to` is fed from `from` directly or through patched modules: `to`'s cable comes from a
module, and that module has an input that is (recursively) fed from `from`. So clock
GATE → sequencer CLOCK, sequencer GATE → volume TRIG satisfies "clock GATE → volume
TRIG". Every required place must still be mounted. `sounding`, the stream, the goals
and the rack lamp follow as before.
- Rejected: adding the sequencer's cables to `configure.cables`. The sequencer is
  optional; requiring it would break the first patch.
- Rejected: asking the engine whether anything sounds. "Configured" is a rack-state
  rule (the engine never reads `RackState`), and silence by a quiet knob is still
  configured.

**D8. Acoustic profile.** `assets/creatures/snail_shell/acoustics.json`: no emission;
the cavity's Helmholtz resonance f = (c / 2π) · √(A / (V · L′)) from the aperture area,
whorl volume and an end-corrected neck length, labelled "simplified simulation" and
"not excited by anything yet" (the "sea in a shell" needs wind, which comes later).

## Risks / Trade-offs

- [Path-based completion accepts odd patches] → it only asks that the suggested
  connections exist through modules; that is the point. Rule out loops: a module can't
  feed itself (the search stops at visited modules).
- [8 HP more widens the rack] → check the frame; widen in `create_hud_rack.py`.
- [Gate-length follows the clock pulse] → good enough for a basic version; gate length
  as a control is a non-goal.
- [The active-step light is a game-side stand-in until engine lights exist] → it's
  timed from the engine's own step events, so it's right; only its plumbing changes.

## Migration Plan

Additive, except the burbler's configure block (generator) and `is_complete`
(path-based, a superset of the old rule). Rollback restores both.

## Open Questions

- How many shells in the opening, and how far from the spawn?
- CV range: 0–2 V (two octaves) unquantised, or quantised to semitones from the start?
