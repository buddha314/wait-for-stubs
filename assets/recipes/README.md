# Rules: items, resources, mines, recipes

The game's rules are rows in these files. **The designer owns the rows**; the schema
and validator were Rust code in stubby-music's `crates/stubby_recipes` (now an archive; a
GDScript check is still to be written), and new kinds of rule
go through OpenSpec. See AGENTS.md, "Rules are data; the schema is code", and
`openspec/changes/add-rules-data-conventions/`.

| File | Holds |
| --- | --- |
| `items.json` | Everything that can sit in an inventory: `square_wave`, `reed`, `clock`, `patch_cable` |
| `resources.json` | Finite pickups and what they yield: `lightning_bug`, `reed_clump`, `clock_source` |
| `mines.json` | Infinite sources and the resource they produce: `scrub_oak`, `mudpit_burbler` |
| `recipes.json` | Inputs → outputs. Empty: no production recipe is designed yet |
| `buildables.json` | What the player builds in the world and its item cost per one built: `stream_segment` (6 `reed`) |
| `goals.json` | What the goal bar tells the player to do next: major goals made of minor goals (steps), each step met by a `condition` (e.g. `machine_configured`). Kept in the order the bar offers them. Writing guide: `docs/design/goals.md` |
| `start.json` | The starter inventory a new player gets: 10 patch cables |
| `migrations.json` | Every renamed or removed ID, so saves survive the change |
| `ids.lock` | Every ID ever shipped (maintained by the formatter; never delete lines) |
| `schema/` | JSON Schemas for editors. They were generated from stubby-music's Rust types; that generator is archived, so edit them by hand with the matching check in `autoload/rules.gd` |

## Changing the rules

1. Edit the JSON in an editor that reads JSON Schema (VS Code does by default: each file
   names its schema in `$schema`, so fields autocomplete and typos are underlined).
2. Check it: the JSON Schemas in `schema/` validate in any editor that reads `$schema`.
   stubby-music's Rust formatter and tests (`rules-fmt`, `cargo test -p
   stubby_recipes`) are archived with it. A GDScript check that loads these files
   through `autoload/rules.gd` is still to be written; until then, run the game
   headless and check that `Rules` loads without errors.
3. Keep `ids.lock` and `migrations.json` in step by hand: record every new ID, and
   every renamed or removed one, so saves survive the change.
4. Open a **data PR** (the PR template asks). No code or OpenSpec change is needed for
   a new row or value of a kind that already exists.

If a row seems to need a condition, a formula or a field that does not exist, that is a
new rule type: write an OpenSpec change instead of bending the data.

## Rules the validator enforces

- IDs are `snake_case`: a lowercase letter, then `a-z`, `0-9` or `_`. Each ID is used
  once across all files. `name` is the display name and may change freely.
- Unknown fields are errors (a misspelled `yeilds` fails instead of being ignored).
- Every referenced item, resource and mine exists; quantities are positive; item lists
  are not empty; every recipe's inputs can be obtained from some resource or recipe.
- **IDs are part of the save format.** To rename or remove one, add a row to
  `migrations.json` (`registry`, `from`, `to`, or `to: null` to remove). An ID that
  disappears without one fails the `ids.lock` check.
- Every file carries `"format": 1`. Only a schema change that old files cannot satisfy
  bumps it.

## What the current rows mean

Lightning bugs are exhaustible: each yields two `square_wave` items and returns at the
next night. Reed clumps yield six reeds and return after 60 seconds. The `scrub_oak`
mine produces finite lightning bugs, scaled later by water and light quality
(`openspec/changes/add-scrub-oak-production/`). The `mudpit_burbler` mine produces the
`clock_source` resource (renamed from `clock`, which is the item's ID), which yields the
`clock` item. Square wave is in development: keep its stable ID and metadata while its
asset is built. Collection feedback plays once per waveform, not per yielded item.
