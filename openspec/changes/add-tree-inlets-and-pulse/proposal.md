## Why

Play-testing (user, 2026-11-13): a stream can be led to a scrub oak, but nothing shows
or sounds when it arrives. The player can't see where a stream should end, can't tell
the tree is watered, and hears nothing new. The oak should show where streams connect,
and, once a stream carrying a beat reaches it, pulse and sound on that beat: the factory
is the patch, and watering a tree should feel like patching it in.

## What Changes

- **Root inlets on the scrub oak.** Each oak has a few inlets at its roots, authored in
  the Blender generator as `Inlet_<n>` with a halo, as the burbler's `Outlet_0` is. In
  build mode, a free inlet near the aim shows its halo and the hologram snaps its end
  to it, arriving along the inlet. Laying onto an inlet connects the stream to the tree.
  A connected inlet is taken; dismantling the last segment frees it.
- **Watering by connection.** A tree is watered by the flowing streams connected to its
  inlets (no longer by any stream end within 3 m). Growth, bloom levels and the
  "water the tree" goal condition are unchanged; they read "watered" as before.
- **The tree pulses on the beat.** While watered by a stream from a sounding source,
  the oak swells and glows briefly on each beat of the source's clock, at the instant
  the beat is heard (the lightning bugs' rule). No beat of its own, so it never sets a
  rhythm apart from the music.
- **The trunk knocks on the beat.** The same beats excite the trunk: a short, low,
  woody knock from the tree, pitched by its trunk height (quarter-wave in wood). It is a
  rack on the audio engine, on the same whole multiple of the master clock as its
  source, so it lands with the burbler's beat. Silent until watered, true to "objects
  stay silent until a discovered source excites them".
- **Acoustic profile:** `assets/flora/scrub_oak/acoustics.json` describes the trunk's
  resonance (quarter-wave formula, confidence label), beside `asset.json`.

### Existing tools this relies on

- The stream builder's ports and halos (`StreamPort`, `add-stream-building` D2), and
  the burbler's authored outlet and halo (`tools/blender/create_burbler.py`) as the
  pattern for inlets.
- The engine's modules: `tempo_clock` (whole multiple of the master), `envelope`,
  `vca`, `vco_sine`, `RackEmitter`; `RackServer.clock_ticked` and
  `sample_to_ticks_usec` for the heard instant, as the bugs use.
- `GrowthLevels`, the scrub oak's growth, and its `watered_changed` signal.

Written from scratch: the inlet snap at the end of the hologram, the pulse envelope,
and the knock's patch (made of existing modules, no new DSP). See design.md.

## Capabilities

### New Capabilities
- `tree-inlets`: inlets on growing trees, the builder's end snap, connection, and
  watering by connected streams.
- `tree-pulse`: the watered tree's pulse and knock on its source's beat, and the oak's
  acoustic profile.

### Modified Capabilities
<!-- plant-growth and stream-building are still in add-stream-building (not archived):
     its "Flowing streams water plants" requirement is edited there to defer to inlets -->

## Impact

- `tools/blender/create_scrub_oak.py`: `Inlet_<n>` empties and halos; regenerate the
  oak's models and `asset.json`; `colliders.json` unchanged.
- `assets/flora/scrub_oak/scrub_oak.gd`: inlets as ports, watering by connection, pulse,
  knock rack; `acoustics.json`, `knock.json` (the knock's tuning) beside the profile.
- `scenes/stream_builder/`: end snap to a free inlet; `scenes/stream/laid_stream.gd`:
  the end's connection; `common/stream_port.gd`: an inlet kind.
- `common/growth_levels.gd`: water from connected streams.
- `add-stream-building` spec text: watering defers to inlets for trees that have them.
