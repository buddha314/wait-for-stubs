# Research: weather in Godot 4 (dust storms, rain, storms, fog, wind)

*2026-11-13. Asked: "what exists for rain and other weather events in Godot 4, which
add-ons are worth using, and how much would be our own work." Method: read our vendored
Sky3D (`addons/sky_3d/src/Sky3D.gd`, `SkyDome.gd`) to see what weather it already
covers; read the weather parts of stubby-music's `add-desert-opening` (the silent
windstorm) and of our `add-acoustic-asset-profiles`; searched the Asset Library,
godotshaders.com and GitHub; checked licence, language and last push of every GitHub
candidate with `gh api repos/<owner>/<repo>` on this date; read the Godot docs for
particle collision, volumetric fog and global shader uniforms. The game is MIT, so
GPL/LGPL and CC-NC/ND/SA are out, and CC-BY art needs care. Claims I could not verify are
marked as such.*

## What we already have

- **Sky3D's "Weather" group is wind only**: `wind_speed` (m/s) and `wind_direction`
  (radians, 0 = wind *from* north, 90° from east). They only move the clouds:
  `SkyDome.WIND_SPEED_FACTOR = 0.01` turns m/s into UV scroll. `cirrus_speed_reduction`
  adds parallax (negative values give wind shear). Clouds update in `_physics_process`
  by default; `process_method = Manual` plus `process_tick(delta)` lets us drive them
  from `Calendar` time, so future time-speed controls also speed up the clouds.
- **Overcast is already possible**: `cumulus_coverage`, `cirrus_coverage`,
  `*_intensity`, `*_thickness`, `*_absorption` and `clouds_night_color` are plain
  exported properties we can tween. The clouds are 2D layers in the sky shader, not
  volumetric. That's fine for a sky seen from the ground, but no cloud ever casts a
  shadow or comes down to the ground.
- **Sky3D's fog** (`AtmFog.gdshader`) is a screen-quad atmospheric fog
  (`fog_density`, `fog_start`/`fog_end`, `fog_falloff`, Rayleigh/Mie depth). It isn't
  volumetric, but it does give distance haze in the sky's colours.
- **Sky3D has no rain, lightning, snow, dust or wetness.** Nothing in the addon
  mentions them.
- **The lighting keys** (`assets/lighting/lighting_keys.json`) already carry
  `fog_color` and `fog_density` per mood and time key. Weather should *multiply or
  offset* those values, not own fog outright.
- **The design**: stubby-music's `add-desert-opening` defines the opening as a
  **silent windstorm** ("blowing sand, low visibility, and no sound at all"), with a
  seeded `StormIntensity` gust curve that has guaranteed troughs every 20–40 s, volumetric
  fog bound to that intensity, camera-following sand particles, and storm intensity
  that falls as light quality rises. None of it is ported yet. That makes **dust
  storms the first weather we need**, not an optional extra.

## Verdicts

