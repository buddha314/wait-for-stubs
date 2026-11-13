## Why

The world has sky motion and a horizon but no weather. stubby-music's opening
specifies a silent windstorm (`add-desert-opening` §3.1–3.3), and none of it is
ported. Weather here is also part of the music. The user decided on 2026-11-13 that
lightning and most weather events, the patter of rain included, align with the
master clock. Weather becomes another rhythmic voice rather than random noise laid
over the patch. That rule has to be in place before rain, thunder or gusts are
built, or each would grow its own timer.

## What Changes

- **Weather events are clock events.** A seeded weather controller turns weather
  state into discrete events on the master clock's grid, at whole multiples of
  the 1 BPM master:
  - rain patter (individual audible drops near the listener);
  - lightning strikes and their thunder;
  - gust onsets;
  - the storm's calm troughs.

  The visuals for an event appear at its audible instant: a lightning flash, a
  splash ripple. Continuous state (wind, storm intensity, rain rate, fog) changes
  smoothly between clock-aligned keyframes, and is sent to the engine as slow
  parameters, never as timing.
- **Thunder lands on the grid by choosing where lightning strikes.** Thunder
  arrives distance / 343 m/s after the flash. Each strike's distance is drawn so
  that delay is a whole number of grid ticks, so flash and thunder are both on the
  clock and the physics stays true.
- **Dust storm** (port of stubby-music §3.1–3.3):
  - a seeded storm-intensity curve with guaranteed calm troughs every 20–40 s;
  - a storm `FogVolume` (starting from REKIEX's MIT sandstorm fog shader) whose
    density follows intensity;
  - camera-local blowing sand (GPUParticles3D);
  - silent until the engine voices it;
  - **the game opens in this polluted air** (user, 2026-11-13). Local storm density
    is intensity × (1 − air quality), so the air clears cell by cell as plants
    regrow (`add-air-quality-field`). The calm troughs are what first reveal the
    moon and the burbler.
- **One wind:**
  - a `Weather.wind` vector (direction, speed, gust) feeds a `wind` global shader
    uniform (particles, storm fog, later foliage);
  - Sky3D's `wind_speed` and `wind_direction` (clouds);
  - reed sway, which follows wind speed, leans downwind, and lets gusts travel
    across the bed (today it's a fixed 0.35 Hz);
  - the engine as data.
- **Stand-in clock until stubby-rack plays.** Events are pure functions of
  master-clock time (a sample count). Until `RackServer` exists, a named stand-in
  feeds them wall time, like the rack lamp, and is replaced by the engine's sample
  counter.

- **A request hook for weather recipes.** Game systems can ask the weather for a
  target (rain rate, storm level) with a ramp from a grid tick, layered on the
  seeded baseline. This is so later recipes can control weather.

Out of scope, each a later change under the same clock rule:
- **weather recipes** (user note, 2026-11-13): recipes and patches that control the
  weather, like a rain song or rain dance. A player builds and plays one to call
  rain, calm a storm or raise wind. They use this change's request hook, and
  belong with the rules data (`recipes.json`/`goals.json`) and the rack;
- rain visuals and wet ground (after terrain);
- lightning visuals and thunder sound (after stubby-rack can schedule);
- overcast animation.

## Capabilities

### New Capabilities
- `weather-clock`: weather events on the master clock grid (patter, strikes,
  thunder, gusts, troughs), event visuals at audible instants, continuous state as
  parameters, and the stand-in clock.
- `dust-storm`: the seeded storm curve, storm fog and blowing sand.
- `wind`: one wind source and its consumers (shader global, Sky3D clouds, reeds,
  engine data).

### Modified Capabilities
<!-- none in openspec/specs; extends add-rack-audio-engine's master-clock rule
     "music-driven gameplay follows clock events" to weather -->

## Impact

- **New:** a `Weather` autoload; `scenes/weather/` (storm fog, sand particles,
  presets with the weather scene, as they aren't one asset's data); a
  `wind` global shader uniform in `project.godot`.
- **Changed:**
  - `scenes/reed_clump/` sway follows wind;
  - `main.gd` feeds Sky3D's wind;
  - CLAUDE.md gets the clock rule for weather.
- **Reuse:** Godot GPUParticles3D, FogVolume and volumetric fog, global shader
  uniforms; Sky3D wind; REKIEX sandstorm fog shader (MIT, keep its notice);
  `WorldSeed`, `Calendar`.
- **Rejected:** TCA_Weather_System (its own sky fights Sky3D, and it uses the
  global `randf()`); the other add-ons in `docs/research/godot-weather.md`.
- **Depends on:**
  - `add-rack-audio-engine` 4.2 (quantized scheduling), 4.4 (sync point) and 5.1
    (`RackServer`) to replace the stand-in clock;
  - task 3.3 for any weather sound.
