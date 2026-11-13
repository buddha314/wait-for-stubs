# Research: Godot add-ons for a Satisfactory-style musical factory game

*2026-11-13. Asked: "a main reason for moving off Bevy to Godot was the rich add-ons
ecosystem. Review the Godot assets for crafting and recipe games." Licences, primary
language, and last push were checked against each GitHub repo (`gh api
repos/<owner>/<repo>`) on this date. The game is MIT, so copyleft is out. The engine
is a custom Godot 4.8 beta. Pure-GDScript add-ons usually load as-is. C++
GDExtensions also hit the beta's clean-import abort (`add-rack-audio-engine` task
2.5), and a second `--import` gets past it.*

## Verdicts

| Need in this game | Add-on | Licence · language · last push | Verdict | Start now? |
| --- | --- | --- | --- | --- |
| **Terrain** (the ground is still a flat plane) | **Terrain3D** (TokisanGames, the same author as our vendored Sky3D) | MIT · C++ GDExtension · 2026-11-10, v1.1.0 (2026-10-30), `compatibility_minimum = 4.6` | **Adopt.** Height, texture splat, holes, runtime sculpting API, LODs and collision. It replaces Bevy's seeded procedural mudflat: generate the heightmap from `WorldSeed` and import it into Terrain3D. Its runtime editing also leaves room for `add-digging` later. | **Yes, as a spike.** Load it in the 4.8 beta (expect the clean-import abort), then port stubby-music's terrain generator to write its height and control maps. Needs an OpenSpec change first. |
| **Scattering props** (stumps, brush, debris, scrub oak) | **ProtonScatter** (HungryProton) | MIT · GDScript · 2026-09-27 (last tagged release 4.0, 2023) | **Adopt for props**, with the seed set from `WorldSeed.rng(id)` in code. Keep our own `ReedBed` for reeds, which are harvestable and carry per-clump state. ProtonScatter has Terrain3D-aware projection. | **Yes**, alongside the terrain change. Check that its cached output isn't saved into `.tscn` files (our generated-children rule). |
| **Tests** (ours are hand-rolled `-s` scripts) | **gdUnit4** (godot-gdunit-labs) | MIT · GDScript · 2026-11-12 | **Adopt.** It has a `SceneRunner` that simulates mouse and keys (what `tests/test_rack_screen.gd` fakes by hand), mocks, signal waits, a command-line runner and JUnit output for CI. The alternative is **GUT** (bitwes, MIT, 2026-08-18): older and simpler, but with weaker input simulation. | **Yes.** It's pure GDScript, so port the two rack tests as the first step. It makes the stream and recorder changes' headless tests cheaper. |
| **Inventory containers** (machine input and output buffers, stack limits, the Tab inventory screen) | **GLoot** (peter-kish) | MIT · GDScript · 2026-07-14, v3.x, Godot 4.4+ | **Adopt when the Tab inventory or machine buffers are built.** It has stacks, grids, item prototypes from JSON ("prototrees", which map onto `items.json`), and separate UI controls. Keep `Rules` as the owner of recipes, because `recipes.json` is designer data synced from stubby-music. | **Not yet.** Today's `Inventory` (a dictionary of 16 stacks) is enough for the opening. Adopt it in the change that adds Tab or machine storage. |
| Inventory **and crafting** | **Inventory System** (expressobits) | MIT · C++ GDExtension · 2026-02-20, addon 2.13.0 (2026-03-21) | **Don't adopt; keep it as a reference.** Its `CraftStation` and recipe model (ingredients, required tools, products, autocraft) is close to Satisfactory's constructor. But it's a C++ GDExtension that hasn't been released since March, built against an older API, and it would own recipes that our JSON already owns. Read its recipe design when the first constructor is specced. | No |
| **Conveyors and belts** | **Factory Core Lite** (huginhelm / openclawaimac) | MIT · GDScript · repo created 2026-10-14, 4 commits, 1 star | **Reference only.** It's 2D, ticks on a fixed 60 Hz simulation, and keeps power, blueprints and undo in a paid "Pro". Its two-lane gap-model belts with back-pressure, and its round-robin splitter, are worth reading when streams carry items. Our streams are clock-driven (`add-stream-building`), not tick-driven. | No |
| **Build mode** (placement preview, snapping, demolish) | **Grid Building Plugin / GridPlacement** (Chris' Tutorials) | Paid (itch.io) · TileMapLayer (2D) grids; v6 is a C# rewrite in progress | **Reject.** It's 2D-grid and paid, and our placement is free-form 3D along curves. Build mode stays as specified in `add-stream-building` (Q, hologram, F from any angle). | No |
| **Streams and rivers** | **Waterways** (Arnklit, GDScript, MIT, 2025-12-17); **Waterways .NET** (C#, MIT, 2025-09-05) | — | **Watch.** It does river meshes with flow maps from Bézier curves. Our streams bend the authored `stream_segment` glTF instead (`add-stream-building` D4), but stubby-music's `explore-water-landscape-ideas` (qanats, larger water) may want it. Not the C# port: the game is GDScript and C++. | No |
| Streams as splines | **Road Generator** (TheDuckCow) | MIT · GDScript · 2026-11-07 | Already considered and **rejected** in `add-stream-building` (it's road-shaped, and we bend authored meshes). | No |
| **Spreadsheet editing of data** | **Edit Resources as Table** (don-tnowe) | MIT · GDScript · 2026-10-31 | **Adopt when `.tres` definitions exist** (`RackModuleDefinition`, `add-rack-audio-engine` 6.1). It edits many Resources as a table, which suits dozens of module definitions. It doesn't help with the JSON rules, which stubby-music owns. | Later |
| Game data (items, quests) | **Pandora** (bitbrain) | MIT · GDScript · 2026-08-20; marked alpha | **Reject.** It's alpha, and our rules are designer-owned JSON in stubby-music's schema. | No |
| **Key and pad prompts** ("[E] Configure burbler", the rack's key line) | **Controller Icons** (rsubtil) | MIT · GDScript · 2026-10-22 | **Adopt with gamepad support.** It draws the icon for an input action and switches between keyboard and pad. It also fixes the hard-coded `"E"` in `hud.gd` and the recorder tip's "[H]". | Small, any time. Fold it into the field recorder change, whose tip has to read keys from the input map. |
| **Creature behaviour** (bugs, future fauna) | **LimboAI** (C++, MIT, 2026-10-30) or **Beehave** (GDScript, MIT, 2026-09-20) | — | **Later.** Behaviour trees and state machines. Prefer Beehave (GDScript, no GDExtension risk) unless profiling says otherwise. Music-driven behaviour must still follow clock events, never frame time. | No |
| **Tutorial and tips text** | **Dialogue Manager** (nathanhoad, MIT, 2026-11-12) | — | **Later**, if the opening gains narrated hints. The goals (`goals.json`) and tips stay data-driven either way. | No |
| **Save games** | Many add-ons (SaveGuard, SaveFlow, Save System Lite, …) | Mostly paid, new, or self-described as AI-assisted | **Build on Godot's `ResourceSaver`.** `RackState` is already a `Resource`, and `.tres` patches are the engine's plan (D6). No add-on is needed. | When saving is specced |
| Foliage painting | **Spatial Gardener** (dreadpon) | MIT · GDScript · last push 2025-03-05 | **Reject.** It's stale, and forum users report breakage on 4.6. Use ProtonScatter instead. | No |
| Voxel terrain / digging | **godot_voxel** (Zylann) | MIT · C++ · 2026-11-07 | **Not now.** It's heavy, and is either an engine module or a GDExtension. Terrain3D's holes and sculpting cover shallow digging; revisit only if `add-digging` needs caves. | No |
| Audio and music | GDSiON, godot-blipkit, rhythm "conductor" add-ons, godot-midi-player (arlez80, 5 stars) | — | **Covered by `rack-engine-reuse.md`.** Audio is stubby-rack, and the rack's sample counter is the clock. No Godot audio add-on fits that. | — |

## What this means

1. **Godot's ecosystem pays off around the factory, not in it.** There's strong,
   maintained, MIT tooling for terrain (Terrain3D), scattering (ProtonScatter),
   testing (gdUnit4), inventory containers (GLoot), input prompts and data
   editing. Nothing mature covers the factory core: conveyors, machines, recipes
   and build mode. Those exist as 2D, paid, or brand-new projects. That core stays
   ours, and it's where the music lives anyway: clock-driven streams, the rack as
   the patch.
2. **The music core has no add-on equivalent**, as `rack-engine-reuse.md` already
   found for audio.
3. **Prefer GDScript add-ons while we're on the 4.8 beta.** Terrain3D is the one C++
   GDExtension worth the import-abort friction; it's also from Sky3D's author, and
   both target 4.6+.

## Suggested order

1. **gdUnit4 now**: port `tests/test_rack_*.gd` and make it the runner that the stream
   and recorder changes' test tasks use. No OpenSpec change is needed beyond a line
   in CLAUDE.md, since it's tooling.
2. **`add-terrain` change** (new, port of stubby-music's terrain generation): a
   Terrain3D spike in the 4.8 beta, then a seeded heightmap and ProtonScatter for
   props. This is the biggest visible gap and fully independent of audio.
3. **Controller Icons**, inside `add-field-recorder` (its tip must read keys from the
   input map).
4. **GLoot**, in the change that adds the Tab inventory or the first machine buffer.
5. Re-check expressobits' crafting model and Factory Core Lite's belts when the first
   constructor and item-carrying streams are specced.

## Sources

[Terrain3D](https://github.com/TokisanGames/Terrain3D) ([docs](https://terrain3d.readthedocs.io/en/latest/docs/project_status.html)),
[ProtonScatter](https://github.com/HungryProton/scatter),
[gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4), [GUT](https://github.com/bitwes/Gut),
[GLoot](https://github.com/peter-kish/gloot),
[Inventory System (expressobits)](https://github.com/expressobits/inventory-system) ([docs](https://expressobits.com/inventory-system/getting_started/introduction)),
[Factory Core Lite](https://godotengine.org/asset-library/asset/5556) ([repo](https://github.com/openclawaimac/godot-factory-core-lite)),
[Grid Building Plugin](https://chris-tutorials.itch.io/grid-building-godot) ([GridPlacement 6.0](https://grid-placement.pages.dev/v6.0/overview)),
[Waterways](https://github.com/Arnklit/Waterways), [Waterways .NET](https://godotengine.org/asset-library/asset/2607),
[Road Generator](https://github.com/TheDuckCow/godot-road-generator),
[Edit Resources as Table](https://github.com/don-tnowe/godot-resources-as-sheets-plugin),
[Pandora](https://github.com/bitbrain/pandora),
[Controller Icons](https://github.com/rsubtil/controller_icons),
[LimboAI](https://github.com/limbonaut/limboai), [Beehave](https://github.com/bitbrain/beehave),
[Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager),
[Spatial Gardener](https://github.com/dreadpon/godot_spatial_gardener) ([4.6 forum thread](https://forum.godotengine.org/t/mesh-scatter-paint-tools-for-godot-4-6/135963)),
[godot_voxel](https://github.com/Zylann/godot_voxel),
[SaveGuard](https://forum.godotengine.org/t/saveguard-save-slots-migrations-and-corruption-recovery-for-godot-4/145403),
[SaveFlow Lite](https://forum.godotengine.org/t/saveflow-lite-1-0-3-scene-owned-save-load-workflow-plugin-for-godot-4-6/138613),
[conveyor forum thread](https://forum.godotengine.org/t/how-do-i-implement-top-down-conveyor-belts/139281).
