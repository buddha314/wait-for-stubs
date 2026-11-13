## Context

This ports stubby-music's `add-stream-building` (laying streams, done there), plus the
stream parts of `add-mudpit-burbler` (requirement "Mud stream outlet", task 2.7:
notes, bar lines and staff flow, partly done there) and `add-reeds` (6 reeds per
segment). It records the hooks that `add-fluid-quality-and-viscosity` needs.
stubby-music's code is `crates/stubby_game/src/streams.rs` (1,355 lines: build input,
Bézier plan, mesh bending, bar lines, hologram, port halos, cost HUD, voice placement).

What already exists here:

- **Assets:** `assets/streams/stream_segment` (4 m along +X, 24 subdivisions,
  `Port_in`/`Port_out` with halos, `Staff` with `WaveSin`/`WaveCos` morphs and a
  `Staff_Flow` clip, `Pulse_0`, `Bar_0`, `Reeds_L`/`Reeds_R`, and `clarity` stages)
  and `stream_hologram` (the same frame, `Flow` chevrons every 0.5 m, valid and invalid
  tints).
- **Rules:** `assets/recipes/buildables.json` (already copied). `Rules` doesn't load it
  yet.
- **The burbler:** the model has `Outlet_0` and `Outlet_0_Halo` (shipped at scale 0).
  `MudpitBurbler` doesn't expose them yet.
- **Reeds:** reeds are harvestable, 6 per clump, and regrow in 60 s.
- **Audio:** there is no audio engine yet (stubby-rack is a scaffold). The master clock
  is 1 BPM, and every tempo clock is a whole multiple of it (`add-rack-audio-engine`
  D5). The burbler patch comes from `add-burbler-rack-screen`, written in parallel.

## Goals / Non-Goals

**Goals:** lay, chain and dismantle streams from the burbler with Satisfactory
conveyor controls. Spend reeds through the rules. Get note, bar and staff timing that
comes from clock ticks and can be tested today, without the engine.

**Non-Goals:** saving streams, terrain-following, collision and overlap checks,
junctions and splitters, cleaning and viscosity, burbler bubble animation, a build
menu, and pitch of notes (`staff_step` stays 0 until a sequencer exists).

## Decisions

**D1 — Build mode on Q, straight to streams (ported as is).** With one buildable, a
menu adds a click for nothing. A menu arrives with the second buildable. New input
actions: `build` (Q), `dismantle` (F), `build_place` (left mouse), `build_cancel`
(right mouse). Esc stays `release_cursor` and also leaves build mode. Build mode is a
node in group `stream_builder` that sets a flag the player's E target honours, in the
same way the rack screen uses `controls_enabled`.

**D2 — Ports are data on nodes.** Group `stream_port` holds a small `StreamPort`
(`Node3D`) with `flow_direction` and `connected: bool`. The burbler adds one at
`Outlet_0`, and each laid stream keeps one at its free end. Finding the candidate is
a horizontal-distance scan over the group, the same rule as the E reach. A query
through physics was rejected: there are only a few ports, and a scan is
deterministic and needs no colliders.

**D3 — The curve is stubby-music's Bézier, sampled through Godot's `Curve3D`.** The
control points are ported as they are: P0 is the port; P1 = P0 + d0·L/3; P3 is the
aim point, clamped to 32 m; P2 = P3 − d1·L/3. The segment count is
N = max(1, round(L/4)), and the minimum bend radius of 2 m is checked analytically on
the Bézier. The four points go into a `Curve3D` (one cubic span, in and out handles).
Its baked arc-length table and `sample_baked_with_transform` then give every position,
tangent and frame: for bending, for notes, for bar lines and for the voice's nearest
point.
- *Rejected:* porting the Rust arc-length table (Godot already has one); `Path3D` with
  `PathFollow3D` per note (a node per note is heavier than sampling, and notes are
  instanced, see D6); Catmull-Rom through the aim point (it doesn't leave the port
  along its flow direction).

**D4 — Bend the authored meshes on the CPU, once per laid segment.** For each segment
and hologram tile, read the glTF meshes in the asset's root space, map each vertex's x
to an arc position s, and place it at `frame(s).origin + side·z + up·y`. Normals and
tangents rotate with the frame. Then commit an `ArrayMesh` with `SurfaceTool`, and keep
the authored materials. The hologram re-bends every time the plan changes: 25 cross
sections × N tiles is small, and the spike measures it.
- *Rejected:*
  - `CSGPolygon3D` in path mode. It extrudes one profile, so it would lose the authored
    reeds, staff, pebbles and halos.
  - A vertex-shader bend. It's cheap, but picking (F), voice placement and future
    collision need CPU positions, and every material, including glTF imports, would
    need the same shader.
  - Spline-mesh addons. TheDuckCow's Road Generator (MIT) is built around roads, with
    lanes, intersections and its own mesh. The Godot 3 "SplineMesh" plugins aren't
    maintained for 4.x. Spike 1.1 re-checks the Asset Library before building.

**D5 — Cost is a rule; the Inventory spends it.** `Rules.build_cost(id) -> Array` loads
`buildables.json` and validates it against `items.json`.
`Inventory.can_afford(stacks, count)`, `Inventory.spend(stacks, count) -> bool` (all
or nothing) and `Inventory.refund(stacks)` handle the inventory side. This ports
stubby-music's `Catalog::build` and `build_shortfall`. The profile's
`reeds.built_from` stays documentation.

