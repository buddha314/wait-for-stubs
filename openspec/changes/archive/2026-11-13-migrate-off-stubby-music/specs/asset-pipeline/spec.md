## ADDED Requirements

### Requirement: One folder per asset with a master scene
Every world asset SHALL live in one folder, `assets/<category>/<id>/`, holding its
models, profile, colliders, previews and README. A world asset placed in levels SHALL
have exactly one master scene there, `<id>.tscn`, which is what levels instance. No
asset files SHALL live in a separate models tree.

#### Scenario: Finding the oak
- **WHEN** a developer looks for the scrub oak
- **THEN** `assets/flora/scrub_oak/` holds `scrub_oak.tscn` (the scene to place), its six variant models, `asset.json`, `colliders.json` and previews

### Requirement: Profiles name models by project path
Asset profiles SHALL name models relative to `res://assets/`, with no engine-specific
suffix, and every model path in a profile SHALL resolve to an existing file.

#### Scenario: Every path resolves
- **WHEN** the asset check walks every `asset.json` and `colliders.json`
- **THEN** every model path names an existing `.glb` under `res://assets/`

### Requirement: The generators live here and write into the layout
The Blender generators SHALL live in this repository (`tools/blender/`), and SHALL
write models, profiles and previews into the asset's folder and `.blend` sources into
`assets-src/`. Godot SHALL NOT import `assets-src/` or `docs/`.

#### Scenario: Regenerating an asset
- **WHEN** a generator runs headless in Blender
- **THEN** its model, profile and previews appear in `assets/<category>/<id>/` and its source in `assets-src/`, with no files written elsewhere

### Requirement: No sync from stubby-music
The project SHALL NOT depend on stubby-music at build, import or run time, and its
docs SHALL NOT instruct syncing from it.

#### Scenario: A fresh clone
- **WHEN** the repository is cloned without stubby-music beside it
- **THEN** the project imports, runs, passes its tests, and its generators run
