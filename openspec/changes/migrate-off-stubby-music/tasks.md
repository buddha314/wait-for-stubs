## 1. Layout

- [ ] 1.1 Move every `assets/models/**.glb` (with `.import`) into its asset folder; remove `assets/models/`
- [ ] 1.2 Rewrite model paths in every `asset.json`/`colliders.json` to the new form; check that each resolves
- [ ] 1.3 Move the asset scenes (`scrub_oak`, `reed_clump`, `lightning_bug`, `mudpit_burbler`) into their asset folders; update `main.tscn`, code, tests and the LOD import script
- [ ] 1.4 Reimport; all tests pass; the game loads clean

## 2. Tools and sources

- [ ] 2.1 Copy `tools/blender/`, `tools/collider_shapes.py`, `tools/icons/`, `tools/assets/generate_reticle.py`; path policy in `module_kit.py`; each script uses it and writes the new path form
- [ ] 2.2 Copy `assets-src/blender/**` to `assets-src/` (LFS) and `docs/art/`; add `.gdignore` to `assets-src/` and `docs/`
- [ ] 2.3 Run one generator headless and check its outputs land in the asset folder with the new paths

## 3. Docs

- [ ] 3.1 CLAUDE.md: layout, tools, no sync, stubby-music as an archive
- [ ] 3.2 Asset READMEs: Godot notes instead of Jackdaw and Bevy; `docs/godot-asset-guide.md` updated
- [ ] 3.3 `openspec validate --strict migrate-off-stubby-music`
