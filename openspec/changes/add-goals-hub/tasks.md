## 0. Content (user)

- [ ] 0.1 Sign off the first major goal and its steps in `docs/design/goals.md` (the draft is provisional until then)
- [ ] 0.2 Name the major goals after it (they can stay as titles until their conditions exist)

## 1. Data

- [ ] 1.1 Schema format 2: `scale` (`major`/`minor`) replaces `horizon`; `part_of`; conditions `item_held { item, quantity }` and `tree_grown { mine, level }`; update `assets/recipes/README.md` (schema now edited by hand)
- [ ] 1.2 `goals.json` format 2 with the draft first major goal from `docs/design/goals.md`; new ids in `ids.lock`
- [ ] 1.3 `Rules` loads goals with D6's checks in the existing error format; `Rules.goals()` in file order
- [ ] 1.4 Headless test: shipped goals load clean; each D6 rejection names the goal (unknown kind, orphan step, major with a condition, both/neither, unknown item/machine/mine/level, unknown `after`, cycle); a rejected major goal drops its steps

## 2. Tracker

- [ ] 2.1 `Goals` autoload: `report(kind, args, instance_id, holds)`, latched completion, active major and active step (D2, D3), `item_held` from `PlayerInventory.changed`, signals `goal_completed(id)` and `active_changed`
- [ ] 2.2 Headless test with a test goal list: new game's active goals; steps in order; major completes on its last step and the next opens; latched after the condition stops; already-true-on-activation completes; one `goal_completed` for repeated reports; empty after the last major goal

## 3. Reporters

- [ ] 3.1 Burbler reports `machine_configured` on `sounding_changed` (and its state at start)
- [ ] 3.2 Scrub oak reports `tree_watered` on `watered_changed` and `tree_grown` when its bloom level changes
- [ ] 3.3 Headless test in the real scenes: completing the burbler's patch completes "Build a heartbeat"; a laid, flowing stream by an oak completes "Water the tree" and, after growth, the budding step (reuse `test_streams.gd`'s setup)

## 4. Goal bar

- [ ] 4.1 `scenes/goal_bar/goal_bar.tscn` + `.gd`, upper right (D5): major goal name, progress bar and count, the active step's name and description, the 4 s "GOAL COMPLETE · <name>" notice, hidden while `controls_enabled` is false; instanced in `main.tscn`
- [ ] 4.2 Headless test: bar text at start, the notice then the next step and count, hidden with the rack screen open, empty after the last goal
- [ ] 4.3 Screenshot check of the opening: the bar clears the reticle, the prompt, the time readout and the top centre

## 5. Wrap-up

- [ ] 5.1 Mark `add-stream-building` 8.4 done (goal hook)
- [ ] 5.2 CLAUDE.md: goals, the tracker, how to write goals (`docs/design/goals.md`), how to add a condition kind
- [ ] 5.3 `openspec validate --strict add-goals-hub`
