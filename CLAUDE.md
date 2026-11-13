# CLAUDE.md — wait-for-stubs

A **Godot 4 port of `/home/buddha/src/stubby-music`** (Rust/Bevy). That repo is the
design reference: read its `AGENTS.md` for the game's vision, controls, theme and
rules before porting a feature, and its `openspec/` for requirements. Do not edit
stubby-music from here.

The game: modular synthesis (Eurorack patching) fused with a factory builder
(Satisfactory-style). The factory *is* the patch. It opens silent on a hazy,
cracked desert mudflat; sound is what the player discovers. Controls follow
Satisfactory conventions (E interact, Q build, F dismantle, Tab inventory,
O recipe book, H field recorder, B flashlight).

## Engine

- Godot **4.8 beta, custom build** at `godot` on PATH (`/usr/local/bin/godot`).
- Renderer Forward+, physics **Jolt**. Set in `project.godot`.
- Headless checks (no window opens):
  ```bash
  godot --headless --path . --import              # (re)import assets
  godot --headless --path . --quit-after 60       # load + run main scene briefly
  ```
  Grep the output for `ERROR`/`SCRIPT ERROR`. Known noise: `UVs are required to
  generate tangents` comes from vertex-coloured glTFs with no UVs. It is harmless.

## Layout (organise by feature, Godot docs convention)

```
project.godot
scenes/<feature>/       a scene, its script and its feature-only resources together
  main/main.tscn        main scene: environment, sun, ground, camera
assets/                 runtime assets copied from stubby-music/assets (see below)
```

Add new gameplay as `scenes/<feature>/<feature>.tscn` + `.gd` beside it (e.g.
`scenes/player/`, `scenes/lightning_bug/`), instanced into `main.tscn`. Put
cross-cutting singletons in `autoload/` and register them in `project.godot`.

## Naming (Godot style guide)

- Files and folders: `snake_case` (`lightning_bug.tscn`, `main.gd`). Avoids
  case-sensitivity breakage in exported builds.
- Node names and `class_name`: `PascalCase`. Functions/variables: `snake_case`.
  Constants: `CONSTANT_CASE`. Signals: past tense (`collected`, `flashed`).
- Static typing in GDScript everywhere (`var speed: float = 5.0`, typed returns).
- Note: the `Title-Case-Hyphen` rule in `~/CLAUDE.md` is for the Proton Drive sync
  folder only. It does **not** apply to this repo.

## Assets

`assets/` mirrors stubby-music's `assets/` tree unchanged (Jackdaw `.meta` files
excluded), so its JSON paths still resolve:

- `models/<category>/*.glb` — exported models; LODs are `_LOD<n>` nodes inside.
- `<category>/<id>/asset.json` + previews — per-asset profiles (e.g.
  `creatures/lightning_bug/asset.json`: flash timing, click synth params, hover).
- `recipes/*.json` (+ `schema/`) — data-driven items, resources, recipes, goals,
  buildables. Keep game rules data-driven; load these, don't hardcode them.
- `lighting/lighting_keys.json`, `ui/`, `audio/sfx/`.

JSON model paths are Bevy-style and relative to `assets/`, e.g.
`"models/creatures/lightning_bug.glb#Scene0"` → load
`res://assets/models/creatures/lightning_bug.glb` (drop `#Scene0`).

Binary assets (glb, png, wav, blend, fonts, ...) are stored in **Git LFS**; the
patterns live in `.gitattributes`. A new binary type needs a line there before it
is first committed, or it lands in plain git history for good. Check with
`git lfs ls-files`. Fresh clones need `git lfs install` first.

Commit `*.import` and `*.uid` files; never commit `.godot/`. Blender sources stay in
stubby-music's `assets-src/`; re-copy exported `.glb`s from there when they change
(`rsync -a --exclude '*.meta' ../stubby-music/assets/ assets/`). This overwrites
local edits, so check `git status` first.

## Porting notes

- Bevy generates the desert terrain, mud textures and HDR sky procedurally from a
  seed. The main scene has placeholders (flat plane, `ProceduralSkyMaterial`, fog).
  Same seed must give the same world. Use a seeded `RandomNumberGenerator`, never
  the global `randf()`.
- Audio timing is the musical source of truth. In stubby-music, clocks run on the
  audio thread with sample timestamps, not frame time. Preserve that in Godot. Drive
  beats from `AudioStreamGenerator`/`AudioServer` time, not `_process` delta.
