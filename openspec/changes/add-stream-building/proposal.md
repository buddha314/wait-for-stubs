## Why

Streams are the factory's conveyor belts. In stubby-music mud flows from a burbler's
mouth and carries the burbler's beat downstream as notes on a floating staff, so a
stream is the played sequence laid out in space, and it is how music will reach plants
("Water the tree"). The port has the stream assets, the burbler's `Outlet_0` and a
reed harvest, but the player can't lay a stream, so reeds have nothing to be spent on
and the burbler, once patched (`add-burbler-rack-screen`), has nowhere to send its beat.

## What Changes

- **Stream build mode, like a Satisfactory conveyor** (ports stubby-music
  `add-stream-building`). Q enters build mode. Aiming within 3 m of a free port (the
  burbler's mouth or a laid stream's free end) lights that port's halo, and left
  click anchors there. A hologram curves from the port toward the aim point. Left
  click lays it if it's valid, and its far end becomes the new anchor. Right click
  drops the anchor. Q or Esc leaves build mode.
- **Smooth bent segments.** A plan leaves its port along the port's flow direction,
  curves to the aim point (at most 32 m away), and is a whole number of 4 m
  `stream_segment`s bent along the curve. A bend tighter than 2 m radius is invalid.
- **Reed cost from the rules.** Each segment costs what `buildables.json` says
  (`stream_segment`: 6 `reed`). The reed icon and `need / have` show under the
  reticle, in red when the player is short, and a short plan turns the hologram
  invalid. Laying spends the reeds all or nothing.
- **Dismantle (F)**, which is new compared with stubby-music: aiming at a laid
  segment and pressing F removes it and refunds its cost. Segments downstream of the
  gap lose their source and lie quiet.
- **The stream carries the beat** (ports `add-mudpit-burbler` task 2.7 and its "Mud
  stream outlet" requirement). Once the burbler's rack is patched, each tick of the
  burbler's clock emits a note (`Pulse_0`) at the source. The note rides the staff
  downstream at the stream's flow speed, so the spacing between notes shows the
  velocity. A bar line (`Bar_0`) follows every `beats_per_bar` ticks. Ticks come from
  the rack engine's clock with their sample times, never from frame time. The
  burbler's tempo is a whole multiple of the 1 BPM master (`add-rack-audio-engine`
  D5). Until stubby-rack plays, laid streams lie quiet, and the note and bar logic is
  tested against recorded tick lists.
- **Streams water plants, and water quality sets how far they bloom** (decided
  2026-11-13). Every growing asset has a few bloom levels as data (`growth.json`); mud
  is the lowest water and reaches only the first level. The scrub oak reaches
  budding on mud, leafed on silty water and full bloom on clear water. A flowing stream
  within 3 m waters it ("Water the tree").
- **Water stays muddy.** The clarity stages and flow speed are read from the profile,
  but cleaning and viscosity (stubby-music `add-fluid-quality-and-viscosity`) stay out
  of scope. Only the hooks they need are recorded.
- **The stream acoustic profile** (`assets/streams/stream_segment/acoustics.json`):
  water babble while flowing, bank reflections and bed absorption, each with a
  confidence label. Per `add-acoustic-asset-profiles`, it stays silent until a
  patched burbler excites it.
- **Out of scope:** saving laid streams (there's no save system yet), terrain-following
  and collision checks (the ground is a flat plane), stream junctions, cleaning, and
  the burbler's bubble animation.

## Capabilities

### New Capabilities
- `stream-building`: build mode, ports and halos, the curved plan and hologram, bend
  validity, reed cost, laying, chaining and dismantling.
- `stream-flow`: what a laid stream does once its source sounds: notes and bar lines
  driven by clock ticks, the staff wave, clarity stages, the stream's acoustic
  profile, and the machine voice heard along the stream.
- `plant-growth`: bloom levels per growing asset, capped by water clarity (mud lowest),
  and watering by flowing streams.
- `buildable-costs`: a rules file listing what can be built and its item cost, with
  all-or-nothing spending and refunds.

### Modified Capabilities
<!-- none: openspec/specs/ is empty in this repository -->

## Impact

- **Reused, unchanged:** `assets/streams/stream_segment` and `stream_hologram` (glTF
  and profiles), `assets/recipes/buildables.json` (already copied from stubby-music),
  the burbler's `Outlet_0`/`Outlet_0_Halo` nodes, and the `reed` item and `reed_clump`
  resource.
- **Godot features relied on:** `Curve3D` (baked arc length and
  `sample_baked_with_transform`) for placing things along a stream, `SurfaceTool`/`ArrayMesh`
  for bending the segment meshes, `MultiMeshInstance3D` for notes, `PhysicsDirectSpaceState3D`
  raycasts for aiming, and `Area3D` on the interact layer for picking segments to dismantle.
- **New code:** `scenes/stream/` (laid stream, bending, notes),
  `scenes/stream_builder/` (build mode, plan, hologram, cost readout), new rules and
  inventory calls in `autoload/rules.gd` and `autoload/inventory.gd`, and input actions
  `build` (Q), `dismantle` (F), `build_place` (left mouse), `build_cancel` (right mouse)
  in `project.godot`.
- **Depends on:** `add-burbler-rack-screen` (the patched state starts the flow),
  `add-rack-audio-engine` (clock ticks with sample times, sample-to-instant mapping,
  emitters), and `add-acoustic-asset-profiles` (the profile format).
- **Stubby-music crates ported, not linked:** the curve, bend and bar maths in
  `crates/stubby_game/src/streams.rs` and the `buildables` rule in `stubby_recipes`.
