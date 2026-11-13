## Why

Collecting needs a device in the player's hand, and the world is about finding sound by
ear, so the collector is a handheld stereo field recorder under a fur windguard. The
asset is already copied from stubby-music (`assets/equipment/field_recorder/`,
`assets/models/equipment/field_recorder.glb`), but nothing in the Godot port shows it:
H does nothing, and collecting has no feedback in the hand. This ports stubby-music's
`add-field-recorder` and gives its level meter a real input: the sound reaching the
player.

## What Changes

- **H brings up the field recorder** and puts it away (new input action
  `field_recorder`). The hand holds at most one item; the recorder is the first, and
  every later hand item gets its own action. The hand starts empty, and H does nothing
  while a screen (rack, inventory) has the controls.
- **Held in first person** at real size in the lower right of the view, windguard
  forward, at stubby-music's pose. The windguard's fur shells cast no shadows (the
  profile's `windguard.shells_cast_shadows: false`).
- **The record light shows collection:** `Light_rec` lights while E collects and
  rests dark otherwise.
- **The level meter shows what the recorder hears:** the eight `Level_<n>` bars follow
  the level of the world and music audio reaching the listener, read from Godot's bus
  peak meters. In the silent opening they stay dark. This differs from stubby-music,
  where the bars only animated during collection.
- **The recorder makes no sound in this change.** Any later recorder sound (a record
  click, playback of a capture) plays through the audio engine's sampler, timed in
  master samples, with a provenance record.
- **Acoustic profile:** `assets/equipment/field_recorder/acoustics.json` states the
  recorder has no acoustic role in the world (it listens; it neither emits nor shapes
  world sound).

Works before the audio engine: input, the hand, the held model, the record light and
the meter (the meter already reads the lightning bugs' clicks). Nothing here waits on
stubby-rack, except that the meter's input moves onto the engine's stems when they
exist.

### Existing tools this relies on

- Godot: `InputMap` actions, a `Node3D` child of the player's head/camera for the
  held model, `GeometryInstance3D.cast_shadow`, `StandardMaterial3D` emission, and
  `AudioServer.get_bus_peak_volume_left_db/right_db` for the meter.
- The copied stubby-music asset and its profile (nodes `Grip`, `Capture`,
  `Windguard`, `Light_rec`, `Screen`, `Level_0`–`Level_7`, extras on each).
- stubby-music's `hand.rs` (pose, one-item hand, fur shadow rule) as the reference.

Written from scratch: a small hand scene and the recorder's script (light envelope and
meter ballistics). See design.md for what was considered instead.

## Capabilities

### New Capabilities
- `field-recorder`: the hand (one item, a key per item), the held field recorder, its
  record light during collection, its level meter, and its acoustic and sound rules.

### Modified Capabilities
<!-- none: no specs exist yet in openspec/specs/ -->

## Impact

- `project.godot`: input action `field_recorder` (H).
- New `scenes/hand/` (hand scene and script), attached under `Player/Head`.
- `scenes/player/player.gd`: exposes whether E collected a pickup this tick, for the
  record light.
- New `assets/equipment/field_recorder/acoustics.json` (beside, not inside, the
  upstream `asset.json`).
- Related: `add-rack-audio-engine` (stems and the UI stem the meter must exclude;
  the sampler for any future recorder sound), `add-acoustic-asset-profiles` (profile
  format and check).
