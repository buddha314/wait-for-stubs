## ADDED Requirements

### Requirement: Seeded tempo as a master multiple
Each burbler SHALL have a stable instance id. Its starting tempo SHALL be a whole
multiple of the master tempo, drawn from that instance's seeded generator from a
narrow window around 60 BPM (×56 to ×64 at the shipped 1 BPM master), so burblers
start near a resting pulse. The window SHALL be data, not code. The knob's full range
stays the profile's `params.bpm` (40 to 180). The same world seed SHALL always give
each burbler the same tempo.

#### Scenario: Same seed, same tempo
- **WHEN** the game starts twice with seed 42
- **THEN** the burbler starts at the same whole-number BPM both times, between 56 and 64

#### Scenario: Different seed
- **WHEN** the seed changes
- **THEN** the burbler's tempo is drawn again and stays a whole number in range

### Requirement: Three-place configuration
The burbler's rack SHALL have three places in order:
1. a fixed 8 HP clock (`burbler_clock`);
2. an empty 8 HP VCO place that takes a square wave as a Square VCO;
3. a fixed 4 HP volume (`volume`).

It SHALL hang two spare cables on the comb: verdigris for clock GATE → volume TRIG,
and rust for VCO OUT → volume IN.

#### Scenario: First opening
- **WHEN** the player first opens the burbler with a square wave in hand
- **THEN** the clock and volume are mounted, the VCO place shows a labelled outline, the Relevant strip offers the square wave, and two cables hang on the comb

### Requirement: BPM knob and display
The clock's BPM knob SHALL set the burbler's tempo in whole-number steps within the
burbler's range, starting at its seeded tempo. The machine's range SHALL override the
clock module's own wider knob range. The three-digit display SHALL show the knob's
value through the profile's segment table, and so SHALL the window header. The
burbler's bubbles, its lamp and its stream's notes SHALL follow that tempo.

#### Scenario: Turning the tempo up
- **WHEN** the player turns the BPM knob of a ×60 burbler up by 30 steps
- **THEN** the display and header read 90, and the burbler is now a ×90 clock

#### Scenario: Limits
- **WHEN** the player keeps turning past the top of the range
- **THEN** the tempo stays at 180

### Requirement: Gate drives the volume directly
The volume's TRIG SHALL open its VCA directly from the gate, with no envelope, so a
patched burbler sounds a plain square pulse on every beat. The volume knob SHALL set
the level from 0 to 1. Nothing SHALL sound until the configuration is complete.

#### Scenario: Half-patched is silent
- **WHEN** GATE → TRIG is patched but the VCO's OUT is not
- **THEN** the burbler makes no sound

### Requirement: Normalled outlet
The volume's OUT SHALL be normalled to the burbler's outlet (`Outlet_0`) when no cable
is plugged into it. A cable plugged into OUT SHALL break the normal.

#### Scenario: Outlet carries the voice
- **WHEN** the burbler is configured and nothing is plugged into the volume's OUT
- **THEN** the outlet carries the voice, ready for a stream

### Requirement: The beat is visible before sound exists
Until the audio engine plays, the clock lamp SHALL flash on a placeholder tick at the
burbler's tempo. The placeholder SHALL be named as a stand-in, as the lightning bug's
frame-timed flash is. When the engine lands, the lamp SHALL follow the engine's clock
ticks at their sample times instead.

#### Scenario: Stand-in flash
- **WHEN** a ×60 burbler's rack is open before stubby-rack can play
- **THEN** the clock lamp flashes about once a second, and the code marks it as a stand-in for the engine's ticks
