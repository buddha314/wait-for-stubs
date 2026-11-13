# Research: a module library for stubby-rack (west coast, east coast, effects, voices)

*2026-11-13. Extends `rack-engine-reuse.md` (engine-level reuse) and
`add-rack-audio-engine` design D7 (sourcing order: DaisySP MIT core, Mutable
Instruments STM32, Faust → C++, hand-written last). This note covers the module
catalogue itself: which permissive code gives each oscillator, filter, envelope,
modulator, utility and effect, which pre-baked voices those make, and whether the
rack should host third-party VST3/CLAP plugins.*

**Method.** Licences were checked on 2026-11-13 from each repo's LICENSE file
(raw.githubusercontent / GitHub licence API), and for multi-licence repos from the
per-file or per-module headers in shallow clones (DaisySP-LGPL, pichenettes/eurorack,
faustlibraries, MoogLadders, chowdsp_utils, LRTRack, HetrickCV, airwin2rack, sndkit).
Anything marked *uncertain* was not settled by a licence file and must not be
vendored until it is.

**Licence rule** (game is MIT, code is linked): MIT, BSD, ISC, Apache-2.0, zlib,
Boost, Unlicense/CC0/public domain only. Reject GPL, LGPL, AGPL, NC, ND, SA, unknown.
Sample sets follow the same rule (CC0 / CC-BY only).

---

## 1. Corrections to what D7 assumes

D7 lists DaisySP's MIT core as giving "filters (SVF, ladder), ADSR, noise, delay,
**reverb**". Checking the vendored tree (`stubby-rack/thirdparty/daisysp/Source`) and
`electro-smith/DaisySP-LGPL`:

| DaisySP class | Where | Licence | Consequence |
| --- | --- | --- | --- |
| `ReverbSc` (Costello reverb from Csound) | DaisySP-LGPL | LGPL | **No reverb in the MIT core.** Reverb must come from Mutable (Clouds/Rings/Elements/Beads `fx/reverb.h`), Faust `reverbs.lib` or CloudSeed. |
| `Compressor`, `Balance` | DaisySP-LGPL | LGPL | **No compressor in the MIT core.** Faust's compressors are mostly GPL too (§4); use Mutable Streams or Airwindows. |
| `MoogLadder` (Csound `moogladder`, Huovilainen) | DaisySP-LGPL | LGPL | Use MIT `Filters/ladder.h` instead: Richard van Hoesel's Huovilainen "HNM" model (Teensy Audio Library), 4× oversampled, LP/BP/HP modes, MIT. |
| `Bitcrush`, `Fold`, `Tone`, `ATone`, `Biquad`, `Comb`, `Allpass`, `Mode`, `NlFilt`, `Pluck`, `PolyPluck`, `BlOsc`, `Line`, `Port`, `Jitter` | DaisySP-LGPL | LGPL | MIT substitutes: `Decimator` (bitcrush + downsample), `Wavefolder`, `OnePole`, `Svf`/`Soap`, `Resonator`/`ModalVoice`, `StringVoice`/`KarplusString`, `Oscillator` (polyBLEP); slew = Signalsmith or hand-written one-pole. |

Everything in `daisysp.h` outside `#ifdef USE_DAISYSP_LGPL` is MIT (verified header
by header for ladder.h, which carries its own MIT notice).

Mutable Instruments: the eurorack README says "Code (AVR projects): GPL3.0. Code
(STM32F projects): MIT". Per-file headers confirm it, with two traps:

- **Every STM32 project's `test/` folder is GPL-3** (`plaits/test/plaits_test.cc`,
  `rings/test/rings_test.cc`, `marbles/test/*`, `stages/test/*`, `tides2/test/*`,
  `braids/test/braids_test.cc`, `elements/test/elements_test.cc`,
  `peaks/test/peaks_test.cc`). Never vendor `test/`.
- **Grids, Edges, Branches** (and `avrlib*`) are AVR, GPL-3. So the famous Grids
  drum-pattern generator is out; a pattern sequencer must come from elsewhere (§7).

---

## 2. Licence verdicts (verified)

### Usable

