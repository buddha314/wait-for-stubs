## Why

The game is VCV Rack inside a factory builder. Players mount modules into machine
racks and patch them live, and the world's sound is found by ear. Godot's built-in
audio plays streams; it has no patch graph, no per-sample modular semantics and no
musical clock. GDScript DSP measured at about 106% of real time for a 200-module rack
(`docs/research/godot-audio-hosting.md`). The bugs' clicks are a frame-timed
stand-in, and the burbler's rack panel can't mount or patch anything. Every
sound-making feature still to come (more voices, more modules, machines firing on the
beat) depends on this engine, so it comes first.

## What Changes

- **A Godot-native audio engine as a C++ GDExtension** (`stubby_rack`, godot-cpp).
  Godot's mixer calls it once per audio block, so there's one audio thread and one
  clock.
  - Scripts and the editor see Godot types: a `RackServer` singleton, `RackPatch` and
    `RackModuleDefinition` resources (`.tres`), `Rack` and `RackEmitter` nodes, and
    signals for clock ticks.
  - The DSP core inside it is plain C++ and testable without Godot.
- **A VCV-style rack:** every module runs once per sample, cables are 1-sample delays,
  feedback patches are allowed, signals follow VCV voltage standards, and cables are
  ready for polyphony. This ports stubby-music's `add-rack-and-spatial-audio` design,
  which was spiked but never built. stubby-music's Rust engine serves as the
  reference and test oracle.
- **A central master clock** that times all game audio:
  - one sample counter;
  - a musical transport at a configurable default of 1 BPM, 4/4, with every tempo
    clock a whole multiple of it;
  - sample-accurate and beat-quantized scheduling;
  - clocks that follow the master or run free;
  - lock-free time reads for visuals.

  Pausing keeps the clock running and mutes the music. Simulation time (day/night)
  stays separate.
- **Emission stems feed Godot's spatial audio.** Each sounding module's output plays
  through its own `RackEmitter` (an AudioStreamPlayer3D). Godot does panning,
  distance, Area3D reverb and buses. HRTF comes from an addon or from the core,
  chosen by spike.
- **A module catalogue built from existing MIT DSP code:** DaisySP's MIT core,
  Mutable Instruments' STM32 code, and Faust's C++ output. The first modules are the
  ones the opening needs: Square VCO (the lightning bug), Clock (the burbler),
  Envelope, VCA, Constant and Sine VCO.
- **A rack control surface** for the rack screen:
  - smoothed parameters;
  - lights, meters and scopes, read without locks;
  - cable edits that fade audio but switch gates instantly;
  - patches saved as `.tres`.
- **BREAKING (internal):** the lightning bug's frame-timed flash and pre-rendered
  click (`scenes/lightning_bug/`) move to a rack Square VCO driven by a free-running
  seeded clock.

## Capabilities

### New Capabilities
- `audio-engine`: the engine inside Godot's mix, the game↔audio boundary, realtime safety, offline rendering, and silence until sound is discovered.
- `master-clock`: the single audio time base, transport and configured default tempo, sample-accurate and quantized scheduling, clock following, lock-free time reads, pause behaviour, independence from simulation time.
- `modular-rack`: per-sample processing, 1-sample cables, feedback, VCV voltage standards, polyphony-ready cables, determinism, CPU budget.
- `rack-control`: smoothed parameters, lights, meters and scopes, cable edit rules, patches as data.
- `spatial-emission`: emitters and stems, a camera-following listener, voice tiers and budget, distance cues and hearing radius, occlusion, no doppler, speaker fallback.
- `synth-modules`: the module and port model, module definitions as data, DSP from existing libraries, and the first module set.

### Modified Capabilities
<!-- none: openspec/specs/ is empty in this repo -->

## Existing tools this relies on

- **godot-cpp** (MIT), Godot's official C++ binding: `AudioStream`,
  `AudioStreamPlayback`, Resources, Nodes, signals, and its SCons build.
- **DaisySP** (MIT core; the LGPL submodule is excluded) and **Mutable Instruments'
  eurorack STM32 code** (MIT; the AVR code is GPL and excluded) for DSP. **Faust →
  C++** where those lack something (licences checked per library file).
- **Godot**: AudioServer mixing, AudioStreamPlayer3D (panning, attenuation, filter),
  Area3D reverb buses, audio buses, project settings for clock configuration.
- **stubby-music's `stubby_audio`** (Rust) as the reference design. Its tests and
  `spike_rack` patches become parity fixtures.
- **HRTF**, decided by spike: a Steam Audio GDExtension (nurjeff fork) or Nexus
  Resonance if either accepts custom streams; otherwise binaural rendering in the
  core with an MIT/BSD HRTF data set.
- **Occlusion:** raycasts with Godot physics.
- **Written from scratch, deliberately:**
  - the per-sample rack scheduler (no library offers VCV semantics under an
    MIT-compatible licence);
  - the master clock and transport;
  - the stem fan-out;
  - the Godot-facing classes;
  - a C++ port of the engine core (protocol, clocks, fades).

## Impact

- New: `extension/stubby_rack/` (C++17, godot-cpp, SCons) producing
  `addons/stubby_rack/bin/*.so` and a `.gdextension` file. The build needs SCons and a
  C++17 compiler (already present for the custom Godot build). No Rust toolchain.
- Project settings, already added: `audio/driver/mix_rate=48000`,
  `audio/master_clock/tempo_bpm=1.0`, `audio/master_clock/beats_per_bar=4`.
- Game code: `scenes/lightning_bug/` and `scenes/rack_screen/`, and later the
  burbler. `RackServer` replaces the planned GDScript audio autoload.
- Godot 4.8 beta API churn: godot-cpp built against this binary's dumped
  `extension_api.json`, with a 4.7 baseline build in CI.
