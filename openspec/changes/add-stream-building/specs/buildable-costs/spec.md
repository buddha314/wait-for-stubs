## ADDED Requirements

### Requirement: Buildables have item costs in the rules
The game SHALL read what the player can build from the rules data
(`assets/recipes/buildables.json`), each row giving an ID, a name and a cost as a list
of item stacks. Build costs SHALL NOT be hard-coded in game logic, and an asset
profile's documentation of its cost SHALL NOT be read as the rule.

#### Scenario: Shipped stream segment cost
- **WHEN** the shipped rules are loaded
- **THEN** the `stream_segment` buildable costs 6 `reed`

#### Scenario: Changing a cost without code
- **WHEN** `buildables.json` is edited so a `stream_segment` costs 4 `reed` and the game restarts
- **THEN** planning and laying a segment uses 4 reeds, with no code change

### Requirement: Buildable rules are validated on load
Loading the rules SHALL fail when a buildable names an item that doesn't exist, has a
duplicate ID, or has a cost quantity that isn't a positive whole number. The error SHALL
name the file, the buildable's ID and the field.

#### Scenario: Unknown cost item
- **WHEN** a buildable's cost names the item `reeed`
- **THEN** loading fails with an error naming `buildables.json`, the buildable and `cost`

### Requirement: Building spends all or nothing
Building N of a buildable SHALL take N times its cost from the inventory only if every
stack is fully available, and SHALL otherwise take nothing and report the shortfall for
each item.

#### Scenario: Enough items
- **WHEN** the inventory holds 13 reeds and the player builds 2 `stream_segment`
- **THEN** 12 reeds are taken and 1 remains

#### Scenario: Short by some
- **WHEN** the inventory holds 12 reeds and the player tries to build 3 `stream_segment`
- **THEN** no reeds are taken, and the shortfall reported is 6 `reed`

### Requirement: Dismantling refunds the cost
Dismantling a built thing SHALL return its full cost to the inventory.

#### Scenario: Refund a segment
- **WHEN** the player holds 0 reeds and dismantles one laid stream segment
- **THEN** the player holds 6 reeds
