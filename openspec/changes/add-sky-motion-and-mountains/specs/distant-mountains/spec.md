## ADDED Requirements

### Requirement: Seeded mountain rings enclose the basin
The world SHALL be enclosed by three continuous ridge rings at about 480, 590 and
700 m from the origin. Their skylines SHALL be generated from the world seed, the
same seed SHALL always give the same skylines, and the generated geometry SHALL
NOT be saved into scene files.

#### Scenario: Same seed, same skyline
- **WHEN** the game starts twice with seed 42
- **THEN** every ring's ridge heights are identical both times

#### Scenario: Another seed
- **WHEN** the game starts with seed 7
- **THEN** the skylines differ from seed 42's, and the rings stay at the same distances

### Requirement: The rings echo one waveform
The nearest ring's skyline SHALL be a seeded waveform: a sum of a few whole-cycle
harmonics with seeded phases, plus low roughness, so it closes seamlessly around
the circle. Each farther ring SHALL repeat that waveform as an echo:
- shifted by a fixed angle around the circle per ring;
- with a smaller angular amplitude;
- standing a little higher in the view, so it shows over the nearer ring;
- lighter, hazier in colour.

The nearest ring SHALL stay within about 1–4° of elevation (8–30 m at 480 m), as in
stubby-music.

#### Scenario: An echo, not a copy
- **WHEN** ring 0's elevation profile is compared with ring 1's shifted back by the echo angle
- **THEN** they correlate strongly, and ring 1's peak-to-trough range is smaller

#### Scenario: Every ring is visible
- **WHEN** the horizon is viewed from the spawn point
- **THEN** at most bearings, each farther ring's ridge stands above the nearer ring's ridge

#### Scenario: Seamless
- **WHEN** the ridge is sampled just before and just after a full turn
- **THEN** the heights match

### Requirement: Outer ground
A dark mud plane at least 1600 m across SHALL lie just below the mudflat, so no
gap shows between the mudflat and the mountains.

#### Scenario: Looking at the horizon
- **WHEN** the player looks toward the mountains from anywhere on the mudflat
- **THEN** ground continues to the mountain bases with no sky visible below them

### Requirement: Acoustic profile of the rings
The mountain rings SHALL have an acoustic profile (in the format from
`add-acoustic-asset-profiles`) that lists them as reflectors. Each ring SHALL have
an echo delay of 2R/c (2.80 s, 3.44 s and 4.08 s at c = 343 m/s), labelled
established physics, with a delay-line DSP approximation. Like every acoustic
object, they SHALL stay silent until a discovered source excites them.

#### Scenario: Echo delays
- **WHEN** the profile is checked
- **THEN** the three rings list reflection delays within 1% of 2.80 s, 3.44 s and 4.08 s, labelled established physics

#### Scenario: Silent opening
- **WHEN** the game starts and nothing has been discovered
- **THEN** the mountains produce no sound
