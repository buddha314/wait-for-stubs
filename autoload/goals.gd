extends Node
## The goal tracker (add-goals-hub): which goals are complete and which are active.
## Major goals are long arcs made of minor goals (steps), done in file order; a major
## goal completes with its last step. A step completes the first time its condition
## holds while it is active, and stays complete (D2, D3). It knows no scenes: the world
## reports conditions through `report`, and `item_held` is read from PlayerInventory.
## Progress isn't saved yet: a new game starts with nothing complete.

## A goal completed (a step, or a major goal with its last step). Once per goal.
signal goal_completed(id: String)
## The active major goal or step changed.
signal active_changed

var _goals: Array[Dictionary] = []
var _by_id: Dictionary[String, Dictionary] = {}
var _complete: Dictionary[String, bool] = {}
## Condition key -> {instance_id: true} for the instances where it holds.
var _holding: Dictionary[String, Dictionary] = {}
var _active_major := ""
var _active_step := ""


func _ready() -> void:
	PlayerInventory.changed.connect(_advance)
	load_goals(Rules.goals())


## Starts over with these goal rows (already checked by `Rules.check_goals`). The game
## loads the shipped goals; tests load fixtures (D9). Condition reports are kept.
func load_goals(rows: Array) -> void:
	_goals.assign(rows)
	_by_id.clear()
	for row in _goals:
		_by_id[row.id] = row
	_complete.clear()
	_active_major = ""
	_active_step = ""
	_advance()
	active_changed.emit()


## A condition holds or stops holding for one instance (e.g. a burbler sounds).
## `kind` and `args` match a goal's condition (`{"machine": "mudpit_burbler"}`).
func report(kind: String, args: Dictionary, instance_id: String, holds: bool) -> void:
	var key := _key(kind, args)
	var holders: Dictionary = _holding.get(key, {})
	if holds:
		holders[instance_id] = true
	else:
		holders.erase(instance_id)
	_holding[key] = holders
	if holds:
		_advance()


## True while some instance reports this condition (for tests and debugging).
func holds(kind: String, args: Dictionary) -> bool:
	return not _holding.get(_key(kind, args), {}).is_empty()


func is_complete(id: String) -> bool:
	return _complete.has(id)


## The active major goal's row, or {} when none is left.
func active_major() -> Dictionary:
	return _by_id.get(_active_major, {})


## The active step's row, or {}.
func active_step() -> Dictionary:
	return _by_id.get(_active_step, {})


## A major goal's steps, in order.
func steps_of(major: String) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	for row in _goals:
		if row.get("part_of", "") == major:
			steps.append(row)
	return steps


## Steps of `major` complete.
func steps_done(major: String) -> int:
	return steps_of(major).filter(func(row: Dictionary) -> bool: return _complete.has(row.id)).size()


## A goal's row, or {}.
func goal(id: String) -> Dictionary:
	return _by_id.get(id, {})


func goal_name(id: String) -> String:
	return _by_id.get(id, {}).get("name", id)


## Completes active steps whose conditions hold, and major goals whose last step is
## done, until nothing changes; then reports the new active goals.
func _advance() -> void:
	var before := [_active_major, _active_step]
	while true:
		_active_major = _first_open("major", "")
		_active_step = _first_open("minor", _active_major) if not _active_major.is_empty() else ""
		if not _active_major.is_empty() and _active_step.is_empty() \
				and steps_of(_active_major).all(func(row: Dictionary) -> bool: return _complete.has(row.id)):
			_finish(_active_major)
			continue
		if not _active_step.is_empty() and _holds(_by_id[_active_step].get("condition", {})):
			_finish(_active_step)
			continue
		break
	if before != [_active_major, _active_step]:
		active_changed.emit()


func _finish(id: String) -> void:
	_complete[id] = true
	goal_completed.emit(id)


## The first incomplete goal of `scale` (in `major`, for steps) whose `after` goals are
## complete. Steps also wait for the steps before them.
func _first_open(scale: String, major: String) -> String:
	for row in _goals:
		if row.scale != scale or row.get("part_of", "") != major or _complete.has(row.id):
			continue
		var ready: bool = row.get("after", []).all(func(other: String) -> bool: return _complete.has(other))
		return row.id if ready else ""
	return ""


func _holds(condition: Dictionary) -> bool:
	if condition.is_empty():
		return false  # item goals wait for delivery (not built yet)
	if condition.kind == "item_held":
		return PlayerInventory.quantity(condition.item) >= int(condition.quantity)
	var args := condition.duplicate()
	args.erase("kind")
	return not _holding.get(_key(condition.kind, args), {}).is_empty()


## "kind|name=value|..." with the arguments sorted, so reports and goals match.
static func _key(kind: String, args: Dictionary) -> String:
	var keys := args.keys()
	keys.sort()
	var parts: PackedStringArray = [kind]
	for k: String in keys:
		parts.append("%s=%s" % [k, args[k]])
	return "|".join(parts)
