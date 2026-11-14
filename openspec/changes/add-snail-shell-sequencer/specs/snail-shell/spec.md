## ADDED Requirements

### Requirement: Snail shells lie near the reeds
The world SHALL hold a few empty, high-spired snail shells of four whorls on the mud at
the edges of the reed beds, each placed by a seeded scatter with its own stable
identity, so the same seed puts them in the same places. Each SHALL be collectable with
E into a `snail_shell` item without the field recorder, and SHALL NOT return once
collected.

#### Scenario: Finding one
- **WHEN** the player walks the edge of a reed bed in a new game
- **THEN** a snail shell lies on the mud there, and the prompt offers to collect it

#### Scenario: Collecting with an empty hand
- **WHEN** the player has put the recorder away and presses E at a shell
- **THEN** the inventory gains one snail shell and the shell is gone from the mud

#### Scenario: Same seed, same shells
- **WHEN** two games start with the same seed
- **THEN** their shells lie in the same places

### Requirement: Snail shell acoustic profile
The snail shell SHALL have an acoustic profile beside its asset profile, never inside the
generated `asset.json`, stating that it emits nothing and listing its cavity's Helmholtz
resonance with formula, parameters, confidence label and citation, marked as not
excited by anything yet.

#### Scenario: Asset check
- **WHEN** the acoustic asset check runs
- **THEN** the shell's profile is found with a Helmholtz resonance entry labelled "simplified simulation"
