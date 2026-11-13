## Context

Research: `docs/research/godot-weather.md`.
- Sky3D gives wind and cloud coverage only.
- Godot's built-ins (GPUParticles3D with a heightfield collider, FogVolume and
  volumetric fog, global shader uniforms, decals) carry the rendering.
- The one full weather add-on, TCA_Weather_System, fights Sky3D and uses the global
  `randf()`.
- stubby-music's `add-desert-opening` §3.1–3.3 specifies the silent windstorm. Our
  opening differs: a clear night with the moon in view.

The user decided on 2026-11-13 that lightning and most weather events, rain patter
included, align with the clock. That extends `add-rack-audio-engine`'s
master-clock rule ("music-driven gameplay follows clock events") to weather.

## Goals / Non-Goals

**Goals:**
- the clock-event model for weather, with a request hook;
- the dust storm;
- one wind feeding the clouds, reeds, particles and engine.

**Non-Goals:**
- rain visuals and wetness (after terrain);
- lightning visuals and thunder sound (after stubby-rack schedules);
- weather recipes (a later change using the hook);
- overcast animation.

## Decisions

**D1. Events are pure functions of (seed, master-clock sample range, state).**
`Weather.events_between(from_sample, to_sample)` returns the sorted
`{kind, sample, data}` list:
- for each event kind with grid multiple M, its tick period is
  `48000 × 60 / (master_bpm × M)` samples;
- each tick gets a seeded draw: `WorldSeed.rng("weather:<kind>:<tick>")`, so ticks
  are independent and replayable;
- the draw decides whether an event lands, given the continuous state at that tick.

This is the same shape the engine scheduler needs (`add-rack-audio-engine` 4.2):
events arrive with exact sample times. Visuals read the same list and show each
event at its predicted audible instant.

Rejected:
- timers or `_process` countdowns (they drift and depend on frame rate);
- a random clock per drop (patter would no longer align).

**D2. Thunder: pick the distance, not the delay.** For a strike at tick k, draw a
whole number of ticks n ≥ 1 from the storm's distance distribution. The distance
is n × tick_seconds × 343 m, and its bearing is seeded. Thunder lands at tick k + n.
Physics holds (d = c·t), and both ends are on the grid.

Rejected:
- quantizing the thunder after a physical distance, which breaks d = c·t;
- leaving thunder off the grid.

**D3. Grids are whole multiples of the master.** These are defaults, tuned by ear
later:
- patter ×480 (8 ticks/s);
- gust onsets ×15 (one every 4 s);
- strikes ×60;
- storm troughs on ×15 ticks, chosen by the 20–40 s rule.

All of them line up with every other clock in the world once a minute.

Locking patter to the nearest sounding burbler's grid is an option. Not now: a
burbler multiple like ×58 doesn't divide ×480.

**D4. Continuous state** (wind vector, storm intensity, rain rate, fog density) is
keyframed on grid ticks:
- a seeded baseline;
- plus active requests (the recipe hook), each ramping from a tick;
- interpolated smoothly between keyframes.

It's read every frame by visuals, and sent to the engine as smoothed parameters.

**D5. Stand-in time.** `Weather.now_sample()` comes from the stand-in, wall time ×
48 kHz, until `RackServer` exists. It is marked `STAND-IN` and listed in CLAUDE.md,
like the rack lamp. It produces no sound.

**D6. Storm rendering.**
- **Fog:** a `FogVolume` around the camera using REKIEX's sandstorm fog shader (MIT,
  keep its header). Its time scroll is replaced by the global `wind` uniform, and
  density is bound to storm intensity.
- **Sand:** camera-local GPUParticles3D, with rate from intensity and velocity from
  wind.
- **The opening:** starts polluted (user, 2026-11-13). The fog shader multiplies
  density by (1 − q), where q is sampled from the air-quality 3D texture
  (`add-air-quality-field`), so clean cells are clear pockets. Until that change
  lands, q = 0.

Rejected: TCA_Weather_System (its own sky, global `randf()`), and the 2D and C#
add-ons.

**D7. Wind consumers.**
- A `wind` global shader uniform (`vec4`: xz direction × speed, gust in w).
- Sky3D `wind_speed` and `wind_direction`, converted to its "wind from,
  0 = north" convention with north at −Z; check the sign on screen.
- Reed sway: amplitude and rate scale with speed, the clumps lean downwind, and a
  gust's phase is delayed by distance along the wind, so gusts travel across the
  bed.
- The engine: parameters.

**D8. Data lives locally.** Grid multiples, storm-curve shape and presets live in
`scenes/weather/weather_presets.tres`. Not `assets/`, because the rsync from
stubby-music overwrites it.

## Risks / Trade-offs

- [Patter on a strict grid sounds mechanical] → the seeded per-tick density and
  drop sizes vary it, plus the continuous texture. Swing and humanize are engine
  concerns on top of exact event times, if ever wanted.
- [Opening in polluted air hides the moonlit view] → the calm troughs (every
  20–40 s, on the grid) are the reveal; tune the trough depth so the moon and the
  burbler read as silhouettes.
- [Volumetric fog cost on integrated GPUs] → measure in the spike, and fall back to
  depth fog.

## Open Questions

- ~~The opening~~: decided 2026-11-13, it starts in polluted air that clears locally
  as plants regrow (10 m cells, `add-air-quality-field`).
- Should patter follow the master grid (default) or the nearest sounding burbler?
- **Weather recipes** (user note, 2026-11-13): a rain song or dance and similar
  recipes that control weather, through the D4 request hook. These need a
  proposal: what the player builds, what it costs, and how strongly and how long
  it holds.
