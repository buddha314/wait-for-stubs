## 1. Spikes

- [ ] 1.1 REKIEX sandstorm fog in a FogVolume on the 4.8 beta, Forward+: tune the volumetric fog settings; frame cost at 1080p on this machine; depth-fog fallback
- [ ] 1.2 Camera-local GPUParticles3D sand box with a heightfield collider following the camera; cost at full intensity

## 2. Weather controller (clock events)

- [ ] 2.1 `Weather` autoload: grid periods from `audio/master_clock/tempo_bpm`, `events_between(from, to)` from per-tick seeded draws (design D1, D3)
- [ ] 2.2 Continuous state: seeded baseline keyframes on grid ticks, smooth interpolation, request hook with ramps (D4)
- [ ] 2.3 Stand-in time source (`STAND-IN`, wall time × 48 kHz), no sound (D5)
- [ ] 2.4 Storm curve: troughs every 20–40 s on ×15 ticks; the game starts inside the storm
- [ ] 2.5 Patter events (density and drop sizes from rain rate; texture level beyond grid capacity) and strike/thunder events (distance from a whole number of ticks), as data only (D2)
- [ ] 2.6 Headless tests: grid alignment, frame-rate independence, determinism, trough spacing across 1,000 seeds, thunder distance multiples of 343 m per tick, requests ramp from a tick, no requests means an unchanged baseline

## 3. Wind

- [ ] 3.1 `wind` global shader uniform in `project.godot`, set by `Weather` each frame
- [ ] 3.2 Sky3D wind from `Weather.wind` (convention and sign checked on screen)
- [ ] 3.3 Reed sway from wind: amplitude, rate, downwind lean, gust delay along the wind; headless check that upwind clumps respond first

## 4. Dust storm

- [ ] 4.1 Storm `FogVolume` (REKIEX shader with its MIT header; wind instead of its time scroll) bound to intensity × (1 − air quality), with q = 0 until `add-air-quality-field` provides its texture
- [ ] 4.2 Sand particles bound to intensity and wind
- [ ] 4.3 Screenshots: opening (polluted), full storm, trough (the burbler and moon read as silhouettes, 60 m or more)

## 5. Engine hookup (after stubby-rack 4.2, 4.4, 5.1)

- [ ] 5.1 Replace the stand-in with `RackServer` sample time; schedule weather events in the engine; send continuous state as parameters
- [ ] 5.2 Event visuals at audible instants via the sync point (splash ripples come with the rain change; flashes with the lightning change)

## 6. Docs

- [ ] 6.1 CLAUDE.md: weather events on the clock, the stand-in, `wind` global, presets local; `openspec validate --strict add-weather-and-dust-storm`
