## ADDED Requirements

### Requirement: A compass bar shows the heading
The game SHALL show a horizontal compass bar at the top centre of the screen, as in
Satisfactory, with the cardinal letters N, E, S and W, smaller intercardinals NE, SE, SW
and NW, and tick marks every 15°. These SHALL scroll as the view turns so that the
bearing the player faces is at the bar's centre, marked by a caret. Bearings SHALL be
measured clockwise from north, with north at −Z and east at +X (where the sun rises).

#### Scenario: Facing east
- **WHEN** the player looks along +X
- **THEN** "E" is at the centre of the bar, "N" is left of centre and "S" right of it

#### Scenario: Turning
- **WHEN** the player turns 90° to the right from east
- **THEN** "S" moves to the centre and "E" moves to the left

#### Scenario: Looking up or down
- **WHEN** the player pitches the view up or down without turning
- **THEN** the bar does not move

### Requirement: The bar fits the HUD
The bar SHALL show about 180° of bearings, SHALL fade out towards its ends, and SHALL
NOT overlap the time readout, the goal bar or the build-mode label at 1280×720.

#### Scenario: Build mode
- **WHEN** the player enters build mode
- **THEN** the build-mode label shows below the compass bar, not over it

### Requirement: The bar hides behind screens
The bar SHALL be hidden while a screen (rack, inventory) has the controls, and SHALL
show again when the screen closes.

#### Scenario: Opening the inventory
- **WHEN** the player opens the inventory screen
- **THEN** the compass bar is hidden until the screen closes

### Requirement: The game opens facing east
A new game SHALL start with the player facing east (bearing 90° ± 1°), toward the
sunrise, with the opening's composition in front of them: the mudpit burbler ahead.

#### Scenario: Spawn
- **WHEN** a new game starts
- **THEN** the player faces bearing 90°, the compass shows "E" at its centre, and the burbler lies within 10° of straight ahead

#### Scenario: Dawn
- **WHEN** the player stays at spawn until dawn
- **THEN** the sun rises ahead of them, over the burbler
