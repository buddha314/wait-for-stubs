# CLAUDE.md — wait-for-stubs

A Godot 4 game, ported from `/home/buddha/src/stubby-music` (Rust/Bevy). **stubby-music
is a frozen archive** (2026-11-13): it won't be updated, and nothing syncs from it.
Everything now lives here: assets, their Blender generators, art docs and specs. Its
`AGENTS.md` (vision, controls, theme, rules) and `openspec/` remain the design
record to read before porting a feature. Don't edit it.

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
  from stubby-music's (archived) spec where one exists, and use existing tools first. Every
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
`acoustics.json` beside its `asset.json`, never inside it, because the Blender
generators rewrite `asset.json`. A profile lists emission, transmission, reflection,
absorption and resonance separately. Each entry has a DSP approximation and a
confidence label, and its parameters come from geometry by formula (quarter-wave,
Helmholtz, Minnaert, two-path comb). Every sound file needs a provenance record; the
licence audit rejects NC, ND, SA and unknown licences. Acoustic objects don't sound
until a discovered source excites them, so the world still opens in silence.

**Master clock settings** (project settings, decided 2026-11-13):
`audio/master_clock/tempo_bpm=1.0`, `audio/master_clock/beats_per_bar=4`,
`audio/driver/mix_rate=48000`. Every tempo clock runs at a whole multiple of the
master (a 90 BPM burbler is ×90), with ticks derived from the master phase, so all
clocks land together once a minute. Only seeded random clocks (bugs) run free. Pausing never stops the clock. The engine mutes the
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
  rack_screen/          the common rack screen: window + RackView (3D rack in an
                        own-world SubViewport), mounting, cables, knobs
  reed_bed/             @tool; deterministic scatter of reed clumps in a disc
  mountains/            @tool; seeded echo ridge rings at 480/590/700 m
  sky/                  moon_path.gd: drives Sky3D's moon along a star-fixed path
assets/<category>/<id>/ ONE FOLDER PER ASSET: master scene <id>.tscn (+ .gd), models,
                        asset.json, colliders.json, previews, README (see below)
  flora/scrub_oak/      scrub_oak.tscn: seeded oak, growth display, collider
  flora/reeds/          reed_clump.tscn: seeded clump, harvest and regrow
  creatures/lightning_bug/  lightning_bug.tscn: seeded random-clock flash + click
  machines/mudpit_burbler/  mudpit_burbler.tscn: clock mine, RackState, voice stand-in
assets/recipes|lighting|ui|audio   shared data
assets-src/<category>/  Blender sources (.blend, LFS; .gdignore keeps Godot out)
tools/blender/          the asset generators (module_kit.py holds the path policy)
tools/collider_shapes.py, tools/icons/, tools/assets/   colliders, item icons, reticle
tools/import/           asset_lod_import.gd: default scene import script; sets
                        authored LODs (_LOD0/_LOD1) as visibility ranges at import
docs/                   research, design, art (style guide, keys), godot-asset-guide.md
                        (.gdignore)
tests/                  checks: godot --headless --path . -s tests/<file>.gd
                        (test_rack_drag.gd drives the real GUI and needs a window)
