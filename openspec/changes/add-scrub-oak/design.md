## Context

`assets/flora/scrub_oak/asset.json` gives:
- `variants` (six glTFs);
- `per_instance` ranges;
- `growth` (ramps, node rules, colours);
- `sway` (`Limb_<n>`, 2.5°);
- `far_lod` (45 m; `scrub_oak_<k>_LOD0` and `_LOD1` inside each model);
- `materials` (bark and leaf colour by growth; catkins tinted per instance).

`colliders.json` gives a cylinder per variant (Y up, metres, the same axes as
Godot). stubby-music placed no oaks in its opening.

## Decisions

**D1. Both LODs, by visibility range.** Each model carries its near and far levels
as nodes. Every mesh under `*_LOD0` gets `visibility_range_end = far`, and every
mesh under `*_LOD1` gets `visibility_range_begin = far`, with a 2 m margin and
`FADE_SELF`. That's Godot's built-in HLOD, and it already works for the reeds.

Rejected:
- picking one LOD (too heavy near, or too crude);
- Godot's automatic mesh LOD (it decimates the near mesh, and loses the authored
  far billboard and the foliage node that scales with leaf-out).

The helper lives in `common/asset_lod.gd`. **Revised (user, 2026-11-13: "a master
asset you manipulate in the editor, then the LOD are handled quietly by the engine"),
in line with Godot's import guidance:** the ranges are set once at import by
`tools/import/asset_lod_import.gd`, which is the project's default scene import script
and looks up `far_lod.distance_m` in the profile listing the model. Scenes never set
them, and even a raw `.glb` instance swaps detail.

**D2. Growth display follows the profile's rules exactly.**
`ramp(r) = smoothstep(from, to, growth)`.
- **Nodes:**
  - `Dead_<n>` scale 1 − ramp(dead_leaves_fall);
  - `Bud_<n>` scale (0.4 + 0.6·ramp(buds_swell))·(1 − ramp(buds_open));
  - `Foliage_<n>` scale ramp(leaf_out);
  - `Bloom_<k>` opens over `bloom_open_span`, starting at
    from + (to − from)·order/count;
  - the far foliage node scales with leaf_out.
- **Order:** read from the node's glTF extras when Godot imports them (meta
  `extras`), else k.
- **Materials:** bark and leaf get per-instance copies, so trees differ, and their
  colours lerp by their ramps. The bud's emission is 1.5·ramp(buds_swell).
- `growth` is an export, so the editor previews every stage.

**D3. Seeding as the reeds do.** `WorldSeed.rng(instance_id)` draws the variant,
then yaw, scale, height stretch, lean, sway phase, leaf jitter and bloom tint, in
that order. Children are generated without `owner`, so they're never saved into
scenes.

**D4. Placement.** Three oaks, each a few metres from a pair of lightning bugs:
(−9.5, −12.5), (12.5, −15.5) and (−19.5, 11.5). The ids are `scrub_oak-1` to
`scrub_oak-3`.

**D5. Known upstream issue.** The models ship growth parts at scale 0, and Blender's
exporter loses the transforms of the meshes inside them
(`docs/upstream/zero-scale-exports.md`). Dormant (growth 0, the start) is correct, but
leaves and blooms can't be shown until stubby-music re-exports at full scale. Forcing
the children to scale 1 here was tried and puts them in the wrong place, so it isn't
done.

## Risks / Trade-offs

- [Godot's import of glTF extras varies by version] → fall back to the node index
  for bloom order; it only affects which bloom opens first.
- [14k triangles near × many trees] → LOD1 at 45 m is about 1k; fine for the
  opening's three.
