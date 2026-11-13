## Context

stubby-rack now has a per-sample rack, the master clock, a module registry and the
Godot classes (`add-rack-audio-engine` groups 3–5). Group 6 of that change adds the
first six modules and the definition check. This change grows the catalogue to a
real modular's breadth, east coast and west coast, plus effects and pre-baked voices.

The sources are surveyed in `docs/research/module-library.md` (2026-11-13). Every
licence there was checked from LICENSE files and per-file or per-function headers. The
rules carry over from `add-rack-audio-engine`. The game is MIT and links all module
code, so only permissive licences are allowed. The rack runs every module once per
sample, and every cable is a 1-sample delay.

**What this ports from stubby-music.** stubby-music's `add-audio-engine` planned
"oscillators, Moog/SVF/biquad filters, ADSR, noise, delays, reverb" from fundsp, and
`add-module-asset-binding` tied each module to a 3D asset. Neither shipped a library.
Here fundsp is replaced by C++ libraries (D7 of the engine change). The asset
binding becomes a `RackModuleDefinition` with a generated panel (D8 below).

## Goals / Non-Goals

**Goals:**
- About 90 module kinds covering east-coast and west-coast synthesis, modulation,
  utilities, sequencing and effects (catalogue: research §10).
- About 15 pre-baked voices as ordinary patches.
- Every module's source, licence, latency and native sample rate recorded and checked.
- Panels for all of them without hand-modelling each.

**Non-Goals:**
- Hosting third-party plugins (VST3, CLAP, LV2). See D10.
- Sampled instruments (SFZ) and large sample libraries. The sampler from group 5
  covers one-shots. A sampled-instrument change can come later.
- Game balance: which modules are found where, and their recipe costs. Only the data
  hooks are added here; the numbers come from play-testing.
- Polyphonic voice allocation (MIDI-style). Modules carry `PolyVoltage` channels where
  that's cheap (D9), but there's no voice manager.

## Decisions

**D1 — Source order unchanged; D7's DaisySP list corrected.** Sources are tried in
this order: DaisySP MIT core, Mutable Instruments STM32 code, other permissive
libraries (Signalsmith, Airwindows via airwin2rack, HetrickCV, LRTRack DSP, cycfi/q),
then Faust → C++. Hand-written code comes last. DaisySP's reverb (`ReverbSc`),
compressor and `MoogLadder` are in DaisySP-LGPL, so they aren't available. The MIT
ladder is `Filters/ladder.h` (Huovilainen model). Reverbs come from Mutable's `fx/`,
Faust and CloudSeed; the compressor from Mutable Streams. `add-rack-audio-engine`'s
D7 is amended to match.

*Rejected:* GPL sources with better DSP (Surge `sst-*`, VCV Fundamental, Bogaudio,
Befaco, Vital, ChowTape), because the licence forbids them. chowdsp_utils' DSP modules
are GPL-3; only its maths and SIMD parts are BSD. JUCE is AGPL. musicdsp.org has no
licence.

**D2 — Block-based library code runs behind a FIFO and declares its latency.**
Plaits renders 12-sample blocks, Rings 24, Clouds 32, Warps 96, Tides 2 and Stages 8.
A module wrapping one buffers its inputs and runs the library every N samples. Its
definition records `latency_samples = N`, and the rack screen shows it. A feedback
loop through such a module takes N + 1 samples.

*Rejected:*
- Calling block code with N = 1. Most of it breaks (fixed block sizes, per-block
  parameter interpolation), and the rest costs N times more.
- Leaving block-based libraries out. They're the best west-coast and modal DSP there
  is.

**D3 — Mutable code at its native rate, behind a resampler.** Clouds, Elements and
Marbles run at 32 kHz, Stages at 31.25 kHz, Tides 2 at 62.5 kHz and Warps at 96 kHz.
Each module runs at its native rate through stmlib's `SampleRateConverter` (or
Signalsmith's oversampler), as the VCV ports do. Plaits and Rings already run at
48 kHz. The native rate is recorded in the definition.

*Rejected for now:* regenerating each project's `resources.cc` at 48 kHz with its own
MIT Python scripts. It saves CPU but forks the upstream tables and needs every
project's script to run. Revisit a module only if its profile shows the resampler
dominating.

**D4 — Faust code is generated at development time, committed and licence-checked per
function.** A pinned faustlibraries commit, `faust -lang cpp -single -ftz 2`, and a
small architecture file make a plain class driven one sample at a time. A manifest
lists every library function each generated module pulls in, and
`tools/check_licences.py` rejects GPL, LGPL-without-exception, AGPL and undeclared
functions (`springreverb` and `polyblep*` stay out until upstream declares a licence).

*Rejected:* runtime libfaust or the LLVM JIT. It's large, it can't JIT on consoles or
iOS, and it would mean compiling DSP while the game runs.

**D5 — Airwindows: a curated set of about 30, each its own module.** One wrapper
class drives airwin2rack's registry (MIT; not its `src-rack` or `src-juce`, which link
GPL or AGPL hosts). Each curated algorithm is its own catalogue entry with its own
panel and recipe: tape, console, saturation, room reverbs, lo-fi and dynamics.
Airwindows seeds its dither from `rand()`, so the wrapper reseeds it from the module's
seed to keep renders deterministic.

*Rejected:* one module with a selector over all ~530. It defeats discovery (one find
would unlock everything) and puts an unreadable list in the rack screen.

