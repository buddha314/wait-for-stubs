## ADDED Requirements

### Requirement: H brings up the field recorder
The player's hand SHALL hold at most one item. The field recorder action (H by
default) SHALL bring the field recorder into the hand, and pressing it again SHALL put
the recorder away. A new game SHALL start with the recorder in the hand, so the player
sees it from the first moment. While a screen has the player's
controls (a machine's rack, the inventory), the action SHALL NOT change the hand. Each
future hand item SHALL have its own action, and bringing one up SHALL put away
whatever was held.

#### Scenario: Bringing it up and putting it away
- **WHEN** the player presses H during play, then presses H again
- **THEN** the recorder appears in the hand, then is put away and the hand is empty

#### Scenario: Screen open
- **WHEN** a machine's rack screen is open and the player presses H
- **THEN** the hand does not change

#### Scenario: New game
- **WHEN** a new game starts
- **THEN** the recorder is in the hand

### Requirement: Sounds are collected with the recorder
Collecting a sound SHALL require the recorder in the hand. A sound is any pickup whose
yields include a sound item: an item with a `waveform` (a lightning bug's square wave)
or a `sample` (an authored sound file, such as wind), read from the rules data, never a
hard-coded list. Pickups that yield no sound (reeds) SHALL be
collectable with an empty hand. When the player presses E on a sound without the
recorder in hand, nothing SHALL be collected, and the prompt line SHALL show a tip
naming the key that brings the recorder up ("Hold the field recorder to collect
sounds · [H]"), shown each time it happens, with the key read from the input map.

#### Scenario: Collecting a bug empty-handed
- **WHEN** the player has put the recorder away and presses E at a lightning bug
- **THEN** the bug is not collected, it keeps flashing, and the tip "Hold the field recorder to collect sounds · [H]" shows

#### Scenario: Reeds need no recorder
- **WHEN** the player has put the recorder away and holds E at a reed clump
- **THEN** reeds are collected as usual

#### Scenario: Recorder in hand
- **WHEN** the player holds the recorder and presses E at a lightning bug
- **THEN** the bug is collected

### Requirement: The recorder collects authored sounds, never live audio
The recorder SHALL be the tool that collects sounds that already exist in the game:
waveforms and samples defined in the rules data, each sample with a provenance record
that passes the licence audit. Recording wind, for example, SHALL collect the wind
sample item that a wind source yields. The recorder SHALL NOT capture, store or save
the game's rendered audio output.

#### Scenario: Recording the wind
- **WHEN** the player, recorder in hand, collects at a wind source whose resource yields a `wind` sample item
- **THEN** the inventory gains that predefined `wind` item, and no audio is recorded from the output

### Requirement: The meter favours what the recorder points at
Once the audio engine reports a level per emitter, the meter SHALL weight each
emitter's level by the recorder's pickup pattern (the `Capture` node's direction and
its X/Y pattern from the asset), so pointing the windguard at a source raises the
meter and turning away lowers it. Until per-emitter levels exist, the meter SHALL show
the total level without direction, and SHALL be documented as such.

#### Scenario: Pointing at a bug
- **WHEN** a single lightning bug clicks 5 m away and the player turns from facing away to facing it
- **THEN** the meter reads at least 6 dB higher facing it than facing away

#### Scenario: Before the engine
- **WHEN** stubby-rack does not yet report per-emitter levels
- **THEN** the meter shows the total level and turning does not change it

### Requirement: Held in first person at real size
The held recorder SHALL be shown at its real size (about 0.19 m tall) in the lower
right of the view, held at its grip with the windguard leaning forward, and SHALL
move with the camera. The windguard's fur shells SHALL NOT cast shadows; only the sock
beneath them SHALL cast.

#### Scenario: Looking around
- **WHEN** the player turns and looks up while holding the recorder
- **THEN** the recorder stays in the same place in the lower right of the view

#### Scenario: Fur shadows
- **WHEN** the recorder is held under the moon or the sun
- **THEN** no fur shell shadows another, and the windguard does not render black

### Requirement: The record light shows collection
The recorder's record light SHALL rise from its rest strength to its peak strength
when E collects a pickup, and fall back to rest after the collection stops, using
attack and decay times rather than a step. It SHALL rest dark at all other times,
including while a machine is being configured. The light SHALL NOT blink at a rate of
its own, so it never sets a rhythm apart from the music.

#### Scenario: Collecting a bug
- **WHEN** the player holds E within reach of a lightning bug with the recorder held
- **THEN** the record light rises to peak, and returns to dark within one second after the bug is collected

#### Scenario: Not collecting
- **WHEN** the player walks with the recorder held and collects nothing
- **THEN** the record light stays at its rest strength (dark)

### Requirement: The level meter shows what reaches the listener
The recorder's eight level bars SHALL show the level of the world and music audio
reaching the listener, lowest bar first, spanning −48 dBFS to 0 dBFS in 6 dB steps.
The meter SHALL rise immediately to a new peak and fall at a fixed rate, so bars never
flicker at frame rate. UI sounds SHALL NOT move the meter. The meter SHALL NOT produce,
time or schedule any sound.

#### Scenario: Silent opening
- **WHEN** the player holds the recorder at the start of a new game, before any sound is discovered
- **THEN** all eight bars are dark

#### Scenario: A bug clicks nearby
- **WHEN** a lightning bug clicks two metres from the player
- **THEN** the bars rise with the click and fall back after it

#### Scenario: Full scale
- **WHEN** the audio reaching the listener peaks at −9 dBFS
- **THEN** the bottom seven bars are lit and the top bar is dark (bar n lights at −48 + 6·n dBFS, so the top bar lights from −6 dBFS)

### Requirement: Recorder sounds go through the audio engine
Every sound the recorder makes SHALL play through the audio engine's sampler on the
non-spatial UI stem, timed in master-clock samples, and SHALL have a provenance record
that passes the licence audit. This covers, for example, a record click or playing
back a capture. The recorder SHALL make no sound until such a sound is specified.

#### Scenario: No sound yet
- **WHEN** the player brings up the recorder, collects with it and puts it away
- **THEN** the recorder itself adds no sound to the output

#### Scenario: A future record click
- **WHEN** a record-click sound is added to the recorder
- **THEN** it has a provenance record with an MIT-compatible licence, and it plays through the engine's sampler, not through a separate audio player

### Requirement: Acoustic profile
The field recorder SHALL have an acoustic profile beside its asset profile, never
inside the upstream `asset.json`, stating that it has no acoustic role in the world:
it neither emits, transmits, reflects, absorbs nor resonates world sound, and it is
the player's listening point.

#### Scenario: Asset check
- **WHEN** the acoustic asset check runs
- **THEN** the field recorder's profile is found and declares no acoustic role

#### Scenario: Re-syncing assets
- **WHEN** assets are re-synced from stubby-music
- **THEN** the recorder's acoustic profile is unchanged
