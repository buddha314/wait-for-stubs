## Why

The rack can host modules now, but `add-rack-audio-engine` specifies only six (square
and sine VCO, clock, envelope, VCA, constant). The game's promise is a factory that
*is* a patch, so the player needs the breadth of a real modular: both synthesis
traditions (east coast: Moog-style subtractive; west coast: Buchla-style complex
oscillators, wavefolders and low-pass gates), plenty of LFOs, VCOs, VCAs, filters,
envelopes, random sources, utilities and sequencers, a VCV-Rack/VST-like catalogue
of instruments and effects, and pre-baked voices to start from. The research
(`docs/research/module-library.md`, 2026-11-13) found permissive sources for nearly
all of it, so the cost is integration, not DSP invention.

## What Changes

- **A module catalogue of about 90 kinds** in stubby-rack's registry, each with a
  `RackModuleDefinition` in the game: sources (analog VCO, complex oscillator, macro
  oscillator, FM, wavetable, noise, dust, modal and string voices, drums), filters
  and modifiers (ladder, SVF, diode ladder, K35, SEM, low-pass gate, wavefolders,
  saturation, ring mod and frequency shifter), envelopes and function generators,
  modulation (LFOs, poly LFO, smooth random, source of uncertainty, Rungler, chaos,
  sample and hold), utilities, and sequencers.
- **Effects as modules:** delay and tape echo on the master clock, reverbs (room,
  plate, huge space), chorus, flanger, phaser, overdrive, bitcrusher, compressor,
  limiter, EQ, granular, pitch shifter, looper, vocoder, and a curated set of
  Airwindows algorithms.
- **Pre-baked voices:** about fifteen `RackPatch` resources built only from the
  catalogue (Moog bass, acid line, brass, pad, drone, Buchla bongo, LPG pluck,
  west-coast lead, Benjolin chaos, drum kit, bell, wind through reeds, mudpit
  burble, bug click, tape memory). They're ordinary patches the player can open and
  change, and they're unlocked as recipes.
- **Module sourcing rules made checkable:** each definition records its source
  library, file, licence and block latency. The licence check covers every vendored
  file (Faust per function). Library code that assumes another sample rate runs
  behind a resampler.
- **Panels from data:** a generator builds each module's 3D panel from its
  definition (jacks, knobs, lights, width in HP) in an east-coast or west-coast
  visual family, so the catalogue doesn't need a hand-made model per module.
- **Correction to `add-rack-audio-engine` D7:** DaisySP's MIT core has no reverb, no
  compressor and no Csound MoogLadder (those are in DaisySP-LGPL). The MIT ladder is
  `Filters/ladder.h`. D7 is updated to say so.
- **Not included:** hosting third-party VST3, CLAP or LV2 plugins. The licences now
  allow it (the VST3 SDK and CLAP are MIT), but it breaks the realtime guarantees,
  determinism, the per-sample feedback model, patch portability and non-desktop
  export. It can be proposed later as an opt-in, desktop-only feature.

## Capabilities

### New Capabilities
- `module-catalogue`: the catalogue of synthesis modules (sources, filters and
  modifiers, envelopes and function generators, modulation and random, utilities,
  sequencers) covering east-coast and west-coast paths, and the behaviour each kind
  must show.
- `effect-modules`: effects as rack modules, including clock-synced time effects and
  the curated Airwindows set.
- `prebaked-voices`: voices shipped as patches built from catalogue modules,
  openable, editable and unlocked as recipes.
- `module-sourcing`: provenance, licence, latency and sample-rate rules for library
  DSP, enforced by checks.
- `module-panels`: module panels generated from definitions, in east-coast and
  west-coast visual families.

### Modified Capabilities
None in `openspec/specs/`. The `synth-modules` capability is still a pending change
(`add-rack-audio-engine`), so this change builds on it, and corrects its design D7,
rather than writing a delta against an archived spec.

## Impact

- **stubby-rack:** new vendored code under `thirdparty/` (more Mutable Instruments
  STM32 projects, without `test/`; airwin2rack's registry with Airwindows; HetrickCV
  DSP; Faust-generated C++ from a pinned faustlibraries commit; LRTRack's wavefolders
  with a non-GPL Lambert W). New modules under `src/core/modules/`, registry entries,
  per-module tests, and a per-function Faust licence check in
  `tools/check_licences.py`. THIRDPARTY.md gains every pin.
- **wait-for-stubs:** `assets/modules/<id>/` gets a definition `.tres` and a generated
  panel per module; `assets/voices/` holds the voice patches; recipes JSON gains
  module items and voice recipes; a panel generator joins `tools/blender/`.
- **Relies on (existing tools):** DaisySP MIT core, Mutable Instruments STM32 code and
  stmlib (resampler), Signalsmith DSP and Stretch, Airwindows via airwin2rack, Faust
  and faustlibraries, HetrickCV (CC0), LRTRack DSP (BSD-3), Boost.Math's Lambert W
  (BSL-1.0) or our own, and the existing `module_kit.py` panel helpers.
- **Written from scratch, because nothing permissive provides it:** the Buchla 259
  wavefolder (Esqueda et al.), a vactrol low-pass gate (Parker and D'Angelo),
  the touch-plate and MARF-style stage sequencers, and trivial utilities.
- **Depends on** `add-rack-audio-engine` groups 5–6 (registry, definitions, the
  definition check).
