## Context

`autoload/inventory.gd` is a dictionary of counts with a 16-kind limit. The rack screen,
the pickups and the HUD call `quantity`, `harvest`, `take`, `give`, `has_room`,
`items`, `book`, `feedback` and the `changed` signal. stubby-music specified the Tab
screen in `add-inventory-and-goals-hud` (`inventory-screen` spec) but its Bevy code
isn't reused; the spec is.

## Goals / Non-Goals

**Goals:** Satisfactory's 16 boxes of 100; a Tab screen; all-or-nothing adding; the
existing API kept so callers don't change beyond the rename.

**Non-Goals:** the goals hub and pinned recipes (a later change, from the same
stubby-music change); dragging items out of the inventory; machine input and output
buffers (GLoot will serve those too, later); saving.

## Decisions

**D1 — GLoot for storage and the grid.** GLoot's `Inventory` plus a `GridConstraint`
(4 × 4, every item 1 × 1) holds the boxes; each box is one GLoot item stack with
`max_stack_size` 100. `CtrlInventoryGrid` draws them, with icons from each prototype's
`image` property and names from `name`. *Rejected:*
- **Keeping our dictionary and drawing a grid by hand.** That would be the same code
  GLoot already has, against the "existing tools first" rule.
- **Inventory System (expressobits).** A C++ GDExtension with no release since March,
  and it owns items and recipes that our JSON owns
  (`docs/research/godot-addons-factory.md`).
- **Wyvernbox.** An ARPG inventory; only its ingredient patterns fit us.

**D2 — `Rules` stays the owner of item data.** The protoset is built at start from
`items.json` (id → `name`, `description`, `image`, `max_stack_size`), so designers keep
editing the JSON and GLoot never holds a second copy. The box size (100) and box
count (16) are constants of the inventory, as in Satisfactory, not item data.

**D3 — Rename the autoload `PlayerInventory`.** GLoot declares `class_name Inventory`;
an autoload of the same name is hidden by it. The vendored addon isn't edited, so ours
moves. *Rejected:* editing GLoot's class name (forks the addon on every update).

**D4 — All-or-nothing in front of GLoot.** `give` and `harvest` first compute whether
the whole amount fits: free space in the item's existing boxes plus 100 per empty box.
Only then do they add, filling existing boxes first and then new ones. GLoot's
`add_item_autosplitmerge` would add a partial amount, which the spec forbids.

**D5 — Screen mode like the rack screen.** The screen is a `CanvasLayer` that sets
`Player.controls_enabled = false` and frees the cursor. Opening it closes an open rack
screen (group `rack_screen`). The rack screen keeps its own inventory panel for
mounting.

## Risks / Trade-offs

- [A GLoot update changes its API] → pinned to v3.0.2 in `addons/gloot/VERSION`; the
  test covers the calls we use.
- [The rename misses a caller] → the headless tests and a main-scene run catch parse
  errors; a grep for `Inventory.` outside `addons/` must find only GLoot's class.
