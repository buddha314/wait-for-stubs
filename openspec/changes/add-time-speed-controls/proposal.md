## Why

The game opens at solar midnight, and daylight arrives about 7.5 minutes later.
Reeds regrow after 60 s, bugs come back the next night, and a scrub oak takes
minutes to bud. So every play-test of the day, the night, regrowth or growth means
waiting in real time. stubby-music solved this with simulation-speed keys (¼× to 64×,
`docs/research/day-night-and-simulation-speed.md`), and the port never brought them over.

## What Changes

- **`]` speeds simulation time up, `[` slows it down, `\` resets it to 1×.** Steps:
  0.25, 0.5, 1, 2, 4, 8, 16, 64 (stubby-music's list). The game starts at 1×.
- **Only simulation time changes speed:** the calendar (sun, moon, stars, day and
  night), replenishment (reeds' regrowth, bugs' next night) and plant growth. The
  player walks, looks and builds at normal speed, and all audio keeps its pitch and
  tempo: the master clock, the burbler's beat, the bugs' clicks and flashes, and the
  notes on streams never speed up.
- **A time readout in the top left:** phase, solar time and speed (for example
  "NIGHT 03:12 · 64×").
- Scrub oak growth moves from frame time onto calendar time, so it speeds up with
  everything else that grows.

### Existing tools this relies on

- The `Calendar` autoload (stubby-music's `calendar.rs` port), which already drives
  Sky3D and replenishment.
- Godot `InputMap` actions and a HUD `Label`.
- stubby-music's speed list, keys and HUD from `add-desert-opening` and the research
  note above.

Written from scratch: a speed factor on `Calendar` and a readout. Nothing fits
better: `Engine.time_scale` would also speed up the player, physics and every
animation (see design.md).

## Capabilities

### New Capabilities
- `time-speed`: the speed steps and keys, what speeds up and what never does, and
  the readout.

### Modified Capabilities
<!-- none: sky-motion already follows "simulation time", and replenishment already
     reads the calendar -->

## Impact

- `autoload/calendar.gd`: `speed`, `delta()` for calendar-time consumers, and
  stepping between speeds.
- `project.godot`: actions `time_slower` (`[`), `time_faster` (`]`), `time_reset`
  (`\`).
- `scenes/hud/`: the time readout.
- `assets/flora/scrub_oak/scrub_oak.gd`: growth steps by calendar time (sway stays
  on frame time).
- No audio change. The master clock is outside the calendar by design.
