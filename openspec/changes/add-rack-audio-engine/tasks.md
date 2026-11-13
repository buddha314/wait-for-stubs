## 0. Decisions

- [x] 0.1 Host: a C++ GDExtension on godot-cpp; stubby-music's Rust engine is the reference, not a dependency (design D1, D2)
- [x] 0.2 Pause: the clock keeps running and the music is muted (design D5)
- [x] 0.3a Master default tempo: 1 BPM, 4/4, as project settings `audio/master_clock/*` (design D5)
- [x] 0.3b Burbler tempo model: a whole multiple of the master (×40 to ×180, seeded per instance); every tempo clock is a whole multiple (design D5)
- [x] 0.4 Confirm no existing open-source package replaces the rack scheduler, clock, fan-out or queues: only the queues (CHOC) are adopted (design D3, `docs/research/rack-engine-reuse.md`)

## 1. Spike: Godot hosting (measure before building)

- [x] 1.1 Minimal godot-cpp extension (`spikes/host`) built against this binary's dumped `extension_api.json`, and against the 4.7 baseline; record which loads in 4.8
- [x] 1.2 Driver playback plus N stem playbacks rendering one shared test tone, rendered on first request per block via a block cursor; stems ignore `pitch_scale`, doppler off
- [x] 1.3 Drift and glitch test: one tone fanned to 48 AudioStreamPlayer3D for 10 minutes; check sample alignment and dropouts
- [x] 1.4 Cost per AudioStreamPlayer3D (main thread and mixer) at 16, 48 and 96 emitters
- [x] 1.5 Port stubby-music's `spike_rack` patch to the C++ core: a 200-module feedback patch's cost per 512-frame block inside `_mix`, against the 15% budget and Rust's 8.8 ns per module-sample
- [x] 1.6 Clock-to-light jitter: publish the sync point, flash a light on ticks, measure the error against the predicted audible instant
- [x] 1.7 Pause with `process_mode = ALWAYS` players: the rack keeps rendering, and the in-core mute fades cleanly
- [ ] 1.8 Scene reload and editor hot-reload of the extension (scene reload passes: 20 cycles × 32 players, 0 skips; editor hot reload needs a manual check in the editor)
- [ ] 1.9 HRTF: check whether the Steam Audio fork or Nexus Resonance accepts a custom stream; otherwise measure in-core binaural rendering at 16 emitters (tested: Nexus v1.1.0 wraps our stream but its 4.6 binary fails in 4.8: registration errors, silent with Steam Audio on. Next: rebuild it against 4.8, or in-core binaural; see design.md)
- [ ] 1.10 Record results in design.md (D1, D4, D8); if the driver-player approach fails, evaluate the engine-module fallback

## 2. Repository and build

