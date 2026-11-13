## 1. Scene

- [x] 1.1 `common/asset_lod.gd` plus `tools/import/asset_lod_import.gd`: LOD ranges set at import (project default import script, and existing `.import` files); scenes don't set them (design D1)
- [x] 1.2 `scenes/scrub_oak/scrub_oak.gd` + `.tscn` (`@tool`): seeding, per-instance materials, sway, growth display, collider (D2, D3)
- [x] 1.3 Three oaks in `main.tscn` (D4)
- [x] 1.4 Headless test (`tests/test_scrub_oak.gd`): raw imported models carry LOD ranges; same seed same tree; growth 0 vs 1 node states; collider; three oaks in the opening
- [x] 1.5 Screenshots: dormant oaks in the opening (correct)
- [x] 1.6 Full bloom on screen: the export now keeps hidden parts' children (`start_scale`, `docs/upstream/zero-scale-exports.md`); `test_scrub_oak.gd` checks leaves and catkins strictly

## 2. Docs

- [x] 2.1 `docs/godot-asset-guide.md` (paths, LODs, colliders, seeding, generated children, placing instances, the scrub oak as worked example); pointer in CLAUDE.md
- [x] 2.2 `openspec validate --strict add-scrub-oak`
