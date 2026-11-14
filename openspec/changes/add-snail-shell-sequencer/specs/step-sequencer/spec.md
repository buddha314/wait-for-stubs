## ADDED Requirements

### Requirement: A shell mounts as a four-step sequencer
A `snail_shell` SHALL mount in a rack place that accepts it as the Snail sequencer
module: four steps, each with a CV knob and a lit step button, CLOCK and RESET inputs,
and GATE and CV outputs, behaving as a hardware step sequencer (Intellijel Steppy, KORG
SQ-1) does wherever this specification is silent. A newly mounted sequencer SHALL start
with every step off.

#### Scenario: Mounting
- **WHEN** the player opens the burbler's rack holding a snail shell and mounts it in the sequencer place
- **THEN** the Snail sequencer is mounted with four dark steps and the shell leaves the inventory

### Requirement: Stepping on the clock
The sequencer SHALL advance one step on each rising edge at CLOCK, from step 1 to step
4 and back to 1. A rising edge at RESET SHALL make the next clock edge play step 1. The
step SHALL change on the sample the clock edge reaches it (one sample after the edge,
the cable delay), so it stays on the master grid.

#### Scenario: Four beats
- **WHEN** a clock is patched into CLOCK and ticks four times
- **THEN** the sequencer plays steps 1, 2, 3, 4, and the fifth tick plays step 1

#### Scenario: Reset
- **WHEN** RESET receives an edge while the sequencer is on step 3
- **THEN** the next clock edge plays step 1

### Requirement: Gate and CV outputs
GATE out SHALL carry the clock input's pulse on steps whose gate button is on, and be
low on steps whose button is off. CV out SHALL hold the current step's knob voltage, from
0 to 2 V, so on a VCO's V/OCT input the four steps span two octaves.

#### Scenario: Backbeat
- **WHEN** only the buttons of steps 2 and 4 are on and a clock ticks four times
- **THEN** GATE out pulses on the second and fourth ticks only

#### Scenario: A four-note line
- **WHEN** CV out is patched to the square VCO's V/OCT and the step knobs are set to 0, 0.25, 0.5 and 1 V
- **THEN** the VCO plays its base pitch, three semitones up, six semitones up, and an octave up, on successive steps

### Requirement: One light per step shows its state and the playhead
Each step SHALL have one light, in its button: steady when the step is on and dark when
it is off. As the playhead passes, that light SHALL invert for the step's duration (a
lit step blinks dark, an unlit step blinks on), starting at the instant the step's
clock edge is heard.

#### Scenario: Lighting steps
- **WHEN** the player pushes the buttons of steps 2 and 4 on a new sequencer
- **THEN** those two buttons light, and GATE out pulses on the second and fourth clock ticks

#### Scenario: Watching the playhead
- **WHEN** the sequencer runs on the burbler's clock
- **THEN** the playhead's blink moves one step per heard beat, in time with the sound
