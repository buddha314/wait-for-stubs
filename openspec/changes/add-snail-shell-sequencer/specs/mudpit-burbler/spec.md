## MODIFIED Requirements

### Requirement: Three-place configuration
The burbler's rack SHALL have three required places in order, and one optional place:
1. a fixed 8 HP clock (`burbler_clock`);
2. an empty 8 HP VCO place that takes a square wave as a Square VCO;
3. a fixed 4 HP volume (`volume`);
4. an optional, empty 8 HP sequencer place that takes a snail shell as a Snail
   sequencer, which configuration does not require.

It SHALL hang two spare cables on the comb: verdigris for clock GATE → volume TRIG,
and rust for VCO OUT → volume IN.

#### Scenario: First opening
- **WHEN** the player first opens the burbler with a square wave in hand
- **THEN** the clock and volume are mounted, the VCO place shows a labelled outline, the Relevant strip offers the square wave, and two cables hang on the comb

#### Scenario: The sequencer place is optional
- **WHEN** the player mounts the VCO and patches both comb cables, with no snail shell mounted
- **THEN** the burbler is configured and sounds

### Requirement: Gate drives the volume directly
The volume's TRIG SHALL open its VCA directly from the gate, with no envelope, so a
patched burbler sounds a plain square pulse on every beat. The volume knob SHALL set
the level from 0 to 1. Nothing SHALL sound until the configuration is complete. The
configuration SHALL be complete when every required place is mounted and each suggested
connection is made, directly or through patched modules, so routing the clock's GATE
through a sequencer to the volume's TRIG counts.

#### Scenario: Half-patched is silent
- **WHEN** GATE → TRIG is patched but the VCO's OUT is not
- **THEN** the burbler makes no sound

#### Scenario: Through the sequencer
- **WHEN** clock GATE → sequencer CLOCK, sequencer GATE → volume TRIG and VCO OUT → volume IN are patched
- **THEN** the burbler is configured, sounds on the sequencer's gated steps, and its stream flows
