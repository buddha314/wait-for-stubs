## ADDED Requirements

### Requirement: Engine core is independent of the game engine
The synthesis engine (rack, master clock, sampler, module DSP) SHALL NOT depend on the
game engine's types or APIs. A thin adapter SHALL connect it to the game engine's
audio mix, and the same core SHALL also render offline with no audio device.

#### Scenario: Offline render in a test
- **WHEN** the engine's test suite runs on a machine with no audio device and no game engine
- **THEN** patches render offline and every test passes

### Requirement: Rendered by the game engine's audio thread
The engine SHALL render on the game engine's audio thread, called once per mix
block, and SHALL NOT open its own audio device while hosted in the game. Rendering
SHALL keep running while no emitter is audible, so clocks and the transport never
stall.

#### Scenario: Nothing audible
- **WHEN** every emitter is out of range for a minute
- **THEN** the master clock has still advanced by one minute of samples, and running clocks have kept ticking

### Requirement: Lock-free message boundary
The game SHALL change the engine only through commands (add or remove a module,
connect or disconnect a cable, set a parameter, schedule an action, control the
transport), queued during a frame and committed once per frame as one batch. The
engine SHALL report back through events (clock ticks, late notices, rejected
commands), each carrying its sample time. Neither direction SHALL block either
thread. Module IDs SHALL be assigned by the game.

#### Scenario: A frame's edits land together
- **WHEN** the game adds a VCO, adds a VCA and cables them in one frame
- **THEN** all three edits take effect on the same sample

#### Scenario: Invalid command
- **WHEN** the game connects a cable to a module ID that doesn't exist
- **THEN** the engine rejects that command with an event naming it, and the rest of the batch applies

### Requirement: Realtime safety on the audio thread
Code running on the audio thread SHALL NOT allocate, free, lock, block, perform I/O,
call into game-engine objects or scripts, or panic. Module construction and
destruction SHALL happen off the audio thread.

#### Scenario: Allocation guard
- **WHEN** the engine renders 1,000 blocks of a patch that is being edited every frame, under an allocation guard
- **THEN** no allocation occurs on the rendering thread

#### Scenario: Script holds the engine
- **WHEN** a script is in the middle of a long call on the engine controller while the audio thread renders
- **THEN** the render does not wait for it

### Requirement: Silent until sound is discovered
The engine SHALL output silence when nothing audible is in range. Before the first
oscillator is discovered, its own emission SHALL be the only sound in the game: no
ambient, UI or effects audio.

#### Scenario: Fresh engine is silent
- **WHEN** an engine starts with an empty patch
- **THEN** every stem and the master output are digital silence

### Requirement: Sound effects share the engine
One-shot sounds (effects, UI, ambience) SHALL play through the engine's sampler, on
an emitter stem or a non-spatial stem, so they are timed by the master clock and
obey the same silence rule.

#### Scenario: Cable snap on the beat
- **WHEN** a cable-snap sound is scheduled for the next beat
- **THEN** it starts on the first sample of that beat, sample-aligned with the rack
