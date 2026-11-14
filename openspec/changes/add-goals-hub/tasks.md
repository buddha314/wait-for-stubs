## 1. Data

- [ ] 1.1 `Rules` loads `goals.json` with D6's checks in the existing error format; `Rules.goals()` in file order
- [ ] 1.2 Headless test: shipped goals load clean; unknown condition, unknown machine or mine, both/neither, unknown `after`, and a cycle are each rejected, naming the goal

## 2. Tracker

- [ ] 2.1 `Goals` autoload: `report(kind, arg, instance_id, holds)`, completed set (latched), `is_open`, `active(horizon)`, signals `goal_completed(id)` and `active_changed`; completion checked on report and on opening (D2, D4)
- [ ] 2.2 Headless test: a new game's active goal; completing opens the next; latched after the condition stops; already-true-on-open completes; one `goal_completed` for repeated reports; empty after the last goal

## 3. Reporters

- [ ] 3.1 Burbler reports `machine_configured`/`mudpit_burbler` on `sounding_changed` (and its state at start)
- [ ] 3.2 Scrub oak reports `tree_watered`/`scrub_oak` on `watered_changed`
- [ ] 3.3 Headless test in the real scenes: completing the burbler's patch completes "Build a heartbeat"; a laid, flowing stream by an oak completes "Water the tree" (reuse `test_streams.gd`'s setup)

## 4. Panel

- [ ] 4.1 `scenes/goals_hub/goals_hub.tscn` + `.gd`, upper right, in the HUD's text style: active short-term and long-term goals, the 4 s "GOAL COMPLETE · <name>" notice, hidden while `controls_enabled` is false; instanced in `main.tscn`
- [ ] 4.2 Headless test: panel text at start, the notice then the next goal, hidden with the rack screen open, empty after the last goal
- [ ] 4.3 Screenshot check of the opening with the panel (it must not cover the reticle, prompt or time readout)

## 5. Wrap-up

- [ ] 5.1 Mark `add-stream-building` 8.4 done (goal hook)
- [ ] 5.2 CLAUDE.md: goals, the tracker, how to add a condition kind (schema, `Rules` check, a reporter)
- [ ] 5.3 `openspec validate --strict add-goals-hub`
