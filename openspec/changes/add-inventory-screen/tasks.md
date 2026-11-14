## 1. GLoot and the rename

- [x] 1.1 Vendor GLoot v3.0.2 into `addons/gloot/` (LICENSE, `VERSION` with the tag and commit); enable its editor plugin
- [x] 1.2 Rename the `Inventory` autoload to `PlayerInventory` in `project.godot` and every caller; grep finds no stale `Inventory.` call outside `addons/`

## 2. The box model

- [x] 2.1 `PlayerInventory` holds a GLoot `Inventory` with a 4 × 4 `GridConstraint`; the protoset is built from `items.json` (name, description, icon, `max_stack_size` 100)
- [x] 2.2 `quantity`, `items`, `take`, `give`, `has_room`, `harvest` over the boxes; `give` and `harvest` all or nothing (fill existing boxes, then new ones); `book` and `feedback` unchanged
- [x] 2.3 A full inventory sets the "INVENTORY FULL" notice with the item; the HUD shows it briefly with the icon
- [x] 2.4 `tests/test_inventory.gd`: 250 reeds fill 100/100/50; full refuses and leaves the inventory unchanged; take across boxes; the starter 10 patch cables

## 3. The screen

- [x] 3.1 Input action `inventory` (Tab) in `project.godot`
- [x] 3.2 `scenes/inventory_screen/`: `CanvasLayer` with `CtrlInventoryGrid` on the player's GLoot inventory, counts on boxes, name and description of the hovered or selected box; Tab/Esc close; controls off and cursor free while open; opening closes the rack screen
- [x] 3.3 Instance it in `main.tscn`; remove item counts from the bottom-left HUD
- [x] 3.4 Headless test of open/close, the rack-screen hand-off, and the boxes shown for 2 square waves and 6 reeds

## 4. Docs

- [x] 4.1 CLAUDE.md: controls, layout (`addons/gloot/`, `scenes/inventory_screen/`), the `PlayerInventory` name; run `openspec validate --strict add-inventory-screen`
