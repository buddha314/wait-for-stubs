## Why

stubby-music is frozen (user, 2026-11-13). We pull from it only to recreate
everything here, and it won't be updated. So wait-for-stubs must own its assets and
the Blender tools that make them, and the project should be laid out so each asset's
master scene is obvious. Today one asset is spread over three trees: profile in
`assets/<category>/<id>/`, models in `assets/models/`, scene in `scenes/<id>/`. And
the docs still tell people to rsync from stubby-music and read Jackdaw notes.

## What Changes

- **One folder per asset** (Godot's guidance: keep assets close to the scenes that
  use them). `assets/<category>/<id>/` holds:
  - the **master scene** `<id>.tscn` and its script: what you drag into a level;
  - its models `*.glb` (variants in their own subfolders beside their previews);
  - `asset.json`, `colliders.json` and previews;
  - a README.

  `assets/models/` is removed. The asset scenes leave `scenes/`: `scrub_oak`,
  `reed_clump`, `lightning_bug`, `mudpit_burbler`. `scenes/` keeps levels and
  gameplay that isn't an asset (main, player, hud, rack_screen, reed_bed, mountains,
  sky).
- **Profile paths become plain `res://assets/`-relative paths**
  (`flora/scrub_oak/scrub_oak_0/scrub_oak_0.glb`), replacing Bevy's
  `models/...#Scene0`. All code, scenes, tests and the LOD import script are updated.
- **Blender tools move in.** From stubby-music: `tools/blender/` (18 generator
  scripts plus `module_kit.py` and `export_gltf.py`), `tools/collider_shapes.py`,
  `tools/icons/make_item_icons.py` and `tools/assets/generate_reticle.py`. Their
  output paths change to the new layout, through one path policy in `module_kit.py`.
  Not moved: the Jackdaw and Bevy tooling.
- **Sources move in.** `assets-src/<category>/...blend`, in Git LFS, with a
  `.gdignore` so Godot doesn't import them. `docs/art/` (style guide, palette, keys,
  references, HUD mocks) also moves in, and `docs/` gets a `.gdignore`.
- **Docs:** CLAUDE.md drops the rsync and "mirror unchanged" rules and describes the
  layout and tools. The asset READMEs are ours now; Jackdaw and Bevy notes give way to
  Godot ones. stubby-music is named as a read-only archive.

## Capabilities

### New Capabilities
- `asset-pipeline`: the per-asset folder layout, master scenes, path form, and the
  in-repo Blender tools that generate assets into it.

### Modified Capabilities
<!-- none in openspec/specs -->

## Impact

- **Moves:** every `.glb` (and its `.import`), four scene folders, and paths in every
  `asset.json`/`colliders.json`, `.tscn` and `.gd` that names a model.
- **Adds:** `tools/`, `assets-src/`, `docs/art/`, and `.gdignore` files.
- **Reuse:** Godot's project-organization guidance; `.gdignore`; Git LFS (`.blend`
  is already in `.gitattributes`); Blender 5.3 at `~/.local/bin/blender`.
- **Follow-up, not here:** re-export the models with state parts at full scale
  (`docs/upstream/zero-scale-exports.md`), now that the scripts are ours.
