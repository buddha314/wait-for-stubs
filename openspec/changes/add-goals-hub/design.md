## Context

Ports the goals part of stubby-music's `add-inventory-and-goals-hud`: its spec
"goals-hub" and decisions D3 (delivery), D9 (an event reducer), D10 (save shape) and
D11 (chores). Bevy built the data side only: `goals.json`, its schema,
`GoalDefinition`, `Condition` and validation in `stubby_recipes`. Its two horizons
(`long`, `short`) were independent: the hub showed one goal of each. The user's
request (2026-11-13) is Satisfactory-style **major and minor goals** with a bar that
shows the active goal and its sub-goal, so the two levels become a hierarchy here.

Here, `goals.json` and its schema are copied, and their Rust generator is archived, so
the schema is now edited by hand. `Rules` loads the other rules files and reports
errors as `file: id: field: message`. The condition sources exist:
`MudpitBurbler.sounding_changed`, `ScrubOak.watered_changed` and its bloom level
(`ScrubOak.bloom_level()`, `GrowthLevels`), and `PlayerInventory` (`changed`,
`quantity(item)`). The HUD's top left holds the time readout, the top centre the
build-mode label (and later the compass bar, backlog); the upper right is empty.

## Goals / Non-Goals

**Goals:**
- A first major goal whose minor goals can all be met in play today.
- Goals are written as data, easy to author, and checked on load.
- The tracker takes events and holds progress with no scene knowledge, so it can be
  tested headless and replicated later (multiplayer: goals follow
  server-authoritative world state).

**Non-Goals:**
- Item delivery to goals (stubby-music D3) and where items are handed in. Pins and the
  recipe book (O). Choosing the active goal. Saving (D10 there applies when it lands).
- A completion sound: it would play through the engine's sampler on the UI stem with a
  provenance record. A later, small change.
- The compass bar (backlog), though the layout leaves the top centre free for it.

## Decisions

**D1. Our own small tracker, not a quest addon.**
- Rejected: shomykohai's Quest System (MIT, Godot 4). Quests are Resources with
  scripted objectives, kept outside the rules files. Our goals are rows in
  `goals.json`, validated with the other rules (items, machines, mines). The addon
  would mean a second goal format, or a loader that rebuilds its Resources from our
  JSON, more code than the tracker itself.
- Rejected: Chevifier's QuestManager (MIT, Godot 4.2+). It has its own quest-graph
  resources and editor; the same mismatch.
- Same conclusion as stubby-music's research, where no crate fit.

**D2. Two scales, a hierarchy.** `scale` is `major` or `minor`. A minor goal names its
major goal in `part_of`; a major goal's minor goals are its steps, in file order. A
major goal has no `condition` or `requires` of its own: it completes when its last
minor goal completes. Major goals open in file order, or after the major goals in
their `after`; a minor goal opens when its major goal is active and the minor goals
before it in the same major goal are complete (its own `after` may add more).
- Rejected: stubby-music's independent horizons. The bar would show two unrelated
  goals, and the user asked for a goal and its sub-goal.
- Rejected: a major goal with its own item cost (Satisfactory's Space Elevator).
  Delivery isn't built; a major goal can gain `requires` when it is.
- Rejected: three levels (phase, tier, milestone). Two are enough for the first
  arcs; a third can be added if the goal list grows.

**D3. Conditions are state, and completion is latched.** Sources report whether a
condition holds: `Goals.report(kind, args, instance_id, holds)`. The tracker keeps,
per condition key, the instances for which it holds. A goal completes when it is
active and its condition holds for any instance, checked on each report and when the
goal becomes active, so a condition already true then completes it at once. Once
complete, a goal stays complete.
- Rejected: one-shot "condition met" events (Bevy's `ConditionMet`): an event before
  its goal opens is lost.

**D4. The condition kinds.** A closed list; adding one is a rule-type change (schema,
`Rules` check, a reporter).

| Kind | Args | Holds while | Reporter |
| --- | --- | --- | --- |
| `machine_configured` | `machine` | a machine of that kind is fully patched and sounds | burbler, on `sounding_changed` |
| `tree_watered` | `mine` | a flowing stream waters a tree of that kind | scrub oak, on `watered_changed` |
| `tree_grown` | `mine`, `level` | a tree of that kind is at that bloom level or above | scrub oak, when its bloom level changes |
| `item_held` | `item`, `quantity` | the inventory holds at least that many | the tracker, on `PlayerInventory.changed` |

`level` is a name from the tree's `growth.json` (`budding`, `leafed`, `full_bloom`).

**D5. The goal bar.** Upper right, in the HUD's text style:
```
BUILD A CAMP                    ▰▰▱▱▱▱  2 / 6
› Build a heartbeat
  Patch both cables so the burbler sounds on every beat.
```
The major goal's name, a progress bar and count (minor goals complete of total), then
the active minor goal's name and description. On completion it shows "GOAL COMPLETE ·
<name>" for 4 s (a major goal's completion replaces its last minor's), then the next
goals. It hides while a screen has the controls, and it updates on the tracker's
signals, not every frame. Top centre stays free for the compass bar.

**D6. Validation in `Rules`.** Checked on load, in the existing error format: duplicate
ids; `scale` missing or unknown; a major goal with no steps; a minor goal without `part_of`, or whose `part_of`
isn't a major goal; a major goal with `part_of`, `condition` or `requires`; a minor
goal with both or neither of `condition` and `requires`; an unknown condition kind,
item, machine, mine or bloom level; an unknown `after` id; a cycle. A goal with errors
is left out, along with any minor goals of a major goal left out.

**D7. Goals are written in JSON.** `goals.json` stays the source, in the order the
bar offers them. `docs/design/goals.md` is the writing guide (fields, condition kinds,
a template) and the draft list.
- Rejected: CSV. Names and descriptions fit cells, but conditions have different
  fields per kind, and `after` and `requires` are lists. That needs packed cells
  (`machine_configured:mudpit_burbler`) and a converter, and loses the schema's
  autocomplete and checks while writing.
- Rejected: a spreadsheet exported to JSON. The same converter, plus a second source
  of truth.

**D8. Format 2.** `horizon` becomes `scale` (`long`→`major`, `short`→`minor`) and
`part_of` is added, so old files no longer validate: `format` goes to 2 (the rules
README's rule). No saves exist, and goal ids don't change, so `migrations.json` gets
no rows. `ids.lock` gains the new ids.

**D9. Tests never depend on goal content.** Goals are written and rewritten while
playing (user, 2026-11-13), so a content edit must never break a test. `Goals.load(rows)`
takes any goal list; tests load fixtures (`tests/fixtures/goals.json`) that exercise
every condition kind and rule. The shipped `goals.json` is only checked to load without
errors, never for its names, step counts or order.

## Risks / Trade-offs

- [No saving: progress resets each launch] → acceptable while there's no save at all.
- [Item goals load but never show] → the draft list uses conditions only; delivery
  adds them.
- [The first major goal's last step needs the campfire] → "Build a camp" (decided
  2026-11-13) ships steps 1–5 here; its step 6, "Build a campfire" (`built`), arrives
  with the campfire change, which adds the `built` kind. Until then the bar holds at
  "Build a camp" with the campfire as the step after the last shipped one.
- [Several burblers or oaks] → any instance counts (D3), matching "a tree of that kind".

## Migration Plan

Additive apart from the schema's format 2, which only `goals.json` uses. Rollback is
removing the autoload, the bar and the reporters, and restoring format 1.

## Open Questions

- The major goals after "Build a camp" (titles in `docs/design/goals.md`).
- Completion sound: which CC0 clip (a later change).