**D6 — Notes are instanced and placed from tick times.** Each flowing stream owns a
`MultiMeshInstance3D` for `Pulse_0` and another for `Bar_0` (meshes taken from the
segment glTF), and a ring of active tick times. Each frame, a note's distance
downstream is `note_spacing_m × (clock beats from tick_audible to now_audible)`, so the
mud follows the burbler clock: speed is spacing × BPM / 60, and a retune changes the
whole stream's speed without moving any note. `note_spacing_m` (1.0 for raw mud) lives
in `assets/streams/stream_segment/flow.json`, beside `asset.json`, which
`tools/blender/create_stream.py` rewrites (decided 2026-11-13). Its transform is
`curve.sample_baked_with_transform(distance)`, offset onto the staff wave, and
`staff_step × spacing / 2` along the normal. A note is dropped once it passes the
stream's end. Notes are visuals interpolated between clock events, which
`add-rack-audio-engine`'s master-clock spec allows. The tick times themselves only
ever come from the clock.
- *Rejected:* a node per note (thousands at high tempo on long streams); a GPU particle
  system (particle lifetimes are frame-timed, and particles can't follow a bent ribbon
  exactly).

**D7 — Until stubby-rack plays, the time source is an interface with a recorded stub.**
`StreamFlow` reads ticks and "now" from a `TickSource`, with two calls:
`ticks_since(sample) -> PackedInt64Array` and `audible_usec(sample) -> int`. The
runtime source wraps `RackServer` (`clock_ticked`, `sample_to_ticks_usec`) once
`add-rack-audio-engine` tasks 4.4 and 5.1 land. Until then, the game ships with no
source, so laid streams lie quiet. That's correct, because a burbler can't sound
without the engine. Headless tests use a `RecordedTickSource` that holds a fixed list
of tick samples for a ×90 clock at 48 kHz. Spacing, bars, retuning and frame-rate
independence are therefore tested now. A frame-timed fake in the running game was
rejected: CLAUDE.md forbids timing music from `_process`, and it would hide clock bugs.

**D8 — Source connection is a walk up the chain.** Each laid stream has an `upstream`
reference (a port's owner: a burbler or another stream). A stream flows when walking
upstream reaches a burbler whose rack reports `sounding`. The rack change exposes this
as a signal and a property, which this change only reads. Dismantling a segment splits
its stream into an upstream part and a downstream part. The downstream part's
`upstream` becomes null.

**D9 — The voice's nearest point is the stream's job; the emitter is the engine's.**
Each frame, the burbler's `RackEmitter` (from `add-rack-audio-engine` 5.3) is moved to
the point of the burbler or its flowing streams nearest the listener. Those points come
from each curve's `get_closest_point`. This ports stubby-music's
`add-localized-machine-voices` `nearest_source`. It is blocked on the emitter existing,
and the moved emitter keeps doppler off.

**D10 — Staff phase uses audio time.** Phase = 2π · flow · t / wavelength, with t the
audible time of the source clock (D7), and drives the `WaveSin`/`WaveCos` blend shapes
on the bent staff. Bending keeps the blend shapes: they are bent with the same frame
mapping. Wall time would let notes slide off their crests.

**D11 — Acoustic profile (`assets/streams/stream_segment/acoustics.json`).** The file
sits beside the profile and is never synced from stubby-music. It is written in the
format from `add-acoustic-asset-profiles` and has these entries:

| Behaviour | DSP approximation | Confidence |
| --- | --- | --- |
| Emission | `noise_source` grains into a `resonator` bank, with bubble radii 2–10 mm and Minnaert f ≈ 3.26/R (about 330–1,600 Hz) | simplified: mud is denser and lossier than water |
| Absorption | the bed, as a gentle high-shelf cut | gameplay abstraction |
| Reflection | between the banks, as a short comb with spacing from the 1 m channel width | simplified |

The emission is a rack processor, so it plays only while the stream flows.

## Risks / Trade-offs

- **Bending cost while planning** → re-bend the hologram only when the segment count
  or aim point changes by more than 5 cm. The spike measures the cost at N = 8.
- **Alpha-blended mud water sorting across bent, overlapping segments** → each segment
  is its own `MeshInstance3D`. The spike checks the sort order at joins.
- **Blend shapes on bent meshes.** If `SurfaceTool` can't carry the bent blend shapes
  across, the fallback is to rebuild them with `ArrayMesh.add_blend_shape` using the
  same frame mapping.
- **No saves** → laid streams are lost on quit, as in stubby-music. That's acceptable
  for the opening.
- **No collision checks** → streams can cross props and each other until terrain lands.
- **Waiting on two other changes** → build mode, laying, cost and dismantling ship
  first. Flow is tested headless and lights up when the rack screen and the engine
  arrive.

## Migration Plan

This change is additive. The order is: rules and inventory, then build mode and
laying, then dismantling, then flow behind `TickSource`, then the RackServer source
and the voice. Rollback means removing the scenes and input actions. The assets and
rules don't change.

## Open Questions

- ~~Dismantle~~: decided 2026-11-13, F by direct aim from any angle, full refund.
- ~~Flow speed~~: decided 2026-11-13, the mud follows the burbler clock (one note
  spacing per beat); the profile's `flow_speed_mps` is not used.
- ~~Bar lines~~: decided 2026-11-13, from the burbler clock's own `beats_per_bar`
  (burblers sit around 60 BPM, so a bar is about 4 s).
