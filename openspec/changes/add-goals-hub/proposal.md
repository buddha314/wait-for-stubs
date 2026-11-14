## Why

You can do things now (collect sounds, patch the burbler, lay a stream, wake a tree)
but nothing tells you that those are the things to do, or that you did them. In
Satisfactory, goals in the upper right point the way and open what comes next, and
they never end the game. The first two goals are already written in
`assets/recipes/goals.json` (from stubby-music's `add-inventory-and-goals-hud`, D11):
"Build a heartbeat", then "Water the tree". Both can now be met in play, because the
burbler sounds when patched and streams water scrub oaks.

## What Changes

- **Goals load from `goals.json` and are checked on load**, as in stubby-music:
  unknown goals, items, machines or mines, both or neither of `requires` and
  `condition`, unknown condition kinds, and prerequisite cycles are all rejected,
  naming the goal.
- **Chores complete when the world makes their condition true:**
  `machine_configured { machine }` holds while a machine of that kind is fully
  patched and sounds; `tree_watered { mine }` holds while a flowing stream waters a
  tree of that kind. A chore completes once, the first time its condition holds while
  it is open (including when it opens), and stays complete.
- **A goals panel in the upper right** shows the active short-term goal (name and
  one line of what meets it) and the active long-term goal, if one exists. When a
  goal completes, the panel shows "GOAL COMPLETE" with its name for a few seconds,
  then the next open goal.
- **Goals never end the game.** When the last goal completes, the panel empties and
  play continues.
- **Not in this change** (stubby-music's later steps): item goals' delivery, pinned
  recipes, the recipe book, choosing the active goal, saving progress, and a
  completion sound. Item goals load and validate, but nothing shows or completes
  them yet; `goals.json` has none.

### Existing tools this relies on

- The `Rules` autoload and the rules files with their JSON schema
  (`assets/recipes/schema/goals.schema.json`, already ported).
- Existing signals: the burbler's `sounding_changed`, the scrub oak's
  `watered_changed`.
- Godot `Control`s in the HUD's style for the panel.
- stubby-music's goal model (`add-inventory-and-goals-hud` D3, D9, D11) as the design.

Written from scratch: a small goal tracker (open, active, latched completion) and the
panel. Existing quest addons were considered (shomykohai's Quest System, Chevifier's
QuestManager, both MIT). See design.md D1.

## Capabilities

### New Capabilities
- `goals`: goal data and validation, open and active goals, condition goals
  (chores) and their completion, the upper-right panel, and the rule that goals
  never end the game.

### Modified Capabilities
<!-- none: the oak's watering and the burbler's sounding are only read -->

## Impact

- `autoload/rules.gd`: loads and validates `goals.json`.
- New autoload `Goals` (`autoload/goals.gd`): progress and condition reports.
- `assets/machines/mudpit_burbler/mudpit_burbler.gd` and
  `assets/flora/scrub_oak/scrub_oak.gd`: report their conditions.
- New `scenes/goals_hub/` (panel), instanced in `main.tscn`.
- Closes stream-building task 8.4 (the "Water the tree" hook).
