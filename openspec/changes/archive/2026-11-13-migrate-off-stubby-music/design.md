## Decisions

**D1. Layout.**

```
assets/<category>/<id>/            one asset
  <id>.tscn, <id>.gd               master scene: drag into levels (world assets)
  <id>.glb                         its model (single-model assets)
  <variant>/<variant>.glb          variant models, beside that variant's previews
  asset.json, colliders.json       data
  preview.png, preview_far.png     previews
  README.md
assets/recipes|lighting|ui|audio   shared data (unchanged)
assets-src/<category>/.../*.blend  Blender sources (.gdignore, LFS)
tools/blender/*.py                 generators (module_kit.py holds the path policy)
scenes/                            levels and non-asset gameplay
docs/ (.gdignore)                  research, art, guides
```

Rejected:
- **Assets under `scenes/`:** that mixes data assets (modules, HUD parts) with
  gameplay.
- **Keeping `assets/models/`:** that keeps one asset in two places.
- **A Godot-docs style `/models/<area>/`:** that's the same per-asset idea under
  another name, and our profiles already live in `assets/<category>/<id>/`.

**D2. Path form.** Profiles name models relative to `res://assets/`, without
`#Scene0`. Code loads `"res://assets/" + path`. A converter rewrites every old path
mechanically, using the move map.

**D3. The tools' path policy.** `module_kit.py` gains:
- `asset_dir(folder)`;
- `model_path(folder, model_id)`;
- `source_path(folder, model_id)`;
- `PREVIEWS` = the asset folder.

Every script uses these. Profiles the scripts write use the new path form. Running a
generator writes straight into the asset's folder. The scripts are checked by running
one generator and diffing its outputs.

**D4. stubby-music stays read-only.** It's the archive of the design record
(`openspec/`, `AGENTS.md`). Nothing syncs from it again.
