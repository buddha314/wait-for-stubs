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

**D3 — Its own repository, with a Godot-free DSP core.** The engine lives in
[`buddha314/stubby-rack`](https://github.com/buddha314/stubby-rack) (MIT, created
2026-11-13), so it can be versioned, tested and reused apart from the game. This
spec stays in the game repository, and stubby-rack's README points back here.

```
stubby-rack/
  src/core/       rack, master clock, scheduler, modules: plain C++17, no godot-cpp types
  src/godot/      AudioStream/Playback, Resources, Nodes, the RackServer singleton
  thirdparty/     DaisySP (MIT core), Mutable Instruments STM32 + stmlib (MIT),
                  CHOC subset (ISC), Signalsmith DSP (MIT), doctest; pins in THIRDPARTY.md
  godot-cpp/      submodule at 10.0.0-stable
  api/            extension_api.json dumped from the Godot 4.8 binary
  tests/          doctest tests of src/core (`scons tests`, no Godot)
  demo/           minimal project; the build writes the addon to demo/addons/stubby_rack/
  SConstruct      godot-cpp's SCons build, as Godot itself uses
```

**Reuse survey (2026-11-13, `docs/research/rack-engine-reuse.md`).** Adopted: CHOC's
lock-free FIFO and block dispatcher, and Signalsmith DSP alongside DaisySP and
Mutable Instruments. Nothing permissive provides a per-sample scheduler with VCV
semantics (permissive engines are block-based; the per-sample ones are all GPL-3), a
master clock that other code can schedule against, the stem fan-out, or the
Godot-facing classes, so those are written here. *How the game consumes the
addon* (copy `demo/addons/stubby_rack`, a git submodule, or release artifacts) is
decided when the game first uses it.

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

- Rendering is triggered by the first playback to read in each Godot mix step. The
  renderer detects steps itself: a gap of more than a quarter block since the last
  read, or a reader that already read in this step reading again. Every read in a
  step gets the same block, so Godot's playback order doesn't matter and emitters
  stay sample-aligned. Per-player block cursors were tried in the spike and drifted
  1–2 blocks apart (see Spike results).
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
- **Default tempo is configuration (decided 2026-11-13, revised the same day).** The
  project settings `audio/master_clock/tempo_bpm` (1.0) and
  `audio/master_clock/beats_per_bar` (4) are read at start. Changing the default is a
  settings edit, not a code change. At 1 BPM a master beat is 60 s and a bar 4 min.
- **Every tempo is a whole multiple of the master (decided 2026-11-13).** A tempo
  clock runs at N × the master BPM, N a whole number, and computes its ticks from the
  master beat phase rather than counting its own period. With a 1 BPM master, N *is*
  the clock's BPM, so a burbler's 40–180 BPM is ×40 to ×180, and every clock in the
  world lands together once a minute. Rejected: free-running per-instance BPM (clocks
  drift apart and never share a downbeat, so machines can't be composed against each
  other); a 20 BPM master with ratios (only 9 burbler tempos between 40 and 180, or
  fractional ratios that again share a downbeat only rarely). Seeded random clocks
  (lightning bugs) are the one exception: they stay free, in master samples.
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
  lock-free SPSC queue (CHOC), with module objects prebuilt off the audio thread. Removed
  modules return on a second queue and are freed on the main thread.
- **Events.** Events drain on the main thread and are emitted as signals carrying
  sample times. Module IDs are assigned by the game.
- **Godot-free core.** The core never sees a Godot type, so no Godot lock or object
  is ever reached from `_mix`.

**D7 — Modules: DSP from existing MIT libraries, definitions as Resources.** Each
module kind is a C++ class implementing the core's per-sample `process()`. Sources,
in order of preference:

1. **DaisySP**, MIT core only, never the `DaisySP-LGPL` submodule: oscillators
   (band-limited), filters (SVF, `ladder.h`), ADSR, noise, delay, modal and string
   voices, drums, chorus/flanger/phaser/overdrive. *Corrected 2026-11-13
   (`add-module-library`):* the reverb (`ReverbSc`), compressor and Csound
   `MoogLadder` are in DaisySP-LGPL, not the MIT core. Reverbs come from Mutable's
   `fx/`, Faust or CloudSeed; the compressor from Mutable Streams.
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

