## Context

stubby-music's rack screen is `machine_config.rs` (808 lines) and `rack.rs` (2,174
lines). Its design record is `add-rack-configurations` plus `add-mudpit-burbler` 2.x.
It ended as data-driven:
- machine `configure` blocks;
- per-module parts and jack tables;
- a `RackState` per placed machine;
- a screen drawn by a HUD camera at y = −1000 on render layer 31.

Every asset that screen needs is already copied here, with the game-facing nodes
present: `Port_*`, `Jack_*_Halo`, `Knob_*`, `Light_*`, `Lamp`, display segments,
`CableComb` / `Comb_<n>_Plug{A,B}`, `Label_<kind>` and `Cable_attach`.

The port today has `MachineInteract` → `rack_screen.gd`, a text list. The master clock
is now 1 BPM, and every tempo clock is a whole multiple of it
(`add-rack-audio-engine` D5). stubby-rack is only a scaffold, so this change must not
depend on it.

## Goals / Non-Goals

**Goals:**
- Feature parity with stubby-music's final rack screen (2.3–2.18): window, 3D rack,
  mounting, comb, cables, snap, guidance, knobs, inventory strip and grid.
- A `RackState` resource that is the single source of the patch, ready for the engine.
- The burbler's seeded tempo as a master multiple, with the BPM knob and display.
- A headless asset-contract test, so renamed nodes upstream fail loudly here.

**Non-Goals:**
- Sound. The engine patch, real lights and meters, and the VCO LED level all come
  from `add-rack-audio-engine` 9.2.
- Streams from the outlet: `add-stream-building`.
- Crafting cables (bird nests), other machines, the Tab inventory screen, saving
  games.

## Decisions

**D1. Rack view: a `SubViewport` with `own_world_3d`, shown in a
`SubViewportContainer` in the centre panel.**

The SubViewport has its own `World3D` and `Environment`, an orthographic `Camera3D`
facing the faceplates, and the `screen.key_light` as an area-light approximation (a
`SpotLight3D` with a soft angle, since Godot has no area light). An isolated world
means the day/night sun, fog and Sky3D never touch the rack.

Rejected:
- Bevy's approach, the rack placed far away in the game world on its own layer.
  Godot cull masks don't isolate lights and environment as cleanly, and Sky3D's
  directional lights would reach it.
- 2D sprites of the modules. They would throw away the 3D assets, their emissive
  lights and the stretchable frame.
- A `CanvasLayer` over a `Camera3D` in the main viewport. It needs its own world
  anyway.

**D2. Picking by projection, not physics.**

