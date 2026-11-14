## ADDED Requirements

### Requirement: Goals are data, validated on load
Goals SHALL be read from the rules file `goals.json`, each with an id, a name, a
description, a horizon (short or long), either required items or a condition, the
goals it comes after, and what it unlocks. Loading SHALL reject, naming the goal and
the field, a duplicate id, a goal with both or neither of required items and a
condition, an unknown condition kind, an unknown item, machine or mine, an unknown
goal in its prerequisites, and a prerequisite cycle.

#### Scenario: The shipped goals
- **WHEN** the game loads the shipped `goals.json`
- **THEN** "Build a heartbeat" and "Water the tree" load with no errors

#### Scenario: Unknown condition
- **WHEN** a goal names a condition kind the schema does not define
- **THEN** loading reports an error naming the goal and the condition, and that goal is left out

#### Scenario: Cycle
- **WHEN** goal A comes after B and B comes after A
- **THEN** loading reports the cycle, naming the goals

### Requirement: Open and active goals
A goal SHALL be open when every goal it comes after is complete. The active goal of
each horizon SHALL be the first open, incomplete goal of that horizon in file order,
and a horizon with none SHALL have no active goal.

#### Scenario: A new game
- **WHEN** a new game starts
- **THEN** "Build a heartbeat" is the active short-term goal and "Water the tree" is not open

#### Scenario: The next goal
- **WHEN** "Build a heartbeat" completes
- **THEN** "Water the tree" opens and becomes the active short-term goal

### Requirement: Chores complete when their condition holds
A goal with a condition SHALL complete the first time its condition holds while the
goal is open, including at the moment it opens, and SHALL stay complete if the
condition later stops holding. `machine_configured` SHALL hold while a machine of the
named kind is fully patched and sounds. `tree_watered` SHALL hold while a flowing
stream waters a tree of the named kind. Completion SHALL be reported exactly once.

#### Scenario: Build a heartbeat
- **WHEN** "Build a heartbeat" is active and the player patches the burbler's last cable so it sounds
- **THEN** the goal completes and "Water the tree" opens

#### Scenario: Unpatching later
- **WHEN** the player unplugs a cable from the burbler after "Build a heartbeat" completed
- **THEN** the goal stays complete

#### Scenario: Water the tree
- **WHEN** "Water the tree" is active and a stream from the sounding burbler reaches within watering range of a scrub oak
- **THEN** the goal completes

#### Scenario: Already true when it opens
- **WHEN** a goal's condition already holds at the moment the goal opens
- **THEN** the goal completes at once

#### Scenario: Reported twice
- **WHEN** a condition is reported to hold twice for a goal
- **THEN** the goal is reported complete once

### Requirement: The goals panel, upper right
During play the upper right of the screen SHALL show the active short-term goal's
name and description, and the active long-term goal's if there is one. When a goal
completes, the panel SHALL show that it completed, with its name, for about 4
seconds, then the next active goal. The panel SHALL be hidden while a screen has the
player's controls.

#### Scenario: Showing the chore
- **WHEN** a new game starts
- **THEN** the upper right shows "Build a heartbeat" and its description

#### Scenario: Completion
- **WHEN** "Build a heartbeat" completes
- **THEN** the panel shows "GOAL COMPLETE · Build a heartbeat" for about 4 seconds, then "Water the tree"

#### Scenario: Rack screen open
- **WHEN** the burbler's rack screen is open
- **THEN** the goals panel is hidden, and it returns when the screen closes

### Requirement: Goals never end the game
Completing the last goal SHALL NOT end, pause or reset the game. The panel SHALL then
show no goal, and play SHALL continue.

#### Scenario: Last goal
- **WHEN** "Water the tree" completes and no other goal is open
- **THEN** no ending appears, the panel is empty after the completion notice, and the player keeps playing
