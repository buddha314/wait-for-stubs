## Why

The scrub oak is the mine that produces lightning bugs. Its six seeded variants,
growth mapping and colliders are already in `assets/`, but there's no Godot scene
for it, so it can't be placed in the opening. The user also found that the asset
instructions (`assets/flora/README.md`) are written for Bevy and Jackdaw: prefabs,
`.glb.meta`, LODs "imported by Jackdaw". That README is synced from stubby-music
and can't be edited here.

## What Changes

- `scenes/scrub_oak/` (`@tool`, like `reed_clump`), from (world seed,
  `instance_id`):
  - the variant;
  - yaw, scale, height stretch and lean;
  - sway phase on `Limb_<n>`;
  - leaf value jitter and bloom tint.
- **Growth shown, not yet driven.** A `growth` value (0 dormant to 1 full bloom)
  applies the profile's mapping:
  - bark colour;
  - dead leaves falling;
  - buds swelling and opening;
  - leaves growing out and maturing;
  - blooms opening in order.

  It starts at the profile's `starts` (0, dormant, winter). What raises it (clean
  water) is stubby-music's `add-scrub-oak-production`, later, with streams.
- **Both LODs**, swapped by distance with Godot visibility ranges at the profile's
  `far_lod.distance_m` (45 m), with a fade. The LOD helper is shared with the reeds.
- **Static colliders** from `colliders.json` (one cylinder per variant).
- **Three oaks in the opening,** near the lightning bugs they will one day produce.
- **`docs/godot-asset-guide.md`:** how to use stubby-music assets in Godot (model
  paths, LODs, colliders, seeding, generated children, placing instances), with the
  scrub oak as the worked example. CLAUDE.md points to it.

## Capabilities

### New Capabilities
- `scrub-oak`: the placed tree (variant and per-instance look, growth display,
  LODs, collider, sway) and its place in the opening.

### Modified Capabilities
<!-- none -->

## Impact

- **New:** `scenes/scrub_oak/`, `common/asset_lod.gd`, `docs/godot-asset-guide.md`.
- **Changed:** `scenes/reed_clump/reed_clump.gd` uses the shared LOD helper;
  `main.tscn` gets three oaks.
- **Reuse:** Godot `visibility_range_*` (the built-in HLOD), `CylinderShape3D`,
  `WorldSeed`, `AssetProfile`.
- **Not in scope:** bug production, the water that drives growth, acoustics
  (`add-acoustic-asset-profiles` 3.4 lists scrub oak).
