## ADDED Requirements

### Requirement: Catalogue coverage
The module catalogue SHALL provide, at minimum:
- **sources:** analog-style VCO (shape morph, PWM, hard sync), complex oscillator,
  macro oscillator, 2-op and 6-op FM, wavetable, formant, additive, supersaw, noise
  (white, pink, brown, clocked), dust/crackle, modal resonator, string and physical
  voices, and drum voices (kick, snare, hi-hat);
- **filters and modifiers:** 24 dB ladder, multimode state-variable filter, diode
  ladder, Korg-35 style, SEM-style, low-pass gate, Buchla 259, Lockhart and Serge
  wavefolders, an anti-aliased saturator, ring modulator, frequency shifter, comb
  filter, and vowel filter;
- **envelopes and function generators:** AD, ADSR, multistage, chainable segment
  generator, function generator (rise/fall, cycle), envelope follower, slew;
- **modulation:** LFO, 4-phase LFO, smooth random, source of uncertainty, sample and
  hold, Rungler/shift register, chaos, bouncing ball, random gates;
- **utilities:** attenuverter/offset, multiple, min/max, comparator, crossfader,
  stereo mixer with pan, quantizer, logic, clock divider/multiplier, gate delay, DC
  blocker, poly split/merge;
- **sequencers:** step sequencer, Euclidean, probability/swing, touch plate, stage
  sequencer, arpeggiator, random sequencer.

Each kind SHALL have a definition (ports, parameters, lights, source, licence) that
agrees with the engine.

#### Scenario: Every catalogue kind is real
- **WHEN** the definition check runs over the catalogue
- **THEN** every listed kind exists in the engine and its definition agrees with it

#### Scenario: Both traditions are patchable
- **WHEN** a player has the tier 1 modules
- **THEN** they can patch an east-coast voice (VCO → ladder → VCA with ADSR) and a west-coast voice (complex oscillator → wavefolder → low-pass gate) without any other module

### Requirement: Oscillators track 1 V/oct
Every pitched source SHALL follow 1 V/oct on its pitch input, with 0 V at its
frequency parameter, within 2 cents over at least 8 octaves of its range, and SHALL
be band-limited so that aliasing products stay below −60 dB relative to the
fundamental for fundamentals up to 4 kHz at 48 kHz.

#### Scenario: Octave up
- **WHEN** an analog VCO at 261.63 Hz receives +1 V
- **THEN** its fundamental is 523.25 Hz ± 2 cents

#### Scenario: Bright saw at 4 kHz
- **WHEN** an analog VCO plays a saw at 4 kHz
- **THEN** no alias component exceeds −60 dB relative to the fundamental

### Requirement: Filters behave like their circuits
The ladder filter SHALL give a 24 dB/octave low-pass slope above cutoff and SHALL
self-oscillate near its cutoff at maximum resonance. The state-variable filter SHALL
offer low-pass, band-pass and high-pass outputs at 12 dB/octave. Cutoff SHALL follow
1 V/oct on its CV input.

#### Scenario: Ladder slope
- **WHEN** white noise passes a ladder at 1 kHz cutoff with no resonance
- **THEN** the level at 4 kHz is 24 dB ± 3 dB below the passband level per octave beyond the knee

#### Scenario: Self-oscillation
- **WHEN** the ladder's resonance is at maximum and its input silent
- **THEN** it outputs a sine near the cutoff frequency

### Requirement: Low-pass gate couples level and brightness
The low-pass gate SHALL lower its cutoff and its gain together as its control falls,
SHALL respond to a short trigger on its strike input with a natural decay (a "ping")
without an envelope module, and its decay SHALL take 100–1500 ms depending on its
decay parameter.

#### Scenario: Ping
- **WHEN** a sine through a low-pass gate is struck by a 1 ms trigger
- **THEN** the output rises fast and decays, and its spectral centroid falls during the decay

### Requirement: Wavefolders add harmonics with fold depth
A wavefolder SHALL leave a low-level sine nearly unchanged and SHALL add odd
harmonics as its fold or input level rises. It SHALL stay alias-suppressed
(oversampled or anti-derivative) so that a 1 kHz sine folded at maximum shows no
inharmonic component above −50 dB.

#### Scenario: Folding a sine
- **WHEN** a 200 Hz sine's fold depth goes from minimum to maximum
- **THEN** the third and fifth harmonics grow and the output stays within ±10 V

### Requirement: Modulation and sequencers keep master time
Every LFO, clock divider, sequencer and synced function generator SHALL offer a mode
whose rate is a whole multiple or whole division of the master clock, with its phase
derived from the master transport, so it lands on master beats. A free mode MAY set a
rate in Hz.

#### Scenario: Synced LFO on the downbeat
- **WHEN** an LFO is synced at ×4 of a 1 BPM master
- **THEN** its cycle starts on every master beat, sample-exact

#### Scenario: Sequencer step on a tick
- **WHEN** a step sequencer is clocked by a ×120 tempo clock
- **THEN** each step's gate starts on the clock tick's exact sample

### Requirement: Random sources are seeded
Every random module SHALL draw from a seed given when it's built, and the same seed
and inputs SHALL give bit-identical output. This covers noise, dust, random gates,
source of uncertainty, random sequencer, smooth random, and the Rungler started from
noise.

#### Scenario: Two renders
- **WHEN** a source of uncertainty with seed 7 renders 10 s twice
- **THEN** both renders are bit-identical, and seed 8 gives a different render

### Requirement: Block latency is declared
A module whose DSP runs in blocks SHALL declare its latency in samples, SHALL add
exactly that latency, and SHALL show it to the player.

#### Scenario: Measured latency
- **WHEN** an impulse enters a module declaring 24 samples of latency
- **THEN** the response begins 24 samples (plus the 1-sample cable) later
