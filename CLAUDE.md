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

## Requirements live in OpenSpec

`openspec/` (CLI `openspec` 1.4) tracks requirements, as in stubby-music. **Don't
start a feature without a change proposal.**

- Use `/opsx:propose` → `/opsx:apply` → `/opsx:archive`, or the CLI: `openspec list`,
  `openspec show <change>`, `openspec validate --strict <change>`.
- `openspec/config.yaml` gives every artifact the project context and rules. Port
  from stubby-music's spec where one exists, and use existing tools first. Every
  design decision that builds instead of reusing names the options it rejected.
- Requirements use SHALL/MUST in the first sentence (the validator checks), plus
  `#### Scenario:` blocks written as WHEN/THEN.
- Research notes behind decisions go in `docs/research/`.

**Audio is specified in `openspec/changes/add-rack-audio-engine`** and is being built in
its own repository, **`/home/buddha/src/stubby-rack`**
([buddha314/stubby-rack](https://github.com/buddha314/stubby-rack); scaffold only:
`RackServer` loads, core voltage tests pass). Read its CLAUDE.md before working there.
It's a Godot-native C++ GDExtension (godot-cpp, chosen 2026-11-13 over hosting
stubby-music's Rust `stubby_audio`, which is now only a reference and test oracle),
rendered from Godot's mix. Godot sees it as Resources (`RackPatch`,
`RackModuleDefinition` as `.tres`), nodes (`Rack`, `RackEmitter`) and a `RackServer`
singleton. DSP comes from DaisySP's MIT core and Mutable Instruments' MIT STM32 code.
It adds a VCV-style per-sample rack, a **master clock that times all
game audio**, and stems played by AudioStreamPlayer3D. The research is in
`docs/research/godot-audio-hosting.md`. Short version: GDScript DSP can't keep up,
Godot's block is a fixed 512 frames, and extensions get no mix hook or mix counter.
So the engine's sample counter is the clock, and timed sounds never bypass the
engine.

**Acoustic ecology** shapes asset work (`docs/design/acoustic-ecology-brief.md`;
`openspec/changes/add-acoustic-asset-profiles`). Every world asset gets an
`acoustics.json` beside its `asset.json`, never inside it, because re-syncing from
stubby-music would overwrite it. A profile lists emission, transmission, reflection,
absorption and resonance separately. Each entry has a DSP approximation and a
confidence label, and its parameters come from geometry by formula (quarter-wave,
Helmholtz, Minnaert, two-path comb). Every sound file needs a provenance record; the
licence audit rejects NC, ND, SA and unknown licences. Acoustic objects don't sound
until a discovered source excites them, so the world still opens in silence.

**Master clock settings** (project settings, decided 2026-11-13):
`audio/master_clock/tempo_bpm=20.0`, `audio/master_clock/beats_per_bar=4`,
`audio/driver/mix_rate=48000`. Pausing never stops the clock. The engine mutes the
music and world stems with a short fade, and the UI stem stays audible.

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
addons/sky_3d/          Sky3D v2.1.0 (TokisanGames, MIT), vendored; don't edit
autoload/               Rules (assets/recipes JSON), Inventory, Calendar
common/                 classes with no scene: WorldSeed, AssetProfile,
                        Interactable (E target), ResourceNode (finite pickup)
scenes/<feature>/       a scene, its script and its feature-only resources together
  main/                 the opening: Sky3D, ground, and instances below
  player/               first-person CharacterBody3D (stubby-music's speeds/keys)
                        + Head/Reach area that picks the E target
  hud/                  reticle, "[E] Collect ..." prompt, status/inventory lines
  rack_screen/          a machine's configure panel (stand-in for Bevy's 3D rack)
  mudpit_burbler/       static machine + cylinder collider from colliders.json
  lightning_bug/        seeded random-clock flash + square click
  reed_clump/           @tool; seeded variant/yaw/scale/sway, LOD0/LOD1 by range
  reed_bed/             @tool; deterministic scatter of reed clumps in a disc
