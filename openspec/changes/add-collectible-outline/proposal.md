## Why

At night on the mudflat it's hard to tell what you're about to collect. A reed clump
looks like the reeds beside it, a snail shell is a few centimetres of brown on brown
mud, and a lightning bug is dark between flashes. The only cue is the "[E] Collect ..."
prompt, which names the target but doesn't show which object it is. Satisfactory
handles this with a white outline around the item under the crosshair. We follow
Satisfactory's conventions (controls already do), so we do the same.

## What Changes

- The pickup that is the player's current E target (a `ResourceNode`: lightning bugs,
  reed clumps, snail shells, and any pickup added later) is drawn with a **white
  outline** around its visible body, as in Satisfactory.
- Only the current target is outlined. The outline moves with the target, goes away
  when nothing is targeted or when the target is collected, and is never shown while a
  screen (rack, inventory) has the controls or in build mode.
- A pickup that can't be collected right now still gets the outline when targeted (a
  sound with no recorder in hand, a full inventory), as in Satisfactory. The prompt and
  tip explain why.
- Outline colour and thickness are data in `assets/ui/collectible_outline.json`. The
  default is white.

## Capabilities

### New Capabilities
- `collectible-outline`: when the targeted pickup is outlined, what is outlined, its
  look, and where its settings live.

### Modified Capabilities
<!-- None: the field recorder's prompt and tip requirements are unchanged. -->

## Impact

- `common/resource_node.gd`: an `outline_root` (the visual to outline; owners set it),
  plus show/hide.
- `lightning_bug.gd`, `reed_clump.gd`, `snail_shell.gd`: set their `outline_root` to
  the visible body. For the reed clump that's the standing reeds, not the stubble.
- A small `common/collectible_outline.gd` that follows `Player.target_changed`.
- `assets/ui/collectible_outline.json`, a test in `tests/`, and one line in the style
  guide: the outline is UI, the one hard-edged line allowed in the world.
- **Existing tools used:** Godot's built-in stencil outline (`BaseMaterial3D`
  `stencil_mode = Outline`, `stencil_color`, `stencil_outline_thickness`, present in
  our 4.8 build) applied as a `material_overlay`, and the player's existing
  `target_changed` signal. **Written from scratch:** only the glue that picks the
  meshes and switches the overlay on and off. No shader, addon or Blender change.