| Need | Candidate | Licence · language · last push | Verdict | Start now? |
| --- | --- | --- | --- | --- |
| **Whole weather system** (rain, snow, fog, wind, wetness, clouds) | **TCA_Weather_System** (kS222138), v1.4.0 | MIT · GDScript · 2026-04-24 (21 commits, 40★), Godot 4.6+ | **Reject; read as reference.** It brings its own sky shader, volumetric clouds, day/night colour and `WorldEnvironment`, and its `WeatherController` writes `small_cloud_cover`/`large_cloud_cover` into whatever sky material it finds, which would fight Sky3D. It picks weather with the global `randf()`/`randi()`, which breaks "same seed, same world". Worth reading: `wind_controller.gd` (gusts), `VegetationWindDriver.gd` (registering materials instead of walking the tree), `WetnessController.gd` (drying over time), and its signal list (`rain_intensity_changed`, `wind_gust_triggered`…), which is close to the data our engine needs. | No |
| Weather system | **GodotWeatherSystem** (mlavik1) | MIT · C# · 2024-02-14 | **Reject.** C#, stale, and the game is GDScript and C++. | No |
| 2D weather | **Weather FX Free** (heyheythere); **godot-weather-2D** (parachutino, now `pirachute`) | Repo licence `NOASSERTION` (the listing says CC BY 4.0) · 2026-09-29; MIT · GDScript · 2021-03-19 | **Reject.** Both are 2D. Weather FX also has no clear licence. | No |
| **Dust storm / moving fog** | **Sandstorm / Fog Shader (Godot 4.X)** (REKIEX, godotshaders.com) | MIT (stated on the page) · `shader_type fog` · 2025-09-24 | **Adopt as a starting point** inside a `FogVolume`. It's ~30 lines: a scrolled 3D noise texture, a density gradient and emission. Swap its `fog_speed × TIME` scroll for the global `wind` vector. Keep the MIT notice in the file header. One commenter couldn't reproduce it, and another says it needs larger volumetric fog *Volume Size/Depth* (project settings). Expect to tune. | **Yes**, with the dust storm change |
| **Puddles and wet ground** | **Rain puddles with ripples and reflections** (shadecore_dev, godotshaders.com) | CC0 · spatial full-screen post shader · 2025-06-11 | **Reference.** A full-screen pass with its own SSR ray march is a lot of cost for occasional rain. Godot's Environment already has SSR in Forward+. Borrow the ripple normal function and the "horizontal surfaces only" mask for our ground shader. | Later |
| Puddles (2D) | **Puddle System** (Asset Library) | — | **Reject.** 2D only. Licence not checked. | No |
| **Lightning bolts** | Zap VFX (Godot store), Electric FX (itch), "Random 2D Lightning Strikes" and "2D lightning" shaders, GodotLightning (JarLowrey, 2D, Godot 3) | Store/paid packs not checked; the rest are 2D | **Build our own.** I found no maintained, MIT, 3D GDScript bolt generator. A bolt is a short-lived branched ribbon mesh (midpoint displacement) with an unshaded emissive material, plus a light flash. That's small. | With the storm change |
| Rain/snow screen shader | "Rain and Snow with Parallax Effect" (steampunkdemon; godotshaders and itch) | Listed as MIT in search results; **not verified** | **Not needed.** GPU particles do 3D rain better and collide with the ground. | No |
| Foliage wind | Many godotshaders.com sway shaders; hexaquo.at grass tutorial | Per-shader licences | **Pattern only.** Use one global `wind` uniform (Godot's own recommended pattern). Our reeds sway on the CPU anyway (see Wind). | — |
| Volumetric clouds | TCA's `clouds_volume.gdshader`; other volumetric sky add-ons | — | **Reject.** It would compete with Sky3D. Overcast is a coverage tween. | No |
| Weather **audio** add-ons | — | — | **Out of scope.** All sound goes through stubby-rack. See "Data the audio engine needs". | — |

## Godot built-ins that do most of the work

- **GPUParticles3D** (Forward+): rain streaks (`ParticleProcessMaterial` with velocity
  alignment, or `trail_enabled`), splashes as a **sub-emitter at collision**, dust
  motes and sand in a camera-following box. **Collision** comes from
  `GPUParticlesCollisionHeightField3D`. The docs call it "a good choice for weather
  effects such as rain and snow", and it has `follow_camera_enabled`, so one
  1024² heightfield around the player covers the mudflat (lower `resolution`, because
  following the camera re-renders it on every move). It rasterises visual layers, so
  it will see Terrain3D's mesh too. `heightfield_mask` keeps reeds and bugs out of it.
  `GPUParticlesAttractor3D` (box, sphere or vector field) can add a dust devil or
  swirl. Particles collide only on the GPU (not `CPUParticles3D`), and heightfields
  can't represent overhangs.
- **Volumetric fog + FogVolume** (Forward+ only, which we use): Environment
  `volumetric_fog_density`, `albedo` (amber dust), `emission`, `anisotropy` and
  `length`, plus `FogVolume` boxes with a `shader_type fog` material for the storm
  wall and drifting banks. The docs recommend a ≤64³ density texture, and say temporal
  reprojection ghosts behind moving volumes. It sits on top of Sky3D's AtmFog, so the
  two need tuning together.
- **Global shader uniforms** (Project Settings → Shader Globals, set with
  `RenderingServer.global_shader_parameter_set`): one `wind` (vec3: direction ×
  speed), `gust`, `wetness` and `dust_density`. They work in "every shader type",
  particle shaders included, per Godot's own announcement. `ParticleProcessMaterial`
  itself can't read globals, so wind-blown particles either get a custom particle
  shader or have their `gravity`/`initial_velocity` set from script.
- **Decal**: dark, glossy wet patches and puddles in low spots, fading with
  `modulate.a` as the mud dries. Cheap, and it doesn't touch the terrain shader.
- **WorldEnvironment / Sky3D**: storm darkening through `Sky3D.ambient_energy`,
  `tonemap_exposure` and cloud coverage. A lightning flash is a short
  `DirectionalLight3D`/`OmniLight3D` energy spike plus an exposure kick. Use our own
  light; don't touch Sky3D's SunLight.
- **Rain occlusion under cover**: the camera-following heightfield already stops rain
  on roofs and machine tops, because it takes the topmost surface. It fails only
  under overhangs (a player standing under a big machine's lip sees no rain hit the
  ground, but drops still stop at the lip, which reads correctly). The mudflat is
  open, so **no extra occlusion system is needed**. If interiors arrive, add a
  `GPUParticlesCollisionSDF3D` for that building, or an `Area3D` that fades rain out.

## How much is our own work

| Weather | Built-ins | Add-on / borrowed | Ours | Size |
| --- | --- | --- | --- | --- |
| **Weather state + scheduler** (`Weather` autoload) | `Tween`, global uniforms | TCA's structure as a reference | Seeded from `WorldSeed.rng("weather")` and advanced on `Calendar` time (so pause and time-speed behave). It owns `storm_intensity` (port of Bevy's gust curve with guaranteed troughs), `wind`, `gust`, `rain_rate`, `wetness` and `cloud_cover`, publishes them as globals and signals, and writes Sky3D and the Environment. Presets live as `.tres` in `scenes/weather/`, with the weather scene, not in an asset folder. | **Medium** |
| **Wind** | global uniforms, Sky3D wind | — | See below. Reeds read the wind; Sky3D gets direction and speed. | **Small** |
| **Dust storm** (the opening) | volumetric fog, FogVolume, GPUParticles3D, attractors | REKIEX fog shader (MIT) | Camera-local sand particle box with a wind-driven particle shader, a storm `FogVolume` bound to `storm_intensity`, fog and exposure scaled into the lighting keys, and storm intensity falling with light quality (once that field exists). Visibility tuning is the real work: navigable by silhouette, with guaranteed troughs. | **Medium–large** (mostly tuning and art) |
| **Fog / haze** | Environment fog, volumetric fog, Sky3D AtmFog | — | Mostly configuration: lighting keys → Sky3D/Environment mapping (needed anyway), and weather multiplies it. Morning ground mist over streams is a few `FogVolume`s. | **Small** |
| **Overcast** | Sky3D cloud coverage and intensity | — | Tween coverage, absorption and night colour; lower `ambient_energy`. | **Small** |
| **Rain** | GPUParticles3D, heightfield collision, sub-emitter splashes, Decal | puddle ripple maths (CC0) | Rain box following the camera, splash sub-emitter, ground `wetness` in the ground or Terrain3D shader (darker albedo, lower roughness), drying over calendar time, puddle decals in low spots. Mud-specific looks (cracks darkening and closing, streams swelling) are game art. | **Medium** |
| **Thunderstorm** | lights, exposure, Sky3D clouds | — | Bolt mesh generator, flash envelope, strike scheduling (see audio note). Its sound is the engine's job. | **Small–medium** |
| **Snow** | GPUParticles3D, same heightfield | — | Another particle preset plus `snow_cover` in the ground shader. It doesn't fit a desert mudflat, so skip it unless the design asks. | Small (if ever) |
| **Occlusion under cover** | heightfield collision (SDF if needed) | — | Nothing for the open mudflat. | None now |

