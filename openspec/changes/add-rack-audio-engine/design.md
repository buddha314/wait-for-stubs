## Context

This ports two stubby-music changes into Godot:

- `add-audio-engine`, the built engine core in `crates/stubby_audio`: Firewheel graph,
  fundsp DSP, a command/flush/event boundary, offline rendering, 18 tests.
- `add-rack-and-spatial-audio`: the VCV-style rack and spatial layer, designed and
  spiked but not built.

Their requirements carry over almost unchanged. What changes is the host and the
language. In Godot, Godot's AudioServer owns the device, mixes on its own thread, and
provides spatial players, buses and reverb areas. Godot-side facts and the hosting
comparison are in `docs/research/godot-audio-hosting.md`.

**The user chose a Godot-native C++ GDExtension (2026-11-13)** over hosting the Rust
crate. stubby-music's Rust engine becomes the reference design and test oracle, no
longer a dependency. The user also asked for a central clock that syncs **all** game
audio, not only the rack; that is the `master-clock` capability.

## Goals / Non-Goals

**Goals:**
- A Godot-native audio engine: modules, patches, cables and emitters are Godot
  resources and nodes, editable in the inspector, saved as `.tres`, and scripted from
  GDScript with signals.
- A VCV-semantics rack whose sound plays through Godot's spatial audio.
- One master clock for all game audio: rack, sound effects, UI, ambience.
- Adding a synth voice or module is cheap: DSP from an existing MIT library plus a
  resource definition.

**Non-Goals:**
- The full 3D rack screen (mounting, cable dragging, knobs). This change provides
  the API it needs; the screen is its own change.
- Polyphonic modules (the cable type allows them).
- Multi-threaded rack processing.
- Physically based reverb and transmission.

## Decisions

