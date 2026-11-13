## 1. Spikes (measure before building)

- [ ] 1.1 Re-check the Godot Asset Library for a maintained 4.x spline-mesh addon that can bend an authored multi-material glTF along a `Curve3D` and keep its blend shapes; record what was considered in `docs/research/stream-bending.md` (design D4)
- [ ] 1.2 Bend `stream_segment` and `stream_hologram` along a test Bézier with `SurfaceTool`, keeping materials and the `WaveSin`/`WaveCos` blend shapes; measure the re-bend time for an 8-segment hologram (target: under 2 ms) and check alpha sorting of the mud water at joins
- [ ] 1.3 Check that `Curve3D.sample_baked_with_transform` on a single cubic span gives a stable frame (no flips) for every plan within the 2 m bend limit

## 2. Rules and inventory (buildable-costs)

- [ ] 2.1 `Rules` loads `buildables.json` and validates it (known items, unique IDs, positive whole quantities), with errors that name the file, ID and field; `Rules.build_cost(id)`
- [ ] 2.2 `Inventory.can_afford`, `spend` (all or nothing, reports the shortfall) and `refund`, and their `changed` and feedback behaviour
- [ ] 2.3 Headless test script for the spec's scenarios (13 → 1 reed, 12 short by 6, refund, unknown item)

## 3. Ports, build mode and plan (stream-building)

- [ ] 3.1 Input actions `build` (Q), `dismantle` (F), `build_place` (left mouse) and `build_cancel` (right mouse) in `project.godot`
- [ ] 3.2 `StreamPort` (group `stream_port`, flow direction, connected flag, halo node); the burbler adds one at `Outlet_0` with `Outlet_0_Halo` (shown only for the candidate)
- [ ] 3.3 `scenes/stream_builder/`: Q/Esc enter and leave, blocked while a screen is open; suppress E targeting while active; the HUD shows build mode
- [ ] 3.4 Aim raycast onto the ground; candidate = nearest free port within 3 m horizontally; anchor on left click, drop on right click
- [ ] 3.5 Bézier plan (D3) into `Curve3D`; 32 m clamp; N = max(1, round(L/4)); analytic minimum-radius check; headless tests ported from `streams.rs` (`path_leaves_along_the_port_and_ends_at_the_aim`, `bending_a_straight_path_keeps_the_segment_shape`)
- [ ] 3.6 Hologram: bent tiles (D4), chevrons scrolling downstream at the flow speed wrapping at 0.5 m, valid and invalid tints on every `StreamHologram_*` material
- [ ] 3.7 Cost readout under the reticle: reed icon and `need / have`, warning colour when short; no hint text

## 4. Laying, chaining and dismantling

- [ ] 4.1 `scenes/stream/`: a laid stream owns its `Curve3D`, bent segment meshes, upstream reference and free-end port; laying spends the cost and re-anchors at the far end
- [ ] 4.2 Joins: a stream extended from a free end meets it with no gap or step; the old end is no longer a port
- [ ] 4.3 Per-segment `Area3D` on the interact layer for aiming; F removes the aimed segment, refunds it, splits the stream (D8), and frees the upstream end as a port
- [ ] 4.4 Headless tests: deterministic geometry for the same plan; a 2-segment lay with 24 reeds leaves 12; dismantling the middle of 4 segments leaves 1 flowing and 3–4 quiet

## 5. Flow behind a tick source (stream-flow)

- [ ] 5.1 `TickSource` interface and `RecordedTickSource` (a fixed ×90 tick list at 48 kHz) for tests; with no source, streams lie quiet (D7)
- [ ] 5.2 Source connection: walk upstream to a burbler and read its `sounding` state from `add-burbler-rack-screen`; start on the next tick after it starts sounding
- [ ] 5.3 Notes: `Pulse_0` `MultiMeshInstance3D` per stream, placed from tick times (D6), carried across joins, dropped past the end
- [ ] 5.4 Bar lines: `Bar_0` every `beats_per_bar` source ticks, half a spacing downstream of the downbeat note, `beats_per_bar` read at run time
- [ ] 5.5 Staff wave driven by audio time through the bent blend shapes (D10); still when quiet
- [ ] 5.6 Clarity: blend the profile stages into `Stream_Water`, `Stream_Staff` and the reed materials; burbler streams at clarity 0; `note_spacing_m` from `assets/streams/stream_segment/flow.json`; flow speed = spacing × source BPM / 60
- [ ] 5.7 Headless tests with `RecordedTickSource`: 1 m spacing and 1 m/s at ×60, 2 m/s with no position jump after retuning to ×120, bar lines 4 m apart, same positions at 30 and 144 simulated fps

## 6. Acoustics

- [ ] 6.1 `assets/streams/stream_segment/acoustics.json` per design D11 (Minnaert bubble grains, bed absorption, bank reflection, confidence labels, citations) once the `add-acoustic-asset-profiles` schema (its task 1.1) exists
- [ ] 6.2 The same for `stream_hologram` with an explicit "no acoustic role" entry

## 7. Engine hookup (blocked on add-rack-audio-engine 4.4, 5.1, 5.3)

- [ ] 7.1 `RackTickSource` wrapping `RackServer.clock_ticked` and `sample_to_ticks_usec`; streams flow in the running game
- [ ] 7.2 Move the burbler's `RackEmitter` to the nearest point of the burbler or its flowing streams each frame (D9); fade at the hearing radius (`hearing_radius_metres`, re-sync it from stubby-music's burbler profile)
- [ ] 7.3 Stream water emission as a rack processor that plays only while the stream flows
- [ ] 7.4 Update CLAUDE.md (controls, layout, status) and run `openspec validate --strict add-stream-building`
