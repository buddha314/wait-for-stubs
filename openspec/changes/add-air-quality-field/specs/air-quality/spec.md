## ADDED Requirements

### Requirement: A field of 10 m cells
The world SHALL hold an air-quality value in [0, 1] for each cubic cell of the size
in `lighting_keys.json` (`light_quality.cell_size_m`, 10 m), where 0 means polluted
and bleak and 1 means clean and bloomed, defaulting to 0. Cells SHALL be stored
sparsely by integer cell coordinates, so an untouched desert holds no cells. Each
cell's value SHALL ease toward its target over at least 3 seconds.

#### Scenario: Untouched desert
- **WHEN** a new game starts and nothing has grown
- **THEN** every sample of the field reads 0 and no cells are stored beyond those with living plants

#### Scenario: Easing
- **WHEN** a cell's target jumps from 0 to 1
- **THEN** its value rises over at least 3 seconds, never stepping

### Requirement: Life sets the target
Each living plant (and later animal) SHALL register a weight at its position. A
cell's target SHALL be the total weight in it divided by a configured capacity,
clamped to [0, 1]. Cutting or killing a plant SHALL remove its weight until it
regrows. Weight SHALL count in the plant's own cell and the cell above it.

#### Scenario: Plants raise air quality locally
- **WHEN** a reed bed grows densely within a cell
- **THEN** that cell's air quality eases upward, and a cell 50 m away is unchanged

#### Scenario: Cutting lowers it
- **WHEN** the player cuts every reed clump in a cell
- **THEN** that cell's air quality eases back toward 0, and rises again as they regrow

### Requirement: One camera-local texture for rendering
The cells in a window around the camera (640 m × 80 m × 640 m by default) SHALL be
packed into one 3D texture with linear filtering, available to every shader as a
global uniform with its world origin and size. It SHALL be rewritten only when a
cell in the window changes or the window moves. Sampling SHALL blend smoothly across
cell borders.

#### Scenario: No step at a border
- **WHEN** the field is sampled along a line crossing from a cell at 0 into a cell at 1
- **THEN** the samples rise monotonically over the cell spacing with no jump larger than one interpolation step

#### Scenario: Cost
- **WHEN** 200 cells ease at once while the camera moves
- **THEN** the field's CPU time stays under 0.5 ms per frame and its upload stays at most one 3D texture per frame

### Requirement: The haze clears where the air is clean
The storm's local fog density SHALL be scaled by (1 − air quality) at that point, so
clean cells are clear pockets in the polluted haze, even during gusts.

#### Scenario: A grove in the haze
- **WHEN** the storm is strong and a cell nearby is at air quality 1
- **THEN** that cell's air is visibly clear while the polluted cells around it stay hazy

### Requirement: Bleak to bloomed look
Global lighting SHALL blend the moods in `lighting_keys.json`, in their stop order,
by the air quality sampled at the camera, smoothly across cell borders. The blend
SHALL handle any number of moods, so a `clearing` stage can be added by data alone.
Ground tint and flora emission SHALL use the air quality of the cell they are in, so
a bloomed area reads distinctly from the bleak plain around it.

#### Scenario: Walking into a grove
- **WHEN** the player walks from bleak desert into a cell at air quality 1 at night
- **THEN** the lighting eases from the bleak night key to the bloomed night key with no visible step at the cell border

#### Scenario: Seeing a grove from outside
- **WHEN** the camera stands in bleak desert looking at a bloomed area
- **THEN** that area's ground and flora show bloomed colour while the light around the camera stays bleak

#### Scenario: A third mood by data
- **WHEN** a `clearing` mood is added to `lighting_keys.json` at stop 0.5
- **THEN** air quality 0.5 shows the clearing key and 0.25 blends bleak and clearing, with no code change
