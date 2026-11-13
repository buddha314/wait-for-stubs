## ADDED Requirements

### Requirement: Seeded gusting storm
Storm intensity SHALL follow a seeded curve between calm and near-zero visibility,
with a calm trough guaranteed every 20–40 s. Trough times SHALL lie on the storm's
clock grid. The same seed SHALL always give the same curve.

#### Scenario: Troughs keep coming
- **WHEN** 5 minutes of storm are generated for any of 1,000 seeds
- **THEN** no gap between troughs is shorter than 20 s or longer than 40 s, and every trough lands on a grid tick

### Requirement: Storm fog and blowing sand follow intensity
A storm fog volume's density SHALL follow storm intensity. Camera-local blowing sand
SHALL follow intensity in rate, and the wind in direction and speed. Both SHALL read
the shared wind.

#### Scenario: A trough reveals the burbler
- **WHEN** a calm trough occurs
- **THEN** objects at least 60 m away read as silhouettes, as stubby-music's opening specifies

#### Scenario: Sand follows the wind
- **WHEN** the wind turns from north to east
- **THEN** the sand streams the new way within the gust ramp time

### Requirement: The storm and the opening view
The storm SHALL NOT hide the opening view (the moon and the burbler from spawn) for
the first 30 s of a new game, unless the opening is changed to start in the storm.
The choice SHALL be a single setting.

#### Scenario: Opening
- **WHEN** a new game starts with the default setting
- **THEN** storm intensity is near calm for the first 30 s, then rises on the seeded curve

### Requirement: The storm is silent until voiced
The storm SHALL produce no sound by itself. Any storm sound SHALL come from the
audio engine, driven by the storm's parameters and events.

#### Scenario: Silent storm
- **WHEN** the storm is at full intensity before the engine voices it
- **THEN** the audio output carries no storm sound