| Library | Licence (verified) | What it gives us | Notes |
| --- | --- | --- | --- |
| [DaisySP](https://github.com/electro-smith/DaisySP) core | MIT | see §1 and catalogue | Already vendored. |
| [pichenettes/eurorack](https://github.com/pichenettes/eurorack) STM32 projects | MIT | Plaits, Rings, Clouds (vendored); **Braids, Elements, Warps, Tides 2, Stages, Marbles, Peaks, Streams, Beads, Frames, Yarns** (not yet) | Exclude `test/` and AVR projects. Trademark: don't call modules "Mutable Instruments". |
| [stmlib](https://github.com/pichenettes/stmlib) | MIT | `dsp/polyblep.h`, `filter.h` (Svf, OnePole), `sample_rate_converter.h`, `limiter.h`, `hysteresis_quantizer.h` | Already vendored. |
| [Signalsmith DSP](https://github.com/Signalsmith-Audio/dsp) | MIT | delays, biquad designs, FFT, oversampling, `envelopes.h` (CubicLfo, box filters) | Already vendored. |
| [Signalsmith Stretch](https://github.com/Signalsmith-Audio/signalsmith-stretch) | MIT | high-quality pitch shift / time stretch | Block-based, ~100 ms latency at default settings; fine for an effect. |
| [Airwindows](https://github.com/airwindows/airwindows) | MIT | ~530 effects (536 `*Proc.cpp` in airwin2rack): reverbs, consoles, tape, saturation, EQ, dynamics, lo-fi | Use via [airwin2rack](https://github.com/baconpaul/airwin2rack) `src/` + `libs/airwindows` (MIT; README: "fine to use in closed source", link `airwin-registry`). Its `src-rack` links VCV (GPL): don't use that part. |
| [Faust libraries](https://github.com/grame-cncm/faustlibraries) | **per function** (§4) | VA filters, reverbs, phasers, WDF, ADAA nonlinearities | Many functions MIT or STK-4.3 (MIT-style); some GPL/LGPL/AGPL. |
| [cycfi/q](https://github.com/cycfi/q) | MIT | polyBLEP oscillators, biquads, compressor/expander/agc, envelope followers, **pitch detection** | Pitch detection is useful for the field recorder too. |
| [STK](https://github.com/thestk/stk) | MIT-style (non-binding "send changes" request) | physical models (Clarinet, Flute, Bowed, Mandolin, ModalBar, BandedWG, Shakers, Sitar, VoicForm), FM instruments (Rhodey, Wurley, TubeBell, BeeThree), JCRev/NRev/PRCRev/FreeVerb, PitShift, Granulate | Older code; allocates in constructors (fine off-thread); `rawwaves/` ship under the same licence. |
| [Gamma](https://github.com/LancePutnam/Gamma) | MIT | oscillators, filters, FreqShift, Chorus, spectral tools | Secondary. |
| [CloudSeed](https://github.com/ValdemarOrn/CloudSeed) | MIT | algorithmic reverb (huge, lush); C++ AudioLib in repo | Block-based; good "pad space" reverb. |
| [chowdsp_wdf](https://github.com/Chowdhury-DSP/chowdsp_wdf) | BSD-3 | wave-digital-filter toolkit (diode clippers, tone stacks) | Header-only. |
| chowdsp_utils `chowdsp_core`, `chowdsp_math`, `chowdsp_simd`, `chowdsp_buffers` | BSD-3 | maths, SIMD | **All DSP modules (`filters`, `eq`, `compressor`, `reverb`, `waveshapers`, `sources`, `modal_dsp`, `dsp_utils`) are GPL-3.** Reject those. |
| [MoogLadders](https://github.com/ddiakopoulos/MoogLadders) (some files) | Unlicense repo; per-file provenance | `StilsonModel.h`, `KrajeskiModel.h` (public domain by author email), `MicrotrackerModel.h` (Unlicense), `ImprovedModel.h` (D'Angelo, ISC-style), `RKSimulationModel.h` (Puckette, BSD-style), `HyperionModel.h` (PD) | **Reject** `HuovilainenModel.h` (from Csound, LGPL), `MusicDSPModel.h` (unknown, maybe CC-BY-SA), `OberheimVariationModel.h` (Pirkle book licence), `SimplifiedModel.h` (DAFX book, unclear). |
| [LRTRack](https://github.com/lindenbergresearch/LRTRack) `src/dsp` | BSD-3 | **Lockhart and Serge wavefolders** (Esqueda et al. models), MS-20 ZDF, Korg35 (`Type35Filter`), diode ladder, ladder, BBD device, saturators | `LambertW.{h,cpp}` and `Horner.h` are **GPL-3** (Veberic). Lockhart.cpp depends on them, so replace Lambert W with a permissive one (Boost.Math `lambert_w`, BSL-1.0, or a Halley iteration we write). Module code links the VCV API: port DSP only. |
| [HetrickCV](https://github.com/mhetrick/hetrickcv) | CC0-1.0 (LICENSE.txt and plugin.json) | **Rungler** (Benjolin), chaos maps, Crackle, Dust, random gates, binary/boolean logic, shift registers, phasor toolkit (Euclidean, swing, probability, burst) | Vendors Gamma (MIT). Strip VCV API. Best permissive source of "source of uncertainty" utilities. |
| [ML_modules](https://github.com/martin-lueders/ML_modules) | BSD-3 | sequencer, quantizer, shift register, S&H, trigger utilities | VCV module code: port logic. |
| [JW-Modules](https://github.com/jeremywen/JW-Modules) | BSD-3 | grid sequencers, NoteSeq (Life-style), quantizer, clocks | Port logic. |
| [southpole-vcvrack](https://github.com/gbrandt1/southpole-vcvrack) | MIT | VCV wrappers around Mutable code | Reference for how others drove MI DSP per-sample/blocks. |
| [sndkit](https://github.com/PaulBatchelor/sndkit) | CC0 docs; code MIT or Unlicense | `valp1` (Zavalishin VA lowpass), `vardelay`, `chorus`, `peakeq`, `modalres`, `tract` (vocal tract), `chaosnoise`, `euclid`, `bigverb` | *Uncertain:* `bigverb` reimplements Costello's reverbsc topology and tunings, whose Csound code is LGPL; avoid it. |
| [msfa](https://github.com/google/music-synthesizer-for-android) | Apache-2.0 | DX7 engine (the core Dexed grew from) | Plaits `six_op_engine` (MIT) already loads DX7 patches; msfa only if we want a full 16-voice DX. Apache needs the NOTICE carried. |
| [CMSIS-DSP](https://github.com/ARM-software/CMSIS-DSP) | Apache-2.0 | biquad cascades, FIR, FFT | Low value on desktop; skip. |
| [Maximilian](https://github.com/micknoise/Maximilian) | MIT | teaching-grade oscillators/filters | Skip; others are better. |
| [synth-plugin-book](https://github.com/hollance/synth-plugin-book) | MIT | Kellett's MDA JX10 clone, explained | Reference for a polyphonic "VST-like" subtractive voice. |
| [sfizz](https://github.com/sfztools/sfizz) | BSD-2 | SFZ sample player | Only if sampled instruments arrive; check its submodule licences first (*uncertain*). |
| [Vult](https://github.com/modlfo/vult) compiler | MIT | DSP language → C++ | Not needed (Faust covers it). VultModules has **no licence** (and is commercial): reject. |

### Rejected

| Library | Licence (verified) | Note |
| --- | --- | --- |
| DaisySP-LGPL | LGPL | §1. |
| Surge XT, `sst-filters`, `sst-basic-blocks`, `sst-effects`, `sst-waveshapers` | GPL-3 (repo LICENSE) | Excellent filters (Cytomic SVF, OB-Xd, K35, diode) but unusable. Read papers instead. |
| VCV Fundamental, Befaco, Bogaudio, AudibleInstruments | GPL-3 (LICENSE.md: "All source code … GPL") | Behaviour reference only. AudibleInstruments wraps MIT Mutable code, so go to eurorack directly. |
| Vital | GPL-3 | |
| ChowTapeModel (AnalogTapeModel) | GPL-3 | Tape: use Airwindows ToTape / IronOxide instead. |
| chowdsp_utils DSP modules | GPL-3 per module header | §2 above. |
| JUCE (incl. `juce_dsp`) | AGPLv3 / commercial (JUCE 9 EULA) | |
| ykchorus | GPL | |
| SoundpipeAudioKit | MIT on the repo, **but** Soundpipe modules ported from Csound (moogladder, reverbsc, etc.) carry LGPL heritage, which is why DaisySP split them out | *Uncertain* per module; avoid. |
| musicdsp.org | **No licence** (site footer "© 2019, Too many to list") | Read for ideas; never paste. |
| Will Pirkle book code / ASPiK | custom book licence (forum terms), repo not found | Reference only; his free app notes (Korg35, Moog, diode ladder, SEM) are papers. |
| Faust GPL/LGPL/AGPL functions | §4 | |

---

## 3. Integration notes for library DSP in a per-sample rack

1. **Block-based DSP adds latency, not breakage.** Plaits renders 12-sample blocks
   (max 24), Rings 24, Clouds 32, Elements 16, Warps 96, Tides 2 and Stages 8, Marbles
   5/8. In a per-sample rack, a module wraps the library with an input FIFO and runs
   it every N samples, so the module adds N samples of latency. A feedback loop
   through it is N + 1 samples, not 1. Record each module's latency in its
   definition. DaisySP, Faust-generated code, Signalsmith filters and Airwindows
   (`processReplacing` with `sampleFrames = 1` works, at some per-call cost) are
   genuinely per-sample.
2. **Hard-coded sample rates.** Several Mutable projects bake their rate into
   coefficient tables: Clouds and Elements 32 kHz, Stages 31.25 kHz, Tides 2
   62.5 kHz, Marbles 32 kHz, Warps 96 kHz (block 96). At 48 kHz they play
   detuned or with wrong time constants. Either run them at their native rate
   behind stmlib's `SampleRateConverter`/Signalsmith oversampling (cleanest; the VCV
   ports do this), or regenerate the `resources.cc` tables at 48 kHz with the
   project's own `resources/` Python scripts (MIT). Plaits and Rings already run at
   48 kHz.
3. **Fixed-point/int16 I/O.** Clouds, Beads and Elements take `ShortFrame`/int16 or
   float buffers with ±1 scaling. Convert at the module boundary to VCV volts
   (±5 V audio ⇒ ÷5).
4. **Realtime rules.** Mutable and DaisySP never allocate after `Init`. Clouds,
   Beads and Rings need a caller-supplied buffer (Clouds' firmware passes 118,784 B +
65,408 B, `clouds/clouds.cc`):
   allocate it when the module is built off-thread. STK and CloudSeed allocate in
   constructors and some setters: call those off-thread only, and audit setters
   before exposing them as knobs. Airwindows constructors call global `rand()` to seed
   dither (`fpdL`); harmless to timing but breaks bit-determinism across runs. Seed
   it from `WorldSeed` if parity tests need it.
5. **Faust code generation.** Generate with `faust -lang cpp -single -ftz 2` (or
   `-double`) into a plain class with `compute(count, in, out)`, call it with
   `count = 1` or a small block, and use our own architecture wrapper. The Faust
   compiler's own licence doesn't reach generated code, but the **library functions
   compiled in do** (§4), so pin the faustlibraries commit and keep a list of every
   function each generated module pulls in.

---

## 4. Faust libraries: licence per file and per function

`faustlibraries` declares a licence **per function** (`declare <fn> license "…"`),
and per section in comment headers for functions without one. Counted at the current
master:

- **Permissive:** `MIT`; `LicenseRef-STK-4.3` (the STK 4.3 licence: MIT text plus a
  non-binding request to send changes, which is permissive); `ISC`; `BSD-3-Clause`.
- **Usable for generated code:** `LicenseRef-LGPL-2.1-or-later-with-Faust-exception`
  (the "GRAME section"). The exception says: "you may create a larger FAUST program
  which directly or indirectly imports this library file and still distribute the
  compiled code generated by the FAUST compiler … under your own copyright and
  license." So generated C++ is fine; copying the `.lib` text into our repo is
  not needed and not done.
- **Reject:** `GPL-3.0-only`, `GPL-2.0-or-later`, `AGPL-3.0-only`, `LGPL-2.1-only`,
  `LGPL-3.0-only`, and plain `LGPL-2.1-or-later` without the exception.

| File | Declared licences | Non-permissive functions (avoid) | Useful permissive functions |
| --- | --- | --- | --- |
| `aanl.lib` | 37 MIT | none | ADAA hard/soft clip, tanh, arctan, cubic (Parker–Zavalishin–Le Bivic): antialiased saturation and folding |
| `vaeffects.lib` | 20 STK, 10 MIT, 1 BSD-3 | none (vocoder: GRAME section) | `moog_vcf`, `moog_vcf_2b`, `moogLadder`, `moogHalfLadder`, `diodeLadder`, `korg35LPF/HPF`, `oberheim*` (SEM SVF), `sallenKey*`, `lowpassLadder4` (MIT), `wah4`, `crybaby`, `mxrPhase90` (MIT), `fulltoneOCD` (MIT), `klonCentaur` (BSD-3) |
| `filters.lib` | 120 STK, 27 MIT, 1 ISC, 1 LGPL+exc | none | `svf` (Nesterov, STK), `resonlp/hp/bp`, `lowpass`/`highpass` (Butterworth), `peak_eq`, `low_shelf`, `high_shelf`, `tf2s`, `allpass_comb`, `fb_comb` |
| `reverbs.lib` | 2 STK, 3 MIT, 2 GPL-3; JOS section STK-4.3; GRAME section LGPL+exc; "further contributions" section | **`vital_rev`, `kb_rom_rev1` (GPL-3)**; `springreverb` (Leonov) has **no declaration**: *uncertain*, check `git blame`/ask | `zita_rev1_stereo`, `jcrev`, `satrev`, `fdnrev0` (JOS section, STK-4.3); `dattorro_rev` (STK); `jpverb`, `greyhole`, `valhallaSupermassive` (MIT); `mono/stereo_freeverb` (GRAME LGPL+exc, OK for generated code) |
| `phaflangers.lib` | JOS section STK-4.3; GRAME section | none | `flanger_mono/stereo`, `phaser2_mono/stereo` |
| `misceffects.lib` | 13 STK, 8 MIT; file header LGPL+exc | none declared | `cubicnl`, `gate_mono/stereo`, `transpose` (pitch shift), `echo`, `wavefold` (Braun) |
| `compressors.lib` | **24 GPL-3**, 6 STK, 1 MIT | **all `*_N_chan`, FF/FB/FBFF compressors, `limiter_lad_*`, expanders (GPL-3)** | only the non-GPL `compressor_mono/stereo`, `compressor_lad_mono`, `limiter_1176_R4_mono/stereo`, `xfer_ott` |
| `oscillators.lib` | 25 STK, 2 LGPL+exc; JOS section STK; GRAME; "further contributions" | `polyblep*`, `dsf`, `twin_osc`, `hs_*` have **no declaration** (contributions section): *uncertain* | `sawN`, `squareN`, `triangleN` (DPW, STK), `lf_*` (STK) |
| `envelopes.lib` | 10 STK; file LGPL+exc | none | `adsr`, `ar`, `asr`, `adsre`, `dx7envelope` |
| `noises.lib` | 6 MIT, 1 STK | none | `pink_noise`, `lfnoise`, `sparse_noise`, `noise` |
| `wdmodels.lib` | 48 STK | none | WDF diodes, op-amp clippers (tube screamer-style) |
| `physmodels.lib`, `instruments.lib` | GRAME LGPL+exc / STK | none declared GPL | waveguide strings, `fof` formant voice, modal bars |
| `delays.lib`, `maths.lib`, `fastmath.lib`, `maxmsp.lib`, `reducemaps.lib`, `webaudio.lib` | LGPL+exc (file) | none | `fdelay*` fractional delays |
| `basics.lib` | 4 MIT, 4 STK, 5 GPL-3, 2 AGPL-3 | **`parallelOp/Max/Min/Mean/RMS` (GPL-3), `processArray`, `tabulateNd` (AGPL-3)** | everything else |
| `interpolators.lib` | 19 MIT, 2 LGPL-3 | **`frdtable`, `frwtable` (LGPL-3)** | others |
| `hysteresis.lib` | 5 LGPL-2.1-only | **all** (Jiles–Atherton tape/transformer) | none |
| `tonestacks.lib` | LGPL-2.1-or-later (no exception) | **all** | none |
| `pinktrombone.lib` | 12 MIT | none | vocal tract |
| `demos.lib` | mixed | **`greyhole_demo`, `jprev_demo` (GPL-2+), `vital_rev_demo`, `kb_rom_rev1_demo` (GPL-3), `freeverb_demo`, `vocoder_demo` (LGPL-2.1+, no exception), `ja_transformer_demo` (LGPL-2.1)** | Use the underlying functions (e.g. `re.greyhole`, MIT), never the `*_demo` wrappers. `zita_rev1` demo is MIT. |

**Rule for Faust modules:** each module's `.dsp` names the library functions it
calls; a check script resolves them (including what those functions call) against
the pinned faustlibraries and fails on any function in the reject list above. The
compressors.lib functions that are *not* GPL-3 are exactly `compressor_mono`,
`compressor_stereo`, `compressor_lad_mono`, `compression_gain_mono`,
`limiter_1176_R4_mono/stereo` and `xfer_ott`; check what each one calls before use.

---

## 5. Sources by synthesis path

### 5.1 East coast (Moog-style subtractive)

| Need | Best source | Alternatives | Notes |
| --- | --- | --- | --- |
| VCO (saw/square/tri/sine, PWM, sync) | Plaits `oscillator/variable_shape_oscillator.h` + `variable_saw_oscillator.h` (MIT; polyBLEP, hard sync, continuous shape) | DaisySP `Oscillator` (polyBLEP saw/square/tri), `VariableShapeOscillator`, `VariableSawOscillator`; Braids `analog_oscillator` (MIT) | Plaits' are per-sample inside a block loop; they run fine with block = 1. |
| Supersaw / detuned stack | Braids `digital_oscillator` (CSAW, SAW_SWARM) / Plaits `swarm_engine` | DaisySP `OscillatorBank` (string-machine divide-down) | |
| Ladder filter (24 dB, resonance, drive) | DaisySP `Filters/ladder.h` (MIT, Huovilainen HNM, 4× OS, LP/BP/HP) | Faust `ve.moogLadder` / `moog_vcf_2bn` (STK); MoogLadders `ImprovedModel.h` (D'Angelo–Välimäki), `KrajeskiModel.h` | Our "Moog" voice filter. |
| Other VCFs | Faust `ve.diodeLadder` (TB-303), `korg35LPF/HPF` (MS-20), `oberheim*` (SEM) | LRTRack `MS20zdf`, `DiodeLadder`, `Type35Filter` (BSD-3) | Three flavours are enough for variety. |
| ADSR | DaisySP `Control/adsr.h` (MIT) | Faust `en.adsr` (LGPL+exc), Peaks `multistage_envelope` | Our own Envelope (spec) stays for the AD case. |
| VCA (linear/exponential) | hand-written (two lines) | Streams `gain` (MIT) | Already in `basic.h`. |
| Mixer | hand-written (`Mix4` exists) | | |
| Noise (white/pink/brown) | DaisySP `WhiteNoise`, `FractalRandomGenerator`; Faust `no.pink_noise` (MIT) | Plaits `noise/` | |
| Sample & hold, slew | DaisySP `SampleHold`; Signalsmith/stmlib one-pole for slew | HetrickCV `HCVSlewLimiter.h` (CC0) | |
| Glide/portamento | stmlib `OnePole`/`Slope` | | |
| Ring mod / cross-mod | Warps `modulator` (MIT, analog ring-mod models, XOR, compare, vocoder) | | Warps runs at 96 kHz/96-sample blocks: §3. |

### 5.2 West coast (Buchla-style)

| Buchla idea | Best source | Alternatives | Notes |
| --- | --- | --- | --- |
| **Complex oscillator** (259: principal + modulation osc, FM/AM, timbre, symmetry) | Compose: Plaits `sine_oscillator` + `fm_engine` (2-op through-zero-ish) and `waveshaping_engine` (triangle → waveshaper → **wavefolder**), DaisySP `Fm2` | Plaits `phase_distortion_engine` (engine2) | A `ComplexOsc` module wiring two Plaits sine oscillators, FM/AM index, and the folder below. Mostly composition, little new DSP. |
| **Wavefolder / timbre** | LRTRack `Lockhart.cpp` and `Serge.cpp` (BSD-3; Esqueda et al. models, ADAA) **with a non-GPL Lambert W** | DaisySP `Wavefolder` (MIT, simple); Faust `ef.wavefold` (Braun), `aanl.lib` ADAA folders (MIT); Plaits `waveshaping_engine` tables | Buchla 259 folder: implement from Esqueda–Pöntynen–Välimäki–Parker DAFx-17 (paper), 5 parallel folding stages with ADAA. That paper is the gap; LRT gives Lockhart/Serge only. |
| **Low-pass gate with vactrol** (292) | Plaits `fx/low_pass_gate.h` + `envelope.h` `LPGEnvelope` (MIT): Emilie's vactrol-ish LPG used in Plaits' internal LPG | Streams `vactrol.h`, `filter_controller.h`, `follower.h` (MIT): Streams' "vactrol" and "LPG" modes | Parker & D'Angelo DAFx-13 for a fuller model (nonlinear vactrol with asymmetric attack/decay, filter and VCA from one control). Start with Plaits' LPG (cheap, proven), upgrade later. |
| **Function generator** (281, Serge DUSG) | Tides 2 `poly_slope_generator.h`, `ramp_shaper.h` (MIT): AD/AR/looping, shape, slope, smoothness, 4 outputs | Stages `segment_generator.h` (MIT; chainable segments, rise/fall/hold, loop), Peaks `multistage_envelope` | Tides 2 is the closest thing to a 281/DUSG. Runs at 62.5 kHz: §3. |
| **Source of uncertainty** (266: fluctuating/quantized random, stored random, noise) | Marbles `random/` (MIT): `t_generator` (random gates, Bernoulli/clusters/drums), `x_y_generator`, `output_channel` (spread, bias, steps, quantizer), `random_sequence` (déjà vu loop) | DaisySP `SmoothRandomGenerator`, `ClockedNoise`, `Dust`, `Particle`; HetrickCV `Rungler.cpp`, `RandomGates`, `Crackle`, `ChaoticAttractors`, `HCVRandom.h` (CC0) | Seed every one from `WorldSeed` (the game rule). Marbles' generator is seedable. |
| **Touch-plate sequencing** (218 keyboard, 245/246/248 sequencers, "pressure + position") | Hand-written: a `TouchPlate` module (N plates → gate, pressure CV, position CV, pitch CV) fed by the rack screen | Peaks `mini_sequencer` (MIT); ML_modules / JW-Modules sequencers (BSD-3) | No DSP to reuse: it's UI → CV. The 248 MARF (stage time per step, sustain/enable/stop flags) is a small state machine; write it. |
| **Bongo / Buchla pluck** | LPG pinging: a short trigger into Plaits LPG on a sine/folded tone | Rings `resonator` (modal), DaisySP `ModalVoice` | See voices §9. |
| **Balanced modulator / frequency shifter** | Warps (`quadrature_transform.h`, frequency shifter mode, MIT) | Gamma `FreqShift` (MIT) | |

### 5.3 Modulation, LFOs, random

| Module | Source |
| --- | --- |
| LFO (sine/tri/saw/square/S&H, phase, sync) | DaisySP `Oscillator` at sub-audio rate; Peaks `lfo.h` (MIT); Signalsmith `CubicLfo` (smooth random LFO) |
| Quad/poly LFO | Frames `poly_lfo.h` (MIT) |
| Chaotic LFO | Streams `lorenz_generator.h` (MIT); HetrickCV `ChaoticAttractors`, `Chaos1/2/3Op` (CC0) |
| Bouncing ball | Peaks `bouncing_ball.h` (MIT) |
| Random / S&H / Turing-style | Marbles; DaisySP `SampleHold`, `MayTrig`; HetrickCV `HCVShiftRegister.h`, `Rungler` (CC0) |
| Keyframer / scanner | Frames `keyframer.h` (MIT); HetrickCV `Scanner` (CC0) |
| Envelope follower | Streams `follower.h` (MIT); cycfi/q `envelope_follower` (MIT) |

### 5.4 Utilities

Mostly hand-written (each is a few lines and pure VCV convention): attenuverter,
offset, mixer (mono/stereo, CV pan), multiple, crossfader (DaisySP `CrossFade`),
min/max, comparator, logic (HetrickCV `Boolean3`, `LogicCombine`, `FlipFlop`, CC0),
clock divider/multiplier (on the master grid; HetrickCV phasor tools as reference),
quantizer (Braids `quantizer.h` + `quantizer_scales.h`, MIT; Marbles quantizer),
slew limiter, DC blocker (DaisySP `DcBlock`), precision adder, gate delay, trigger
→ gate, sequential switch, scope/meter (UI only), polyphonic split/merge (core).

### 5.5 Effects

| Effect | First choice | Others | Notes |
| --- | --- | --- | --- |
| Delay / echo | Signalsmith `delay.h` (MIT) + DaisySP `DelayLine` | Airwindows `PurestEcho`, `TapeDelay2`; Beads `multitap_delay` | Clock-synced delay times come from the master clock (tempo multiples). |
| Tape delay / wow & flutter | Beads `fx/wow_and_flutter.h` (MIT) + Signalsmith delay | Airwindows `ToTape6/8`, `IronOxide5`, `TapeDust` | ChowTape rejected (GPL). |
| Reverb (plate/hall) | Faust `re.zita_rev1_stereo` (STK) or `re.dattorro_rev` (STK) | Clouds/Rings/Elements `fx/reverb.h` (MIT, small Griesinger-style); Faust `re.jpverb`, `re.greyhole` (MIT); CloudSeed (MIT); Airwindows `Galactic`, `Verbity`, `kCathedral` etc.; STK `NRev`/`FreeVerb` | **The desert's own echoes (mountains at 2R/c) are rack delays, not a reverb.** |
| Spring reverb | Faust `re.springreverb` (*uncertain licence*) | Airwindows reverbs | Resolve licence before use. |
| Chorus / ensemble | DaisySP `Chorus` | Rings/Plaits `fx/ensemble.h` (MIT, string ensemble), Faust | |
| Flanger | DaisySP `Flanger` | Faust `pf.flanger_stereo` | |
| Phaser | DaisySP `Phaser` | Faust `pf.phaser2_stereo`, `ve.mxrPhase90` (MIT) | |
| Distortion / saturation | Faust `aanl.lib` ADAA (MIT); DaisySP `Overdrive`; Plaits `fx/overdrive.h` | Airwindows (`Density`, `Tube2`, `Console*`), Faust `fulltoneOCD`, `klonCentaur`, `wdmodels.lib` | Use ADAA or oversampling (Signalsmith `rates.h`) for anything hot. |
| Bitcrush / sample-rate reduce | DaisySP `Decimator`, `SampleRateReducer` | Plaits `fx/sample_rate_reducer.h`, Airwindows `DeRez2`, `BitShiftGain` | |
| Compressor / limiter | Streams `compressor.h` (MIT) | Airwindows `Pressure4`, `ButterComp2`, `Pop2`; cycfi/q `compressor`; DaisySP `Limiter`; stmlib `limiter.h` | DaisySP compressor (LGPL) and Faust FF/FB compressors (GPL-3) rejected. |
| EQ | Signalsmith `filters.h` biquads (RBJ cookbook designs) | Faust `fi.peak_eq`, shelves; Airwindows `Baxandall`, `Pear` | |
| Granular | Clouds `granular_processor` (MIT) | Beads (MIT, newer, 48 kHz-ish), DaisySP `GranularPlayer` | |
| Pitch shift | Signalsmith Stretch (MIT, quality) | DaisySP `PitchShifter`, Clouds `fx/pitch_shifter.h`, Faust `ef.transpose`, STK `PitShift` | |
| Looper | DaisySP `Looper` | Clouds looping-delay mode | |
| Vocoder | Warps `vocoder.h` (MIT) | Faust `ve.vocoder` (GRAME, LGPL+exc) | |
| Auto-wah / tremolo | DaisySP `Autowah`, `Tremolo` | Faust `ve.crybaby`, `wah4` | |
| Spectral freeze / textures | Clouds spectral mode (MIT) | Signalsmith `spectral.h` | |

### 5.6 Voices, physical models and drums ("VST instruments")

| Instrument | Source |
| --- | --- |
| Macro oscillator (16+ models) | Plaits `voice.cc` (whole module) and Braids `macro_oscillator` (MIT) |
| DX7-style 6-op FM | Plaits `six_op_engine` (MIT, reads DX7 SysEx banks) |
| String machine / Solina | Plaits `string_machine_engine` (engine2, **not yet vendored**) + `fx/ensemble.h` |
| Wave terrain, VA VCF engine, chiptune | Plaits engine2 (`wave_terrain_engine`, `virtual_analog_vcf_engine` not yet vendored; `chiptune_engine` vendored) |
| Modal / string resonator | Rings (MIT), Elements (MIT; bow, blow, strike exciters into a modal resonator), DaisySP `ModalVoice`, `StringVoice`, `Resonator`, `KarplusString`, `Drip` |
| Wind / bowed / plucked waveguides | STK `Clarinet`, `Flute`, `Bowed`, `Mandolin`, `Sitar`, `BlowBotl` (MIT-style); Faust `physmodels.lib` |
| Voice / speech | Plaits `speech_engine` (LPC, SAM-style, formant); Faust `pinktrombone.lib` (MIT); sndkit `tract` |
| Drums | Plaits `drums/` (analog/synthetic bass and snare, hi-hat), DaisySP `Drums/`, Peaks `drums/` (FM drum, MIT) |

---

## 6. Papers and references (algorithms; implementations are ours)

All are papers or freely distributed notes: we read them and write our own code.

- T. Stilson, J. O. Smith, "Analyzing the Moog VCF with Considerations for Digital
  Implementation," ICMC 1996. <https://ccrma.stanford.edu/~stilti/papers/moogvcf.pdf>
- A. Huovilainen, "Non-linear digital implementation of the Moog ladder filter,"
  DAFx-04, Naples. (DaisySP `ladder.h` implements the 2006 CMJ form below.)
- V. Välimäki, A. Huovilainen, "Oscillator and Filter Algorithms for Virtual Analog
  Synthesis," Computer Music Journal 30(2), 2006.
- S. D'Angelo, V. Välimäki, "An improved virtual analog model of the Moog ladder
  filter," ICASSP 2013. (MoogLadders `ImprovedModel.h`.)
- V. Zavalishin, *The Art of VA Filter Design*, rev. 2.1.2, Native Instruments, 2020
  (free PDF). <https://www.native-instruments.com/fileadmin/ni_media/downloads/pdf/VAFilterDesign_2.1.2.pdf>
  ZDF/TPT ladder, SVF, diode ladder, Sallen-Key, MS-20.
- A. Simper (Cytomic), technical papers on trapezoidal SVF and other filters.
  <https://cytomic.com/technical-papers/>
- J. Parker, S. D'Angelo, "A Digital Model of the Buchla Lowpass-Gate," DAFx-13,
  Maynooth. Vactrol plus 292 circuit.
- F. Esqueda, H. Pöntynen, V. Välimäki, J. Parker, "Virtual Analog Buchla 259
  Wavefolder," DAFx-17, Edinburgh.
- F. Esqueda, H. Pöntynen, J. Parker, S. Bilbao, "Virtual Analog Models of the
  Lockhart and Serge Wavefolders," *Applied Sciences* 7(12), 2017 (open access).
- J. Parker, V. Zavalishin, E. Le Bivic, "Reducing the aliasing of nonlinear
  waveshaping using continuous-time convolution," DAFx-16 (ADAA; Faust `aanl.lib`).
- D. Giannoulis, M. Massberg, J. Reiss, "Digital Dynamic Range Compressor Design —
  A Tutorial and Analysis," JAES 60(6), 2012.
- J. Dattorro, "Effect Design, Part 1: Reverberator and Other Filters," JAES 45(9),
  1997.
- R. Bristow-Johnson, *Audio EQ Cookbook* (W3C Note). <https://www.w3.org/TR/audio-eq-cookbook/>
- W. Pirkle, app notes on Korg35, Moog ladder, diode ladder and SEM filters
  (free PDFs on willpirkle.com); his books' code is *not* under a standard licence.

*Remaining gap:* no permissive implementation of the **Buchla 259 folder** or a
**full Parker–D'Angelo LPG**. Both are well specified in the papers; they're the
two hand-written DSP modules this catalogue needs, and both fit D7's "hand-written
last" rule because nothing permissive provides them.

---

## 7. Sequencing

- **Clock-locked sequencers are ours.** Every sequencer steps on master-clock ticks
  (CLAUDE.md: the rack's sample counter is the clock). Port logic, not timing, from:
  ML_modules (BSD-3: 8-step sequencer, shift register, quantizer), JW-Modules (BSD-3:
  grid sequencer, NoteSeq cellular sequencer), HetrickCV (CC0: `PhasorEuclidean`,
  `PhasorProbability`, `PhasorSwing`, `PhaseDrivenSequencer`, `Rungler`), Peaks
  `mini_sequencer` (MIT), Marbles `t_generator` (MIT: random/drum gate patterns).
- **Drum patterns:** Grids is GPL (AVR). Use Euclidean (HetrickCV, sndkit `euclid`,
  both permissive) plus Marbles' "drums" t-mode.
- **Touch plates and MARF:** hand-written (§5.2).
- **Arpeggiator:** Plaits `engine2/arpeggiator.h` (MIT, vendored) and Yarns (MIT).

---

## 8. Sample sets (for samplers, drum hits, convolution)

| Set | Licence (verified) | Verdict |
| --- | --- | --- |
| [VCSL](https://github.com/sgossner/VCSL) (Versilian Community Sample Library) | CC0-1.0 | **Use.** Orchestral, percussion, ethnic, keys. |
| karoryfer.meatbass, karoryfer.big-rusty-drums, virtuosity_drums, Dsmolken.double-bass ([sfzinstruments](https://github.com/sfzinstruments)) | CC0-1.0 | **Use.** |
| SalamanderGrandPiano (sfzinstruments) | CC-BY 3.0 | Usable with attribution (BY only). |
| jlearman.jRhodes3d | samples CC BY-NC 4.0 | **Reject** (NC). |
| tidalcycles/Dirt-Samples | no clear licence | **Reject** (unknown). |
| Sonatina Symphonic Orchestra | CC Sampling Plus 1.0 | **Reject** (non-commercial-like). |
| Freesound | per-sound | Only CC0 / CC-BY sounds, each with a provenance record (`add-acoustic-asset-profiles` audit). |

The game is synthesis-first; samples should stay rare (impulses, recorded
field sounds), and each one gets a provenance record.

---

## 9. Plugin hosting (VST3, CLAP) inside the rack

**Licences.** Verified: the VST 3 SDK README ("VST SDK 3.8.x") says "VST 3 SDK is
under MIT license" and "Licensing under GPLv3 and the Steinberg proprietary license
is no longer available"; `vst3_pluginterfaces/LICENSE.txt` is MIT (© 2026
Steinberg). VSTGUI is BSD-3. CLAP, clap-helpers and clap-wrapper are MIT. LV2 is
ISC. So **a host is now licence-clean in all three formats.** (The user's "late 2025"
date for the relicence matches SDK 3.8; no dated announcement was fetched.)

**What hosting would give.** Thousands of instruments and effects for desktop
players who already own them; a DAW-like sandbox.

**Costs and problems:**

1. **Platforms.** Plugins are native desktop binaries (Windows/macOS/Linux; macOS
   needs signed/notarised bundles). Nothing on web export, Android, iOS (AUv3 only)
   or consoles. Arch must match the game (x86_64 vs arm64).
2. **Block processing vs the per-sample rack.** Plugins process blocks. A plugin
   module needs a FIFO, which adds its block size in latency; feedback through it
   becomes N + 1 samples. VST3 and CLAP allow small and variable block sizes
   (CLAP has `min/max_frames_count`), but per-sample calls are very slow and many
   plugins misbehave below ~16–32 frames.
3. **Realtime and stability.** We can't audit third-party `process()`: it may
   allocate, lock or log, which breaks stubby-rack's allocation guard and can glitch
   Godot's mix. A crash in a plugin takes down the game; sandboxing out-of-process
   (as Bitwig does) adds IPC, a block of latency and a lot of code.
4. **Determinism and the clock.** Plugins don't know the master clock unless we
   feed transport (both formats support it), aren't seeded by `WorldSeed`, and
   render differently per machine. Patches that reference plugins don't travel:
   another player, or a save on a different machine, may lack them.
5. **GUI.** Plugin editors are native windows (Win32/Cocoa/X11), not drawable in
   the 3D `RackView`. We'd show generic knobs from the parameter list.
6. **Licences of the plugins themselves.** We can't ship most free plugins
   (Surge, Vital, Dexed: GPL-3) with the game. Loading user-installed GPL plugins
   into a non-GPL host in-process is a grey area (the FSF treats shared-address-space
   plugins as one combined work).
7. **Design fit.** The game's fiction is that sound is discovered and built in the
   desert from found modules. "Load your VST" is a sandbox/modding feature, not the
   core loop.
8. **Effort.** A minimal headless CLAP host (scan, load, activate, process,
   params, state) is roughly 1–2 k lines with clap-helpers; VST3 is larger
   (COM-style interfaces, component/controller split), plus scanning, crash
   blacklisting and per-OS packaging.

**Better ways to get "VST-like" breadth:**

- **Compile permissive plugin DSP from source as modules.** Airwindows via
  airwin2rack's registry gives ~530 effects under MIT with no host at all. Plaits,
  Braids and Rings are already "plugins" in all but name.
- **Expose stubby-rack as a CLAP plugin** (reverse direction) as a *development
  tool*, so patches and modules can be auditioned in a DAW. Optional, not for the
  shipped game.

---

## 10. Recommended module catalogue

Licence column: the licence of the code the module links. "ours" = hand-written
(MIT, part of stubby-rack), allowed only where the Source column says nothing
permissive fits. Latency is the block size from §3 (0 = per-sample).

### 10.1 Sources

| Module | Source (file) | Licence | Notes |
| --- | --- | --- | --- |
| Sine / Square / Saw / Triangle VCO | DaisySP `Synthesis/oscillator.h` | MIT | Exist or specified. |
| Analog VCO (shape morph, PWM, sync) | Plaits `dsp/oscillator/variable_shape_oscillator.h`, `variable_saw_oscillator.h` | MIT | East-coast workhorse. |
| Supersaw / Swarm | Plaits `engine/swarm_engine` or Braids `digital_oscillator` | MIT | |
| Complex Oscillator (259-style) | Plaits `sine_oscillator.h` ×2 + FM/AM + Wavefolder 259 | MIT + ours | West-coast core. |
| Macro Oscillator | Plaits `voice.cc` (all engines) | MIT | "Everything" module. |
| FM Voice (2-op) | DaisySP `Synthesis/fm2.h` / Plaits `fm_engine` | MIT | |
| DX Voice (6-op) | Plaits `engine2/six_op_engine` | MIT | DX7 banks: check each bank's licence (*uncertain*). |
| Formant / VOSIM | DaisySP `formantosc.h`, `vosim.h`; Plaits `grain_engine` | MIT | |
| Harmonic / Additive | DaisySP `harmonic_osc.h`; Plaits `additive_engine` | MIT | |
| Wavetable | Plaits `wavetable_engine` | MIT | |
| Wave Terrain | Plaits `engine2/wave_terrain_engine` | MIT | Vendor first. |
| String Machine | Plaits `engine2/string_machine_engine` + `fx/ensemble.h` | MIT | Vendor first. |
| Speech | Plaits `speech_engine` | MIT | |
| Noise (white/pink/brown/clocked) | DaisySP `whitenoise.h`, `clockednoise.h`; Faust `no.pink_noise` | MIT | |
| Dust / Particle / Crackle | DaisySP `dust.h`, `particle.h`; HetrickCV `HCVCrackle.h` | MIT / CC0 | Desert textures. |
| Modal Resonator | Rings `dsp/` | MIT | |
| Physical Voice (bow/blow/strike) | Elements `dsp/` | MIT | 32 kHz: SRC. |
| Karplus String / Modal Voice / Drip | DaisySP `PhysicalModeling/` | MIT | Cheap per-sample. |
| Drums (BD, SD, HH, FM drum) | Plaits `dsp/drums/`, DaisySP `Drums/`, Peaks `drums/fm_drum` | MIT | |
| Sampler | ours + CHOC WAV (`sampler.h` exists) | ISC | CC0/CC-BY samples only. |

### 10.2 Modifiers and filters

| Module | Source | Licence | Notes |
| --- | --- | --- | --- |
| Ladder VCF (24 dB) | DaisySP `Filters/ladder.h` | MIT | Moog voice. |
| Multimode SVF | DaisySP `Filters/svf.h`; Faust `fi.svf` | MIT / STK | |
| Diode Ladder (303) | Faust `ve.diodeLadder` | STK | |
| MS-20 / K35 | Faust `ve.korg35LPF/HPF`; LRTRack `MS20zdf` | STK / BSD-3 | |
| SEM SVF | Faust `ve.oberheim*` | STK | |
| Low-Pass Gate (vactrol) | Plaits `fx/low_pass_gate.h` + `LPGEnvelope`; later ours from Parker–D'Angelo | MIT (+ ours) | Buchla 292. |
| Wavefolder 259 | ours (Esqueda et al. DAFx-17) | ours | No permissive code exists. |
| Wavefolder Lockhart / Serge | LRTRack `dsp/Lockhart.cpp`, `Serge.cpp` with non-GPL Lambert W | BSD-3 (+ BSL-1.0) | |
| Simple Folder | DaisySP `Effects/wavefolder.h` | MIT | |
| Waveshaper / Saturator (ADAA) | Faust `aanl.lib` | MIT | |
| Ring Mod / Cross-mod / Freq Shifter | Warps `dsp/modulator.cc`, `quadrature_transform.h` | MIT | 96 kHz blocks. |
| Comb / Resonator | DaisySP `Resonator`; Faust `fi.fb_comb` | MIT / STK | |
| Formant / Vowel filter | Faust `physmodels.lib` `fof`, sndkit `vowel` | LGPL+exc / MIT | |

### 10.3 Envelopes and function generators

| Module | Source | Licence |
| --- | --- | --- |
| AD Envelope | ours (spec'd, `basic.h`) | ours |
| ADSR | DaisySP `Control/adsr.h` | MIT |
| Function Generator (281/DUSG) | Tides 2 `poly_slope_generator.h`, `ramp_shaper.h` | MIT |
| Segment Generator (chainable) | Stages `segment_generator.h` | MIT |
| Multistage Envelope | Peaks `modulations/multistage_envelope.h` | MIT |
| Envelope Follower | Streams `follower.h` | MIT |
| Slew / Lag | stmlib `filter.h` OnePole; HetrickCV `HCVSlewLimiter.h` | MIT / CC0 |

### 10.4 Modulation, LFOs and random

| Module | Source | Licence |
| --- | --- | --- |
| LFO (shapes, sync to master) | Peaks `modulations/lfo.h`; DaisySP `Oscillator` | MIT |
| Poly LFO (4 phases) | Frames `poly_lfo.h` | MIT |
| Smooth Random LFO | DaisySP `smooth_random.h`; Signalsmith `CubicLfo` | MIT |
| Source of Uncertainty | Marbles `random/` | MIT |
| Sample & Hold / Track & Hold | DaisySP `Utility/samplehold.h` | MIT |
| Rungler / Shift Register | HetrickCV `Rungler.cpp`, `HCVShiftRegister.h` | CC0 |
| Chaos (Lorenz, maps) | Streams `lorenz_generator.h`; HetrickCV `ChaoticAttractors` | MIT / CC0 |
| Bouncing Ball | Peaks `bouncing_ball.h` | MIT |
| Random Gates / Bernoulli | Marbles `t_generator.h`; DaisySP `maytrig.h` | MIT |

### 10.5 Utilities

| Module | Source | Licence |
| --- | --- | --- |
| Constant, VCA, Mix4, Thru | existing `basic.h` | ours |
| Attenuverter / Offset, Multiple, Min/Max, Comparator | ours (trivial) | ours |
| Crossfader | DaisySP `Dynamics/crossfade.h` | MIT |
| Stereo Mixer with pan | ours | ours |
| Quantizer | Braids `quantizer.h` + `quantizer_scales.h` | MIT |
| Logic (AND/OR/XOR, flip-flop) | HetrickCV `Boolean3`, `FlipFlop` | CC0 |
| Clock Divider / Multiplier | ours on the master grid (`TempoClock`) | ours |
| Gate Delay / Trigger Shaper | HetrickCV `GateDelay`, `TrigShaper` | CC0 |
| DC Blocker | DaisySP `Utility/dcblock.h` | MIT |
| Poly Split / Merge | ours (core `PolyVoltage`) | ours |

### 10.6 Effects

| Module | Source | Licence |
| --- | --- | --- |
| Delay (clock-synced) | Signalsmith `delay.h` | MIT |
| Tape Echo (wow/flutter, saturation) | Beads `fx/wow_and_flutter.h` + Airwindows `ToTape6` | MIT |
| Plate / Hall Reverb | Faust `re.zita_rev1_stereo` or `re.dattorro_rev` | STK-4.3 |
| Small Room / Diffuser | Clouds `fx/reverb.h`, `fx/diffuser.h` | MIT |
| Huge Space | CloudSeed or Faust `re.greyhole` / `re.jpverb` | MIT |
| Chorus / Ensemble | DaisySP `chorus.h`; Rings `fx/ensemble.h` | MIT |
| Flanger, Phaser | DaisySP `flanger.h`, `phaser.h` | MIT |
| Overdrive / Saturation | Faust `aanl.lib`; DaisySP `overdrive.h` | MIT |
| Bitcrusher | DaisySP `decimator.h`, `sampleratereducer.h` | MIT |
| Compressor | Streams `compressor.h` | MIT |
| Limiter | DaisySP `Dynamics/limiter.h` | MIT |
| EQ (3-band, shelves) | Signalsmith `filters.h` | MIT |
| Granular | Clouds `granular_processor` (later Beads) | MIT |
| Pitch Shifter | Signalsmith Stretch (quality) / DaisySP `pitchshifter.h` (cheap) | MIT |
| Looper | DaisySP `Utility/looper.h` | MIT |
| Vocoder | Warps `vocoder.h` | MIT |
| Airwindows (one module, selectable algorithm) | airwin2rack `src/AirwinRegistry.h` + `libs/airwindows` | MIT |

### 10.7 Sequencing

| Module | Source | Licence |
| --- | --- | --- |
| Step Sequencer (8/16) | ours, logic after ML_modules | ours / BSD-3 |
| Euclidean | HetrickCV `PhasorEuclidean`; sndkit `euclid` | CC0 / MIT |
| Probability / Swing | HetrickCV `PhasorProbability`, `PhasorSwing` | CC0 |
| Touch Plate (218-style) | ours (UI → gate/pressure/position CV) | ours |
| Stage Sequencer (248 MARF-style) | ours | ours |
| Arpeggiator | Plaits `engine2/arpeggiator.h` | MIT |
| Random Sequencer (déjà vu) | Marbles `random_sequence.h` | MIT |

---

## 11. Pre-baked voices

Each voice is a saved `RackPatch` built only from catalogue modules, so it's also a
teaching patch the player can open. All timing comes from master-clock multiples.

| Voice | Path | Modules |
| --- | --- | --- |
| **Moog Bass** | east | Analog VCO (saw) + Analog VCO (square, −1 oct) → Mix4 → Ladder VCF (high res, drive) → VCA; ADSR → VCF cutoff and VCA; Glide on V/oct |
| **Acid Line** | east | Analog VCO (saw/square) → Diode Ladder → VCA; AD Envelope (accent) → cutoff; Step Sequencer with slide → V/oct |
| **Brass Stab** | east | Supersaw → SEM SVF (LP) → VCA; ADSR (slow attack on cutoff) |
| **Strings / Pad** | east | String Machine → Chorus/Ensemble → Plate Reverb; slow ADSR; Smooth Random LFO → pitch (tiny) |
| **Drone** | both | Complex Oscillator (slow FM index LFO) → Wavefolder (Serge) → SVF; Poly LFO → fold and cutoff; Huge Space reverb. Fits the silent desert opening. |
| **Buchla Bongo** | west | Sine VCO → Low-Pass Gate (vactrol), pinged by a short trigger (no envelope); Euclidean → trigger; Source of Uncertainty → pitch (quantized) |
| **LPG Pluck** | west | Complex Oscillator (modulator at 2:1, FM) → Wavefolder 259 → Low-Pass Gate; Function Generator (fast rise, medium fall) → LPG and fold |
| **West-Coast Lead** | west | Complex Oscillator → Wavefolder (Lockhart) → LPG; Touch Plate → V/oct, pressure → timbre |
| **Benjolin Chaos** | west | 2× Triangle VCO cross-modulated → Rungler → SVF; Comparator → Rungler clock |
| **Kick / Snare / Hat kit** | perc | Drums module per voice (Plaits analog BD/SD, hi-hat), Euclidean + Random Gates, Compressor on the bus |
| **Bell / Mallet** | perc | Modal Resonator (Rings) or Modal Voice; Random Gates → strike; Plate Reverb |
| **Wind Through Reeds** | ambient | Pink Noise → SVF (BP, slow Smooth Random cutoff) → VCA; acoustic object of the reed beds (excited, not free-running) |
| **Mudpit Burble** | ambient | Dust → Resonator (low) → Overdrive; burbler clock gates the dust density (fits the existing burbler) |
| **Bug Click** | ambient | Square VCO → AD Envelope → VCA on a seeded Random Clock (current lightning-bug stand-in, spec'd) |
| **Tape Memory** | fx chain | any voice → Tape Echo (clock-synced, wow/flutter) → Granular |

---

## 12. Recommendation

1. **Fix D7's DaisySP list** (no MIT reverb, compressor or Csound MoogLadder; the
   MIT ladder is `ladder.h`).
2. **Vendor next, in order:** Mutable Tides 2, Stages, Marbles, Peaks, Streams,
   Warps, Braids, Elements, Beads, Frames (STM32 code only, no `test/`) plus the
   missing Plaits engine2 files; then the airwin2rack registry
   (`src/AirwinRegistry.*`, `src/airwin_consolidated_base.*`, `src/autogen_airwin/`,
   `libs/airwindows`, no `src-rack`/`src-juce`); then HetrickCV's `src/DSP` (CC0)
   with VCV calls stripped.
3. **Faust → C++** for the VA filter set (diode ladder, K35, SEM), ADAA saturation,
   and zita/Dattorro/greyhole reverbs, pinned to one faustlibraries commit with a
   function-level licence check (§4) added to `tools/check_licences.py`.
4. **Hand-write** only the Buchla 259 wavefolder, the full Parker–D'Angelo LPG
   (upgrade from Plaits' LPG), touch-plate and MARF sequencers, and trivial
   utilities, each citing its paper in the module definition.
5. **Plugin hosting: don't, for the shipped game.** Licences allow it (VST3 MIT,
   CLAP MIT), but it breaks realtime guarantees, determinism, the master clock, the
   per-sample feedback model, patch portability and non-desktop platforms, and it
   doesn't fit the game's discovery loop. Get breadth from source-level reuse
   (Airwindows, Mutable) instead. Revisit later as an opt-in, desktop-only,
   **CLAP-first** "foreign module" with a fixed block size, clearly marked as
   non-deterministic; optionally build stubby-rack as a CLAP plugin as a dev tool.

## 13. Open questions

1. Do Mutable modules run at their native rates behind a resampler, or do we
   regenerate their tables at 48 kHz? (Affects CPU and parity tests.)
2. Is block latency (Plaits 12, Rings 24, Clouds 32, Warps 96 samples) acceptable
   on every cable through those modules, or should the definition expose it so the
   rack screen can show it?
3. Faust `re.springreverb` and `os.polyblep*` carry no licence declaration (the
   "further contributions" sections). Ask upstream or `git blame` before use.
4. DX7 SysEx banks for the 6-op voice: which banks are clearly licensed? (Plaits'
   built-in banks are MIT with the module; third-party `.syx` files are *uncertain*.)
5. LRTRack's Lockhart model needs Lambert W: Boost.Math (BSL-1.0, header-only but
   pulls Boost) or our own Halley iteration?
6. Should the Airwindows module expose all ~530 algorithms (one module, a selector)
   or a curated ~30 as separate panels? The game's discovery loop suggests curated.
7. Do pre-baked voices ship as `.tres` patches in the game repo (data-driven,
   CLAUDE.md rule) and get unlocked as recipes?
8. sndkit `bigverb` and SoundpipeAudioKit: worth asking the authors about Csound
   provenance, or simply avoid (current recommendation: avoid)?

## Sources

Libraries: [DaisySP](https://github.com/electro-smith/DaisySP),
[DaisySP-LGPL](https://github.com/electro-smith/DaisySP-LGPL),
[eurorack](https://github.com/pichenettes/eurorack), [stmlib](https://github.com/pichenettes/stmlib),
[Signalsmith DSP](https://github.com/Signalsmith-Audio/dsp),
[Signalsmith Stretch](https://github.com/Signalsmith-Audio/signalsmith-stretch),
[Airwindows](https://github.com/airwindows/airwindows), [airwin2rack](https://github.com/baconpaul/airwin2rack),
[faustlibraries](https://github.com/grame-cncm/faustlibraries), [cycfi/q](https://github.com/cycfi/q),
[STK](https://github.com/thestk/stk), [Gamma](https://github.com/LancePutnam/Gamma),
[CloudSeed](https://github.com/ValdemarOrn/CloudSeed), [chowdsp_wdf](https://github.com/Chowdhury-DSP/chowdsp_wdf),
[chowdsp_utils](https://github.com/Chowdhury-DSP/chowdsp_utils), [MoogLadders](https://github.com/ddiakopoulos/MoogLadders),
[LRTRack](https://github.com/lindenbergresearch/LRTRack), [HetrickCV](https://github.com/mhetrick/hetrickcv),
[ML_modules](https://github.com/martin-lueders/ML_modules), [JW-Modules](https://github.com/jeremywen/JW-Modules),
[southpole-vcvrack](https://github.com/gbrandt1/southpole-vcvrack), [sndkit](https://github.com/PaulBatchelor/sndkit),
[msfa](https://github.com/google/music-synthesizer-for-android), [CMSIS-DSP](https://github.com/ARM-software/CMSIS-DSP),
[Maximilian](https://github.com/micknoise/Maximilian), [synth-plugin-book](https://github.com/hollance/synth-plugin-book),
[sfizz](https://github.com/sfztools/sfizz), [Vult](https://github.com/modlfo/vult).
Rejected: [Surge](https://github.com/surge-synthesizer/surge), [sst-filters](https://github.com/surge-synthesizer/sst-filters),
[sst-basic-blocks](https://github.com/surge-synthesizer/sst-basic-blocks), [sst-effects](https://github.com/surge-synthesizer/sst-effects),
[VCV Fundamental](https://github.com/VCVRack/Fundamental), [Befaco](https://github.com/VCVRack/Befaco),
[Bogaudio](https://github.com/bogaudio/BogaudioModules), [AudibleInstruments](https://github.com/VCVRack/AudibleInstruments),
[Vital](https://github.com/mtytel/vital), [AnalogTapeModel](https://github.com/jatinchowdhury18/AnalogTapeModel),
[JUCE](https://github.com/juce-framework/JUCE), [ykchorus](https://github.com/SpotlightKid/ykchorus),
[SoundpipeAudioKit](https://github.com/AudioKit/SoundpipeAudioKit), [musicdsp.org](https://www.musicdsp.org/).
Plugin formats: [VST 3 SDK](https://github.com/steinbergmedia/vst3sdk) (README "License & Usage guidelines"),
[vst3_pluginterfaces](https://github.com/steinbergmedia/vst3_pluginterfaces), [VSTGUI](https://github.com/steinbergmedia/vstgui),
[CLAP](https://github.com/free-audio/clap), [clap-helpers](https://github.com/free-audio/clap-helpers),
[clap-wrapper](https://github.com/free-audio/clap-wrapper).
Samples: [VCSL](https://github.com/sgossner/VCSL), [sfzinstruments](https://github.com/sfzinstruments).
