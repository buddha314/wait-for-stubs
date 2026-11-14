## ADDED Requirements

### Requirement: A watered tree pulses on its source's beat
A tree watered by a stream from a sounding source SHALL pulse on each beat of that
source's clock, at the instant the beat is heard: a brief swell and glow that rises and
falls with attack and decay times. It SHALL NOT pulse when it isn't watered, when its
source is silent, or at any rate of its own.

#### Scenario: Watered by a sounding burbler
- **WHEN** an oak is connected to a stream from the burbler, which sounds at 60 BPM
- **THEN** the oak pulses once per second, each pulse at the moment the burbler's beat is heard

#### Scenario: Source silenced
- **WHEN** the player unplugs a cable so the burbler stops sounding
- **THEN** the oak stops pulsing

### Requirement: The trunk knocks on the beat
A watered tree with a sounding source SHALL sound a short knock from its trunk on each
of the source's beats, played by the audio engine on the same whole multiple of the
master clock as the source, so the knock and the source's beat land on the same sample.
Its pitch SHALL come from the trunk's height by the quarter-wave formula f = c / (4 · L),
with c and other constants in data. The tree SHALL make no sound when it isn't watered
by a sounding source.

#### Scenario: On the beat
- **WHEN** a watered oak's source sounds
- **THEN** each knock starts on the same master-clock sample as the source's beat

#### Scenario: Pitch from the trunk
- **WHEN** an oak's trunk is 2.4 m tall and c is 3800 m/s
- **THEN** its knock is pitched at about 396 Hz

#### Scenario: Silent until excited
- **WHEN** an oak has no connected stream
- **THEN** it makes no sound

### Requirement: Scrub oak acoustic profile
The scrub oak SHALL have an acoustic profile beside its asset profile, never inside the
generated `asset.json`, listing the trunk's resonance with its formula, parameters,
confidence label and citation, stating that it emits nothing of its own until excited,
and marking canopy absorption as not yet modelled.

#### Scenario: Asset check
- **WHEN** the acoustic asset check runs
- **THEN** the scrub oak's profile is found with a trunk resonance entry labelled "simplified simulation"

#### Scenario: Regenerating the model
- **WHEN** the oak generator rewrites `asset.json`
- **THEN** the acoustic profile is unchanged
