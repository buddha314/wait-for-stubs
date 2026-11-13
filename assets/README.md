# Assets

One folder per asset: `assets/<category>/<id>/`. Everything about an asset is there.

| File | What it is |
| --- | --- |
| `<id>.tscn` + `<id>.gd` | **The master scene.** Instance this in levels (world assets only: scrub oak, reed clump, lightning bug, mudpit burbler) |
| `<id>.glb` (or `<variant>/<variant>.glb`) | The model. Never edit it in Godot: regenerate it with its Blender tool |
| `asset.json` | The profile the game reads: per-instance ranges, nodes, growth, LOD distance, … |
| `colliders.json` | Primitive collider shapes per model (`tools/collider_shapes.py`) |
| `preview.png`, `preview_far.png`, … | Renders from the Blender tool |
| `README.md` | What the asset is for |

Variant families (`flora/scrub_oak`, `flora/reeds`, `props/desert`) keep the family
profile and master scene at the top, and each variant's model, profile and previews in
`<variant>/`.

- **Levels of detail** are `<id>_LOD0`/`_LOD1` nodes inside the model. They become
  visibility ranges at import (`tools/import/asset_lod_import.gd`), so you never pick
  one. See `docs/godot-asset-guide.md`.
- **Paths in profiles** are relative to `res://assets/`, for example
  `flora/scrub_oak/scrub_oak_0/scrub_oak_0.glb`.
- **Sources:** the `.blend` for each model is in `assets-src/<category>/` (ignored by
  Godot). The generators are in `tools/blender/` and write straight into these
  folders.
- **Shared data** that isn't one asset: `recipes/` (rules), `lighting/`, `ui/`,
  `audio/`.

Categories: `actors/`, `cables/`, `creatures/` ([lightning bug](creatures/lightning_bug/README.md)),
`equipment/`, `flora/` ([reeds and scrub oak](flora/README.md)), `hud/`, `machines/`,
`modules/` ([README](modules/README.md)), `props/` ([README](props/README.md)), `streams/`
([README](streams/README.md)).

These assets were first made for stubby-music (Bevy), now a frozen archive. They're
maintained here.
