## ADDED Requirements

### Requirement: Effects catalogue
The catalogue SHALL provide effects as rack modules, at minimum: delay, tape echo
(wow, flutter, saturation), room, plate and huge-space reverbs, chorus/ensemble,
flanger, phaser, overdrive/saturation, bitcrusher/sample-rate reducer, compressor,
limiter, 3-band EQ with shelves, granular processor, pitch shifter, looper, vocoder,
and a curated set of about 30 Airwindows algorithms, each its own module. Every
effect SHALL have a dry/wet or mix control unless it is a dynamics or EQ stage.

#### Scenario: Effect in a patch
- **WHEN** a VCO is cabled through a plate reverb to an emitter
- **THEN** the emitter plays the reverberated signal, and the mix control at 0 gives the dry signal

### Requirement: Time effects sync to the master clock
Delay, tape echo and looper SHALL offer a synced mode whose time is a whole number of
ticks of a clock at a whole multiple of the master, derived from the master
transport, and SHALL keep that time across tempo changes. A free mode MAY set the
time in milliseconds.

#### Scenario: Echo on the grid
- **WHEN** a synced delay set to 3 ticks of ×120 echoes a trigger at master sample S
- **THEN** the echoes start at S + 3 × 24,000, S + 6 × 24,000, … at 48 kHz

#### Scenario: Tempo change
- **WHEN** the master tempo changes while a synced delay runs
- **THEN** new echoes land on the new grid without a click

### Requirement: Effects are realtime-safe and stable
Effects SHALL allocate their buffers when built, never while rendering, SHALL stay
bounded (no output beyond ±12 V, no NaN) at any parameter setting, and SHALL decay to
silence after their input stops unless they're set to infinite feedback or freeze.

#### Scenario: Maximum feedback, then silence
- **WHEN** a reverb at maximum decay (not freeze) has its input cut
- **THEN** its output stays finite and within ±12 V, and decays below −90 dBFS within its stated tail time

#### Scenario: No allocation
- **WHEN** an effect renders with its parameters swept
- **THEN** the render thread performs no allocation

### Requirement: Deterministic effects
Effects that use randomness (dither, modulated delays, grains) SHALL draw it from the
module's seed, so the same seed and input give bit-identical output.

#### Scenario: Airwindows dither
- **WHEN** an Airwindows tape module with seed 3 renders the same input twice
- **THEN** both renders are bit-identical
