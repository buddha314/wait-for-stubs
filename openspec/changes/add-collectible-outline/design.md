## Context

The player picks the E target in `scenes/player/player.gd` (`_choose_target`, emitting
`target_changed(target)`). Pickups are `ResourceNode`s, which are small `Area3D` markers.
Their visible bodies are separate meshes owned by the asset scene:

- the lightning bug's `Body/Model`, which hovers at a seeded height above the marker;
- the reed clump's `Standing` reeds (cut to `Stubble` when collected; the far LOD is a
  billboard);
- the snail shell's `Model`.

There is no stubby-music change to port: Bevy never outlined pickups. The look follows
Satisfactory, as the user directed (2026-11-13): "Satisfactory uses a white outline;
default to Satisfactory when uncertain."

## Goals / Non-Goals

**Goals:** outline the one targeted pickup, white, with Godot built-ins; one
place to change the colour and thickness; works for every current and future
`ResourceNode`.

**Non-Goals:** outlining machines (`MachineInteract`) or stream ports, which have their
own amber halos; a discovery glow on pickups that aren't targeted; VR pointer
targeting (the outline follows `target`, so it carries over when the pointer is added).

## Decisions

**D1. Godot's built-in stencil outline, as a `material_overlay`.** Every
`MeshInstance3D` under the pickup's `outline_root` gets one shared overlay material:
a `StandardMaterial3D` with `stencil_mode = Outline`, `stencil_color` and
`stencil_outline_thickness` from the data file, unshaded, and a fully transparent
albedo so the overlay pass only writes the stencil. Godot then generates the outline
next pass from it. We clear the overlay to un-outline. That restores the
mesh exactly, because none of these assets use `material_overlay` today.
- *Rejected: inverted-hull shader (a grown, front-culled copy).* It's hand-written and
  breaks on the reeds' thin, open blades, which have no closed hull. The stencil
  outline handles those.
- *Rejected: a screen-space edge post-process (depth or normal Sobel, or a mask
  SubViewport).* It needs a custom compositor effect or a second render of the target,
  and it's more code for the same result.
- *Rejected: an addon.* The outline addons on the Asset Library wrap one of the
  techniques above. Godot ≥ 4.5 ships the stencil outline itself (probe: `stencil_mode`
  `Disabled,Outline,X-Ray,Custom` and `stencil_outline_thickness` are on `BaseMaterial3D`
  in our 4.8 build).
- *Rejected: the soft accent halo first drafted.* Satisfactory uses a white outline,
  and the user chose it.

**D1a (spike result, 2026-11-13).** The overlay works on all three assets, the reeds'
thin blades included. Two findings:
- **Thickness has to be in pixels.** A fixed world thickness swallowed the shell and
  the reed blades (2 cm turned them solid white). `CollectibleOutline` gives each
  outlined mesh its own overlay and sets `stencil_outline_thickness` every frame to
  `width_pixels` at that mesh's camera distance, divided by its scale (the outline
  grows the mesh in its own space). That's Satisfactory's constant on-screen line.
- **The outline grows along normals, so they must face out.** The snail shell's tube
  was wound inward (two-thirds of its normals pointed in, hidden by its double-sided
  material), so the outline grew into the shell and vanished. Fixed at the source:
  `create_snail_shell.py` winds its faces outward; the shell was regenerated.

**D2. The owner says what to outline.** `ResourceNode` gains `outline_root: Node3D`
(null means the pickup's parent). Each asset sets it to its visible body: the bug its
`Body/Model`, the shell its `Model`, the clump `Standing` plus the far-LOD billboard if
it is a mesh. The meshes are gathered when the outline turns on, so generated children
(reed clumps build theirs in `_ready`) are included. The marker itself has no mesh.

**D3. One controller follows the target.** `common/collectible_outline.gd` is a plain
node in the player scene. It connects to `target_changed`, `collected_changed` of the
current target, `controls_enabled` and `building`. It shows the outline only for a
`ResourceNode` target that isn't collected while the controls are free and build mode
is off. Keeping this out of `ResourceNode` puts the one-at-a-time rule in a single
place. Pickups that can't be collected right now are still outlined (spec), matching
Satisfactory, where the outline means "this is what you're aiming at".

**D4. Settings in `assets/ui/collectible_outline.json`:**
`{"color": "#ffffff", "width_pixels": 2.0}`, loaded with `AssetProfile.load_json`
(see D1a for why pixels, not metres).

**D6. The crosshair picks the target.** Targeting was "nearest, measured
horizontally". Shells lie at the reed beds' edges, so the clump beside a shell was
nearly always nearer, and a shell the player looked straight at was never outlined
(user report, 2026-11-13). Satisfactory targets what's under the crosshair: the
interactable whose marker is nearest the view axis, within 20°, now wins. The old rule
stays as the fallback when nothing is in the cone, so holding E still sweeps a bed and
every existing test passes unchanged.
- *Rejected: a physics ray from the camera.* Markers are 0.25 m spheres; a shell's is
  hard to hit exactly, and a ray would need the marker to be the first thing hit.
  The cone is forgiving and needs no extra collision.

**D5. A targeted lightning bug keeps a body.** A bug is its flash: its whole model is
white emission, scaled by the flash envelope, so between flashes there is nothing to
outline. While targeted (`ResourceNode.outline_shown`, set by the controller before
the overlay goes on), the bug's model stays at full size: a dark silhouette
(`#100b19`) between flashes, white while flashing. Its light still follows the
envelope, so it never glows on its own. The silhouette material is per bug: a
`static var` Resource outlived the renderer at exit and crashed the 4.8 beta.
- *Rejected: no outline between flashes.* That left the target invisible for most of
  the time (user report, 2026-11-13: "not reading at all").

**Style guide.** Living light in the world is soft-edged. The outline is UI, like the
reticle, so a crisp white line is allowed for it alone. One line in
`docs/art/style-guide.md` records that.

## Risks / Trade-offs

- [The stencil outline is newer and this is a 4.8 beta: it might not combine with
  transparent or alpha-scissor reed materials] → task 1 is a spike on one reed clump
  and a shell, headless screenshot plus a look in the editor. Fallback: set the outline
  as the mesh material's own `stencil_mode` on a duplicated material instead of the
  overlay (still built-in).
- [A shared overlay on many reed blades costs one extra pass per mesh] → only one
  pickup is outlined at a time, so the cost is bounded by the largest clump.
- [Stencil reference collision with Sky3D or other stencil users] → none in the project
  today; the reference value goes in the data file if one ever appears.
- [The bug's body is small and far above the marker] → it's outlined at its body,
  which is the point of D2. Targeting itself is unchanged.
