## Why

The player can't see what they carry beyond a line of text in the bottom left, and the
inventory has no real limits: 16 "stacks" means 16 kinds of item, with no box size.
Streams (`add-stream-building`) are about to spend reeds by the dozen, so the inventory
needs Satisfactory's model and a screen: Tab, 16 boxes of up to 100, all-or-nothing.

## What Changes

- **Tab opens the inventory screen** (ports the `inventory-screen` capability of
  stubby-music's `add-inventory-and-goals-hud`; its goals hub is left for a later
  change). A grid of 16 boxes with each item's icon and count, the name on hover, and
  the selected item's name and description beside it. Tab or Esc closes it. While it's
  open the cursor is free and the player stops, as with the rack screen; opening it
  closes the rack screen.
- **16 boxes of up to 100.** An item fills as many boxes as it needs. Adding that
  doesn't fit fails without changing anything, with an "INVENTORY FULL" notice and the
  item's icon.
- **Built on GLoot** (peter-kish, MIT, v3.0.2), as `docs/research/godot-addons-factory.md`
  decided: its `Inventory` with a 4 × 4 `GridConstraint` holds the boxes, and its
  `CtrlInventoryGrid` draws them. Prototypes are built from `items.json` at start, so
  `Rules` still owns the item data.
- **BREAKING (internal):** the `Inventory` autoload is renamed `PlayerInventory`, because
  GLoot's `class_name Inventory` would hide it. Its API is unchanged.
- **Item counts leave the text HUD.** The bottom-left HUD keeps the prompt and feedback.
- **Input action** `inventory` (Tab).

## Capabilities

### New Capabilities
- `inventory-screen`: the Tab screen, the 16 × 100 box model, all-or-nothing adding,
  the full notice, and the HUD split.

### Modified Capabilities
None (`openspec/specs/` has no inventory capability). The rack screen keeps using the
inventory through the same calls.

## Impact

- **Reused:** GLoot v3.0.2 vendored in `addons/gloot/` (MIT; not edited); the item
  icons in `assets/ui/icons/`; `items.json` and `start.json`; the screen-mode pattern of
  the rack screen (`Player.controls_enabled`, cursor visible).
- **New code:** `scenes/inventory_screen/` (scene and script), a GLoot-backed
  `autoload/inventory.gd`, a notice in `scenes/hud/`, and `tests/test_inventory.gd`.
- **Renamed references:** `common/resource_node.gd`, `scenes/player/player.gd`,
  `scenes/rack_screen/rack_screen.gd`, `scenes/hud/hud.gd`, the tests and `project.godot`.
- **Written from scratch:** nothing beyond glue. The box arithmetic (fill existing boxes
  first, then new ones, all or nothing) is a check before calling GLoot.
