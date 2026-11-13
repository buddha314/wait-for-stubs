## ADDED Requirements

### Requirement: Stream build mode
The build key (Q) SHALL enter stream build mode when no screen is open and the player
has control. In build mode, the build key or the cancel key (Esc) SHALL leave it. While
the mode is active, interaction (E) SHALL NOT pick up or open anything, and the HUD
SHALL show that build mode is active. With one buildable there SHALL be no build menu.

#### Scenario: Entering and leaving
- **WHEN** the player presses Q while walking, then presses Q again
- **THEN** build mode starts, then ends, and E works normally again

#### Scenario: Rack screen open
- **WHEN** the burbler's rack screen is open and the player presses Q
- **THEN** build mode does not start

### Requirement: Ports and halos
A port SHALL be a point on the ground with a horizontal flow direction: a burbler's
mouth (its outlet node, flowing along the outlet's +X) or the free downstream end of a
laid stream. Each port SHALL feed at most one stream. In build mode, the free port
nearest the aim point within 3 m (measured horizontally) SHALL be the candidate, and
only the candidate's halo SHALL be visible. Outside build mode no port halo SHALL be
visible, whether or not a stream is connected.

#### Scenario: Halo at the burbler's mouth
- **WHEN** the player is in build mode and aims at the ground 2 m from a burbler's mouth with no stream connected
- **THEN** the mouth's halo appears in the stream's cross-section

#### Scenario: Taken port
- **WHEN** a stream is already laid from a burbler's mouth and the player aims at the mouth in build mode
- **THEN** the mouth is not a candidate, and the laid stream's free end is a candidate if it is within 3 m

#### Scenario: Not building
- **WHEN** the player walks past a burbler outside build mode
- **THEN** no halo is visible

### Requirement: Anchoring and planning
In build mode, the place key (left click) on a candidate port SHALL anchor a plan
there, and the cancel key (right click) SHALL drop the anchor without leaving build
mode. An anchored plan SHALL leave the port along the port's flow direction and curve
smoothly to the aim point. The aim point SHALL be clamped to 32 m from the port. A plan
SHALL be a whole number of segments, N = max(1, round(length / 4 m)), each covering
1/N of the curve, so a segment stretches by at most ±12.5% and the plan ends at the
aim point.

#### Scenario: Planning a curve
- **WHEN** the player anchors at a port and aims 10 m away, off to its side
- **THEN** a hologram of 3 segments curves from the port, leaving along its flow direction, and ends at the aim point

#### Scenario: Dropping the anchor
- **WHEN** a plan is anchored and the player right-clicks
- **THEN** the plan and hologram disappear and build mode stays active

### Requirement: Bend limit
A plan whose curve bends tighter than 2 m radius anywhere SHALL be invalid, because
its banks would fold.

#### Scenario: Doubling back
- **WHEN** the player anchors at a port and aims 3 m behind it
- **THEN** the hologram shows invalid and the plan can't be laid

### Requirement: Stream hologram
The plan SHALL be shown as the stream hologram asset, bent along the plan in the same
segments as the stream it would lay. Its flow chevrons SHALL scroll downstream at the
plan's flow speed, wrapping at the asset's chevron spacing. Every hologram material
SHALL take the asset's valid colour when the plan can be laid, and the invalid colour
otherwise.

#### Scenario: Valid plan
- **WHEN** a plan is within the bend limit and the player holds enough reeds
- **THEN** the hologram shows the valid tint and its chevrons move away from the port

#### Scenario: Invalid plan
- **WHEN** a plan bends tighter than 2 m or costs more reeds than the player holds
- **THEN** the hologram shows the invalid tint

### Requirement: Cost shown, not told
While a plan is anchored, the HUD SHALL show the cost item's icon and `need / have`
under the reticle, in the warning colour when the player is short. There SHALL be no
hint text. Validity SHALL be read from the hologram's tint.

#### Scenario: Not enough reeds
- **WHEN** a 3-segment plan needs 18 reeds and the player holds 12
- **THEN** the cost reads `18 / 12` in the warning colour, and the hologram is invalid

### Requirement: Laying and chaining
The place key on a valid plan SHALL spend its cost all or nothing, lay the stream as
bent stream segments that meet the port exactly, and make the laid stream's far end
the new anchor, so the player can keep extending. The place key on an invalid plan
SHALL lay nothing and spend nothing. Laid segments SHALL be deterministic: the same
port, aim point and segment count SHALL give the same geometry.

#### Scenario: Laying spends reeds and chains
- **WHEN** the player holds 24 reeds and lays a valid 2-segment plan
- **THEN** 12 reeds are spent, the stream lies along the plan, and a new plan is anchored at its far end

#### Scenario: Joining a stream
- **WHEN** a stream is extended from a laid stream's free end
- **THEN** the new segments continue its channel with no gap or step at the join, and the old end stops being a port

### Requirement: Dismantling streams
Outside build mode and with no screen open, the dismantle key (F) SHALL remove the laid
stream segment the player aims at within reach, from any angle, and refund all of its
materials. Segments
downstream of a removed one SHALL stay laid but lose their source, and SHALL lie quiet
until they are joined to a source again. The end left upstream of the gap SHALL become
a free port again.

#### Scenario: Removing a middle segment
- **WHEN** a 4-segment stream flows from a sounding burbler and the player dismantles segment 2
- **THEN** 6 reeds are refunded, segment 1 keeps flowing, segments 3 and 4 fall quiet, and segment 1's end is a free port
