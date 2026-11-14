# Goals: writing guide and draft list

Goals tell the player what to do next, as in Satisfactory: a **major goal** is a long
arc, made of **minor goals** (its steps), done in order. The goal bar in the upper
right shows the active major goal with its progress, and the step being worked on.
Goals point the way; they never end the game.

The design is `openspec/changes/add-goals-hub/`. The goals themselves live in
`assets/recipes/goals.json`, in the order the bar offers them. This page is the
writing guide and the draft list. **Status: draft (2026-11-13), not yet signed off.**

## Writing a goal

Edit `goals.json` in an editor that reads JSON Schema (VS Code does): fields
autocomplete, and typos are underlined. Then run the game headless and check that
`Rules` loads without errors.

A major goal (no condition: it completes when its last step does):

```json
{
  "id": "wake_the_mudflat",
  "name": "Wake the mudflat",
  "description": "Find the mudflat's first sounds and bring water back to it.",
  "scale": "major"
}
```

A step (a minor goal), listed after its major goal:

```json
{
  "id": "build_a_heartbeat",
  "name": "Build a heartbeat",
  "description": "Patch both cables so the burbler sounds on every beat.",
  "scale": "minor",
  "part_of": "wake_the_mudflat",
  "condition": { "kind": "machine_configured", "machine": "mudpit_burbler" }
}
```

Rules:
- `id` is `snake_case`, used once across all rules files, and never changes once
  shipped (add it to `ids.lock`). `name` and `description` can change freely.
- `name`: a short imperative ("Water the tree"). `description`: one line saying what
  meets it, in plain words, as the player will see it under the name.
- Steps of a major goal are done in the order they appear in the file.
- A step has exactly one `condition`. (`requires`, items handed in, loads but isn't
  shown or completed until item delivery is built.)
- `after` (optional, a list of goal ids) holds a goal back until those are complete.
  Major goals otherwise follow file order.

### Condition kinds

| Kind | Fields | Met when |
| --- | --- | --- |
| `machine_configured` | `machine` (a mine id: `mudpit_burbler`) | a machine of that kind is fully patched and sounds |
| `tree_watered` | `mine` (`scrub_oak`) | a flowing stream waters a tree of that kind |
| `tree_grown` | `mine`, `level` (`budding`, `leafed`, `full_bloom`) | a tree of that kind reaches that bloom level |
| `item_held` | `item` (an item id), `quantity` | the inventory holds at least that many |

A step that needs something not on this list is a new condition kind: an OpenSpec
change (schema, a check in `Rules`, and the thing in the game that reports it).

## Draft goal list

Only the first major goal can be completed with what the game has today. The later
ones are titles, waiting for their features.

### 1. Wake the mudflat (major)

*Find the mudflat's first sounds and bring water back to it.*

| # | Step | Description | Condition | New? |
| --- | --- | --- | --- | --- |
| 1 | Catch a spark | Hold the field recorder up to a lightning bug and collect its square wave. | `item_held` `square_wave` × 1 | kind new |
| 2 | Build a heartbeat | Patch both cables so the burbler sounds on every beat. | `machine_configured` `mudpit_burbler` | exists |
| 3 | Cut reeds | Gather twelve reeds for a stream. | `item_held` `reed` × 12 | kind new |
| 4 | Water the tree | Lead the burbler's stream to a scrub oak. | `tree_watered` `scrub_oak` | exists |
| 5 | Wake the tree | Keep the water flowing until the oak buds. | `tree_grown` `scrub_oak` `budding` | kind new |

Note on step 3: a stream segment costs 6 reeds, and an oak is a few segments from the
burbler, so 12 gets the player started without telling them the exact cost.

### Later major goals (titles only)

| Major goal | Idea | Waits on |
| --- | --- | --- |
| Clear the air | Plants clear the polluted air around them, cell by cell. | `add-air-quality-field` |
| A second voice | Build a voice from modules beyond the square VCO. | `add-module-library` |
| Call the rain | Configure a sacred site to bring rain. | weather recipes, sacred sites |

## Open questions

- Names and wording of everything above.
- Should collecting the first sound come before the burbler (as drafted), or after?
- What the first major goal unlocks, once unlocks exist.
