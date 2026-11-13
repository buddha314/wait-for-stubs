## Why

The acoustic ecology brief (`docs/design/acoustic-ecology-brief.md`) makes listening,
acoustic experimentation and modular composition the game's main verbs: physical
things in the world are part of the instrument. Our assets are made today for looks
and gameplay only (`asset.json`: model, LODs, resources, bloom). The assets we
already have are natural acoustic objects: reeds are tubes, hollow stumps are
cavities, the burbler is bubbles in mud, the mudflat is a reflecting ground. If
every asset carries an acoustic description from the start, the rack, the spatial
layer and future puzzles can use it. Retrofitting it later means revisiting every
asset.

## What Changes

- Every world asset gets an **acoustic profile**, `acoustics.json`, beside its
  `asset.json`. It's a separate file, so re-syncing assets from stubby-music never
  overwrites it.
- Profiles describe behaviours **separately**: emission, transmission, reflection,
  absorption, resonance. Each carries its physical basis, its simplified DSP
  approximation and a confidence label. Legible approximations come first, not wave
  simulation.
- Geometry maps to DSP parameters through documented formulas (quarter-wave tube,
  Helmholtz cavity, Minnaert bubble, two-path comb), checked by tests.
- Three asset kinds are kept distinct and share one patching interface: **sound
  assets** (samples, impulse responses), **acoustic objects** (physical things that
  shape sound) and **processors** (abstract rack modules).
- **Provenance and licence for every sound asset**, audited separately from code
  licences, with a check that fails on anything missing or incompatible with MIT.
- Each acoustic object gets a **frequency-response preview** next to its visual
  previews, so asset reviews include how it sounds.
- Experiments use the brief's **shared YAML format** in `docs/experiments/`.
- A first-pass acoustic reading of the existing assets (design.md), marked as
  proposals.

## Capabilities

### New Capabilities
- `acoustic-assets`: acoustic profiles, the three asset kinds, separately labelled behaviours, physical-to-DSP mappings, provenance and licensing, response previews, the experiment format, and the silent-opening rule for acoustic objects.

### Modified Capabilities
<!-- none: openspec/specs/ is empty -->

## Existing tools this relies on

- The rack and spatial layer from `add-rack-audio-engine`, which render acoustic
  objects as DSP: filters, resonators, delay/comb, impulse responses. Nothing here
  needs new DSP beyond what that change's module libraries provide.
- Godot's Area3D reverb buses and audio effects for room- and environment-scale
  acoustics.
- stubby-music's asset pipeline (`asset.json` contracts, Blender builders in
  `tools/blender/`, preview images), extended rather than replaced.
- JSON Schema for profile validation, matching `assets/recipes/schema/`.
- **Written from scratch, deliberately:** the formula library (a few textbook
  equations) and the response-preview tool.

## Impact

- New `acoustics.json` files under `assets/<category>/<id>/`, and a schema in
  `assets/acoustics/schema/`.
- New `docs/experiments/`. New checks: profile validation, formula tests,
  provenance and licence audit.
- Depends on `add-rack-audio-engine` to make profiles audible. The data and checks
  can land first.