In total: no add-on to adopt beyond one MIT fog shader. Godot's built-ins carry the
rendering, and our real work is the seeded `Weather` state, the storm look and the
wetness shading.

## Wind

One source of truth, a **`Weather.wind`** value (horizontal `Vector3` in m/s, plus a
`gust` 0–1 and a turbulence scalar), sampled from the seeded weather state on
`Calendar` time. Every consumer reads it; none invents its own.

- **Shader globals**: `RenderingServer.global_shader_parameter_set("wind", …)` (and
  `gust`, `dust_density`). Sand particles, the storm `FogVolume`'s noise scroll, grass
  and future foliage shaders, and rain slant all read it, so everything leans the
  same way.
- **Sky3D**: set `Sky3D.wind_speed` and `Sky3D.wind_direction` from it. Convert the
  vector to Sky3D's convention (angle the wind comes *from*, 0 = north, 90 = east). In
  this project north is −Z and east is +X (the sun rises at +X and crosses +Z), but
  check the sign once on screen. Clouds sit far above the ground, so use a separate
  multiplier for cloud speed. Set `process_method = Manual` and call
  `sky.process_tick(delta)` from calendar time so clouds follow time speed.
- **Reeds**: `reed_clump.gd` sways `Sway_*` nodes on the CPU with a fixed
  `SWAY_RATE = 0.35` Hz and `max_deg` from the profile. Make the amplitude scale
  with wind speed, add a lean (bias) along the wind direction, and phase-shift by
  `dot(position, wind_dir)` so gusts visibly travel across the bed. Keep it on the
  CPU: clumps are few, and they own harvest state. Move it to a vertex shader only if
  profiling says so. It's a small change once `Weather.wind` exists.
