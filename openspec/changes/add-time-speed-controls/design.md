## Context

Ports the simulation-speed part of stubby-music's `add-desert-opening` (research note
`docs/research/day-night-and-simulation-speed.md`). In Bevy, `[`, `]` and `\` set
`Time<Virtual>`'s relative speed to 0.25, 0.5, 1, 2, 4, 8, 16 or 64. Movement and
resource deadlines ran on virtual time (movement substepped at 1/120 s so it stayed
stable at 64×), while sample-driven audio kept its pitch and tempo. The HUD showed
phase and speed.

Here `Calendar` (autoload) owns simulation time: `elapsed` grows by frame `delta`,
Sky3D reads `solar_hour()`, `ResourceNode` reads `elapsed` and `nights_started()`.
Scrub oak growth (`GrowthLevels.step`) uses frame `delta`. Audio is timed by
stubby-rack's sample counter, which nothing here touches.

## Goals / Non-Goals

**Goals:**
- Reach day, night, regrowth and growth quickly while play-testing.
- Never change audio timing, pitch or the master clock.
- Keep the player's movement and the building controls at normal speed.

**Non-Goals:**
- Pausing simulation time (0×). No pause exists yet; it comes with a pause menu.
- Faster clouds: Sky3D drifts them with its own wind in frame time.
- Multiplayer: speed is local here. Later, `Calendar` is server-authoritative, and
  so is its speed.

## Decisions

**D1. Scale the calendar, not the engine.** `Calendar.speed` multiplies the delta
`Calendar` adds to `elapsed`. Things that follow simulation time read `Calendar`
(`elapsed`, `nights_started()`, `solar_hour()`, or `Calendar.delta(frame_delta)` for
rates).
- Rejected: `Engine.time_scale`. It also scales physics, so at 64× the player would
  walk 64 times faster and physics steps would grow 64 times longer. It would also
  speed up tweens, timers, sway and the rack screen's halos. That is Bevy's
  behaviour minus its 1/120 s substepping, and walking at 64× is useless in a large
  open world.
- Rejected: Sky3D's own game time and time scale. `Calendar` owns time (CLAUDE.md),
  and Sky3D's clock would leave replenishment and growth behind.
- Differs from Bevy: Bevy moved the player on virtual time. Here the player stays on
  real time.

**D2. What follows the calendar, and what never does.**
Follows: sun, moon, stars (already), day and night (`night_started`), replenishment
(already reads `elapsed` and nights), plant growth (`GrowthLevels.step` with calendar
delta), and later weather's smooth parameters (`add-weather-and-dust-storm`).
Never: the master clock and every tempo clock, engine audio, bug clicks and flashes
(they fire at the heard instant), stream notes, player movement and look, sway and
other frame-time animation, and UI.

**D3. Speeds and keys.** The steps are stubby-music's: 0.25, 0.5, 1, 2, 4, 8, 16, 64
(no 32, as there). `]` moves one step up, `[` one step down, both stopping at the
ends; `\` returns to 1×. They're Godot input actions (`time_faster`, `time_slower`,
`time_reset`). They act during play and are ignored while a screen has the controls,
like H.

**D4. Large steps stay correct.** At 64× a 60 Hz frame adds about 1.07 s of calendar
time, and a long frame adds more. The calendar delta is capped at 0.1 s × speed per
frame (Bevy's cap: `dt.min(0.1 × relative_speed)`), so a hitch can't skip a night:
night lasts 900 s, more than the 6.4 s cap. `night_started` is still emitted once
per crossing. Growth steps toward a target level and already clamps.

**D5. Readout.** A top-left label: `DAY`/`NIGHT`, solar time as `HH:MM`, and the
speed (`¼×`, `½×`, `1×` … `64×`), always shown, as in Bevy. It's text in the HUD's
existing font, outside the reticle and the goals area (upper right).

## Risks / Trade-offs

- [Faster growth at 64× hides how slow it really is] → the readout always shows the
  speed.
- [A future system reads frame delta for something that should follow the calendar]
  → CLAUDE.md lists what follows the calendar; reviews check new timers against D2.
- [Players use 64× to skip the night] → acceptable now (it was a player control in
  Bevy). If that hurts play, gate it behind a setting later.

## Migration Plan

Additive. At 1× nothing changes (`speed = 1`). Rollback is removing the actions and
the readout.

## Open Questions

- Should speed controls stay in the shipped game or become a debug or creative
  setting? Bevy shipped them. Keep them until play-testing decides.
