## ADDED Requirements

### Requirement: A stream flows only from a sounding source
A laid stream SHALL flow, meaning notes, bar lines, a moving staff and water sound,
only while it is connected, through its chain of segments, to a burbler whose voice is
sounding (its rack fully patched, per `add-burbler-rack-screen`). Otherwise it SHALL
lie quiet: a still staff, no notes, no bar lines and no sound. When the source starts
sounding, notes SHALL begin on the source clock's next tick.

#### Scenario: Unpatched burbler
- **WHEN** a stream is laid from a burbler whose rack is not fully patched
- **THEN** the stream shows no notes and makes no sound

#### Scenario: Patch completed
- **WHEN** the player completes the burbler's patch while a stream is laid from it
- **THEN** the first note enters the stream on the burbler clock's next tick

### Requirement: Notes are clock ticks
Each tick of the source's clock SHALL emit one note at the stream's source. The mud
SHALL follow the source clock: it flows one note spacing (`note_spacing_m`, read from
data, 1 m for raw mud) per clock beat, so its flow speed is `note_spacing_m × BPM / 60`
and notes always sit one spacing apart. A note's distance downstream SHALL be
`note_spacing_m` × the clock beats elapsed since its tick, computed from audio sample
times mapped to audible instants, never from frame time. Notes SHALL continue across
segment joins until they reach the stream's end.

#### Scenario: Stream pulses at the burbler's tempo
- **WHEN** a stream is connected to a sounding burbler at ×60 of the 1 BPM master
- **THEN** notes enter the stream once a second, each on a clock tick's audible instant, and the mud flows at 1 m/s

#### Scenario: Tempo reads as speed
- **WHEN** a ×60 stream and a ×90 stream flow side by side
- **THEN** both have notes 1 m apart, and the ×90 stream's mud flows 1.5 times as fast

#### Scenario: Frame-rate independence
- **WHEN** the same stream runs once at 30 fps and once at 144 fps
- **THEN** each note is at the same distance downstream at the same audio time in both runs (within one frame's interpolation)

#### Scenario: Retuning the burbler
- **WHEN** the burbler's tempo changes from ×60 to ×120
- **THEN** the whole stream, notes already on it included, speeds up from 1 m/s to 2 m/s with no jump in any note's position, and notes stay 1 m apart

### Requirement: Bar lines mark measures
Every `beats_per_bar` ticks of the source clock, on its downbeat, a bar line SHALL
enter the stream half a note spacing downstream of the downbeat note, square to the
staff, and ride downstream with the notes. `beats_per_bar` SHALL be read from the
source clock's settings at run time (4 by default), never hard-coded, and SHALL NOT
come from the master transport (a master bar is 4 minutes).

#### Scenario: Measures follow the burbler
- **WHEN** a ×60 stream flows with 4 beats per bar
- **THEN** a bar line enters every 4 seconds and bar lines ride the staff 4 m apart, between the last note of one measure and the first of the next

### Requirement: The staff is a travelling wave
A flowing stream's five-line staff SHALL wave from bank to bank as the segment profile
describes, with its wave travelling downstream at the flow speed, its phase taken from
the same audio time as the notes, so each note stays on its crest. A quiet stream's
staff SHALL be still.

#### Scenario: Notes stay on the staff
- **WHEN** a note is anywhere on a flowing stream
- **THEN** it lies on the staff's centre line (plus its pitch offset) at its position, turned to the line's slope

### Requirement: Clarity stages
A stream's water, staff glow and bank reeds SHALL be set from its clarity (0 muddy to
1 clear), blending the segment profile's stages. Streams from a burbler SHALL carry
raw mud (clarity 0), and their staff and notes SHALL still show, dimmer than on clear
water. Note spacing SHALL be a property of the stream's fluid, read from data (1 m
for raw mud), so cleaning and viscosity can change it later; flow speed is always that
spacing per beat of the source clock.

#### Scenario: Muddy water is still sheet music
- **WHEN** a stream carries raw mud
- **THEN** its water is the muddy stage's colour, its reeds are dry, and its staff and notes are visible

### Requirement: The voice is heard along the stream
A burbler's voice SHALL be heard from the point of the burbler or of its flowing
streams nearest the listener, so a patched burbler can be found by following its
streams by ear. Distance attenuation SHALL be measured from that point, and the voice
SHALL fade to silence at the machine's hearing radius.

#### Scenario: Following the stream
- **WHEN** the listener stands 2 m from the end of a 30 m stream that flows from a sounding burbler
- **THEN** the burbler's voice is heard from the stream's end, 2 m away, not from the burbler 30 m away

### Requirement: Stream acoustic profile
The stream segment SHALL have an acoustic profile classed as an acoustic object that is
also a source. Its entries SHALL include: emission (flowing water as noise grains
through bubble resonances sized by the Minnaert formula, labelled simplified because
mud is denser and lossier than water), absorption by the mud bed, and reflection
between its banks, each with its DSP approximation, parameter ranges, coupling and
confidence label. The stream's water sound SHALL play only while the stream flows, so
the world still opens silent.

#### Scenario: Profile present and valid
- **WHEN** the asset check runs
- **THEN** `stream_segment` has an `acoustics.json` that validates, and its emission entry is labelled simplified

#### Scenario: Quiet until excited
- **WHEN** a stream is laid from an unpatched burbler
- **THEN** it makes no water sound
