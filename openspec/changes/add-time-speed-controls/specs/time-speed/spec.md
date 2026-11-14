## ADDED Requirements

### Requirement: Simulation speed steps
The player SHALL be able to change the speed of simulation time in the steps 0.25,
0.5, 1, 2, 4, 8, 16 and 64. The faster key SHALL move one step up and the slower key
one step down, each stopping at the end of the list, and the reset key SHALL return
to 1. A new game SHALL start at 1. The keys SHALL be ignored while a screen has the
player's controls.

#### Scenario: Speeding up and down
- **WHEN** the player presses the faster key three times from 1×, then the slower key once
- **THEN** the speed is 8×, then 4×

#### Scenario: Ends of the list
- **WHEN** the player presses the faster key eight times from 1×
- **THEN** the speed stops at 64×

#### Scenario: Reset
- **WHEN** the speed is 16× and the player presses the reset key
- **THEN** the speed is 1×

#### Scenario: Screen open
- **WHEN** a machine's rack screen is open and the player presses the faster key
- **THEN** the speed does not change

### Requirement: Only simulation time changes speed
Simulation time SHALL advance s times as fast at speed s as at 1×: the day and night
cycle, the sky, replenishment timers and next-night returns, and plant growth. Player movement and
look, building, frame-time animation, the UI, the master clock and every clock and
sound of the audio engine SHALL run at the same rate at every speed.

#### Scenario: Reaching day
- **WHEN** the game starts at night and the player sets 64×
- **THEN** day arrives after about 7 real seconds instead of 7.5 minutes

#### Scenario: Reeds regrow faster
- **WHEN** reeds that regrow after 60 s are collected at 4×
- **THEN** they return after about 15 real seconds

#### Scenario: Walking is unchanged
- **WHEN** the player walks for one second at 64×
- **THEN** they cover the same distance as at 1×

#### Scenario: Music is unchanged
- **WHEN** the burbler sounds and the speed changes from 1× to 64×
- **THEN** its beat, its pitch and the master clock are unchanged

### Requirement: A slow frame cannot skip time
Simulation time SHALL advance by at most 0.1 s times the speed in one frame, so a
long frame never skips a whole night, and the start of each night SHALL be reported
exactly once.

#### Scenario: A hitch at 64×
- **WHEN** one frame takes 2 s at 64×
- **THEN** simulation time advances 6.4 s, not 128 s

#### Scenario: Night at 64×
- **WHEN** a night begins while running at 64×
- **THEN** the start of night is reported once and night-returning resources return

### Requirement: The time readout
The HUD SHALL show the phase (day or night), the solar time as hours and minutes, and
the current speed at all times during play.

#### Scenario: Night at speed
- **WHEN** it is 03:12 solar time at night and the speed is 64×
- **THEN** the readout shows "NIGHT 03:12 · 64×"

#### Scenario: Slow speed
- **WHEN** the speed is 0.25
- **THEN** the readout shows the speed as ¼×