**D11 — The game vendors the built addon (decided 2026-11-13).** wait-for-stubs keeps
a copy of stubby-rack's built `addons/stubby_rack/` (the `.gdextension` and its
binaries, in Git LFS), pinned by a `VERSION` file naming the stubby-rack commit, and
refreshed by `tools/sync_stubby_rack.sh`. This follows Godot's conventions: commit
everything but `.godot/`; addons live in `res://addons/` (as the Asset Library
installs them); `godot-cpp-template` builds the extension in its own repo and CI and
ships the addon folder. Rejected: a git submodule (Godot would scan godot-cpp and
`thirdparty/` inside `res://` unless `.gdignore`d, and every clone would need a C++
toolchain); downloading release artifacts on demand (needs CI for every platform
first, too slow while the engine changes daily). Release builds for other platforms
come from stubby-rack's CI artifacts through the same script.

## Spike results (2026-11-13, task group 1)

Measured in stubby-rack (branch `spike-hosting`) on Linux, Godot 4.8 beta, PulseAudio,
48 kHz, 512-frame steps, a 12-core desktop with an RTX 5070 Ti. Code:
- `src/core/stem_renderer.*` (fan-out and step detection);
- `src/core/spike_rack.*` (rack port);
- `demo/spike_*.gd`, `tools/spike_sync.py`, `bench/spike_rack_bench.cpp`.

**1.1 Hosting (D1): confirmed.**
- The extension builds against the dumped 4.8 API (godot-cpp 10.0.0-stable) and loads
  in 4.8.
- It also builds against godot-cpp's bundled 4.7 API, and that build loads and runs
  in 4.8 too (the smoke and reload spikes pass).
- The first clean `--import` aborts (exit 134); the second succeeds (task 2.5).

**1.2 Fan-out (D4): works, with one design change.** Players keeping their own block
cursors drifted apart permanently: a stem that started mid-game couldn't tell whether
the current step's block was already rendered, and ended up 1–2 blocks (10–21 ms)
off the others. That's an audible flam between emitters. The renderer now
**detects mix steps itself**. A new step begins when:
- the gap since the end of the previous read exceeds a quarter block (2.7 ms); or
- a reader that already read in the current step reads again (this catches PulseAudio,
  which asks for two 512-frame steps back to back).

Every read in a step gets the same block, whatever order Godot mixes players in.
Measure the gap from the *end* of a read, or render time looks like a gap.

At 250 µs, about one step in 2,000 was split by a preempted audio thread (30 splits
and 1,470 skipped reads in 10 minutes). At a quarter block: 0 splits in 3 minutes, and
the 10-minute confirmation run is recorded below.

**1.3 Drift and glitches (48 emitters, 10 minutes):**
- 0 late steps; the worst gap between mixes was 22.5 ms (PulseAudio pairing; 32 ms
  counts as late).
- Stems stay sample-aligned by construction (see 1.2).
- 10-minute confirmation with the 2.7 ms gap: 56,250 steps and 56,250 renders,
  **0 skips**, 0 late steps, worst gap 22.5 ms, 0.52 ms of audio-thread CPU per step.
- The first run's apparent 330 ms "clock drift" was the split steps, not the
  hardware: each split rendered an extra block (30 × 10.7 ms ≈ 320 ms).

**1.4 Cost per AudioStreamPlayer3D:** about 10 µs of audio-thread CPU per emitter per
512-frame step, half of it Godot's own 3D panning. Main-thread cost is about 0.1 ms
per frame at 96 emitters.

| Emitters | Audio-thread CPU per step (mean / max) | Share of the 10.7 ms block |
| --- | --- | --- |
| 0 (driver only) | 0.03 / 0.26 ms | 0.3% |
| 16 | 0.14 / 0.36 ms | 1.3% |
| 48 | 0.53 / 1.07 ms | 4.9% |
| 96 | 1.00 / 1.68 ms | 9.3% |

**1.5 Rack cost.** stubby-music's `spike_rack` patch was ported to C++ with the same
structure (virtual modules, double-buffered 1-sample cables, a feedback loop in every
voice) and DaisySP oscillators.
- **Offline (`-O3`, 512 frames):** 4.6 ns per module-sample at 200 modules, against
  Rust's 8.8. 200 modules take 4.4% of a block and 400 take 9.1%. Finite, bounded at
  ±5 V and deterministic.
