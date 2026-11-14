extends SceneTree
## The inventory (add-inventory-screen): 16 boxes of up to 100 (GLoot), all or nothing,
## the starter cables, and the Tab screen.
##   godot --headless --path . -s tests/test_inventory.gd

var _failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var inv := root.get_node("PlayerInventory")
	_expect(inv.quantity("patch_cable") == 10 and inv.boxes.get_item_count() == 1, "starts with 10 patch cables in one box")

	# 250 reeds fill 100, 100, 50.
	_expect(inv.give("reed", 250), "250 reeds fit")
	var sizes: Array = inv.boxes.get_items_with_prototype_id("reed").map(func(b: InventoryItem) -> int: return b.get_stack_size())
	_expect(sizes == [100, 100, 50], "reeds fill 100/100/50 (got %s)" % [sizes])
	_expect(inv.quantity("reed") == 250 and inv.items["reed"] == 250, "quantity sums the boxes")

	# Taking across boxes empties the last-filled first.
	_expect(inv.take("reed", 120), "take 120")
	sizes = inv.boxes.get_items_with_prototype_id("reed").map(func(b: InventoryItem) -> int: return b.get_stack_size())
	_expect(sizes == [100, 30], "120 taken leaves 100/30 (got %s)" % [sizes])
	_expect(not inv.take("reed", 1000) and inv.quantity("reed") == 130, "taking too many takes nothing")

	# Fill every box, then a new kind doesn't fit and nothing changes.
	_expect(inv.give("clock", 13 * 100), "13 boxes of clocks fit (16 in use)")
	_expect(inv.boxes.get_item_count() == 16, "all 16 boxes in use")
	_expect(inv.give("reed", 70) and inv.quantity("reed") == 200, "reeds still top up their own box")
	var before: Dictionary = inv.items.duplicate()
	_expect(not inv.give("square_wave", 2), "a new kind needs a box: refused")
	_expect(inv.items == before and inv.full_item == "square_wave" and inv.feedback == "INVENTORY FULL",
			"full: unchanged, with the notice for the item")
	_expect(not inv.harvest("lightning_bug") and inv.items == before, "a harvest that doesn't fit takes nothing")
	_expect(not inv.give("reed", 1), "a full reed box and no free box refuses")

	# The Tab screen, in the opening scene.
	inv.take("clock", inv.quantity("clock"))
	inv.take("reed", inv.quantity("reed"))
	inv.give("square_wave", 2)
	inv.give("reed", 6)
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var screen: Node = main.get_node("InventoryScreen")
	var player: Node = main.get_node("Player")
	var hud: Node = main.get_node("HUD")
	_expect(not screen.is_open() and player.controls_enabled, "starts closed, player free")
	_action("inventory")
	await process_frame
	_expect(screen.is_open() and not player.controls_enabled, "Tab opens it and stops the player")
	var grid: Control = screen.get("_grid")
	var shown: Array = grid.inventory.get_items().map(func(b: InventoryItem) -> String:
			return "%s:%d" % [b.get_prototype().get_prototype_id(), b.get_stack_size()])
	shown.sort()
	_expect(shown == ["patch_cable:10", "reed:6", "square_wave:2"], "the grid shows the boxes held (%s)" % [shown])
	_action("inventory")
	await process_frame
	_expect(not screen.is_open() and player.controls_enabled, "Tab closes it")
	_action("inventory")
	await process_frame
	_action("release_cursor")
	await process_frame
	_expect(not screen.is_open(), "Esc closes it")

	# Opening it closes the rack screen.
	var rack: Node = main.get_node("RackScreen")
	rack.open_rack(main.get_node("MudpitBurbler").find_child("MachineInteract", true, false))
	await process_frame
	_expect(rack.is_open(), "rack open")
	screen.open()
	_expect(screen.is_open() and not rack.is_open(), "Tab's screen closes the rack screen")
	screen.close()

	# No counts in the text HUD; a refusal shows the notice.
	var status: String = hud.get_node("Status").text
	_expect(not status.contains("Inventory:") and not status.contains("6 reed"), "no item counts in the HUD (%s)" % status)
	inv.give("clock", 13 * 100)
	inv.give("patch_cable", 90)  # fills the cable box: 13 + 3 boxes in use
	inv.give("square_wave", 98)
	inv.give("reed", 94)
	_expect(not inv.give("reed", 1) and hud.full_notice_visible(), "the full notice shows")
	main.free()

	if _failures.is_empty():
		print("test_inventory: OK")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		quit(1)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)


func _action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
