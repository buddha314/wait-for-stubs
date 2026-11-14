## ADDED Requirements

### Requirement: Goals are major or minor, written as data
Goals SHALL be read from the rules file `goals.json`, each with an id, a name, a
description and a scale, major or minor. A minor goal SHALL belong to one major goal
and SHALL have either a condition or required items. A major goal SHALL have neither:
its minor goals, in file order, are its steps. Any goal MAY list goals it comes after.

#### Scenario: The shipped goals
- **WHEN** the game loads the shipped `goals.json`
- **THEN** every goal loads with no errors, and each minor goal belongs to a major goal

#### Scenario: Steps in order
- **WHEN** a major goal has the minor goals "Build a heartbeat" then "Water the tree" in the file
- **THEN** "Build a heartbeat" is its first step and "Water the tree" its second

### Requirement: Goals are checked on load
Loading SHALL reject, naming the goal and the field: a duplicate id, a missing or
unknown scale, a minor goal without a major goal, a major goal with a condition,
required items or a major goal of its own, a minor goal with both or neither of a
condition and required items, an unknown condition kind, item, machine, mine or bloom
level, an unknown goal it comes after, and a cycle. A rejected goal SHALL be left out,
and a rejected major goal SHALL take its minor goals with it.

#### Scenario: Unknown condition
- **WHEN** a minor goal names a condition kind the schema does not define
- **THEN** loading reports an error naming the goal and the condition, and that goal is left out

#### Scenario: Orphan step
- **WHEN** a minor goal names a major goal that does not exist
- **THEN** loading reports an error naming the goal and its major goal

#### Scenario: Cycle
- **WHEN** major goal A comes after B and B comes after A
- **THEN** loading reports the cycle, naming the goals

### Requirement: Active goals
The active major goal SHALL be the first incomplete major goal in file order whose
earlier goals are complete. Its active minor goal SHALL be its first incomplete minor
goal whose earlier goals are complete. A major goal SHALL complete when its last minor
goal completes, and the next major goal SHALL then become active.

#### Scenario: A new game
- **WHEN** a new game starts
- **THEN** the first major goal is active, and its first minor goal is the active step

#### Scenario: The next step
- **WHEN** the active minor goal completes and its major goal has more steps
- **THEN** the next step becomes active, and the major goal's count rises by one

#### Scenario: The last step
- **WHEN** the last minor goal of a major goal completes
- **THEN** the major goal completes and the next major goal becomes active

### Requirement: Minor goals complete when their condition holds
A minor goal with a condition SHALL complete the first time the condition holds while
the goal is active, including at the moment it becomes active, and SHALL stay complete
if the condition later stops holding. Completion SHALL be reported exactly once. The
conditions SHALL be: a machine of the named kind is fully patched and sounds; a
flowing stream waters a tree of the named kind; a tree of the named kind is at the
named bloom level or above; the inventory holds at least the named quantity of an item.

#### Scenario: Build a heartbeat
- **WHEN** "Build a heartbeat" is active and the player patches the burbler's last cable so it sounds
- **THEN** the goal completes and the next step becomes active

#### Scenario: Unpatching later
- **WHEN** the player unplugs a cable from the burbler after "Build a heartbeat" completed
- **THEN** the goal stays complete

#### Scenario: Water the tree
- **WHEN** "Water the tree" is active and a stream from the sounding burbler reaches within watering range of a scrub oak
- **THEN** the goal completes

#### Scenario: Holding items
- **WHEN** a step needs 12 reeds held, and the player already holds 12 when it becomes active
- **THEN** the step completes at once

#### Scenario: A tree buds
- **WHEN** a step needs a scrub oak at budding, and a watered oak reaches budding
- **THEN** the step completes

#### Scenario: Reported twice
- **WHEN** a condition is reported to hold twice for the active step
- **THEN** the step is reported complete once

### Requirement: The goal bar
During play the upper right of the screen SHALL show the active major goal's name, a
progress bar with its count of completed and total steps, and the active step's name
and description. When a goal completes, the bar SHALL show that it completed, with its
name, for about 4 seconds, then the active goals. The bar SHALL be hidden while a
screen has the player's controls, and SHALL leave the top centre of the screen free.

#### Scenario: Starting out
- **WHEN** a new game starts
- **THEN** the bar shows the first major goal at 0 of its steps, and its first step's name and description

#### Scenario: A step completes
- **WHEN** "Build a heartbeat" completes as step 2 of 5
- **THEN** the bar shows "GOAL COMPLETE · Build a heartbeat" for about 4 seconds, then the major goal at 2 of 5 and the next step

#### Scenario: Rack screen open
- **WHEN** the burbler's rack screen is open
- **THEN** the goal bar is hidden, and it returns when the screen closes

### Requirement: Goals never end the game
Completing the last major goal SHALL NOT end, pause or reset the game. The bar SHALL
then show no goal, and play SHALL continue.

#### Scenario: Last goal
- **WHEN** the last step of the last major goal completes
- **THEN** no ending appears, the bar is empty after the completion notice, and the player keeps playing
