## ADDED Requirements

### Requirement: Module and port model
Every synth module SHALL declare named, typed input and output ports (audio, CV,
gate) and named parameters with ranges, defaults and units. A cable SHALL join
exactly one output port to one input port. An output MAY fan out to many inputs, and
an input SHALL accept at most one cable.

#### Scenario: Fan-out
- **WHEN** a Clock output is cabled to two different modules' inputs
- **THEN** both receive the same signal

#### Scenario: Second cable to an input
- **WHEN** a cable is connected to an input that already has one
- **THEN** the engine rejects the connection with an error

### Requirement: Module definitions are data
Each module kind's ports, parameters, lights and panel bindings SHALL be defined in
a data file beside the module's asset. The rack screen and the engine SHALL both read
that definition, and a check SHALL fail the build if a module's DSP and its data file
disagree.

#### Scenario: Mismatch caught
- **WHEN** a module's data file declares an input port the DSP doesn't have
- **THEN** the definition check fails, naming the module and the port

### Requirement: Modules are built from existing DSP
A new module's DSP SHALL come from an existing MIT- or Apache-compatible library
where one provides it (for example DaisySP's MIT core, Mutable Instruments' MIT
STM32 code, or Faust-generated code),
and the module SHALL record its source. GPL-licensed code SHALL NOT be used.

#### Scenario: New oscillator
- **WHEN** a Saw VCO module is added
- **THEN** its DSP comes from a library oscillator, and its definition names that source

### Requirement: Square VCO module
The game SHALL provide a band-limited Square VCO with a frequency parameter, a V/oct
input and an audio output at ±5 V. It is the lightning bug's voice.

#### Scenario: Square tone
- **WHEN** a Square VCO at 220 Hz is rendered offline
- **THEN** its fundamental is 220 Hz (±0.1 Hz), its RMS is above 0.85 of its peak, and no sample exceeds 6.25 V

### Requirement: Sine VCO module
The game SHALL provide a Sine VCO with a frequency parameter, a V/oct input and a
±5 V audio output.

#### Scenario: Pure tone
- **WHEN** a Sine VCO at 440 Hz is rendered offline for one second at 48 kHz
- **THEN** the dominant spectral peak is at 440 Hz and the peak level is 5 V (±0.05 V)

### Requirement: Clock module
The game SHALL provide a Clock with a gate output (10 V) and a mode: a tempo clock
that follows the master at a whole-number multiple (its BPM parameter is that multiple
times the master BPM, set in whole steps), or a seeded random clock. A random clock
MAY use a seeded random interval between a minimum and a maximum. Every tick SHALL
be reported to the game with its exact sample time.

#### Scenario: Tempo clock
- **WHEN** a Clock at ×120 of the 1 BPM master renders 10 seconds at 48 kHz from a master downbeat
- **THEN** it ticks 20 times, 24,000 samples apart, with zero sample error

#### Scenario: Seeded random clock
- **WHEN** two random Clocks with the same seed and range render offline
- **THEN** their tick times are identical, and every interval lies within the range

### Requirement: Envelope module
The game SHALL provide an attack/decay Envelope with a gate input and a 0–10 V
output. Each rising gate edge SHALL start a linear attack to 10 V from the current
level, so a retrigger never jumps. An exponential decay SHALL follow, reaching -60 dB
after the decay time.

#### Scenario: Shape
- **WHEN** a 15 ms / 285 ms envelope is gated
- **THEN** it reaches 10 V (±0.2 V) after 15 ms and 0.01 V (±20%) a further 285 ms later

#### Scenario: Retrigger
- **WHEN** the gate rises again before the decay has finished
- **THEN** the output climbs from its current level with no step larger than one attack increment

### Requirement: VCA module
The game SHALL provide a VCA whose output is its audio input times its CV / 10 V
(negative CV treated as 0) times a gain parameter. With no CV cabled it SHALL be
closed. As an audio source, it SHALL fade on add and remove.

#### Scenario: Clock blip
- **WHEN** a Clock gates an Envelope that drives a VCA on a Square VCO
- **THEN** a blip sounds starting at each tick's sample, with a click-free onset, and dies away before the next tick

### Requirement: Constant module
The game SHALL provide a Constant module with a value parameter (volts) and one
output carrying that value.

#### Scenario: Octave up
- **WHEN** a Constant of 1 V is cabled to a VCO's V/oct input
- **THEN** the VCO sounds one octave above its frequency parameter