- **Particles**: dust, rain and splashes take wind as a velocity term in a particle
  shader (or as `gravity` set from script on a `ParticleProcessMaterial`).
- **Audio engine (as data only)**: send wind speed, direction and gust to stubby-rack
  as control-rate parameters, not events. They drive excitation amplitude, never
  timing.

### Data the audio engine needs (not audio add-ons)

The acoustic-ecology rule is that sources are physical and discovered, and the opening
storm is silent until then. So weather is a **control source** for engine modules:

| Data | Feeds | Notes |
| --- | --- | --- |
| Wind speed, direction, gust, turbulence (at listener and per emitter) | Reed quarter-wave tubes (edge-tone excitation), brush rattle (`noise_source` + `nonlinear`), the `wind` sample item | Control rate, smoothed. Only excites *discovered* sources. |
| `storm_intensity`, dust density | Air absorption and high-frequency loss with distance; sand hiss on surfaces | Visibility and hearing can share one curve. |
| Rain rate (mm/h) and drop-size distribution (e.g. Marshall–Palmer) | Minnaert-bubble drops on water (bubble radius → pitch), impacts on mud, metal and reeds | The engine generates the drops' *own* stochastic timing on its sample clock; the particles don't trigger sounds. |
| `wetness` per surface | Damping on mud and wood impacts, footstep timbre | Slow. |
| Lightning strike (position, energy) | Thunder: arrives at strike time + distance / 343 m/s, lowpassed with distance | **Open decision:** for flash and thunder to stay consistent, the strike should be an event scheduled on the engine's clock, with the flash displayed from it (like the clock light, D5), not a frame-timed visual that tells the engine afterwards. |

Weather visuals never time anything musical. Weather runs on calendar time. The engine
only receives parameters, and it schedules any sound itself.

## What this means

1. **Weather is mostly ours, built on strong built-ins.** Godot 4 Forward+ gives
   GPU particles with heightfield collision, volumetric fog with fog shaders, and
   global shader uniforms. Those are the hard parts. The only full 3D weather add-on
   (TCA) would replace Sky3D's sky and break seeding.
