## ADDED Requirements

### Requirement: Growing assets have bloom levels
Every growing asset SHALL define a few bloom levels as data beside its profile, each a
growth value (0 dormant .. 1 full bloom) reached only by water of at least a given
clarity. Mud SHALL be the lowest water and SHALL reach only the first level. Cleaner
water SHALL reach higher levels. The scrub oak's levels SHALL be budding (0.3, muddy
water), leafed (0.7, silty water) and full bloom (1.0, clear water).

#### Scenario: Mud wakes an oak only partly
- **WHEN** a muddy stream waters a dormant scrub oak for long enough
- **THEN** the oak reaches budding (growth 0.3) and grows no further

#### Scenario: Levels are data
- **WHEN** a growing asset's levels file is edited to give muddy water a different growth
- **THEN** watering it with mud reaches the new value, with no code change

### Requirement: Flowing streams water plants
A growing asset SHALL count as watered while a flowing stream passes within its water
reach (3 m for the scrub oak, measured horizontally), with the clearest such stream's
water. While watered, its growth SHALL rise toward the highest level that water
reaches. Without water, or with water that allows less than its current growth, it
SHALL ease back toward that level (dormant without water), more slowly than it rose.
Becoming watered and unwatered SHALL be signalled, for goals such as "Water the tree".

#### Scenario: Leading the burbler's stream to an oak
- **WHEN** the player lays a stream from a sounding burbler to within 3 m of a scrub oak
- **THEN** the oak is watered with muddy water and rises to budding

#### Scenario: The stream stops
- **WHEN** the burbler stops sounding while its stream waters an oak
- **THEN** the oak is no longer watered and its growth eases back