```

Placements in `main.tscn` for the burbler and 7 lightning bugs are copied from
stubby-music's `jackdaw/assets/scene.bsn`. The reed beds are new: that scene had no
reeds placed.

**Seeds:** everything random comes from `WorldSeed.rng("<stable instance id>")`.
Override the seed at launch with `godot --path . -- --seed=7`. Give every new
instance a unique `instance_id`/`bed_id`. Changing an id changes that instance.

**Generated children:** `ReedBed`, `ReedClump` and `ScrubOak` build their children in `_ready`
without setting `owner`, so the children appear in the editor but are never saved
into `.tscn` files. Keep it that way. Saving them would freeze the seeded output.

**Sky and time:** `Sky3D` (addon) draws the sky, sun, moon, stars and clouds. The
`Calendar` autoload owns the clock: it ports Bevy's `calendar.rs` (60-minute cycle,
45 min of day, then 15 min of night; it starts at solar midnight, because the Bevy
opening is at night). `main.gd` writes `Calendar.solar_hour()` into
`Sky3D.current_time` every frame, and Sky3D's own game and editor time are off.
TimeOfDay is set to latitude 37°, longitude 0, UTC 0 and the equinox, so the sun
rises at +X, crosses south (+Z) and sets at −X, the same as Bevy. Stars rotate
with sidereal time and clouds drift with Sky3D's wind on their own. The **moon
travels**: `compute_moon_coords = false`, and `MoonPath` (in `main.tscn`) writes
SkyDome's `moon_azimuth`/`moon_altitude` each frame. Sky3D measures "altitude"
down from the zenith, with direction (sin θ sin az, cos θ, sin θ cos az). The moon
is fixed among the stars: its start bearing and altitude (330°, 20° up, 30° left of
the spawn view along −Z) give a declination and hour angle, then it turns 15° of
hour angle per simulated hour. That start needs a declination of about 59°, so it's
circumpolar and never sets, which is unrealistic but keeps the opening view. Change
the two exports for a real path (`add-sky-motion-and-mountains` D3).

**Horizon:** `MountainRings` builds three seeded ridge rings (480, 590 and 700 m).
Ring 0's skyline is a waveform made of whole-cycle harmonics plus roughness. Each
farther ring echoes it: shifted round the circle, a smaller angular amplitude,
higher in the view, and hazier. They're real reflectors with echo delays of 2R/c
(2.80, 3.44 and 4.08 s). Their `acoustics.json` waits for the acoustic profile
format. A 1600 m dark `OuterGround` plane fills the gap from the 216 m mudflat
out to the mountains.

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
Esc.

**The rack** (`add-burbler-rack-screen`, ported from stubby-music's
`machine_config.rs` + `rack.rs`): a machine provides `rack_state` (a `RackState`
resource: mounted modules, knob values as `"place/param"`, cables with
`from`=output, `to`=input and `source` `comb:<n>` or `inventory`), `configure`,
`knob_overrides()`, `rack_header()` and `bpm()`. `RackState` emits `changed` on
every edit and `configured` once per completion. It never talks to audio: the
engine turns it into a `RackPatch` later (`add-rack-audio-engine` 9.2). `RackView`
draws the real glTFs in its own `World3D`, picks by `Camera3D.unproject_position`
(no physics), and takes mouse input and item drops on a transparent `Input` layer
over it (a `SubViewportContainer` forwards drag-and-drop into its SubViewport, so
drops on the container itself never land). It caches its materials (freeing a mesh together with the only
reference to its material errors in the 4.8 beta). Module data comes from
`assets/modules/<id>/asset.json` via `RackModules`; cable geometry from
`PatchCable`. The burbler's tempo is a seeded whole multiple of the 1 BPM master
from `assets/machines/mudpit_burbler/tempo.json` (56–64, outside `asset.json`, which
`tools/blender/create_burbler.py` rewrites); its
BPM knob covers `params.bpm` (40–180) in whole steps. `sounding` /
`sounding_changed` mean "fully patched".
Owners react to `collected_changed`: a bug goes dark, and reeds cut
to stubble and regrow over the interval. Physics layers: 1 world, 2 player,
3 interact.

In `-s` test scripts, autoloads aren't compile-time identifiers. Reach them with
`root.get_node("Inventory")`. To simulate keys, use `Input.parse_input_event` with
an `InputEventAction`. `Input.action_press` doesn't reach `_unhandled_input`.

**Input actions** live in `project.godot` under `[input]`: `move_*`, `jump`,
`crouch`, `sprint`, `interact` (E), `release_cursor` (Esc), `item_1`…`item_10`
(keys 1–0, insert from the rack's Relevant strip). Use action names, not raw
keycodes.

Add a new world asset as `assets/<category>/<id>/<id>.tscn` + `.gd` beside its models
and profile (e.g. `assets/flora/scrub_oak/`). Add other gameplay as
`scenes/<feature>/<feature>.tscn` + `.gd` (e.g. `scenes/player/`). Instance both
into `main.tscn`. Put
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

**One folder per asset** (`assets/README.md`; Godot's guidance is to keep assets
close to the scenes that use them): `assets/<category>/<id>/` holds:
- the master scene `<id>.tscn` + `.gd` (world assets), which levels instance;
- the model `<id>.glb` (variants in `<variant>/` beside their previews);
- `asset.json` (the profile the game reads), `colliders.json`, previews and a README.

`recipes/*.json` (+ `schema/`) holds data-driven items, resources, recipes, goals and
buildables. Keep game rules data-driven; load these, don't hardcode them. Also
`lighting/lighting_keys.json`, `ui/` and `audio/sfx/`.

**Placing assets:** see `docs/godot-asset-guide.md`. In short: instance the master
scene, give it a unique `instance_id`, and never pick an LOD. LODs are set at import,
never in scenes. **Hidden parts** (oak leaves and blooms, reed stubble, halos) are
exported at scale 1 with the glTF extra `start_scale: 0`, and the import script
restores 0, so models ship posed and their parts open correctly. Game code scales
only the named part, never its children (`docs/upstream/zero-scale-exports.md`).

Load profiles with `AssetProfile.load_json(path)`. When exports are set up, add
`*.json` to the export's non-resource include filter, or profiles will be missing
from the built game.

Profile model paths are relative to `res://assets/`, e.g.
`"creatures/lightning_bug/lightning_bug.glb"` → `res://assets/creatures/lightning_bug/lightning_bug.glb`.

Binary assets (glb, png, wav, blend, fonts, ...) are stored in **Git LFS**; the
patterns live in `.gitattributes`. A new binary type needs a line there before it
is first committed, or it lands in plain git history for good. Check with
`git lfs ls-files`. Fresh clones need `git lfs install` first.

Commit `*.import` and `*.uid` files; never commit `.godot/`.

**Making and changing assets** (Blender 5.3 at `~/.local/bin/blender`): each
generator in `tools/blender/` builds its asset from code and writes the `.blend` to
`assets-src/<category>/` and the model, `asset.json` and previews into the asset's
folder. For example:
```bash
~/.local/bin/blender -b --factory-startup -P tools/blender/create_scrub_oak.py
python3 tools/collider_shapes.py        # rewrite colliders.json from the models
godot --headless --path . --import      # reimport (LOD ranges are set here)
```
Edit the generator, not the `.glb` or the generated `asset.json`. Data the game adds
lives beside them (`tempo.json`, `acoustics.json`). `module_kit.py` holds the path
policy (`asset_dir`, `model_path`, `source_path`, `model_ref`).

## Porting notes

- Bevy generates the desert terrain and mud textures procedurally from a seed. The
  ground here is still a flat placeholder plane. Bevy's sky was a hand-made
  gradient (amber horizon, slate zenith, brown fog); we use Sky3D instead, and its
  defaults (blue sky, white clouds) don't match that bleak, hazy look yet. Same seed must give the same world. Use a seeded `RandomNumberGenerator`, never
  the global `randf()`.
- **Lightning bugs currently flash on frame time** (a `_process` countdown) and play
  a pre-rendered square click (`AudioStreamWAV`). That's a stand-in. Replace it with
  `RackServer` clock ticks once stubby-rack can play (task 9.1).
- **Rack screen stand-ins** (marked `STAND-IN` in code): the clock lamp and gate
  lights flash on a wall-time placeholder tick at the burbler's BPM
  (`RackView._update_lamps`, replace with `clock_ticked`, task 9.2), and the plug-in
  snap plays through a plain `AudioStreamPlayer` (`RackScreen._play_snap`, replace
  with the rack sampler on the UI stem, task 5.5). Neither times anything musical.
- **Burbler voice stand-in** (`assets/machines/mudpit_burbler/burbler_voice.gd`): a patched
  burbler loops one pre-rendered beat of stubby-music's voice (the square at FREQ ×
  GAIN, gated for the first half beat) from `Outlet_0`, within 30 m. The mixer loops
  it, so nothing is frame-timed, but it isn't locked to the master clock. The rack
  lamp follows its heard phase. Replace it with the engine (task 9.2).
- Audio timing is the musical source of truth. **The rack's sample counter is the
  master clock for all game audio** (design D5). Godot exposes no mix counter or
  callback to extensions, and `AudioStreamGenerator` is fed from the main thread, so
  neither can be the clock. Never time music from `_process` delta or wall time.
- **Weather is on the clock too** (decided 2026-11-13). Lightning and most weather
  events, rain patter included, land on grids at whole multiples of the master.
  Thunder lands on the grid because the strike distance is chosen as a whole number
  of ticks × 343 m. Event visuals (flash, splash) appear at the event's audible
  instant. Wind, storm intensity and rain rate are smooth parameters, never timing
  (`add-weather-and-dust-storm`).

## Audio occlusion (researched 2026-11-13, not used yet)

Godot core has no occlusion or HRTF, only `Area3D` reverb buses and distance
lowpass. The options that keep Godot's own audio pipeline, which stubby-rack's
stems need (they play through AudioStreamPlayer3D):

1. **Raytraced Audio** (whoStoleMyCoffee, GDScript, MIT) or **Spatial Audio
   Extended** (Danikakes, GDScript, MIT). Raycast lowpass and reverb with one bus
   per player. Easiest, but cost grows with the number of players.
2. **Steam Audio GDExtension**: upstream stechyo/godot-steam-audio was archived
   2026-10; nurjeff's fork is active. Real geometry, transmission and HRTF; its
   `SteamAudioPlayer` wraps any stream.

FMOD and Wwise replace Godot's mixer, so Godot-generated synth audio wouldn't reach
them. Avoid both unless synthesis moves into the middleware.

## Status and next steps (2026-11-13)

**Playable now:** night opening (Sky3D, moon in view at spawn, day after ~7.5 min);
walking; E-collect bugs (2 square waves, back next night) and reeds (6 reeds,
regrow in 60 s); the burbler's rack: mount the square VCO, patch with comb or own
cables, turn the BPM/freq/level knobs (silent until stubby-rack plays).

**Open threads, roughly in order:**
1. **stubby-rack spike done** (`add-rack-audio-engine` group 1; results in its design.md,
   code on stubby-rack's `spike-hosting` branch). The driver-player approach holds:
   - stems are sample-aligned by step detection;
   - about 10 µs per emitter per step; a 200-module rack takes 6% of a block in `_mix`;
   - the sync point is accurate to 0.4 ms;
   - the driver must be `PROCESS_MODE_ALWAYS` or pause stops the clock.

   Open: editor hot-reload (a manual check), and the HRTF live test with Nexus
   Resonance (MIT plus Steam Audio, Apache-2.0), which needs approval to load its
   native libraries. Next: engine core (groups 3 to 5).
2. **Archived (2026-11-13), specs in `openspec/specs/`:** `add-burbler-rack-screen`,
   `add-scrub-oak`, `add-sky-motion-and-mountains`, `migrate-off-stubby-music`.
   **Proposed, ready to apply:** `add-field-recorder` (H, the hand, record light,
   level meter, sound gating) and `add-stream-building` (streams of reeds as the
   conveyor from the burbler's outlet; reads the burbler's `sounding`). The game will vendor stubby-rack's built addon into
   `addons/stubby_rack/` via `tools/sync_stubby_rack.sh` (design D11, task 2.6).
3. **Proposed:** `add-weather-and-dust-storm` (clock-aligned weather events, the
   dust storm, one wind; a request hook for later weather recipes) and
   `add-air-quality-field` (10 m cells of air quality, 0 polluted to 1 clean, raised
   by living plants. The game opens in polluted air that clears cell by cell as
   plants regrow; one camera-local 3D texture feeds the haze, ground tint, flora
   glow and the mood blend). **To propose later:** weather recipes, such as a rain
   song or dance the player builds to call rain or calm a storm (user notes,
   2026-11-13). The form is **sacred sites**: like Satisfactory's resource nodes,
   they're discovered in the world and then configured, with a rack built like the
   mudpit burbler's and tied to the local weather. They need their own world asset.
   The rain grid (master or a site's clock) is decided by play-testing.
4. **Not started:** `add-acoustic-asset-profiles` (acoustics.json, provenance
   audit); time-speed controls (Bevy had ¼×–64×; without them, reaching day takes
   about 9 minutes); terrain (still a flat plane); tuning Sky3D toward Bevy's bleak
   amber haze.
5. **Upstream:** report the Godot 4.8 beta abort on a clean headless `--import` with
   any GDExtension (exit 134; it reproduces with godot-cpp's own test extension;
   task 2.5). Once the game loads stubby-rack, its first clean import will hit it too:
   run the import again.
