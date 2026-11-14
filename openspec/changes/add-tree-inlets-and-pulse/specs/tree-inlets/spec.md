## ADDED Requirements

### Requirement: Trees have root inlets
Each scrub oak SHALL have one or more inlets at its roots where a stream can connect
(the number is a model setting), each shown
with a halo while it is the build candidate. Inlets SHALL be part of the tree's model,
and their positions SHALL vary between instances with the tree's seeded variant.

#### Scenario: Seeing where to connect
- **WHEN** the player is anchored on a port in build mode and aims within 3 m of a free inlet of an oak
- **THEN** that inlet's halo shows

#### Scenario: Instances differ
- **WHEN** two oaks have different instance ids
- **THEN** their inlets sit at different angles around their trunks

### Requirement: Streams snap to an inlet and connect
While planning a stream, a free inlet within 3 m of the aim SHALL take the plan's end:
the plan SHALL end exactly at the inlet, arriving along it, or be invalid if the bend
limit can't be met. Laying such a plan SHALL connect the stream to the tree, take the
inlet, and leave the stream with no free end. Dismantling the connected segment SHALL
free the inlet.

#### Scenario: Snapping
- **WHEN** the player aims 2 m from a free inlet while planning
- **THEN** the hologram ends at the inlet

#### Scenario: Connecting
- **WHEN** the player lays a plan that ends at an inlet
- **THEN** the stream is connected to the tree, the inlet is taken, and the stream can't be extended past it

#### Scenario: Freeing
- **WHEN** the player dismantles the segment connected to an inlet
- **THEN** the inlet is free again and the tree is no longer watered by that stream

### Requirement: Trees with inlets are watered by connection
A tree with inlets SHALL be watered only by flowing streams connected to its inlets, at
the clearest such stream's clarity. A stream end near the tree but not connected SHALL
NOT water it.

#### Scenario: Connected and flowing
- **WHEN** a stream from the sounding burbler is connected to an oak's inlet
- **THEN** the oak is watered

#### Scenario: Near but not connected
- **WHEN** a stream's free end lies 2 m from an oak but isn't connected to an inlet
- **THEN** the oak is not watered