**D1 — A C++ GDExtension built on godot-cpp, rendered from Godot's mix.**
`stubby_rack` is a godot-cpp extension (MIT, Godot's official binding). It
implements `AudioStream`/`AudioStreamPlayback`. Godot's audio thread calls `_mix`
every 512-frame block, and the rack renders that block. One thread, one clock, no
extra buffering. The extension loads in stock Godot and in the custom build, and the
editor hot-reloads it.

*Rejected:*
- **GDScript with `AudioStreamGenerator`.** 110 ns per module-sample measured, about
  106% of real time at 200 modules. It is also fed from the main thread.
- **godot-rust hosting `stubby_audio`.** It keeps fundsp and the existing tests, but
  adds a Rust toolchain beside Godot's C++. gdext's audio-thread soundness issues
  (#1130/#1131) are open. The user asked for a more Godot-native engine.
- **A C++ engine module compiled into the custom Godot build.** It is the most
  native option and could use AudioServer's internal mix callback and mix counter.
  But it needs custom export templates and an engine rebuild for every change, and it
  ties the game to the fork. Revisit only if the driver-player workaround (D4) fails.
- **libpd.** Feedback costs at least one Pd block, and the Godot bindings are small and
  dated.
- **Faust as the host.** No maintained Godot bridge. Faust is still used as a
  *module source* (D7).
- **VCV Rack or Cardinal as an engine.** GPL-3, so it can't be linked into this MIT
  game.

**D2 — stubby-music's engine is the reference, not a dependency.** The C++ rack is
new code: the rack scheduler wasn't built in Rust either. The engine core (protocol,
clocks, fades) is a port of about 1,850 lines of `stubby_audio`. The Rust engine's 18
tests and the `spike_rack` patches become **parity fixtures**: stubby-music renders
them offline to reference files, and C++ tests must match within a tolerance
(bit-exact isn't expected across fundsp and DaisySP oscillators). The two engines then
evolve separately, and stubby-music keeps its Rust engine.

**D3 — Layout: a Godot-free DSP core inside the extension.**

```
extension/stubby_rack/
  src/core/       rack, master clock, scheduler, modules: plain C++17, no godot-cpp types
  src/godot/      AudioStream/Playback, Resources, Nodes, the RackServer singleton
  thirdparty/     DaisySP (MIT core only), Mutable Instruments STM32 dsp (MIT), godot-cpp
  tests/          doctest unit + offline-render tests of src/core
  SConstruct      godot-cpp's SCons build, as Godot itself uses
```

The core builds and tests with no Godot (requirement "Engine core is independent of
the game engine"), and offline rendering lives there. Only `src/godot/` touches
godot-cpp. The build uses SCons (`scons platform=linux`), Godot's own toolchain, so
there is no CMake and no Cargo. The `.gdextension` file sits in `addons/stubby_rack/`.

**D4 — Stems fan out to AudioStreamPlayer3D, rendered once per block.**

```
Godot audio thread, one 512-frame step
 ├─ DriverPlayback._mix (always playing, silent output)
 │    └─ if block cursor < step: rack + clock + sampler render the block → stems[]
 ├─ StemPlayback(emitter 7)._mix → copy stems[7]   (AudioStreamPlayer3D at the module)
 ├─ StemPlayback(emitter 2)._mix → copy stems[2]
 └─ …
```

- Rendering is triggered by whichever playback first asks for a block the rack
  hasn't produced, using a block cursor. That way Godot's playback order doesn't
  matter.
- The driver playback keeps the rack and the clock running when nothing is audible.
- Stems are plain `AudioStreamPlayback` (not resampled) and ignore `pitch_scale`, so
  **doppler is off** on synth emitters. Godot supplies panning, distance attenuation,
  the distance filter, Area3D reverb sends and bus routing.
- `_mix` touches only the core's lock-free state, never a Godot object.

**D5 — The master clock is the rack's sample counter.** Godot doesn't expose its mix
counter or mix callback to extensions, and its clocks are wall time, so the rack's
count of rendered samples is the only sample-exact time base.

- **Transport.** Lives in the core: tempo, meter, start/stop, beat phase kept
  continuous across tempo changes.
- **Scheduling.** Actions carry an absolute sample time or a quantized musical
  position, and the core applies them inside the block at the exact sample offset.
- **Sync point.** Each block publishes the sample at the block start, the mix instant
  and the output latency, through an atomic triple. The game maps samples to
  predicted audible instants.
- **All audio goes through the rack.** One-shot sound effects and UI sounds play
  through a sampler in the core, onto a non-spatial stem or an emitter stem, so they
  share the clock. A raw `AudioStreamPlayer` for anything timed is a bug.
- **Simulation time stays separate.** The `Calendar` autoload remains simulation time
  and never drives audio.
- **Default tempo is configuration (decided 2026-11-13).** The project settings
  `audio/master_clock/tempo_bpm` (20.0) and `audio/master_clock/beats_per_bar` (4)
  are read at start. Changing the default is a settings edit, not a code change. At
  20 BPM a beat is 3 s and a bar 12 s.
- **Pause keeps time and mutes the music (decided 2026-11-13).** Godot's pause skips
  paused playbacks, so the driver and every stem player run with
  `process_mode = ALWAYS`, and the rack keeps rendering. Muting is a gain stage in the
  core on the world and music stems, faded over 20–50 ms. It is not a bus mute,
  because Godot smooths bus volume per block. The UI stem stays audible.

**D6 — A Godot-native API.** Everything scripts and the editor see is a Godot type:

| Godot type | Role |
| --- | --- |
| `RackServer` (engine singleton, like `AudioServer`) | owns the core; `commit()` once per frame; signals `clock_ticked(clock_id, sample)`, `action_late(id, samples)`, `command_rejected(reason)`; time reads `now_sample()`, `position()`, `sample_to_ticks_usec()` |
| `RackModuleDefinition` (Resource, `.tres`) | a module kind: ports, parameters (range, default, unit), lights, panel bindings, DSP source; one per kind under `assets/modules/<id>/` |
| `RackPatch` (Resource, `.tres`) | modules, parameter values, cables, emitter settings; patches are data, so save games and test fixtures are `.tres` |
| `Rack` (Node3D) | one machine's rack in the world; instantiates a `RackPatch` into the server; exposes `connect_cable()`, `set_param()`, `schedule()` |
| `RackEmitter` (AudioStreamPlayer3D subclass) | plays one module's stem from where the module stands; stem stream, doppler off, `process_mode = ALWAYS` |

- **Lock-free boundary.** Calls on `Rack` and `RackServer` queue commands on the main
  thread. `commit()` publishes the frame's batch to the audio thread through a
  lock-free SPSC queue, with module objects prebuilt off the audio thread. Removed
  modules return on a second queue and are freed on the main thread.
- **Events.** Events drain on the main thread and are emitted as signals carrying
  sample times. Module IDs are assigned by the game.
- **Godot-free core.** The core never sees a Godot type, so no Godot lock or object
  is ever reached from `_mix`.

**D7 — Modules: DSP from existing MIT libraries, definitions as Resources.** Each
module kind is a C++ class implementing the core's per-sample `process()`. Sources,
in order of preference:

1. **DaisySP**, MIT core only, never the `DaisySP-LGPL` submodule: oscillators
   (band-limited), filters (SVF, ladder), ADSR, noise, delay, reverb, modal and string
   voices.
2. **Mutable Instruments' STM32 code** (`pichenettes/eurorack`, MIT; the AVR code is
   GPL and excluded): Plaits engines, Rings, Clouds.
3. **Faust → C++** for anything those lack, checking each Faust library file's licence.

Hand-written DSP is the last resort. Ports and parameters live in the module's
`RackModuleDefinition` resource. The rack screen reads it, the core's registry
declares the same, and a test checks that the two agree. stubby-music's
`assets/modules/<id>/asset.json` files seed the first definitions.

*Rejected:* fundsp. It is Rust, and that choice went with D1.

**D8 — Spatial: Godot first, HRTF decided by spike.**

- **Base layer:** every voiced emitter is a `RackEmitter`, so Godot provides panning,
  attenuation and the distance filter.
- **Hearing radius:** `max_distance` plus a fade to the edge applied in the stem gain.
- **Voice tiers:** game-side ranking each frame by estimated audibility, with
  hysteresis. Virtual emitters keep rendering in the rack, but their player is
  stopped.
- **HRTF tier (top 16), options in the order the spike tries them:**
  1. a Steam Audio GDExtension (nurjeff's fork) or Nexus Resonance, if one accepts a
     custom stream;
  2. binaural rendering inside the core with an MIT/BSD HRTF data set and
     convolution, output through a non-positional player.
- **Speaker fallback:** the panning tier for everything.

**D9 — Occlusion is game-side.** For voiced emitters only, the game raycasts from the
listener with Godot physics each frame. It lowers the emitter's
`attenuation_filter_cutoff_hz` and volume, smoothed over about 100 ms. *Considered:*
Raytraced Audio and Spatial Audio Extended (one bus per player doesn't fit hundreds of
stems), and Steam Audio occlusion (rides along if D8 picks Steam Audio).

**D10 — Rate and latency.** The project mix rate is 48 kHz. Godot's block is fixed at
512 frames (10.7 ms). With the default 15 ms output latency that is about 25 ms end to
end, fine for a rack you listen to. The sync point corrects visuals for it.

**Budgets carried over from the Bevy spikes, rescaled to a 512-frame block (10.67 ms):**
200 modules ≈ 0.9 ms (8.5%) in Rust. The C++ spike must confirm a similar cost
per module-sample. The 15% budgets in the specs are percentages, so they still apply.

## Risks / Trade-offs

- [Rewriting the engine core in C++ loses the Rust engine's tested behaviour] →
  parity fixtures rendered by stubby-music (D2); the core's tests run without Godot.
- [DaisySP or Mutable Instruments oscillators differ from fundsp, so parity can't be
  bit-exact] → tolerance-based parity (spectral peak, RMS, timing exact); timing and
  clock tests stay exact.
- [Licence slip: DaisySP's LGPL submodule, MI's AVR code, Faust library files] →
  vendor only the MIT parts; a licence check over `thirdparty/` in CI.
- [Godot 4.8 beta API churn] → build godot-cpp against this binary's
  `extension_api.json` (`--dump-extension-api`), plus a CI build against the 4.7
  baseline. Pin the godot-cpp revision.
- [Godot's playback order or skipping changes] → render on block cursor; the spike
  tests drift over 10 minutes.
- [Doppler is unavailable on synth stems] → accepted; a modular rack shouldn't
  pitch-shift with motion.
- [Many AudioStreamPlayer3D cost main-thread and mixer time] → the voice budget caps
  voiced players at 48; the spike measures cost per player.
- [The driver-player workaround is fragile] → fallback is the engine-module option
  (D1), which has a real mix callback.

## Migration Plan

1. Spike (task group 1) before production code. If it fails on drift or cost, revise
   this design (the engine-module fallback, D1).
2. Land the extension, the core and the master clock, with Square VCO, Clock,
   Envelope, VCA, Constant and Sine VCO.
3. Replace the lightning bug's frame-timed flash and WAV click with a rack voice on a
   free-running seeded clock. Its light follows `clock_ticked`.
4. The rack screen change builds mounting and patching on `Rack` and `RackPatch`.

Rollback: the extension is additive until step 3. The frame-timed bug stays in git
history.

## Open Questions

- ~~Pause~~: decided, the clock keeps running and the music is muted (D5).
- ~~Master default tempo~~: decided, 20 BPM in 4/4, in configuration (D5).
- ~~Host language~~: decided, a C++ GDExtension (D1).
- **The burbler's tempo:** its profile sets a per-instance BPM (40–180, from the world
  seed), far above the 20 BPM master. Should each burbler run free at its own BPM, or
  follow the master at a ratio (for example ×2 to ×9, which gives 40–180)?
- **HRTF provider** (D8), decided by the spike.
- **Emitter per module:** stubby-music leaned toward VCOs, VCAs and mixers emitting by
  default, and utilities not.
- **Ranking by estimated or measured loudness:** stubby-music leaned toward measured
  stem RMS (from meters), which is one frame late.
