## Context

Ports the goals part of stubby-music's `add-inventory-and-goals-hud`: its spec
"goals-hub" and decisions D3 (delivery), D9 (an event reducer), D10 (save shape) and
D11 (chores). Bevy built the data side only: `goals.json`, its schema,
`GoalDefinition`, `Condition` and validation in `stubby_recipes` (tasks 1.5b, 1.6a).
The reducer, the hub and the condition reports were never built.

Here, `goals.json` and its schema are already copied. `Rules` loads the other rules
files with validation errors as `file: id: field: message`. The two conditions have
sources: `MudpitBurbler.sounding_changed` (the rack is complete) and
`ScrubOak.watered_changed` (a flowing stream within reach). The HUD
(`scenes/hud/`) holds the reticle, prompt and status. The upper right is empty.

## Goals / Non-Goals

**Goals:**
- The two chores show, complete in play, and lead from one to the next.
- Data stays in `goals.json`, validated like the other rules files.
- The goal tracker takes events and holds progress, with no scene knowledge, so it
  can be tested headless and replicated later (multiplayer: goals follow
  server-authoritative world state).

**Non-Goals:**
- Item goals' delivery (D3 there) and where items are handed in (its open question
  0.1). Pins and the recipe book (O). Choosing the active goal. Saving.
- A completion sound. It would play through the engine's sampler on the UI stem,
  with a provenance record. That's a later, small change.
- The first long-term goal (stubby-music's open question 0.2).

## Decisions

**D1. Our own small tracker, not a quest addon.**
- Rejected: shomykohai's Quest System (MIT, Godot 4). Quests are Resources with
  scripted objectives, kept outside the rules files. Our goals are rows in
  `goals.json`, validated with the other rules (items, machines, mines) and shared
  with stubby-music's schema. The addon would mean a second goal format, or a loader
  that rebuilds its Resources from our JSON, more code than the tracker itself.
- Rejected: Chevifier's QuestManager (MIT, Godot 4.2+). It has its own quest-graph
  resources and editor; the same mismatch with the rules files.
- Same conclusion as stubby-music's research, where no crate fit.
The tracker is about 100 lines: completed set, open goals, active per horizon,
condition state.

**D2. Conditions are state, and completion is latched.** Sources report whether a
condition holds for an instance: `Goals.report(kind, arg, instance_id, holds)`. The
tracker keeps the set of instances for which each `(kind, arg)` holds. A condition
goal completes when it is open and its condition holds for any instance. That is
checked when a report arrives and when the goal opens, so a condition already true
when its goal opens completes it at once. Once complete, a goal stays complete
(stubby-music D11).
- Rejected: one-shot "condition met" events (Bevy's `ConditionMet`). An event that
  arrives before its goal opens is lost. Here, the oak can't be watered until the
  burbler sounds, so the order happens to work, but a later chain wouldn't.

**D3. Who reports.** The burbler reports `machine_configured` with its machine id
(`mudpit_burbler`) on `sounding_changed`. The scrub oak reports `tree_watered` with
`scrub_oak` on `watered_changed`. Each uses its `instance_id`. Reporters don't know
about goals; the reported kinds are the schema's closed list.

**D4. Active goal per horizon.** The active goal of a horizon is the first open,
incomplete goal of that horizon in file order (stubby-music's rule, minus the
player's choice, which waits for the recipe book). A horizon with none shows
nothing.

**D5. The panel.** Upper right, in the HUD's text style: a "GOAL" header for the
short-term goal, its name and description, and the same for a long-term goal under
it if any. On completion it shows "GOAL COMPLETE" and the name for 4 s, then the next
goal. It hides while a screen has the controls, as the prompt does. It updates on the
tracker's signals, not every frame.

**D6. Validation in `Rules`.** `goals.json` is checked on load with the existing
error format: duplicate ids, both or neither of `requires` and `condition`, an
unknown condition kind (the schema's list: `machine_configured`, `tree_watered`),
unknown item, machine or mine ids (`items.json`, `mines.json`), unknown `after` ids,
and cycles. A goal with errors is left out.

## Risks / Trade-offs

- [No saving: completed goals reset each launch] → acceptable while there's no save
  at all; D10's save shape applies when saving lands.
- [Item goals load but never show] → `goals.json` has none, and the delivery change
  adds them. Validation still covers them now.
- [Several burblers or oaks] → the tracker counts any instance (D2), which matches
  "a tree of that mine".

## Migration Plan

Additive. New autoload and panel. Rollback is removing them and the two `report`
calls.

## Open Questions

- Completion sound: which CC0 clip and when (a later change).
- The first long-term goal and its items (stubby-music 0.2), now with the module
  library in view.
