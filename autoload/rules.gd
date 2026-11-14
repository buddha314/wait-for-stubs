extends Node
## The game's rules as data: items, resources and the starter inventory, read
## from assets/recipes/*.json (stubby-music's designer-owned rule files).
## Keep rules in the JSON. Don't hardcode yields or names in scripts.

const DIR := "res://assets/recipes/"

var _items: Dictionary[String, Dictionary] = {}
var _resources: Dictionary[String, Dictionary] = {}
var _start: Array = []
var _buildables: Dictionary[String, Dictionary] = {}
var _mines: Dictionary[String, Dictionary] = {}
var _goals: Array[Dictionary] = []
## Problems found validating the rule files ("file: id: field: message").
var errors: PackedStringArray = []


func _init() -> void:
	for row: Dictionary in AssetProfile.load_json(DIR + "items.json").get("items", []):
		_items[row.id] = row
	for row: Dictionary in AssetProfile.load_json(DIR + "resources.json").get("resources", []):
		_resources[row.id] = row
	_start = AssetProfile.load_json(DIR + "start.json").get("inventory", [])
	_load_buildables(AssetProfile.load_json(DIR + "buildables.json").get("buildables", []))
	for row: Dictionary in AssetProfile.load_json(DIR + "mines.json").get("mines", []):
		_mines[row.id] = row
	var checked := check_goals(AssetProfile.load_json(DIR + "goals.json").get("goals", []))
	_goals = checked.goals
	for text: String in checked.errors:
		errors.append(text)
		push_error("Rules: " + text)


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


## The goals that passed the checks, in file order (add-goals-hub).
func goals() -> Array[Dictionary]:
	return _goals


## Checks goal rows (add-goals-hub D6) and returns {goals: the valid rows in order,
## errors: "goals.json: id: field: message"}. A rejected major goal takes its steps with
## it. Takes any rows, so tests check fixtures, never the shipped goals (D9).
func check_goals(rows: Array) -> Dictionary:
	var errs: PackedStringArray = []
	var err := func(id: String, field: String, message: String) -> void:
		errs.append("goals.json: %s: %s: %s" % [id, field, message])
	var by_id: Dictionary[String, Dictionary] = {}
	var order: Array[String] = []
	var bad: Dictionary[String, bool] = {}
	for row: Dictionary in rows:
		var id: String = row.get("id", "")
		if by_id.has(id):
			err.call(id, "id", "duplicate id")
			continue
		by_id[id] = row
		order.append(id)
	for id in order:
		var row := by_id[id]
		var scale: String = row.get("scale", "")
		var has_condition := row.has("condition")
		var has_requires := row.has("requires")
		if scale == "major":
			for field: String in ["part_of", "condition", "requires"]:
				if row.has(field):
					err.call(id, field, "a major goal has no %s: it completes with its last step" % field)
					bad[id] = true
			if not order.any(func(other: String) -> bool: return by_id[other].get("part_of", "") == id):
				err.call(id, "scale", "a major goal needs at least one step")
				bad[id] = true
		elif scale == "minor":
			var major: String = row.get("part_of", "")
			if major.is_empty():
				err.call(id, "part_of", "a minor goal belongs to a major goal")
				bad[id] = true
			elif by_id.get(major, {}).get("scale", "") != "major":
				err.call(id, "part_of", "'%s' is not a major goal" % major)
				bad[id] = true
			if has_condition == has_requires:
				err.call(id, "condition", "needs exactly one of condition and requires")
				bad[id] = true
			elif has_condition:
				var problem := _condition_problem(row.condition)
				if not problem.is_empty():
					err.call(id, "condition", problem)
					bad[id] = true
			else:
				for stack: Dictionary in row.requires:
					if not _items.has(stack.get("item", "")):
						err.call(id, "requires", "unknown item '%s'" % stack.get("item", ""))
						bad[id] = true
		else:
			err.call(id, "scale", "must be major or minor, not '%s'" % scale)
			bad[id] = true
		for other: String in row.get("after", []):
			if not by_id.has(other):
				err.call(id, "after", "unknown goal '%s'" % other)
				bad[id] = true
	for id in _goal_cycle(by_id, order):
		err.call(id, "after", "is part of a cycle")
		bad[id] = true
	var valid: Array[Dictionary] = []
	for id in order:
		var major: String = by_id[id].get("part_of", "")
		if not bad.has(id) and not bad.has(major):
			valid.append(by_id[id])
	return {"goals": valid, "errors": errs}


## Why a goal condition is invalid, or "" if it's fine.
func _condition_problem(condition: Dictionary) -> String:
	match condition.get("kind", ""):
		"machine_configured":
			return "" if _mines.has(condition.get("machine", "")) else "unknown machine '%s'" % condition.get("machine", "")
		"tree_watered":
			return "" if _mines.has(condition.get("mine", "")) else "unknown mine '%s'" % condition.get("mine", "")
		"tree_grown":
			var mine: String = condition.get("mine", "")
			if not _mines.has(mine):
				return "unknown mine '%s'" % mine
			var names := bloom_levels(mine)
			return "" if names.has(condition.get("level", "")) else "unknown bloom level '%s' for %s (%s)" % [condition.get("level", ""), mine, ", ".join(names)]
		"item_held":
			var quantity: Variant = condition.get("quantity", 0)
			if not _items.has(condition.get("item", "")):
				return "unknown item '%s'" % condition.get("item", "")
			if not (quantity is float or quantity is int) or quantity != floorf(quantity) or quantity < 1:
				return "quantity must be a whole number of at least 1"
			return ""
	return "unknown condition kind '%s'" % condition.get("kind", "")


## Goals on a prerequisite cycle of `after` links.
func _goal_cycle(by_id: Dictionary[String, Dictionary], order: Array[String]) -> Array[String]:
	var on_cycle: Array[String] = []
	for start in order:
		# Depth-first from `start`; a path back to it is a cycle.
		var stack: Array[String] = []
		var seen: Dictionary[String, bool] = {}
		for next: String in by_id[start].get("after", []):
			stack.append(next)
		while not stack.is_empty():
			var id: String = stack.pop_back()
			if id == start:
				on_cycle.append(start)
				break
			if seen.has(id) or not by_id.has(id):
				continue
			seen[id] = true
			for next: String in by_id[id].get("after", []):
				stack.append(next)
	return on_cycle


## Bloom level names of a mine's growing asset (its growth.json, found in the asset's
## folder `res://assets/<category>/<mine>/`), lowest first; [] if it doesn't grow.
func bloom_levels(mine: String) -> PackedStringArray:
	var names: PackedStringArray = []
	var assets := DirAccess.open("res://assets")
	if assets == null:
		return names
	for category in assets.get_directories():
		var path := "res://assets/%s/%s/growth.json" % [category, mine]
		if FileAccess.file_exists(path):
			var levels: Array = AssetProfile.load_json(path).get("levels", [])
			levels.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.growth < b.growth)
			for level: Dictionary in levels:
				names.append(level.name)
	return names


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
