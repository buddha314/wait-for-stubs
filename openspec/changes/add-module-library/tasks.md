## 1. Groundwork and measurements

- [x] 1.1 Amend `add-rack-audio-engine` design D7: DaisySP's MIT core has no reverb, compressor or Csound MoogLadder; the MIT ladder is `Filters/ladder.h`
- [ ] 1.2 Extend the definition format with provenance (source, file/function, commit, licence), `latency_samples`, `native_rate`, `polyphonic`, panel family; the definition check fails on missing provenance
- [ ] 1.3 Extend `tools/check_licences.py`: per-file headers in mixed repos, no `test/` folders, Faust per-function manifest, sample-set audit
- [ ] 1.4 Block-module wrapper (input FIFO, N-sample latency) and resampler wrapper (stmlib `SampleRateConverter`); tests for exact declared latency and pitch at 48 kHz
- [ ] 1.5 Spike: cost per module-sample of Plaits (12-sample blocks) and Clouds (32 kHz behind the resampler) in the rack; record results in design.md before tier 1 commits to them
- [ ] 1.6 Per-module cost benchmark beside the 200-module budget test
- [ ] 1.7 Offline voice render harness: render a patch to a reference file and compare within tolerance

## 2. Tier 1: east-coast and west-coast core

- [ ] 2.1 Vendor the missing Plaits engine2 files and Mutable Tides 2, Stages, Peaks (STM32 only, no `test/`); pin in THIRDPARTY.md
- [ ] 2.2 Analog VCO (Plaits variable shape/saw: morph, PWM, sync), with 1 V/oct and alias tests
- [ ] 2.3 Ladder VCF (DaisySP `ladder.h`) and multimode SVF, with slope and self-oscillation tests
- [ ] 2.4 ADSR (DaisySP) and a Glide/slew utility
- [ ] 2.5 Complex oscillator (two sines, FM/AM index, timbre) and the Buchla 259 wavefolder (Esqueda et al.), with harmonic and alias tests
- [ ] 2.6 Low-pass gate (Plaits `low_pass_gate.h` + LPG envelope) with strike input; ping test; decide whether the vactrol model is needed now
- [ ] 2.7 Function generator (Tides 2 slope generator) with rise/fall and cycle, synced mode on the master
- [ ] 2.8 Noise (white, pink, brown, clocked), dust and crackle, seeded
- [ ] 2.9 Panel generator (`tools/blender/create_module_panel.py` on `module_kit.py`): layout from a definition, east and west families, sockets named for ports; regenerate tier 1 panels
- [ ] 2.10 Voices: Moog bass, drone, Buchla bongo, LPG pluck (patches, READMEs, references, recipes)

## 3. Tier 2: modulation, utilities, sequencing

- [ ] 3.1 Vendor Marbles, Frames' poly LFO, Streams, and HetrickCV `src/DSP` (CC0, VCV calls stripped)
- [ ] 3.2 LFO and 4-phase LFO with master-synced mode; smooth random; sample and hold
- [ ] 3.3 Source of uncertainty and random gates (Marbles), Rungler and shift register, chaos, bouncing ball; seeded-determinism tests
- [ ] 3.4 Multistage envelope (Peaks), segment generator (Stages), envelope follower (Streams)
- [ ] 3.5 Utilities: attenuverter/offset, multiple, min/max, comparator, crossfader, stereo mixer with pan, quantizer (Braids scales), logic, clock divider/multiplier on the master grid, gate delay, DC blocker, poly split/merge
- [ ] 3.6 Sequencers: step sequencer, Euclidean, probability/swing, arpeggiator, random sequencer; touch plate and stage sequencer (hand-written); tick-exact step tests
- [ ] 3.7 Voices: acid line, Benjolin chaos, west-coast lead, drum kit (with tier 1 drums from Plaits/DaisySP)

## 4. Tier 3: effects

- [ ] 4.1 Delay and tape echo with synced mode on the master (Signalsmith delay, Beads wow/flutter), grid and tempo-change tests
- [ ] 4.2 Reverbs: small room (Clouds `fx/reverb.h`), plate (Faust zita or Dattorro), huge space (CloudSeed or Faust greyhole); Faust generation pipeline with pinned library and manifest
- [ ] 4.3 Chorus/ensemble, flanger, phaser, overdrive (Faust ADAA), bitcrusher, limiter, EQ (Signalsmith), compressor (Streams)
- [ ] 4.4 Granular (Clouds), pitch shifter (Signalsmith Stretch and DaisySP), looper, vocoder (Warps)
- [ ] 4.5 Airwindows wrapper over airwin2rack's registry (no `src-rack`/`src-juce`), seeded dither; pick and ship the curated ~30 by listening
- [ ] 4.6 Stability tests for every effect: bounded output, decay to silence, no allocation while rendering
- [ ] 4.7 Voices: strings/pad, tape memory

## 5. Tier 4: the rest

- [ ] 5.1 Vendor Braids, Warps, Elements, Beads; resampler where their rate isn't 48 kHz
- [ ] 5.2 Macro oscillator, 2-op and 6-op FM (DX banks only if licence-clear), wavetable, formant, additive, supersaw, speech
- [ ] 5.3 Diode ladder, Korg-35, SEM (Faust), Lockhart and Serge folders (LRTRack with a non-GPL Lambert W), ADAA saturator, ring modulator and frequency shifter (Warps), comb, vowel filter
- [ ] 5.4 Modal resonator (Rings), physical voice (Elements), Karplus string, modal voice and drip (DaisySP)
- [ ] 5.5 Voices: brass stab, bell/mallet, wind through reeds, mudpit burble, bug click
- [ ] 5.6 Definition check, licence check and voice references pass over the whole catalogue; THIRDPARTY.md complete

## 6. Documentation

- [ ] 6.1 CLAUDE.md (both repos): how to add a module (library first, provenance, definition, panel, test, voice)
- [ ] 6.2 `assets/modules/README.md` and `assets/voices/README.md`: catalogue index by path and tier
