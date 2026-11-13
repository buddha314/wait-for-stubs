## ADDED Requirements

### Requirement: Every world asset has an acoustic profile
Every world asset SHALL have an acoustic profile in its own file beside the asset's
other data, never inside a file that is synced from the upstream asset source. An
asset with no acoustic role SHALL say so explicitly in its profile.

#### Scenario: New asset without a profile
- **WHEN** a world asset is added with no acoustic profile
- **THEN** the asset check fails, naming the asset

#### Scenario: Re-syncing upstream assets
- **WHEN** assets are re-synced from stubby-music
- **THEN** every acoustic profile is unchanged

### Requirement: Three kinds of acoustic asset
Assets SHALL be classified as exactly one of: a sound asset (a sample or impulse
response), an acoustic object (a physical thing that shapes sound), or a processor
(an abstract rack module). All three SHALL expose the same port interface to the
patching system. Their acquisition and physics rules SHALL be defined separately.

#### Scenario: Patching a reed and a filter
- **WHEN** a player cables a reed tube (acoustic object) and a VCF module (processor) into the same patch
- **THEN** both connect through the same kind of ports

### Requirement: Behaviours are labelled separately
A profile SHALL describe emission, transmission, reflection, absorption and resonance
as separate entries. Each entry SHALL name its physical basis, its DSP approximation
from the allowed primitives, its parameters with ranges, its coupling, and a
confidence label (established physics, simplified simulation, or gameplay
abstraction). An entry labelled established physics SHALL cite a source.

#### Scenario: Cavity coupled two ways
- **WHEN** a hollow-stump profile is read
- **THEN** it lists absorption near its resonance when standing alone, and a transmission notch when side-coupled to a channel, as separate entries

#### Scenario: Uncited physics
- **WHEN** an entry is labelled established physics with no source
- **THEN** the profile check fails

### Requirement: Geometry maps to parameters by formula
Acoustic parameters derived from geometry SHALL be computed by the shared formula
library (quarter-wave tube, Helmholtz cavity, Minnaert bubble, two-path comb) from
measurements stored in the profile. Computed frequencies SHALL lie within 20 Hz to
20 kHz, or the profile SHALL be rejected.

#### Scenario: Quarter-wave reed
- **WHEN** a reed tube has effective length 0.20 m and c = 343 m/s
- **THEN** its resonance is 428.75 Hz (±0.5 Hz)

#### Scenario: Helmholtz stump
- **WHEN** a cavity of 0.02 m³ has a neck of area 0.00785 m² and effective length 0.135 m
- **THEN** its resonance is 93.1 Hz (±1 Hz)

### Requirement: Legible approximations first
Each acoustic object SHALL map to at most three DSP primitives. Wave simulation,
measured impulse responses and modal synthesis SHALL NOT be used without a change
proposal that includes a spike.

#### Scenario: Heavier model proposed
- **WHEN** a profile's approximation uses a primitive outside the allowed set
- **THEN** the profile check fails

### Requirement: Provenance and licence for every sound asset
Every sound file SHALL have a provenance record: source, author, SPDX licence, date and
modifications. The audit SHALL derive MIT compatibility from the licence. It SHALL
accept CC0, public domain and attribution licences, adding attribution to the credits.
It SHALL reject non-commercial, no-derivatives, share-alike and unknown licences.
Asset licences SHALL be audited separately from code licences.

#### Scenario: Non-commercial sample
- **WHEN** a sample licensed CC-BY-NC is added
- **THEN** the audit fails, naming the file and its licence

#### Scenario: Attribution sample
- **WHEN** a CC-BY sample is added with a complete provenance record
- **THEN** the audit passes and the credits list its author

### Requirement: Frequency-response previews
Every acoustic object SHALL ship a generated magnitude-response preview beside its
visual previews. The preview SHALL be rendered from the profile's primitives and
parameters by a tool, never drawn by hand.

#### Scenario: Stale preview
- **WHEN** a profile's parameters change and its preview is not regenerated
- **THEN** the preview check fails

### Requirement: Experiments use the shared format
Acoustic mechanic experiments SHALL be recorded in the shared YAML format with:
id, name, hypothesis, physical basis, player action, inputs, outputs, parameters,
prototype, success criteria, risks and confidence. Success criteria SHALL include an
audible A/B comparison.

#### Scenario: Missing success criteria
- **WHEN** an experiment file has no audible success criterion
- **THEN** the experiment check fails

### Requirement: Acoustic objects respect the silent opening
An acoustic object SHALL produce no sound unless excited by a source. Sources,
including environmental ones such as wind or water, SHALL obey the same hearing
radius and silence rules as other emitters, so the world still opens in silence.

#### Scenario: Reeds in the windstorm
- **WHEN** the game starts in the silent windstorm next to a reed bed
- **THEN** nothing is audible until a discovered source excites the reeds
