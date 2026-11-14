# Goals: writing guide and draft list

Goals tell the player what to do next, as in Satisfactory: a **major goal** is a long
arc, made of **minor goals** (its steps), done in order. The goal bar in the upper
right shows the active major goal with its progress, and the step being worked on.
Goals point the way; they never end the game.

The design is `openspec/changes/add-goals-hub/`. The goals themselves live in
`assets/recipes/goals.json`, in the order the bar offers them. This page is the
writing guide and the draft list. **Status: the first major goal is decided (2026-11-13); wording and the later major goals are drafts.**

## Writing a goal

Edit `goals.json` in an editor that reads JSON Schema (VS Code does): fields
autocomplete, and typos are underlined. Then run the game headless and check that
`Rules` loads without errors.

A major goal (no condition: it completes when its last step does):

```json
{
  "id": "build_a_camp",
  "name": "Build a camp",
  "description": "The wind takes everything. Grow a windbreak, then light a fire in its shelter.",
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
  "part_of": "build_a_camp",
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

Decided (user, 2026-11-13): the first major goal is **Build a camp**. The mudflat's wind
blows everything away, so the player waters a scrub oak until it buds and breaks the
wind, then lights a campfire in its lee. Budding is enough shelter (muddy burbler water
reaches it today); later bloom levels widen the shelter. The campfire costs reeds and
one spark (a square wave from a lightning bug).

### 1. Build a camp (major)

*The wind takes everything. Grow a windbreak, then light a fire in its shelter.*

| # | Step | Description | Condition | Status |
| --- | --- | --- | --- | --- |
| 1 | Catch a spark | Hold the field recorder up to a lightning bug and collect its square wave. | `item_held` `square_wave` × 1 | `add-goals-hub` |
| 2 | Build a heartbeat | Patch both cables so the burbler sounds on every beat. | `machine_configured` `mudpit_burbler` | exists |
| 3 | Cut reeds | Gather twelve reeds for a stream. | `item_held` `reed` × 12 | `add-goals-hub` |
| 4 | Water the tree | Lead the burbler's stream to a scrub oak. | `tree_watered` `scrub_oak` | exists |
| 5 | Stop the wind | Keep the water flowing until the oak buds and breaks the wind. | `tree_grown` `scrub_oak` `budding` | `add-goals-hub` |
| 6 | Build a campfire | Light a fire of reeds with a spark, in the shelter of the oak. | `built` `campfire` | needs the campfire change |

Steps 1–5 ship with `add-goals-hub`. Step 6 needs a new change (to propose): the
campfire buildable (reeds + 1 `square_wave`, placed only in shelter), the shelter a
budding oak casts downwind, the wind it shelters from (`add-weather-and-dust-storm`'s
one wind, or a fixed prevailing wind until then), and the `built { buildable }`
condition kind. The fire is a sound source too (a crackle from the audio engine), so
it carries an acoustic profile. Until it lands, the bar shows Build a camp at 5 / 6
with "Build a campfire" as the next step.

Step 1 comes first because the spark lights the fire at the end; steps 3 and 6 both
use reeds (a stream segment costs 6).

### Later major goals (titles only)

| Major goal | Idea | Waits on |
| --- | --- | --- |
| Clear the air | Plants clear the polluted air around them, cell by cell. | `add-air-quality-field` |
| A second voice | Build a voice from modules beyond the square VCO. | `add-module-library` |
| Call the rain | Configure a sacred site to bring rain. | weather recipes, sacred sites |

## Open questions

- Names and wording of everything above.
- The campfire's reed count, and how big the budding oak's shelter is.
- What the camp gives the player (a respawn point, a place to rest at night, a
  home for later machines), once unlocks exist.
