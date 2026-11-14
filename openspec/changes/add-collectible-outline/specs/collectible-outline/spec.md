## ADDED Requirements

### Requirement: The targeted pickup is outlined
The game SHALL draw an outline around the visible body of the pickup that is the
player's current interaction target, and around no other pickup. When the target changes,
the outline SHALL move to the new target within the same frame. When nothing is targeted,
no pickup SHALL be outlined.

#### Scenario: Aiming at a reed clump
- **WHEN** the player walks up to a reed clump and it becomes the interaction target
- **THEN** the clump's standing reeds are outlined, and no other pickup is

#### Scenario: Turning from one pickup to another
- **WHEN** the target changes from a snail shell to a lightning bug
- **THEN** the shell loses its outline and the bug gains one in the same frame

#### Scenario: Walking away
- **WHEN** the player moves so that nothing is in reach
- **THEN** no pickup is outlined

### Requirement: The crosshair picks the target
The interaction target SHALL be the interactable in reach nearest the centre of the
view, within 20° of it, as in Satisfactory. Only when none is within that cone SHALL the
target fall back to the nearest interactable in reach, measured horizontally, so holding
E still sweeps through nearby pickups.

#### Scenario: A shell beside a reed clump
- **WHEN** a snail shell lies 1 m from a reed clump and the player, nearer the clump, looks at the shell
- **THEN** the shell is the target and is outlined, not the clump

#### Scenario: Looking at the sky in a reed bed
- **WHEN** the player stands in a reed bed looking up, with no pickup within 20° of the view
- **THEN** the nearest clump is still the target

### Requirement: The outline follows the visible body
The outline SHALL trace the parts of the pickup the player sees as the collectible
thing, including parts that move (a hovering bug's body). It SHALL NOT trace hidden or
leftover parts, such as cut reed stubble.

#### Scenario: A hovering bug
- **WHEN** a lightning bug hovering at 1.5 m is targeted
- **THEN** the outline surrounds the bug's body at its hover height, not the ground below it

#### Scenario: A bug between flashes
- **WHEN** a targeted lightning bug is dark between flashes
- **THEN** its body is shown as a dark silhouette at full size inside the outline, it still flashes white on its clock, and it gives no light between flashes

### Requirement: Collected pickups lose the outline
A pickup SHALL lose its outline the moment it is collected, even if it is still the
nearest interactable, and SHALL NOT be outlined again until it has replenished.

#### Scenario: Holding E through a reed bed
- **WHEN** the player holds E and the targeted clump is cut to stubble
- **THEN** the stubble is not outlined, and the next uncollected clump in reach is

### Requirement: Uncollectable targets are still outlined
A targeted pickup SHALL be outlined even when it can't be collected right now (a sound
with no field recorder in hand, or a full inventory). The prompt and tip explain why.

#### Scenario: A bug without the recorder
- **WHEN** the player, with the recorder put away, targets a lightning bug
- **THEN** the bug is outlined, and pressing E shows the recorder tip

### Requirement: No outline while the controls are elsewhere
No pickup SHALL be outlined while a screen has the controls or while stream build mode
is on.

#### Scenario: Opening the inventory
- **WHEN** a reed clump is outlined and the player opens the inventory screen
- **THEN** the outline disappears, and comes back when the screen closes and the clump is still the target

#### Scenario: Build mode
- **WHEN** the player enters build mode while targeting a snail shell
- **THEN** the shell is not outlined

### Requirement: The outline's look is white and data-driven
The outline SHALL be white by default, a line of constant colour and constant on-screen
width that is not lit by the scene, as in Satisfactory. Its colour and width SHALL be
read from a data file, not set in code.

#### Scenario: Default look
- **WHEN** the game runs with the shipped settings
- **THEN** the targeted pickup's outline is white (#ffffff), at night and by day alike

#### Scenario: Small and large pickups alike
- **WHEN** a 9 cm snail shell and a 1.5 m reed clump are each targeted from the same distance
- **THEN** both outlines are the same width on screen, and neither is filled in by it

#### Scenario: Changing the colour
- **WHEN** the outline colour in the data file is changed and the game restarts
- **THEN** the outline is drawn in the new colour with no code change
