extends Node
## The game's rules as data: items, resources and the starter inventory, read
## from assets/recipes/*.json (stubby-music's designer-owned rule files).
## Keep rules in the JSON. Don't hardcode yields or names in scripts.

const DIR := "res://assets/recipes/"

var _items: Dictionary[String, Dictionary] = {}
var _resources: Dictionary[String, Dictionary] = {}
var _start: Array = []


func _init() -> void:
	for row: Dictionary in AssetProfile.load_json(DIR + "items.json").get("items", []):
		_items[row.id] = row
	for row: Dictionary in AssetProfile.load_json(DIR + "resources.json").get("resources", []):
		_resources[row.id] = row
	_start = AssetProfile.load_json(DIR + "start.json").get("inventory", [])


func item_name(id: String) -> String:
	return _items.get(id, {}).get("name", id)


func item_description(id: String) -> String:
	return _items.get(id, {}).get("description", "")


## Every item id in the catalog, in file order.
func item_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_items.keys())
	return ids


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
