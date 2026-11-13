extends Node
## The player's inventory and recipe book. The book remembers every item ever
## collected, even after its quantity drops back to zero.

signal changed

var items: Dictionary[String, int] = {}
var book: Array[String] = []
## The last thing that happened, for the HUD.
var feedback: String = ""


func _ready() -> void:
	for stack: Dictionary in Rules.start_inventory():
		items[stack.item] = quantity(stack.item) + int(stack.quantity)
	changed.emit()


func quantity(item: String) -> int:
	return items.get(item, 0)


## Adds a resource's yields. Returns false if it yields nothing.
func harvest(resource_id: String) -> bool:
	var yields := Rules.resource_yields(resource_id)
	if yields.is_empty():
		feedback = "Nothing to collect from %s." % Rules.resource_name(resource_id)
		changed.emit()
		return false
	var parts: PackedStringArray = []
	for stack: Dictionary in yields:
		items[stack.item] = quantity(stack.item) + int(stack.quantity)
		if stack.item not in book:
			book.append(stack.item)
		parts.append("%d x %s" % [stack.quantity, stack.item])
	feedback = "Collected %s. Available as recipe ingredients." % ", ".join(parts)
	changed.emit()
	return true


func set_feedback(text: String) -> void:
	if feedback != text:
		feedback = text
		changed.emit()