2. **Sky3D covers wind-driven clouds and overcast** through properties we can tween.
   Nothing else is needed for the sky.
3. **The dust storm comes first**, because it is the opening. It's specified in
   stubby-music's `add-desert-opening` §3 (3.1–3.3). Rain on mud is second. Snow
   doesn't belong here.

## Suggested order

1. **`add-weather-and-dust-storm`** (new OpenSpec change, a port of
   `add-desert-opening` §3.1–3.3): the `Weather` autoload (seeded, calendar time),
   `wind` and `storm_intensity` globals, Sky3D wind hookup, wind-aware reed sway, sand
   particles and a storm FogVolume. Include the reed sway and Sky3D wind, since they
   are small and prove the single wind source.
2. **Rain**: a particle box with heightfield collision and splashes, `wetness` with
   drying, and puddle decals. Do it after terrain (Terrain3D) lands, so wetness goes
   into the real ground shader once rather than twice.
3. **Thunderstorm**, once stubby-rack can schedule events: decide the strike-on-clock
   question first.

## Decisions since (2026-11-13)

- **Weather events align with the clock.** The user decided that lightning and most
  events, rain patter included, land on master-clock grids. The flash and other
  event visuals show at the audible instant, and thunder lands on the grid by
  choosing the strike distance. See `add-weather-and-dust-storm`.
- **Weather recipes** (a rain song or dance) are wanted later. The weather
  controller takes requests so recipes can drive it.

## Sources

[TCA_Weather_System](https://github.com/kS222138/TCA_Weather_System) ([Asset Library](https://godotengine.org/asset-library/asset/4960)),
[GodotWeatherSystem (mlavik1)](https://github.com/mlavik1/GodotWeatherSystem),
[Weather FX Free](https://godotengine.org/asset-library/asset/5495) ([repo](https://github.com/Spyridon-Pikoulas/godot-weather-fx-free)),
[godot-weather-2D](https://github.com/parachutino/godot-weather-2D),
[Sandstorm / Fog Shader (Godot 4.X)](https://godotshaders.com/shader/sandstorm-fog-shader-godot-4-x/),
[Rain puddles with ripples and reflections](https://godotshaders.com/shader/rain-puddles-with-ripples-and-reflection/),
[Puddle System](https://godotengine.org/asset-library/asset/5406),
[Rain and Snow with Parallax Effect](https://godotshaders.com/?p=5326),
[Random 2D Lightning Strikes](https://godotshaders.com/shader/random-2d-lightning-strikes/),
[2D lightning](https://godotshaders.com/shader/2d-lightning/),
[Zap VFX](https://store.godotengine.org/asset/vefects/zap-vfx/),
[GodotLightning](https://godotengine.org/asset-library/asset/244),
[GPUParticlesCollisionHeightField3D](https://docs.godotengine.org/en/latest/classes/class_gpuparticlescollisionheightfield3d.html),
[3D particle collisions](https://docs.godotengine.org/en/4.4/tutorials/3d/particles/collision.html),
[Volumetric fog and fog volumes](https://docs.godotengine.org/en/latest/tutorials/3d/volumetric_fog.html),
[Godot 4.0 gets global and instance shader uniforms](https://godotengine.org/article/godot-40-gets-global-and-instance-shader-uniforms),
[Grass rendering series part 3 (hexaquo.at)](https://hexaquo.at/pages/grass-rendering-series-part-3-animating-and-interacting-with-grass-in-godot/).
Local: `addons/sky_3d/src/Sky3D.gd`, `addons/sky_3d/src/SkyDome.gd`,
`assets/flora/reeds/reed_clump.gd`, `assets/lighting/lighting_keys.json`,
`openspec/changes/add-acoustic-asset-profiles/design.md` (D7),
`../stubby-music/AGENTS.md` (the opening), `../stubby-music/openspec/changes/add-desert-opening/`.