- **Inside `_mix`** (the debug extension build, 48 emitters): 200 modules add 0.66 ms
  per step (6.2% of the block, inside the 15% budget). With the stems, the total is
  1.15 ms mean and 2.05 ms max (10.8%). 400 modules total 1.82 ms (17%). 0 skips.

**1.6 Clock-to-light.** The sync point is (step's first sample, wall time of the render).
- PulseAudio renders step pairs back to back, so the raw mapping is about 5 ms off.
- A just-in-time estimator, the upper envelope of (render time − sample time) over the
  last 16 renders, maps samples to wall time within **0.07 ms median, 0.34 ms p99**.
- Flashing a light on the frame nearest each predicted tick: 5.8 ms median and 9.5 ms
  p99 error at 60 fps. That's the frame grid (a half frame is 8.3 ms); the clock isn't
  the limit.
- This measured the frame's process time, not its presentation time, which adds about
  one frame of constant offset to calibrate.
- `AudioServer.get_output_latency()` read 64 and 84 ms in two runs.
- Over 10 minutes: the device clock ran within 2 ppm of the system clock. The
  just-in-time mapping held at 0.37 ms p99 (0.76 ms max), and the light error was
  3.8 ms median and 9.2 ms p99 across 1,200 ticks.

**1.7 Pause:** with the driver at `PROCESS_MODE_ALWAYS`, the clock ran through a 3 s
pause (3.01 s advanced). At the default `PAUSABLE`, **it stopped** (0.01 s). D5's
`process_mode = ALWAYS` is required, not optional. The in-core mute fade is engine
work (4.6).

**1.8 Reload:**
- Scene reload: 20 cycles of freeing and recreating 32 stem players while the driver
  ran. 640 joins, 0 skips, renders equal steps, no crash.
- Editor hot reload: not verifiable headless (Godot checks on editor focus); check it
  manually.

**1.9 HRTF (D8): Nexus Resonance works, with two workarounds.** Nexus Resonance
(undomick/godot-nexus-resonance, MIT, v1.1.0) bundles Steam Audio 4.8.1 (Apache-2.0,
MIT-compatible with a NOTICE). Its `ResonancePlayer` extends `AudioStreamPlayer3D`
and wraps the assigned stream, so `RackStemStream` plugs in.

In our 4.8 beta it needs two workarounds:
- start players with **`play_stream()`**, because 4.8 rejects its re-bound
  `play`/`stop`/`set_stream`;
- have at least one `ResonanceGeometry` in the scene, or its spatial-output gate never
  opens.

With them, the **release binary** works:
- **16 stems:** each read exactly once per mix step, 0 skips, Steam ready.
- **Cost:** 0.42 ms per step against 0.14 ms plain, about 17 µs per HRTF emitter, so
  a top-16 tier takes about 4% of a block.
- **Binaural:** one emitter on the right gives +10.9 dB right over left, against
  +6.0 dB from Godot's panning (head shadow).

Nexus also builds from source against our 4.8 API with three small patches. Details,
the errors and the patches are in `docs/upstream/nexus-resonance-godot-4.8.md`.
Options 2 (stock 4.6) and 3 (in-core binaural) aren't needed.

**1.10 Verdict:**
- The driver-player approach holds. D1 and D4 stand, with the step-detection change
  above.
- No engine-module fallback is needed.
- D8's first option works: Nexus Resonance is the HRTF tier (`play_stream()`, plus
  scene geometry).

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
- ~~Master default tempo~~: decided, 1 BPM in 4/4, in configuration (D5).
- ~~The burbler's tempo~~: decided, a whole multiple of the master: ×40 to ×180,
  seeded per instance (D5).
- ~~Host language~~: decided, a C++ GDExtension (D1).
- **HRTF provider** (D8), decided by the spike.
- **Emitter per module:** stubby-music leaned toward VCOs, VCAs and mixers emitting by
  default, and utilities not.
- **Ranking by estimated or measured loudness:** stubby-music leaned toward measured
  stem RMS (from meters), which is one frame late.
