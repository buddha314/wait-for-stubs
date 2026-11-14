extends Node
## The game's rules as data: items, resources and the starter inventory, read
## from assets/recipes/*.json (stubby-music's designer-owned rule files).
## Keep rules in the JSON. Don't hardcode yields or names in scripts.

const DIR := "res://assets/recipes/"

var _items: Dictionary[String, Dictionary] = {}
var _resources: Dictionary[String, Dictionary] = {}
var _start: Array = []
var _buildables: Dictionary[String, Dictionary] = {}
## Problems found validating the rule files ("file: id: field: message").
var errors: PackedStringArray = []


func _init() -> void:
	for row: Dictionary in AssetProfile.load_json(DIR + "items.json").get("items", []):
		_items[row.id] = row
	for row: Dictionary in AssetProfile.load_json(DIR + "resources.json").get("resources", []):
		_resources[row.id] = row
	_start = AssetProfile.load_json(DIR + "start.json").get("inventory", [])
	_load_buildables(AssetProfile.load_json(DIR + "buildables.json").get("buildables", []))


## Loads buildables, validating each against the item catalog (add-stream-building D5).
func _load_buildables(rows: Array) -> void:
	for row: Dictionary in rows:
		var id: String = row.get("id", "")
		if _buildables.has(id):
			_error("buildables.json", id, "id", "duplicate id")
			continue
		var ok := true
		for stack: Dictionary in row.get("cost", []):
			var quantity: Variant = stack.get("quantity", 0)
			if not _items.has(stack.get("item", "")):
				_error("buildables.json", id, "cost", "unknown item '%s'" % stack.get("item", ""))
				ok = false
			elif not (quantity is float or quantity is int) or quantity != floorf(quantity) or quantity <= 0:
				_error("buildables.json", id, "cost", "quantity must be a positive whole number")
				ok = false
		if ok:
			_buildables[id] = row


func _error(file: String, id: String, field: String, message: String) -> void:
	var text := "%s: %s: %s: %s" % [file, id, field, message]
	errors.append(text)
	push_error("Rules: " + text)


## [{item, quantity}, ...] one of this buildable costs; [] if unknown.
func build_cost(id: String) -> Array:
	return _buildables.get(id, {}).get("cost", [])


func buildable_name(id: String) -> String:
	return _buildables.get(id, {}).get("name", id)


func item_name(id: String) -> String:
	return _items.get(id, {}).get("name", id)


func item_description(id: String) -> String:
	return _items.get(id, {}).get("description", "")


## Every item id in the catalog, in file order.
func item_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_items.keys())
	return ids


## True if a harvest of this resource yields a sound: an item with a `waveform`
## (a lightning bug's square wave) or a `sample` (an authored sound file).
func yields_sound(id: String) -> bool:
	for stack: Dictionary in resource_yields(id):
		var item: Dictionary = _items.get(stack.get("item", ""), {})
		if item.has("waveform") or item.has("sample"):
			return true
	return false


func resource_name(id: String) -> String:
	return _resources.get(id, {}).get("name", id)


## [{item, quantity}, ...] a harvest of this resource yields.
func resource_yields(id: String) -> Array:
	return _resources.get(id, {}).get("yields", [])


## {kind: "next_night"} or {kind: "after", seconds: N}; {} means never returns.
func replenishment(id: String) -> Dictionary:
	return _resources.get(id, {}).get("replenishment", {})


## [{item, quantity}, ...] a new player starts with.
func start_inventory() -> Array:
	return _start
