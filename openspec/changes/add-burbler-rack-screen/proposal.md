## Why

The burbler's configure screen is a text list today. It shows no rack, no modules
and no cables, so the game's core verb, patching, can't be played. stubby-music
built the full version: a 3D Eurorack HUD in a Satisfactory-style window, with
mounting from the inventory, elastic VCV-style cables and working knobs. All of its
art is already in `assets/`. Porting it now, independent of the audio engine, means
the rack is ready when stubby-rack can play, and the patch it produces is exactly
what the engine will consume.

## What Changes

- **A common rack screen** replaces the text panel in `scenes/rack_screen/`.
  - It is a framed window: title bar, a Relevant strip on the left, the rack in the
    centre, a 4 × 4 inventory on the right, and key prompts below.
  - The world behind it dims and blurs.
  - The rack is drawn in 3D from the real assets by its own orthographic camera.
    The frame stretches to the total HP of the slots, and empty slots show labelled
    outlines.
- **Mounting.** Drag an item onto its empty slot, click it in the Relevant strip, or
  press its number key (1–0). An item mounts only in a slot of its kind, and fixed
  slots can't be emptied.
- **Patch cables** (ported from VCV Rack via stubby-music):
  - The rack's spare cables hang on the frame's comb and are free.
  - The player's own `patch_cable` items cover any other patch.
  - Drag from jack to jack, with a 40 px snap. Cables are elastic quadratic Béziers
    with a springy cable in hand. Unplugging returns a cable to the comb or to the
    inventory.
- **Patch guidance without text.** Ghost cables show the suggested patch. Jack
  halos pulse in the colour of the cable meant for them, and a halo rests once its
  jack is patched.
- **Knobs.** Drag up or down, or scroll, mapped through each knob's taper. The
  clock's BPM display follows its knob.
- **An engine-independent patch.** The screen writes a `RackState` (mounted modules
  and cables) and signals when it changes and when the configuration is complete.
  stubby-rack turns that state into a `RackPatch` later (`add-rack-audio-engine` 9.2).
- **The burbler as the first machine.**
  - Its tempo is seeded per instance as a whole multiple of the 1 BPM master
    (×40 to ×180), following `add-rack-audio-engine` D5.
  - Its BPM knob steps in whole BPM.
  - Its volume's TRIG drives the VCA directly, with no envelope.
  - Its OUT is normalled to the burbler's outlet, which `add-stream-building` uses.
- **Stand-ins until stubby-rack plays** (named and removable): a snap click on
  plug-in, and the clock lamp flashing on a placeholder tick. Neither is timed
  musically.

## Capabilities

### New Capabilities
- `rack-screen`: the common rack every machine is configured on. It covers the
  window, the 3D rack view, slots and outlines, mounting from the inventory, the
  cable comb, patch cables, patch guidance, knobs, and the rack state it produces.
- `mudpit-burbler`: the burbler as a configurable clock mine. It covers seeded
  tempo as a master multiple, its three-place configuration, the BPM knob and
  display, when the configuration is complete, and the normalled outlet.

### Modified Capabilities
<!-- none: openspec/specs/ is empty -->

## Impact

- **Code.** Rewrites `scenes/rack_screen/`. Adds `common/rack_state.gd`
  (`Resource`) and `common/patch_cable.gd` (tube builder). Touches
  `scenes/mudpit_burbler/` (instance id, seeded tempo) and `main.tscn` (burbler
  `instance_id`). Adds an asset-contract test under `tests/`.
- **Data.** Reads the existing `configure` blocks, `assets/hud/rack_frame`,
  `slot_outline_*`, `slot_labels`, `assets/modules/*`, `assets/cables/patch_plug`,
  `assets/ui/icons/*` and `assets/recipes/start.json` (10 patch cables). No asset
  is re-modelled. The volume profile's envelope note and the clock's 30–240 knob
  range disagree with the burbler's decisions; the design records which one wins.
- **Reuse.**
  - Godot `SubViewport` with `own_world_3d` and an orthographic `Camera3D`.
  - `Camera3D.unproject_position` for picking.
  - A screen-texture blur shader.
  - `Control` containers, `TextureRect` icons and Godot drag-and-drop.
  - `Inventory` and `Rules` autoloads, `AssetProfile`, `WorldSeed`.
- **Written from scratch.** The cable tube mesh, because no maintained Godot addon
  draws VCV's analytic curve (see design).
- **Depends on:**
  - `add-rack-audio-engine` for sound: tasks 5.2, 5.5, 9.2, the 1 BPM clock (D5),
    and the sampler for the snap click.
  - `add-stream-building` consumes the normalled outlet and the "configured"
    signal.
- **Ports:** stubby-music `add-rack-configurations` (all), `add-mudpit-burbler`
  2.1, 2.4, 2.4a, 2.4b and 2.5, and `add-module-asset-binding` (knobs, display,
  lights).
