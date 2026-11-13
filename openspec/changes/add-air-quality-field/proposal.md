## Why

The game opens in polluted air that gets cleaned up as plants regrow (user,
2026-11-13). The cleaning is local: groves the player brings back by playing music
should read as clear, coloured pockets in the haze. stubby-music specified this as
a light-quality field of 10 m cubic cells (`add-desert-opening` 3.5–3.7, spec
"Light quality field" and "Bleak to bloomed look"; `add-clearing-air-stage` adds a
middle stage). It was never built there, and the storm, the lighting and the flora
all need it here.

## What Changes

- **An air-quality field:**
  - one value per 10 m cubic cell, from 0 (polluted, bleak) to 1 (clean, bloomed);
  - cells are stored sparsely, so untouched desert costs nothing;
  - each cell eases toward a target over several seconds;
  - the cell size comes from `lighting_keys.json` `light_quality.cell_size_m`.
- **Targets come from life in the cell.** Plant density first: living reed clumps
  now, and every future plant or creature that registers. Cutting plants lowers
  the target, and regrowth raises it.
- **One small 3D texture.** The cells around the camera are packed into one texture
  every frame (64 × 8 × 64 cells by default, 640 m × 80 m × 640 m, about 32 KB),
  sampled with trilinear filtering so borders blend. It feeds:
  - the storm's fog density (`add-weather-and-dust-storm`: density × (1 − q));
  - ground tint and flora emission, per cell, through a global shader uniform;
  - beyond the volumetric fog range, the depth fog from the camera's cell.
- **Mood blend.** The global lights blend `lighting_keys.json` moods by the quality
  sampled at the camera. The reader handles any number of moods and stops, so the
  coming `clearing` stage drops in (stubby-music `add-clearing-air-stage` 3.1–3.2).
- **A feasibility spike first,** with frame-cost numbers.

## Capabilities

### New Capabilities
- `air-quality`: the 10 m cell field, its targets and easing, the camera-local 3D
  texture, the mood blend, and per-cell ground and flora colour.

### Modified Capabilities
<!-- none in openspec/specs; add-weather-and-dust-storm's storm reads this field -->

## Impact

- **New:** an `AirQuality` autoload (sparse cells, easing, packing); a global shader
  sampler3D `air_quality` with its world origin; a `Planting` registration for
  living things (reeds first).
- **Changed:**
  - `scenes/reed_clump/` registers itself and reports cut and regrown;
  - the ground material samples the field;
  - `main.gd` applies the mood blend to Sky3D and the Environment.
- **Reuse:** `ImageTexture3D`, global shader uniforms, `FogVolume`, Sky3D and
  Environment properties, `lighting_keys.json` (designer data from stubby-music).
- **Written from scratch:** the field (about 150 lines). No add-on keeps a sparse
  per-cell environmental field.
- **Depends on:** nothing to start. The storm reads it, and the clearing keys come
  from stubby-music when authored.
