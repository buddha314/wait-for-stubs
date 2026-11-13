## ADDED Requirements

### Requirement: One time base for all game audio
The game SHALL have exactly one audio clock: a monotonic 64-bit count of samples
rendered to the output since the audio engine started. Every audio source — rack
modules, spatial emitters, one-shot sound effects, UI sounds and ambience — SHALL be
timed against this clock. No audio component SHALL keep its own timer based on frame
time or wall time.

#### Scenario: Rack and sound effect share a sample
- **WHEN** a rack clock tick and a one-shot sound effect are both scheduled for sample S
- **THEN** both begin on sample S of the rendered output

#### Scenario: Clock only moves with rendered audio
- **WHEN** the game renders 48,000 samples at 48 kHz
- **THEN** the audio clock has advanced by exactly 48,000, whatever the wall time taken

### Requirement: Musical transport
The master clock SHALL provide a transport with a tempo in BPM and a meter in beats
per bar, and SHALL derive the current bar, beat and beat phase from the sample count.
The default tempo and meter SHALL come from configuration (shipped as 1 BPM, 4 beats
per bar), never from constants in code.
The transport SHALL start and stop. While it is stopped, the sample count SHALL keep
advancing, and only the musical position SHALL hold. A tempo change SHALL keep the
beat phase continuous: the musical position never jumps.

#### Scenario: Configured default tempo
- **WHEN** the game starts with the shipped configuration
- **THEN** the transport runs at 1 BPM in 4/4, so one beat lasts 60 seconds (2,880,000 samples at 48 kHz)

#### Scenario: Changing the default without code
- **WHEN** the configured default tempo is changed to 60 BPM and the game restarts
- **THEN** the transport runs at 60 BPM, with no code change

#### Scenario: Beat length
- **WHEN** the transport starts at 120 BPM in 4/4 at 48 kHz
- **THEN** beat 2 begins 24,000 samples after the start, and bar 2 begins 96,000 samples after it

#### Scenario: Tempo change mid-beat
- **WHEN** the tempo changes from 120 to 90 BPM halfway through a beat
- **THEN** the beat phase reads 0.5 on both sides of the change, and the rest of that beat lasts 16,000 samples

### Requirement: Sample-accurate scheduling
The game SHALL be able to schedule any audio action (start or stop a sound, set a
parameter, fire a trigger, connect or disconnect a cable) at an absolute sample time,
or at a quantized musical position: the next beat, bar, or a beat division. The
action SHALL take effect on exactly that sample. An action scheduled in the past SHALL
take effect at the start of the next rendered block, and SHALL be reported as late
with the number of samples it missed by.

#### Scenario: Quantized to the next beat
- **WHEN** the game schedules a sound "at the next beat" partway through beat 3
- **THEN** the sound starts on the first sample of beat 4

#### Scenario: Late request
- **WHEN** the game schedules an action for a sample that has already been rendered
- **THEN** it takes effect at the next block, and the game receives a late notice with the miss in samples

### Requirement: Tempo clocks are whole multiples of the master
Every rack clock with a tempo SHALL follow the master transport at a whole-number
multiple N ≥ 1 of the master tempo, phase-locked to it, so its tempo is N × the master
BPM. Its ticks SHALL be derived from the master beat phase (tick k of a master beat at
phase k/N), never accumulated, so clocks never drift apart and all of them tick
together on every master beat. Changing N SHALL take effect from the current master
phase: the next tick is the next k/N boundary of the new multiple. There SHALL be no
fractional ratios and no free-running fixed tempo. The only clocks that run free are
seeded random clocks (such as a lightning bug's); they SHALL still be timed in master
samples, and SHALL stay independent unless set to follow another clock.

#### Scenario: Locked clocks
- **WHEN** two clock modules follow the master at ×1 and ×2
- **THEN** every ×1 tick falls on the same sample as a ×2 tick, and the ×2 clock also ticks exactly halfway between them

#### Scenario: Shared downbeat
- **WHEN** clocks at ×90 and ×120 run at the shipped 1 BPM master
- **THEN** both tick on the first sample of every master beat (once a minute), and neither has drifted after an hour

#### Scenario: Retuning a clock
- **WHEN** a ×90 clock is set to ×120 at master phase 0.5
- **THEN** its next tick falls at phase 61/120 of the same master beat, and it ticks on the following master beat with every other clock

#### Scenario: Independent bugs
- **WHEN** two lightning bugs run free with different seeds
- **THEN** their tick times differ, and each tick carries an exact master sample time

### Requirement: The game reads audio time without locks
Every frame, the game SHALL be able to read, without locks: the current sample
position, the transport's bar, beat and phase, and the predicted wall-clock instant
at which any given sample will be heard, corrected for output latency. Clock and
trigger events sent to the game SHALL carry their exact sample times.

#### Scenario: Light on the beat
- **WHEN** a clock ticks at sample S and the game shows a light for that tick
- **THEN** the light is presented on the frame nearest the predicted audible instant of S, not the frame on which the event was received

### Requirement: Music-driven gameplay follows clock events
Game events on the music SHALL be driven by master-clock events or positions, never
by accumulating frame time. This covers machines firing, lights pulsing, creatures
flashing and burbler bubbles. Visuals MAY interpolate between events
at frame rate.

#### Scenario: Frame-rate independence
- **WHEN** the same patch runs once at 30 fps and once at 144 fps for 60 seconds
- **THEN** the same machines fire on the same beats in both runs, at the same sample times

### Requirement: Deterministic timing offline
Offline rendering SHALL advance the master clock by rendered samples alone. The same
patch, seed and schedule SHALL produce identical event sample times on every run,
whether the render is real-time, faster or slower.

#### Scenario: Repeat offline render
- **WHEN** a patch with master-following and free-running clocks is rendered offline twice
- **THEN** both runs produce identical lists of event sample times

### Requirement: Robust to device events
A buffer underrun SHALL NOT shift musical alignment: events keep their sample times
relative to one another. If the output sample rate changes (for example a new device),
the transport SHALL keep its tempo and musical position, and actions scheduled at
musical positions SHALL keep those positions.

#### Scenario: Device change
- **WHEN** the output device changes from 48 kHz to 44.1 kHz during bar 5 at 120 BPM
- **THEN** playback continues in bar 5 at 120 BPM, and an action scheduled for bar 6 still happens at the start of bar 6

### Requirement: Pause keeps time and mutes the music
Pausing the game SHALL NOT stop the master clock or the transport. The rack SHALL
keep rendering, clocks SHALL keep ticking, and scheduled actions SHALL still fire at
their samples. While paused, the music and world audio SHALL be muted, fading out
and back in over 20–50 ms so neither edge clicks. On resume, playback SHALL continue
at the transport's current position, not where it was when the game paused.

#### Scenario: Pause for three minutes at 1 BPM
- **WHEN** the game is paused at bar 3 beat 1 for 180 seconds at 1 BPM, with a ×90 clock running, and then resumed
- **THEN** nothing was audible during the pause, the ×90 clock ticked 270 times meanwhile, and audio resumes at bar 3 beat 4

#### Scenario: No click on pause
- **WHEN** the game pauses while a loud tone is sounding
- **THEN** the output fades to silence within 50 ms with no step larger than one fade increment

### Requirement: Separate from simulation time
The master clock SHALL be independent of simulation time (the day/night calendar and
its speed controls). Changing simulation speed SHALL NOT change the tempo, the pitch,
or the rate of the audio clock.

#### Scenario: Fast-forwarding the day
- **WHEN** the player speeds simulation time up to ×8
- **THEN** the day/night cycle runs eight times faster, and the music keeps its tempo and pitch
