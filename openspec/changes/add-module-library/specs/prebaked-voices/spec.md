## ADDED Requirements

### Requirement: Voices are ordinary patches
Each pre-baked voice SHALL be a saved patch (modules, parameter values, cables) built
only from catalogue modules, with a short description naming its synthesis path
(east, west, percussion, ambient) and its modules. A voice SHALL contain no code of
its own. The shipped set SHALL include at least: Moog bass, acid line, brass stab,
strings/pad, drone, Buchla bongo, LPG pluck, west-coast lead, Benjolin chaos, drum
kit, bell/mallet, wind through reeds, mudpit burble, bug click and tape memory.

#### Scenario: Open and change a voice
- **WHEN** the player loads the Moog bass into a rack holding its modules and turns the ladder's cutoff
- **THEN** the voice plays and the change is heard like any other patch edit

#### Scenario: Missing module
- **WHEN** a voice is loaded into a rack that lacks one of its modules
- **THEN** the load names the missing modules and changes nothing

### Requirement: Voices are timed by the master clock
Every clock, sequencer and synced effect inside a voice SHALL run at a whole multiple
of the master clock, so voices loaded into different machines share downbeats.

#### Scenario: Two machines, one grid
- **WHEN** the Buchla bongo and the drum kit play in two machines
- **THEN** their beats coincide on every master beat

### Requirement: Voices are unlocked as recipes
Voices SHALL be unlocked through the recipe data, not hard-coded. An unlocked voice
SHALL appear in the rack screen's patch list.

#### Scenario: Unlock
- **WHEN** the player completes a voice's recipe
- **THEN** the voice appears in the patch list of every rack that can hold it

### Requirement: Voice renders are reproducible
Each voice SHALL have an offline reference render. The test suite SHALL render each
voice from its patch and match its reference within the tolerance its modules allow.

#### Scenario: Regression
- **WHEN** a module's DSP changes and a voice using it no longer matches its reference
- **THEN** the voice test fails, naming the voice
