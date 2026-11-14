extends Node
## The player's inventory (autoload `PlayerInventory`) and recipe book: 16 boxes of up
## to 100 items each, as in Satisfactory (add-inventory-screen). The boxes are GLoot
## item stacks in a 4 × 4 GridConstraint (`boxes`); the item data comes from
## items.json through Rules, so GLoot never holds its own copy. Adding is all or
## nothing. The book remembers every item ever collected, even after its quantity
## drops back to zero.

signal changed
## Something didn't fit: `item` was refused (the HUD shows "INVENTORY FULL").
signal refused(item: String)

## Boxes and their size (the inventory's shape, not item data).
const STACKS := 16
const BOX_SIZE := 100
const GRID := Vector2i(4, 4)
const ICON_PATH := "res://assets/ui/icons/%s.png"

## The GLoot inventory holding the boxes (the inventory screen draws it).
var boxes: Inventory
var book: Array[String] = []
## The last thing that happened, for the HUD.
var feedback: String = ""
## Set when something didn't fit: the item id, for the HUD's "INVENTORY FULL" notice.
var full_item: String = ""
## item id -> total held, across its boxes.
var items: Dictionary[String, int]:
	get:
		var totals: Dictionary[String, int] = {}
		for box: InventoryItem in boxes.get_items():
			var id := box.get_prototype().get_prototype_id()
			totals[id] = totals.get(id, 0) + box.get_stack_size()
		return totals


func _ready() -> void:
	boxes = Inventory.new()
	boxes.name = "Boxes"
	var protoset := JSON.new()
	protoset.data = _prototypes()
	boxes.protoset = protoset
	var grid := GridConstraint.new()
	grid.name = "Grid"
	grid.size = GRID
	boxes.add_child(grid)
	add_child(boxes)
	for stack: Dictionary in Rules.start_inventory():
		_add(stack.item, int(stack.quantity))
	changed.emit()


## GLoot prototypes from the item catalog: name, description, icon, box size.
static func _prototypes() -> Dictionary:
	var out := {}
	for id: String in Rules.item_ids():
		var proto := {"name": Rules.item_name(id), "description": Rules.item_description(id),
				"max_stack_size": BOX_SIZE}
		if ResourceLoader.exists(ICON_PATH % id):
			proto["image"] = ICON_PATH % id
		out[id] = proto
	return out


func quantity(item: String) -> int:
	return items.get(item, 0)


## How many more of `item` fit: free space in its boxes plus a box per empty one.
func room_for(item: String) -> int:
	if not boxes.protoset.data.has(item):
		return 0
	var free := 0
	for box: InventoryItem in boxes.get_items_with_prototype_id(item):
		free += BOX_SIZE - box.get_stack_size()
	return free + (STACKS - boxes.get_item_count()) * BOX_SIZE


## True if one more `item` fits.
func has_room(item: String) -> bool:
	return room_for(item) >= 1


## Adds a resource's yields, all or nothing. Returns false if it yields nothing or
## doesn't fit.
func harvest(resource_id: String) -> bool:
	var yields := Rules.resource_yields(resource_id)
	if yields.is_empty():
		feedback = "Nothing to collect from %s." % Rules.resource_name(resource_id)
		changed.emit()
		return false
	if not _fits(yields):
		_report_full(yields[0].item)
		return false
	var parts: PackedStringArray = []
	for stack: Dictionary in yields:
		_add(stack.item, int(stack.quantity))
		if stack.item not in book:
			book.append(stack.item)
		parts.append("%d x %s" % [stack.quantity, stack.item])
	feedback = "Collected %s. Available as recipe ingredients." % ", ".join(parts)
	full_item = ""
	changed.emit()
	return true


## Takes `count` of an item. Returns false, taking nothing, if there aren't enough.
func take(item: String, count: int = 1) -> bool:
	if quantity(item) < count:
		return false
	var left := count
	var held := boxes.get_items_with_prototype_id(item)
	held.reverse()  # empty the last-filled boxes first
	for box: InventoryItem in held:
		var n := mini(left, box.get_stack_size())
		if n == box.get_stack_size():
			boxes.remove_item(box)
		else:
			box.set_stack_size(box.get_stack_size() - n)
		left -= n
		if left == 0:
			break
	changed.emit()
	return true


## Adds `count` of an item. Returns false, adding nothing, if it doesn't all fit.
func give(item: String, count: int = 1) -> bool:
	if room_for(item) < count:
		_report_full(item)
		return false
	_add(item, count)
	changed.emit()
	return true


## What building `count` of a cost would still need: [{item, quantity}] (empty = affordable).
func shortfall(cost: Array, count: int = 1) -> Array:
	var short := []
	for stack: Dictionary in cost:
		var need := int(stack.quantity) * count - quantity(stack.item)
		if need > 0:
			short.append({"item": stack.item, "quantity": need})
	return short


func can_afford(cost: Array, count: int = 1) -> bool:
	return shortfall(cost, count).is_empty()


## Takes `count` × `cost`, all or nothing. False (taking nothing) if anything is short.
func spend(cost: Array, count: int = 1) -> bool:
	if not can_afford(cost, count):
		return false
	for stack: Dictionary in cost:
		take(stack.item, int(stack.quantity) * count)
	return true


## Gives back `count` × `cost` (a dismantle). Returns false if it didn't all fit; what
## fits is still returned, item by item.
func refund(cost: Array, count: int = 1) -> bool:
	var ok := true
	for stack: Dictionary in cost:
		ok = give(stack.item, int(stack.quantity) * count) and ok
	return ok


func set_feedback(text: String) -> void:
	if feedback != text:
		feedback = text
		changed.emit()


## Fills `item`'s existing boxes, then new ones. The caller has checked it fits.
func _add(item: String, count: int) -> void:
	var left := count
	for box: InventoryItem in boxes.get_items_with_prototype_id(item):
		var n := mini(left, BOX_SIZE - box.get_stack_size())
		if n > 0:
			box.set_stack_size(box.get_stack_size() + n)
			left -= n
	while left > 0:
		var box := boxes.create_and_add_item(item)
		if box == null:
			push_error("PlayerInventory: no room for %s after the check" % item)
			return
		var n := mini(left, BOX_SIZE)
		box.set_stack_size(n)
		left -= n


func _fits(stacks: Array) -> bool:
	# Each item kind is checked against the space left once the others are added.
	var boxes_needed := 0
	for stack: Dictionary in stacks:
		var item: String = stack.item
		var count := int(stack.quantity)
		var free := 0
		for box: InventoryItem in boxes.get_items_with_prototype_id(item):
			free += BOX_SIZE - box.get_stack_size()
		if not boxes.protoset.data.has(item):
			return false
		boxes_needed += ceili(maxf(0.0, count - free) / BOX_SIZE)
	return boxes_needed <= STACKS - boxes.get_item_count()


func _report_full(item: String) -> void:
	full_item = item
	feedback = "INVENTORY FULL"
	refused.emit(item)
	changed.emit()