- [x] 2.1 Repository `buddha314/stubby-rack` with godot-cpp 10.0.0-stable as a submodule, SCons build against the dumped 4.8 API (and the 4.7 baseline), `.gdextension` in `demo/addons/stubby_rack/`; `RackServer` loads headless (`demo/smoke_test.gd`)
- [x] 2.2 `thirdparty/`: DaisySP MIT core (no `DaisySP-LGPL`), Mutable Instruments STM32 dsp and stmlib (MIT), CHOC subset (ISC), Signalsmith DSP (MIT), doctest; `tools/check_licences.py` passes
- [x] 2.3 `tests/` with doctest for `src/core`, running with no Godot (`scons tests`: VCV voltage scenarios pass); build documented in stubby-rack's README and CLAUDE.md
- [x] 2.4 Decide how wait-for-stubs consumes the addon: vendored copy in `res://addons/stubby_rack/`, as Godot's version-control guidance and the Asset Library expect (design D11)
- [ ] 2.6 `tools/sync_stubby_rack.sh` in wait-for-stubs: build stubby-rack (or fetch its CI artifact for other platforms), copy `demo/addons/stubby_rack/` to `addons/stubby_rack/`, write `VERSION` with the stubby-rack commit, run `--import` twice (task 2.5); add `*.so`, `*.dll`, `*.dylib` to `.gitattributes` before the first commit; `.gdextension` sets `compatibility_minimum` and `reloadable = true`
- [ ] 2.5 Report the Godot 4.8 beta clean-import abort with GDExtensions upstream (it reproduces with godot-cpp's own test extension)

## 3. Engine core (`src/core`, plain C++17)

- [ ] 3.1 Per-sample rack scheduler with double-buffered ports (1-sample cables), feedback allowed, polyphony-ready cable type
- [ ] 3.2 VCV voltage standards (±5 V audio, 10 V gates, Schmitt 0.1/1.0 V, 1 V/oct, NaN → 0)
- [ ] 3.3 Emission stems: per-emitter block buffers plus a non-spatial UI stem
- [ ] 3.4 Lock-free SPSC command and return queues; modules built and freed off the audio thread
- [ ] 3.5 Offline renderer; allocation guard in tests (global operator new hook during render)
- [ ] 3.6 Parity fixtures: render stubby-music's engine tests and `spike_rack` patches offline in Rust and compare (timing exact; spectra and RMS within tolerance)
- [ ] 3.7 Determinism and 200-module budget tests

## 4. Master clock

- [ ] 4.1 Sample counter as the single time base; transport (tempo, meter, start/stop, continuous beat phase across tempo changes)
- [ ] 4.2 Scheduler: absolute-sample and quantized (beat, bar, division) actions at exact in-block offsets; late notices
- [ ] 4.3 Clock modes: tempo clocks at a whole multiple of the master, ticks derived from master phase; seeded random clocks run free
- [ ] 4.4 Sync point per block (sample, mix instant, output latency) published atomically
- [ ] 4.5 Read the default tempo and meter from project settings `audio/master_clock/tempo_bpm` and `beats_per_bar`
- [ ] 4.6 Pause: driver and stem players use `process_mode = ALWAYS`; an in-core mute gain on world and music stems, faded over 20–50 ms; the UI stem is unaffected
- [ ] 4.7 Sample-rate change keeps tempo and musical position; underrun keeps relative timing
- [ ] 4.8 Offline tests for every master-clock scenario, including pause and the configured default

## 5. Godot-facing classes (`src/godot`)

- [ ] 5.1 `RackServer` engine singleton: `commit()` once per frame, signals with sample times, time reads
- [ ] 5.2 `RackModuleDefinition` and `RackPatch` Resources (`.tres`), with inspector editing
- [ ] 5.3 `Rack` node (instantiates a patch; cables, params, schedule) and `RackEmitter` (AudioStreamPlayer3D subclass bound to a stem, doppler off)
- [ ] 5.4 Driver and stem playbacks (no Godot objects and no locks in `_mix`)
- [ ] 5.5 Sampler for one-shot sounds; port `assets/audio/sfx/patch_snap`; no timed sound bypasses the rack
- [x] 5.6 Project setting `audio/driver/mix_rate` = 48000 (set in project.godot with the master-clock settings)

## 6. Modules

- [ ] 6.1 `RackModuleDefinition` resources seeded from stubby-music's `assets/modules/<id>/asset.json`
- [ ] 6.2 Definition check: the core's registry and the resources agree
- [ ] 6.3 Square VCO, Sine VCO, Clock, Envelope, VCA and Constant, with DSP from DaisySP
- [ ] 6.4 Document how to add a module (library first, definition resource, test) in CLAUDE.md

## 7. Spatial emission

- [ ] 7.1 Hearing radius and distance cues on emitters; doppler off
- [ ] 7.2 Voice ranking with hysteresis: HRTF tier, pan tier, virtual (player stopped, rack still computing); crossfade on tier change
- [ ] 7.3 HRTF provider per spike 1.9; speaker-fallback setting
- [ ] 7.4 Occlusion raycasts for voiced emitters only; cutoff and gain smoothed over about 100 ms
- [ ] 7.5 Spatial budget test (16 HRTF + 32 panned)

## 8. Rack control

- [ ] 8.1 Parameter smoothing (5–20 ms)
- [ ] 8.2 Lights and meters as atomics; scope rings; read by scripts at frame rate
- [ ] 8.3 Cable fades by port type (audio fades, gate and CV switch instantly)
- [ ] 8.4 Patch round trip through `.tres` (modules, params, cables, emitters, positions)

## 9. Game integration

- [ ] 9.1 Lightning bug: free-running seeded random Clock → Envelope → VCA → Square VCO on its emitter; the flash follows `clock_ticked` (replacing the frame-timed `_process` countdown and the WAV click)
- [ ] 9.2 Burbler: its fixed Clock and Volume modules exist in its rack (sound starts once the rack-screen change adds mounting and patching)
- [ ] 9.3 Remove the frame-time stand-in notes from CLAUDE.md; run `openspec validate --strict add-rack-audio-engine`
