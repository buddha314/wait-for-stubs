## 1. Spike: the built-in stencil outline on our assets

- [x] 1.1 In a scratch scene, put a stencil-outline `material_overlay` (D1) on a reed clump's `Standing` meshes, a snail shell and a lightning bug's body. Capture a windowed screenshot at night and by day. Record whether the blades' transparent/alpha-scissor materials outline cleanly, and which approach was kept (overlay or a per-mesh duplicated material, the fallback) in design.md.

## 2. Data and controller

- [x] 2.1 Add `assets/ui/collectible_outline.json` (`color` `#ffffff`, `width_pixels` 2, per the spike).
- [x] 2.2 `ResourceNode.outline_root` (null → parent) and `outline_meshes()` (every `MeshInstance3D` under it) and `outline_shown`.
- [x] 2.3 `common/collectible_outline.gd`, instanced in the player scene: follows `target_changed`, the target's `collected_changed`, `controls_enabled` and `building`. Outlines at most one pickup, uncollected, only while the controls are free and build mode is off.

## 3. Assets

- [x] 3.1 Lightning bug: `outline_root` = `Body/Model` (moves with the hover).
- [x] 3.2 Reed clump: `outline_root` = `Standing` (plus the far LOD if it's a mesh); never the stubble.
- [x] 3.3 Snail shell: `outline_root` = `Model`.
- [x] 3.4 Snail shell generator winds its faces outward (D1a); regenerated.
- [x] 3.5 Lightning bug: a dark silhouette body while targeted between flashes (D5).

## 3b. Targeting (user report: shells beside reeds were never outlined)

- [x] 3b.1 `Player._choose_target`: the interactable nearest the crosshair within `AIM_DEGREES` (20°) wins; else the nearest horizontally.
- [x] 3b.2 Outline width measured at each mesh's nearest point, not its centre (stalks next to the eye went thick).

## 4. Checks and docs

- [x] 4.1 `tests/test_collectible_outline.gd`: one target outlined, switching targets moves it, collection clears it, an inventory screen or build mode clears it, a bug without the recorder is still outlined, the colour comes from the JSON. Grep for `SCRIPT ERROR` as well as `: OK`.
- [x] 4.2 Play check in a window: walk the reed bed holding E; aim at a shell and a bug at night.
- [x] 4.3 Style guide: one line saying the white outline is UI, the only hard edge allowed. CLAUDE.md: a short **Outline** note under Interaction.
