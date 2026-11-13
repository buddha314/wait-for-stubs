# Using stubby-music assets in Godot

How assets copied from stubby-music (`assets/`) become things you place in the
editor. The READMEs under `assets/` are synced from stubby-music and describe the
Bevy/Jackdaw side (prefabs, `.glb.meta`). Don't edit them here; this is the Godot
side. Based on Godot's own guidance (sources at the end).

## The rule: one master scene per asset, LODs handled underneath

You place and manipulate **one scene per asset** (`scenes/<asset>/<asset>.tscn`). The
engine handles detail by itself:

- **Authored LOD levels** (`<id>_LOD0` near, `<id>_LOD1` far, inside each `.glb`)
  become **visibility ranges** at import. That's Godot's documented approach for
  artist-made LODs ("HLOD"). The import script `tools/import/asset_lod_import.gd` is
  the project's default scene import script. It looks up `far_lod.distance_m` in the
  asset profile that lists the model and sets the ranges (2 m margin, crossfade). Even
  a raw `.glb` dropped into a level swaps detail by itself.
- **Automatic mesh LOD** (Godot's import default) additionally thins the near meshes
  by screen size. Nothing to do.

You never pick an LOD by hand, and scene scripts never set visibility ranges.

## Importing

- **Paths:** profiles use Bevy-style paths relative to `assets/`:
  `"models/flora/scrub_oak/scrub_oak_0.glb#Scene0"` → `res://assets/flora/scrub_oak/scrub_oak_0/scrub_oak_0.glb`.
  Drop the `#Scene0`.
- **Don't edit an imported model.** Godot can't save back into the `.glb`, and a
  re-sync or reimport discards edits. Wrap it in an asset scene (below), or use an
  inherited scene for purely visual tweaks. Fix shapes, names and LODs at the source,
  in stubby-music's Blender tools.
- **Import settings are committed** (`*.glb.import`). New models get the LOD import
  script from `[importer_defaults]` in `project.godot`. After changing the script, run
  `godot --headless --path . --import`, deleting `.godot/imported/*.glb-*` first if
  the models need re-importing.
- **glTF extras** (custom properties) arrive as node metadata `extras` in this Godot
  build, for example `Bloom_3.get_meta("extras").order`.
- **Known upstream issue:** parts exported at scale 0 have broken child transforms
  (`docs/upstream/zero-scale-exports.md`).

## The asset scene

`scenes/<asset>/<asset>.gd` (`@tool`, so it shows in the editor) takes a unique
`instance_id` export and builds its children in `_ready`:

1. **Seeding:** `WorldSeed.rng(instance_id)` picks the variant and draws the profile's
   `per_instance` ranges (yaw, scale, height stretch, lean, sway phase, tints), always
   in the same order.
2. **Model:** instantiate the chosen `.glb` and `add_child` it **without setting
   `owner`**, so it shows in the editor but is never saved into `main.tscn`. Saving it
   would freeze one seed's output.
3. **Per-instance materials:** duplicate only the materials that differ per instance
   or change at runtime (growth colours, tints), and set them as surface overrides.
4. **Colliders** from `assets/<category>/<id>/colliders.json`: primitive shapes
   (Cylinder → `CylinderShape3D`) on a `StaticBody3D`, scaled with the instance. Godot
   recommends a few primitive shapes over mesh colliders. The axes match (Y up,
   metres).
5. **State from the profile:** growth, harvested, regrowing. Read the mapping from
   `asset.json`, never hard-code it.

`scenes/scrub_oak/` and `scenes/reed_clump/` are the worked examples.

## Placing an instance

In the editor, open `scenes/main/main.tscn`, right-click the parent node (for example
`ScrubOaks`), choose **Instantiate Child Scene**, pick `scenes/scrub_oak/scrub_oak.tscn`,
move it, and set a **unique `instance_id`** in the Inspector (`scrub_oak-4`). The id
is the tree's identity: changing it gives a different tree, and the same id always
gives the same tree for a world seed. To preview a state, change the scene's exports
(for example `growth`) in the Inspector.

For many copies (reed beds, prop fields), use a scatter scene (`scenes/reed_bed/`) or,
later, ProtonScatter (`docs/research/godot-addons-factory.md`). For thousands of
identical meshes, Godot recommends `MultiMeshInstance3D`, split into separate nodes per
area so culling still works.

## Sources

Godot docs: [Visibility ranges (HLOD)](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html),
[Mesh level of detail](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html),
[Import configuration](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html),
[Node type customization](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.html).