Jacks, knobs, comb plugs and slots are found by `Camera3D.unproject_position()` on
their nodes, by nearest within a pixel radius (the spec's 40 px snap is the same test).
Slots are hit-tested as projected rectangles of HP width.

Rejected:
- Physics raycasts into the SubViewport world. That means collision shapes on every
  port of every module, and input forwarding through the container, and still a
  separate radius test for the 40 px snap.
- Godot's `CollisionObject3D` input events. They don't pass through a
  `SubViewportContainer` without `physics_object_picking` and per-node shapes.

**D3. Cable mesh: a small GDScript tube builder (`common/patch_cable.gd`) using
`SurfaceTool`.**

It samples the quadratic Bézier at about 24 points, sweeps a ring of
`patch_plug.cable.sides` with parallel-transport frames, and rebuilds only when an end
or the spring moves.

Rejected:
- `Path3D` + `CSGPolygon3D` in path mode. It is the built-in route, but CSG rebuilds
  are slow per frame for a swinging cable and produce collision we don't need.
- Rope and verlet addons (for example the "Rope" asset-library plugins). They
  simulate length-constrained rope. VCV's cable has no fixed length and is an
  analytic curve, which is the spec, so a simulation would fight it.
- `ImmediateMesh`. Fine for drawing, but it rebuilds every frame regardless and has
  no tangents.

**D4. The swinging cable in hand: a critically-damped spring on the Bézier control
point** (about 0.25 s settle), integrated in `_process`. This is UI animation, not
music, so frame time is fine here.

**D5. Rack state as a `Resource` (`RackState`), owned by the machine node, not the
screen.**

It holds:
- `mounted: Dictionary[String, String]` (place → module id);
- `knobs: Dictionary[String, float]` (place/param → value);
- `cables: Array[Dictionary]` with colour, from, to and source (`comb:<n>` or
  `inventory`).

It emits `changed` and `configured`. The screen edits the state of whichever machine
opened it, so reopening shows the same rack, and a later save system serialises it as
`.tres`. `add-rack-audio-engine` 9.2 maps it to `RackPatch`.

Rejected:
- Writing `RackPatch` directly. The class doesn't exist yet, and this would tie the
  UI to the engine.
- A dictionary on the screen. That loses state per machine.

**D6. Module data is read from `asset.json`, not duplicated.**

- Ports, knobs, lights and display come from `assets/modules/<id>/asset.json`.
- Which item mounts as which module comes from the machine's `accepts`.
- Display names for modules and kinds come from `slot_labels` and the profile, which
  replaces the hard-coded `"Square VCO"` in `rack_screen.gd`.

Where the machine and the module disagree, the machine wins:
- **Tempo range.** The burbler is 40–180, and the clock module's 30–240 is its
  general range. A `configure.places[].params` override is read if present. Until the
  upstream data adds one, the burbler's `params.bpm` applies to its clock place.
- **Envelope.** `volume/asset.json` describes a built-in envelope, but
  stubby-music's burbler decision (task 1.4) is "TRIG straight to the VCA cv, no
  envelope, the voice stays square". The spec follows the burbler. The profile's note
  is flagged to fix upstream, not edited here, because rsync would overwrite it.

**D7. The burbler's tempo is an integer multiple, seeded near 60.**
`bpm_multiple = rng.randi_range(56, 64)` from `WorldSeed.rng(instance_id)` (decided
2026-11-13: burblers sit around 60 BPM). The window is a
`assets/machines/mudpit_burbler/tempo.json` beside `asset.json`, so a re-sync never
overwrites it; the knob's range stays `params.bpm` (40–180). The BPM shown is that multiple times
`audio/master_clock/tempo_bpm`. The knob steps 1, and the state stores the multiple.
This follows `add-rack-audio-engine` D5. Rejected: a float BPM, which can't
phase-lock to the master.

**D8. Window and blur from Godot built-ins.**

- The blur and dim is a `ColorRect` with a screen-texture shader (`hint_screen_texture,
  filter_linear_mipmap`, sampled at the LOD for `blur_px`).
- The frame is a `PanelContainer` with a `StyleBoxFlat` (corner radius, border and
  colours from `screen.panel`).
- The strip and grid are `GridContainer`s of `TextureRect`s from `assets/ui/icons`.
- Drag-and-drop uses `Control._get_drag_data` / `_drop_data`, onto the rack container,
  which translates the drop into a slot via D2.

Rejected: a UI addon. Nothing here exceeds core `Control`s.

**D9. Stand-ins, named.**

- `SnapClick`, a non-spatial `AudioStreamPlayer` cycling `patch_snap` clips. This is a
  UI sound, not musical timing. It is removed by `add-rack-audio-engine` 5.5.
- `PlaceholderTick` flashes the clock lamp from `Time.get_ticks_usec()` at the
  burbler's BPM. It is replaced by `clock_ticked` in 9.2.

Both carry a `## STAND-IN:` doc comment and are listed in CLAUDE.md, as the bug's
frame-timed flash is.

**D9b. A stand-in voice (added 2026-11-13, after play-testing found the patched
burbler silent).** `BurblerVoice` is an `AudioStreamPlayer3D` at `Outlet_0`. It
loops one pre-rendered beat of stubby-music's voice:
- the gate is high for the first half beat (`PeriodicClock.gate_high`);
- the gate opens the VCA directly (no envelope);
- the VCA passes the square at FREQ × GAIN.

The mixer loops it sample-accurately, so nothing is timed from frame time. It isn't
phase-locked to the master clock. The rack lamp's placeholder flash follows its
heard phase (playback position plus time since the last mix, minus output latency).
It is removed by `add-rack-audio-engine` 9.2.

**D10. Asset-contract test first.** `tests/test_rack_assets.gd` (`godot --headless -s`)
loads every module, `rack_frame`, `slot_labels` and `patch_plug`, and asserts that each
node their profiles name exists. It ports `module_assets.rs`. The screen depends on
these names, and they come from another repo.

## Risks / Trade-offs

- [Area light approximation looks flatter than the Bevy mock] → compare against
  `stubby-music/docs/art/hud_mock*.png` in a screenshot task; add a fill
  `OmniLight3D` if needed.
- [Screen-texture blur cost at 4K] → sample a mip level, not a multi-tap kernel. Check
  the frame time in the run task.
- [Godot 4.8 beta `SubViewport` input/drag quirks] → D2 avoids physics picking. Drag
  goes to the container, not into the viewport.
- [Upstream asset drift (node renames)] → D10's test, run after every rsync.
- [Emissive halos may bloom differently without the game's glow] → give the rack
  world's `Environment` its own glow settings.

## Spike results (2026-11-13)

- **Rack view (task 1.2):** an own-world `SubViewport` with an orthographic camera
  renders the real glTFs as the mocks show. `unproject_position` picking, the 40 px
  snap and drag-and-drop onto the `SubViewportContainer` work in the 4.8 beta.
  Screenshots of the empty, ready and patched states were compared with
  `stubby-music/docs/art/hud_mock*.png`. Halos are ring meshes in the asset, so
  they're drawn opaque (alpha rings sorted badly against the nuts), with the pulse in
  brightness. Glow is set to intensity 0.3 and threshold 1.4, so the lamp flash
  doesn't wash out the panel titles.
- **Backdrop cost (task 1.3):** one mipmapped screen-texture fetch at lod log2(14).
  Measured GPU time with and without it (`viewport_get_measured_render_time_gpu`,
  120 frames, rack open over the night opening): +0.043 ms at 1920×1080, +0.021 ms
  at 2560×1368. 4K couldn't be measured because the test display clamps the window.
  The cost scales with pixels, so 4K is expected to stay under 0.2 ms.
- **4.8 beta:** freeing a `MeshInstance3D` that held the only reference to its
  material prints `material_get_instance_shader_parameters: Parameter "material" is
  null`. `RackView` caches its cable, ghost and plug-tint materials to avoid it.

## Migration Plan

`rack_screen.tscn` is replaced in place. The group `rack_screen` and
`open_rack(point)` stay, so `MachineInteract` doesn't change. `main.tscn` gains the
burbler's `instance_id`. Rollback is reverting the scene folder.

## Open Questions

- ~~Closing~~: decided 2026-11-13, E or Escape, as in Satisfactory.
- Two upstream data fixes to request in stubby-music:
  - the volume profile's envelope note;
  - a per-place knob range override in `configure`.