assets/                 runtime assets copied from stubby-music/assets (see below)
```

Placements in `main.tscn` for the burbler and 7 lightning bugs are copied from
stubby-music's `jackdaw/assets/scene.bsn`. The reed beds are new: that scene had no
reeds placed.

**Seeds:** everything random comes from `WorldSeed.rng("<stable instance id>")`.
Override the seed at launch with `godot --path . -- --seed=7`. Give every new
instance a unique `instance_id`/`bed_id`. Changing an id changes that instance.

**Generated children:** `ReedBed` and `ReedClump` build their children in `_ready`
without setting `owner`, so the children appear in the editor but are never saved
into `.tscn` files. Keep it that way. Saving them would freeze the seeded output.

**Sky and time:** `Sky3D` (addon) draws the sky, sun, moon, stars and clouds. The
`Calendar` autoload owns the clock: it ports Bevy's `calendar.rs` (60-minute cycle,
45 min of day, then 15 min of night; it starts at solar midnight, because the Bevy
opening is at night). `main.gd` writes `Calendar.solar_hour()` into
`Sky3D.current_time` every frame, and Sky3D's own game and editor time are off.
TimeOfDay is set to latitude 37°, longitude 0, UTC 0 and the equinox, so the sun
rises at +X, crosses south (+Z) and sets at −X, the same as Bevy. The **moon is
pinned**: `compute_moon_coords = false`, with SkyDome `moon_azimuth = -150°` and
`moon_altitude = 70°`. Sky3D measures "altitude" down from the zenith, so this
puts the moon 20° above the horizon, 30° left of the spawn view (−Z), visible at
start. It doesn't move.

To build or modify Sky3D nodes from a script, wait a frame after `add_child`.
Sky3D creates its children (SunLight, MoonLight, SkyDome, TimeOfDay) on enter-tree,
and a `SceneTree._init` root isn't in the tree yet.

**Interaction (E):** an `Interactable` is a small `Area3D` on physics layer 3
("interact"). The player's `Head/Reach` cylinder (radius 3 m, height 16 m)
overlaps them. The nearest one with a non-empty `interact_action()`, measured
horizontally, becomes `Player.target`. Holding E calls `interact()` every physics
tick, so it collects successive pickups, as in Bevy. `ResourceNode` harvests via
`Inventory.harvest(resource_id)` and replenishes per `resources.json`
(`next_night` → when `Calendar.nights_started()` increases; `after` → seconds of
calendar time). Pickups set `hold_repeats` (holding E collects one after another).
A `MachineInteract` (machines) acts once per press. The burbler puts one on its
model's `Interact` node (the profile's `configure.interact.node`) and shows
`configure.interact.prompt`. E calls `open_rack` on the `rack_screen` group, which
takes the controls (`Player.controls_enabled = false`, cursor visible) until E or
Esc. The panel only lists the profile's places and patch steps. Bevy's real rack
(`machine_config.rs` + `rack.rs`: 3D Eurorack HUD, mounting items into slots,
cable patching, live synth) is not ported yet and needs the audio engine first.
Owners react to `collected_changed`: a bug goes dark, and reeds cut
to stubble and regrow over the interval. Physics layers: 1 world, 2 player,
3 interact.

In `-s` test scripts, autoloads aren't compile-time identifiers. Reach them with
`root.get_node("Inventory")`. To simulate keys, use `Input.parse_input_event` with
an `InputEventAction`. `Input.action_press` doesn't reach `_unhandled_input`.

**Input actions** live in `project.godot` under `[input]`: `move_*`, `jump`,
`crouch`, `sprint`, `interact` (E), `release_cursor` (Esc). Use action names, not
raw keycodes.

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

Load profiles with `AssetProfile.load_json(path)`. When exports are set up, add
`*.json` to the export's non-resource include filter, or profiles will be missing
from the built game.

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

- Bevy generates the desert terrain and mud textures procedurally from a seed. The
  ground here is still a flat placeholder plane. Bevy's sky was a hand-made
  gradient (amber horizon, slate zenith, brown fog); we use Sky3D instead, and its
  defaults (blue sky, white clouds) don't match that bleak, hazy look yet. Same seed must give the same world. Use a seeded `RandomNumberGenerator`, never
  the global `randf()`.
- **Lightning bugs currently flash on frame time** (a `_process` countdown) and play
  a pre-rendered square click (`AudioStreamWAV`). That's a stand-in. Replace it
  with audio-clock ticks when the audio engine is ported.
- Audio timing is the musical source of truth. In stubby-music, clocks run on the
  audio thread with sample timestamps, not frame time. Preserve that in Godot. Drive
  beats from `AudioStreamGenerator`/`AudioServer` time, not `_process` delta.

## Audio occlusion (researched 2026-11-13, not used yet)

Godot core has no occlusion or HRTF, only `Area3D` reverb buses and distance
lowpass. The options that keep Godot's own audio pipeline, which procedural
`AudioStreamGenerator` synthesis needs:

1. **Raytraced Audio** (whoStoleMyCoffee, GDScript, MIT) or **Spatial Audio
   Extended** (Danikakes, GDScript, MIT). Raycast lowpass and reverb with one bus
   per player. Easiest, but cost grows with the number of players.
2. **Steam Audio GDExtension**: upstream stechyo/godot-steam-audio was archived
   2026-10; nurjeff's fork is active. Real geometry, transmission and HRTF; its
   `SteamAudioPlayer` wraps any stream.

FMOD and Wwise replace Godot's mixer, so Godot-generated synth audio wouldn't reach
them. Avoid both unless synthesis moves into the middleware.
