## 0. Content (user)

- [x] 0.1 First major goal (user, 2026-11-13): "Build a camp": water the tree until it buds to stop the wind, then build a campfire (reeds + a spark). Steps in `docs/design/goals.md`
- [ ] 0.2 Name the major goals after it (they can stay as titles until their conditions exist)

## 1. Data

- [x] 1.1 Schema format 2: `scale` (`major`/`minor`) replaces `horizon`; `part_of`; conditions `item_held { item, quantity }` and `tree_grown { mine, level }`; update `assets/recipes/README.md` (schema now edited by hand)
- [x] 1.2 `goals.json` format 2 with "Build a camp" steps 1–5 from `docs/design/goals.md` (step 6 comes with the campfire change); new ids in `ids.lock`
- [x] 1.3 `Rules` loads goals with D6's checks in the existing error format; `Rules.goals()` in file order
- [x] 1.4 Headless test: the shipped `goals.json` loads with no errors (nothing about its content); each D6 rejection, on fixture rows, names the goal (unknown kind, orphan step, major with a condition, both/neither, unknown item/machine/mine/level, unknown `after`, cycle); a rejected major goal drops its steps

## 2. Tracker

- [x] 2.1 `Goals` autoload: `load(rows)` (the shipped goals by default; tests pass fixtures), `report(kind, args, instance_id, holds)`, latched completion, active major and active step (D2, D3), `item_held` from `PlayerInventory.changed`, signals `goal_completed(id)` and `active_changed`
- [x] 2.2 Headless test with a fixture goal list (`tests/fixtures/goals.json`, never the shipped one): new game's active goals; steps in order; major completes on its last step and the next opens; latched after the condition stops; already-true-on-activation completes; one `goal_completed` for repeated reports; empty after the last major goal

## 3. Reporters

- [x] 3.1 Burbler reports `machine_configured` on `sounding_changed` (and its state at start)
- [x] 3.2 Scrub oak reports `tree_watered` on `watered_changed` and `tree_grown` when its bloom level changes
- [x] 3.3 Headless test in the real scenes, with a fixture goal list: completing the burbler's patch reports `machine_configured`; a laid, flowing stream by an oak reports `tree_watered` and, after growth, `tree_grown` budding (added to `test_rack_screen.gd` and `test_streams.gd`, which already drive the real scenes; they check the reports, not goals)

## 4. Goal bar

- [x] 4.1 `scenes/goal_bar/goal_bar.tscn` + `.gd`, upper right (D5): major goal name, progress bar and count, the active step's name and description, the 4 s "GOAL COMPLETE · <name>" notice, hidden while `controls_enabled` is false; instanced in `main.tscn`
- [x] 4.2 Headless test with a fixture goal list: bar text at start, the notice then the next step and count, hidden with the rack screen open, empty after the last goal
- [x] 4.3 Screenshot check of the opening: the bar clears the reticle, the prompt, the time readout and the top centre

## 5. Wrap-up

Goal content iterates (user, 2026-11-13): no test names a shipped goal, counts its steps
or depends on its order. Tests use fixtures; the shipped file is only checked to load.

- [x] 5.1 Mark `add-stream-building` 8.4 done (goal hook)
- [x] 5.2 CLAUDE.md: goals, the tracker, how to write goals (`docs/design/goals.md`), how to add a condition kind
- [x] 5.3 `openspec validate --strict add-goals-hub`
