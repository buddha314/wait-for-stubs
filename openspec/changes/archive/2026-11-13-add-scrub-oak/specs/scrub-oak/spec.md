## ADDED Requirements

### Requirement: A seeded tree per instance
Each placed scrub oak SHALL choose its variant, yaw, scale, height stretch, lean,
sway phase, leaf value jitter and bloom tint from (world seed, instance id), within
the profile's `per_instance` ranges. The same seed and id SHALL always give the same
tree. Its generated parts SHALL NOT be saved into scene files.

#### Scenario: Same seed, same tree
- **WHEN** the opening loads twice with seed 42
- **THEN** each oak has the same variant, yaw and scale both times

### Requirement: Growth is displayed from the profile
A scrub oak SHALL display a growth value from 0 (dormant) to 1 (full bloom) using the
profile's `growth` ramps, node rules and colours, starting at the profile's `starts`.
At 0 its blooms SHALL be closed and its dead leaves present. At 1 every bloom SHALL
be open and no dead leaves shown.

#### Scenario: Dormant at the start
- **WHEN** a new game starts
- **THEN** every oak shows grey bark, dry leaves, tight buds and no blooms

#### Scenario: Full bloom
- **WHEN** an oak's growth is set to 1
- **THEN** its foliage is fully grown, its dead leaves are gone, and every bloom is open

### Requirement: Near and far detail
Both levels of detail inside the model SHALL be used: the near level within the
profile's `far_lod.distance_m` (45 m), and the far level beyond it, crossfading at
the boundary.

#### Scenario: Walking away
- **WHEN** the player walks from 10 m to 60 m from an oak
- **THEN** the near meshes are drawn first and the far meshes beyond 45 m, with no gap

### Requirement: Solid trunk
A scrub oak SHALL block the player with the static collider listed for its variant
in `colliders.json`.

#### Scenario: Walking into a tree
- **WHEN** the player walks into an oak
- **THEN** they stop at its collider

### Requirement: Oaks in the opening
The opening SHALL have three scrub oaks near the lightning bugs, each with a unique
instance id.

#### Scenario: Opening scene
- **WHEN** the opening loads
- **THEN** three dormant scrub oaks stand near the bug clusters
