# Resolved: parts exported at scale 0 lost their meshes' transforms

*Found 2026-11-13 while porting the scrub oak (`add-scrub-oak`). The generators have
since moved into this repo (`tools/blender/`), so the fix is ours to make.*

**Resolved 2026-11-13.** `tools/blender/export_gltf.py` now exports any object posed
at scale 0 at scale 1, tagged with the glTF extra `start_scale: 0`.
`tools/import/asset_lod_import.gd` puts those parts back to scale 0 at import, so
models still ship posed (dormant, closed, hidden) with correct children.
`tools/collider_shapes.py` honours the tag too. Every model was re-exported, and
`tests/test_scrub_oak.gd` checks it: leaves and catkins show at full bloom.

## What happened

Several Blender generators export "growth" or "state" parts at their starting scale,
0. Examples: the scrub oak's `Foliage_<n>` and `Bloom_<k>`, the reeds' `Stubble`,
the halos. Blender's glTF exporter can't keep a child's local transform under a parent
whose scale is 0. The parent-inverse matrix is singular, so the children come out with
scale 0 and meaningless translations. For example, `ScrubOak_Bloom_0_Catkin0` has
`scale [0,0,0]` and `translation [8,-4,-4]` inside `Bloom_0`.

Scaling the named part back to 1 in a game shows nothing, because its children are
still at 0. Forcing the children to 1 puts leaves and catkins in the wrong place, at
the wrong size. This affects Bevy as much as Godot. Both read the same glTF.

## Fix (in `tools/blender/`)

Export state parts at **full scale** (1), or at a tiny nonzero scale such as 1e-4, so
the children keep real transforms. Let the profile say what the game should set at
load. For example, the scrub oak's growth `starts: 0` already tells the game to
pose the tree dormant. In `tools/blender/`, that means calling `set_growth(1)`
(or the equivalent "fully shown" pose) before `export_gltf.py` runs, then re-exporting.
The game already poses every part from the profile, so nothing in the profiles changes.

A quick check after re-exporting: no node with `scale [0,0,0]` should have
children with `scale [0,0,0]`. `tests/test_scrub_oak.gd` here prints a SKIP line
until that holds for the oak.

## Affected models (2026-11-13)

| Model | Broken parts | Part kinds |
| --- | --- | --- |
| `models/flora/reeds/reed_clump_0.glb` | 1 | `Stubble` |
| `models/flora/reeds/reed_clump_1.glb` | 1 | `Stubble` |
| `models/flora/reeds/reed_clump_2.glb` | 1 | `Stubble` |
| `models/flora/reeds/reed_clump_3.glb` | 1 | `Stubble` |
| `models/flora/scrub_oak/scrub_oak_0.glb` | 97 | `Bloom_<n>`, `Foliage_<n>`, `ScrubOak_Far_Foliage_Node` |
| `models/flora/scrub_oak/scrub_oak_1.glb` | 106 | `Bloom_<n>`, `Foliage_<n>`, `ScrubOak_Far_Foliage_Node` |
| `models/flora/scrub_oak/scrub_oak_2.glb` | 124 | `Bloom_<n>`, `Foliage_<n>`, `ScrubOak_Far_Foliage_Node` |
| `models/flora/scrub_oak/scrub_oak_3.glb` | 124 | `Bloom_<n>`, `Foliage_<n>`, `ScrubOak_Far_Foliage_Node` |
| `models/flora/scrub_oak/scrub_oak_4.glb` | 115 | `Bloom_<n>`, `Foliage_<n>`, `ScrubOak_Far_Foliage_Node` |
| `models/flora/scrub_oak/scrub_oak_5.glb` | 91 | `Bloom_<n>`, `Foliage_<n>`, `ScrubOak_Far_Foliage_Node` |
| `models/machines/mudpit_burbler.glb` | 1 | `Outlet_0_Halo` |
| `models/props/desert/desert_brush_0.glb` | 26 | `Bloom_<n>` |
| `models/props/desert/desert_brush_1.glb` | 26 | `Bloom_<n>` |
| `models/props/desert/desert_brush_2.glb` | 26 | `Bloom_<n>` |
| `models/props/desert/desert_debris_0.glb` | 9 | `Bloom_<n>` |
| `models/props/desert/desert_debris_1.glb` | 6 | `Bloom_<n>` |
| `models/props/desert/desert_debris_2.glb` | 7 | `Bloom_<n>` |
| `models/props/desert/desert_stump_0.glb` | 10 | `Bloom_<n>` |
| `models/props/desert/desert_stump_1.glb` | 11 | `Bloom_<n>` |
| `models/props/desert/desert_stump_2.glb` | 11 | `Bloom_<n>` |
| `models/streams/stream_segment.glb` | 2 | `Port_in_Halo`, `Port_out_Halo` |

The dormant and "closed" starting states still look right. What's lost is everything
that should appear later: leaves, blooms, catkins, stubble after cutting, halos when
a connection is attempted.