**D6 — Written from scratch only where nothing permissive exists:**
- **Buchla 259 wavefolder**, after Esqueda, Pöntynen, Parker and Bilbao (DAFx-17).
  LRTRack's Lockhart and Serge folders (BSD-3) are vendored as well, because they're
  different circuits. Their GPL Lambert W is replaced with Boost.Math's (BSL-1.0) or
  a short Halley iteration of our own.
- **Low-pass gate:** Plaits' `fx/low_pass_gate.h` (MIT) first. A vactrol model after
  Parker and D'Angelo replaces it later, if Plaits' version doesn't sound right
  pinged.
- **Touch plate (218-style) and stage sequencer (248 MARF-style).** These are mostly
  UI turned into CV; nothing to reuse.
- **Trivial utilities** (attenuverter, multiple, min/max, comparator, stereo mixer,
  poly split and merge).

*Rejected for these:* Surge and VCV code with the same functions (GPL), and the
Pirkle book code (its own licence).

**D7 — Time effects follow the master clock.** Delay, tape echo, looper and LFO
rates have a synced mode whose time is a whole number of ticks of a tempo clock (a
whole multiple of the master), read from the transport like `TempoClock`. A free
mode in milliseconds or Hz remains for sound design. A synced delay repeats on the
same grid as the clocks that feed it, so the factory's patches stay composable.

*Rejected:* free-running times only. Echoes would drift off every machine's grid,
which is the drift the 1 BPM master was chosen to prevent.

**D8 — Panels are generated from definitions, in two visual families.** A Blender
generator (on `module_kit.py`) reads a definition and lays out its jacks, knobs,
switches and lights on a panel of its width in HP:
- **East coast:** black or brushed panels, 3.5 mm jacks, Moog-style knobs.
- **West coast:** colour-coded panels with banana jacks, the colours following
  signal type (audio, CV, gate), after the 200-series convention.

A definition can override placement for a hand-designed module, such as the
existing VCOs and the burbler clock. Generated panels pass the same LOD and collider
pipeline as other assets.

*Rejected:* hand-modelling about 90 panels. It would take weeks, and they'd drift
from the definitions.

**D9 — Polyphony where it's free.** Per-channel modules (VCA, mixers, filters,
wavefolders, saturation, envelopes) process every `PolyVoltage` channel.
Library-backed voices (Plaits, Rings, Elements, drums) are mono, and their
definitions say so.

*Rejected:* poly everywhere, because N copies of a block-based voice multiply its
cost.

**D10 — No plugin hosting in the shipped game.** The VST3 SDK (3.8, MIT) and CLAP
(MIT) are licence-clean now. But plugins:
- can't run on web, mobile or consoles;
- process in blocks, adding latency on every cable through them;
- may allocate, lock or crash inside our mix;
- aren't seeded or clock-locked;
- make patches non-portable between machines.

The game's breadth comes from source-level reuse instead. If wanted later, it's a
separate change: opt-in, desktop-only, CLAP first, marked non-deterministic. Building
stubby-rack *as* a CLAP plugin to audition patches in a DAW is a possible dev tool,
also out of scope.

**D11 — Voices are patches in the game repo, unlocked as recipes.** Each voice is a
`RackPatch` `.tres` under `assets/voices/<id>/`, with a README naming its path (east,
west, percussion, ambient) and the modules it uses. Recipes (`assets/recipes/*.json`)
unlock a voice. Unlocking gives a patch the player can load into a rack that has the
modules. Voices hold no special code.

*Rejected:* voices as dedicated C++ instruments. They'd be opaque, not patchable,
and not a teaching tool.

**D12 — Built in tiers.** The catalogue is too big for one pass, so tasks come in
tiers. Each tier ends with its modules, definitions, panels, tests and voices
playable:
1. The east-coast and west-coast core, enough for the Moog bass, Buchla bongo, drone
   and LPG pluck voices.
2. Modulation, utilities and sequencers.
3. Effects and the Airwindows set.
4. The rest of the catalogue, plus remaining voices.

## Risks / Trade-offs

- [Block latency on west-coast modules surprises players patching feedback] → shown on
  the panel and in the rack screen; voices avoid feedback through block modules.
- [A library's licence changes upstream, or a file's header disagrees with its repo]
  → every vendored file is pinned in THIRDPARTY.md, and the licence check reads
  per-file headers, not only LICENSE files.
- [Faust per-function licences mis-tracked] → a generated module's manifest lists
  its functions, and the check fails on any unlisted or undeclared function.
- [CPU: resamplers plus block voices] → each module gets a per-module cost benchmark
  beside the 200-module budget test. The budget stays 15% of a block for a typical
  factory.
- [Airwindows' `rand()` dither breaks bit-identical renders] → reseeded per module
  (D5); its parity tests run with dither seeded.
- [Generated panels look samey] → the two visual families, per-module overrides,
  and colour and label rules from the art style guide.
- [Catalogue sprawl dilutes discovery] → modules are recipe items; which ones appear
  in the opening is a play-test decision, not part of this change.

## Open Questions

- Which DX7 SysEx banks may ship with the 6-op voice? Plaits' built-in banks are MIT;
  third-party `.syx` files are uncertain.
- Lambert W for the Lockhart folder: Boost.Math (header-only, but pulls Boost) or our
  own Halley iteration?
- Is Plaits' low-pass gate convincing enough pinged, or is the vactrol model needed
  in tier 1?
- Which ~30 Airwindows algorithms make the curated set? Proposed from the research,
  settled by listening.
