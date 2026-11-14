## Why

You can do things now (collect sounds, patch the burbler, lay a stream, wake a tree)
but nothing tells you that those are the things to do, or that you did them.
Satisfactory answers with goals at two scales: a **major goal** (a long arc, like a
Space Elevator phase) made of **minor goals** (the next concrete step, like a
milestone), always visible on screen. They point the way and never end the game.

Two minor goals are already written in `assets/recipes/goals.json` (from stubby-music's
`add-inventory-and-goals-hud`, D11): "Build a heartbeat", then "Water the tree". Both
can be met in play today. They need a major goal around them, a few more steps, and a
bar that shows where the player is.

## What Changes

- **Major and minor goals.** A goal is `major` or `minor`. Each minor goal belongs to
  one major goal (`part_of`), and its minor goals are done in file order. A major goal
  completes when its last minor goal does. Then the next major goal opens. Major goals
  can come after other major goals (`after`).
- **The goal bar, upper right:** the active major goal's name with a progress bar
  (minor goals done of total), and under it the active minor goal's name and one line
  of what meets it. When a goal completes, the bar shows "GOAL COMPLETE" with its name
  for a few seconds, then the next one. It hides while a screen has the controls.
- **Minor goals are met by conditions** the world reports. Kept: `machine_configured`
  and `tree_watered`. New: `item_held { item, quantity }` (the inventory holds at least
  that many) and `tree_grown { mine, level }` (a tree of that kind reaches a bloom
  level). A goal completes the first time its condition holds while it is active, and
  stays complete.
- **Goals are written in `goals.json`**, checked on load: unknown goals, items,
  machines, mines or bloom levels, a minor goal without a major goal, a major goal with
  a condition, unknown condition kinds, and cycles are rejected, naming the goal.
  `docs/design/goals.md` is the writing guide and holds the draft goal list.
- **Schema format 2:** `horizon` (`long`/`short`) becomes `scale` (`major`/`minor`),
  and `part_of` is added. No saves exist yet, so nothing needs migrating.
- **Goals never end the game.** After the last major goal, the bar empties and play
  continues.
- **Not in this change:** delivering items to goals (`requires` still loads and
  validates, but nothing shows or completes item goals), pinned recipes, the recipe
  book, choosing the active goal, saving progress, a completion sound, and the compass
  bar (backlog).

### Existing tools this relies on

- The `Rules` autoload and the rules files with their JSON Schema
  (`assets/recipes/schema/goals.schema.json`, already ported), so editors autocomplete
  and underline mistakes while writing goals.
- Existing signals: the burbler's `sounding_changed`, the scrub oak's
  `watered_changed` and growth levels (`GrowthLevels`), `PlayerInventory.changed`.
- Godot `Control`s (`Label`, `ProgressBar`) in the HUD's style.
- stubby-music's goal model (`add-inventory-and-goals-hud` D3, D9, D11) as the design.

Written from scratch: a small goal tracker and the bar. Existing quest addons were
considered (shomykohai's Quest System, Chevifier's QuestManager, both MIT), and so was
writing goals in CSV. See design.md D1 and D7.

## Capabilities

### New Capabilities
- `goals`: major and minor goals as data and their validation, the active goals,
  condition goals and their completion, the goal bar, and the rule that goals never
  end the game.

### Modified Capabilities
<!-- none: the oak, the burbler and the inventory are only read -->

## Impact

- `assets/recipes/goals.json` (format 2, a first major goal), its schema, `ids.lock`.
- `autoload/rules.gd`: loads and validates goals.
- New autoload `Goals` (`autoload/goals.gd`): progress and condition reports.
- Reporters: `mudpit_burbler.gd`, `scrub_oak.gd` (watered, bloom level), and the
  tracker reading `PlayerInventory` for `item_held`.
- New `scenes/goal_bar/` (the bar), instanced in `main.tscn`.
- New `docs/design/goals.md` (writing guide and draft goals).
- Closes stream-building task 8.4 (the "Water the tree" hook).
