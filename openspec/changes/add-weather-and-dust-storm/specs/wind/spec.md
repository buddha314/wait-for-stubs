## ADDED Requirements

### Requirement: One wind source
The world SHALL have one wind: a direction, a speed and a gust level, from the
weather controller. The clouds, the storm fog, blowing sand, reed sway and the
engine's wind parameters SHALL all read it. No consumer SHALL keep its own wind.

#### Scenario: Everything turns together
- **WHEN** the wind direction changes
- **THEN** the clouds, sand, storm fog and reeds all move with the new direction

### Requirement: Reeds sway with the wind
Reed sway SHALL scale with wind speed and lean downwind. Gusts SHALL travel across a
reed bed in the wind direction rather than moving every clump at once. Each clump
SHALL keep its seeded phase.

#### Scenario: Calm and gale
- **WHEN** the wind rises from calm to strong
- **THEN** the reeds go from a faint sway to a strong downwind lean with larger, faster sway

#### Scenario: A gust crosses the bed
- **WHEN** a gust starts
- **THEN** upwind clumps respond before downwind clumps

### Requirement: Wind reaches the engine as data
Wind speed, direction and gust level SHALL be sent to the audio engine as smoothed
parameters, for example so wind can excite reeds as quarter-wave tubes in
`add-acoustic-asset-profiles`. Wind SHALL NOT time any sound.

#### Scenario: Wind as a parameter
- **WHEN** the wind speed changes
- **THEN** the engine receives the new value as a smoothed parameter, with no event scheduled from it
