extends SceneTree
## Goals (add-goals-hub): the checks on goal rows, the tracker and the goal bar, all on
## fixture goals (tests/fixtures/goals.json). The shipped goals.json is only checked to
## load without errors: its content iterates, so no test names, counts or orders it (D9).
##   godot --headless --path . -s tests/test_goals.gd

const FIXTURE := "res://tests/fixtures/goals.json"
const BAR := "res://scenes/goal_bar/goal_bar.tscn"
## Stands in for the player: the bar hides while `controls_enabled` is false.
const FAKE_PLAYER := """extends Node
var controls_enabled := true
"""

var _failures: PackedStringArray = []
var _rules: Node
var _goals: Node
var _inventory: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_rules = root.get_node("Rules")
	_goals = root.get_node("Goals")
	_inventory = root.get_node("PlayerInventory")

	# The shipped goals load clean (nothing about their content).
	var goal_errors: Array = Array(_rules.errors).filter(func(e: String) -> bool: return e.begins_with("goals.json"))
	_expect(goal_errors.is_empty(), "shipped goals.json loads without errors: %s" % [goal_errors])
	_expect(not _rules.goals().is_empty(), "shipped goals.json has goals")

	_check_rejections()
	var rows: Array = _fixture()
	var checked: Dictionary = _rules.check_goals(rows)
	_expect(checked.errors.is_empty() and checked.goals.size() == rows.size(), "the fixture is valid: %s" % [checked.errors])
	await _check_tracker(checked.goals)
	await _check_bar(checked.goals)

	if _failures.is_empty():
		print("test_goals: OK")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		quit(1)


## Each D6 rejection names the goal and the field.
func _check_rejections() -> void:
	var major := {"id": "m", "name": "M", "description": "", "scale": "major"}
	var step := func(id: String, extra: Dictionary) -> Dictionary:
		var row := {"id": id, "name": id, "description": "", "scale": "minor", "part_of": "m",
				"condition": {"kind": "item_held", "item": "reed", "quantity": 1}}
		row.merge(extra, true)
		return row
	var cases := [
		["unknown condition kind", [major, step.call("s", {"condition": {"kind": "moon_full"}})], "goals.json: s: condition: unknown condition kind"],
		["orphan step", [major, step.call("s", {"part_of": "nope"})], "goals.json: s: part_of:"],
		["step without a major", [major, step.call("ok", {}), {"id": "s", "name": "s", "description": "", "scale": "minor", "condition": {"kind": "item_held", "item": "reed", "quantity": 1}}], "goals.json: s: part_of:"],
		["major with a condition", [{"id": "m", "name": "M", "description": "", "scale": "major", "condition": {"kind": "item_held", "item": "reed", "quantity": 1}}, step.call("s", {})], "goals.json: m: condition:"],
		["major without steps", [major], "goals.json: m: scale:"],
		["both condition and requires", [major, step.call("s", {"requires": [{"item": "reed", "quantity": 1}]})], "goals.json: s: condition:"],
		["neither", [major, {"id": "s", "name": "s", "description": "", "scale": "minor", "part_of": "m"}], "goals.json: s: condition:"],
		["unknown item", [major, step.call("s", {"condition": {"kind": "item_held", "item": "reeed", "quantity": 1}})], "goals.json: s: condition: unknown item"],
		["unknown machine", [major, step.call("s", {"condition": {"kind": "machine_configured", "machine": "nope"}})], "goals.json: s: condition: unknown machine"],
		["unknown mine", [major, step.call("s", {"condition": {"kind": "tree_watered", "mine": "nope"}})], "goals.json: s: condition: unknown mine"],
		["unknown bloom level", [major, step.call("s", {"condition": {"kind": "tree_grown", "mine": "scrub_oak", "level": "huge"}})], "goals.json: s: condition: unknown bloom level"],
		["unknown after", [major, step.call("s", {"after": ["nope"]})], "goals.json: s: after: unknown goal"],
		["unknown scale", [major, step.call("ok", {}), step.call("s", {"scale": "medium"})], "goals.json: s: scale:"],
		["duplicate id", [major, step.call("s", {}), step.call("s", {})], "goals.json: s: id: duplicate"],
		["cycle", [{"id": "a", "name": "A", "description": "", "scale": "major", "after": ["b"]}, step.call("sa", {"part_of": "a"}),
				{"id": "b", "name": "B", "description": "", "scale": "major", "after": ["a"]}, step.call("sb", {"part_of": "b"})], "goals.json: a: after: is part of a cycle"],
	]
	for c: Array in cases:
		var result: Dictionary = _rules.check_goals(c[1])
		var found: bool = Array(result.errors).any(func(e: String) -> bool: return e.begins_with(c[2]))
		_expect(found, "%s: expected '%s…' in %s" % [c[0], c[2], result.errors])
	# A rejected major goal takes its steps with it.
	var dropped: Dictionary = _rules.check_goals([
		{"id": "m", "name": "M", "description": "", "scale": "major", "requires": []}, step.call("s", {})])
	_expect(dropped.goals.is_empty(), "a rejected major goal drops its steps (%d left)" % dropped.goals.size())


## Active goals, steps in order, latching, already-true on activation, once-only.
func _check_tracker(rows: Array) -> void:
	_inventory.take("reed", _inventory.quantity("reed"))
	var completed: Array[String] = []
	var on_done := func(id: String) -> void: completed.append(id)
	_goals.goal_completed.connect(on_done)
	_goals.load_goals(rows)
	_expect(_goals.active_major().get("id") == "fixture_major_a" and _goals.active_step().get("id") == "fixture_hold", "start: first major goal, first step")
	_expect(_goals.steps_of("fixture_major_a").size() == 3 and _goals.steps_done("fixture_major_a") == 0, "3 steps, none done")

	_inventory.give("reed", 1)
	_expect(completed.is_empty(), "1 of 2 reeds: not yet")
	_inventory.give("reed", 1)
	_expect(completed == ["fixture_hold"] and _goals.active_step().get("id") == "fixture_machine", "2 reeds held: step done, next active")

	# Water reported before its goal opens: kept as state, used when it opens.
	_goals.report("tree_watered", {"mine": "scrub_oak"}, "oak-1", true)
	_goals.report("machine_configured", {"machine": "mudpit_burbler"}, "burbler-1", true)
	_goals.report("machine_configured", {"machine": "mudpit_burbler"}, "burbler-1", true)
	_expect(completed == ["fixture_hold", "fixture_machine"], "configured: completes once despite two reports (%s)" % [completed])
	_goals.report("machine_configured", {"machine": "mudpit_burbler"}, "burbler-1", false)
	_expect(_goals.is_complete("fixture_machine"), "unpatched later: stays complete")
	_expect(_goals.steps_done("fixture_major_a") == 2, "2 of 3 done")

	_goals.report("tree_grown", {"mine": "scrub_oak", "level": "budding"}, "oak-1", true)
	_expect(completed == ["fixture_hold", "fixture_machine", "fixture_grow", "fixture_major_a", "fixture_water", "fixture_major_b"],
			"last step completes its major goal; the next major's step was already true: %s" % [completed])
	_expect(_goals.active_major().is_empty() and _goals.active_step().is_empty(), "no goals left: nothing active")
	_goals.goal_completed.disconnect(on_done)
	_goals.report("tree_watered", {"mine": "scrub_oak"}, "oak-1", false)
	_goals.report("tree_grown", {"mine": "scrub_oak", "level": "budding"}, "oak-1", false)


## The bar: text at start, the notice then the next step, hidden behind a screen, empty at the end.
func _check_bar(rows: Array) -> void:
	_inventory.take("reed", _inventory.quantity("reed"))
	_goals.load_goals(rows)
	var player := Node.new()
	var script := GDScript.new()
	script.source_code = FAKE_PLAYER
	script.reload()
	player.set_script(script)
	player.add_to_group("player")
	root.add_child(player)
	var bar: Node = (load(BAR) as PackedScene).instantiate()
	root.add_child(bar)
	await process_frame
	_expect(bar.lines() == PackedStringArray(["MAJOR A", "0 / 3", "› Hold reeds", "Hold two reeds."]), "start: %s" % [bar.lines()])

	_inventory.give("reed", 2)
	await process_frame
	_expect(bar.lines() == PackedStringArray(["GOAL COMPLETE · Hold reeds"]), "notice: %s" % [bar.lines()])
	player.controls_enabled = false
	await process_frame
	_expect(bar.lines().is_empty(), "hidden while a screen has the controls")
	player.controls_enabled = true
	await create_timer(4.3).timeout
	_expect(bar.lines() == PackedStringArray(["MAJOR A", "1 / 3", "› Configure", "Make the burbler sound."]), "after the notice: %s" % [bar.lines()])

	# To the end: the major goal's notice replaces its last step's, then nothing.
	_goals.report("machine_configured", {"machine": "mudpit_burbler"}, "burbler-1", true)
	_goals.report("tree_watered", {"mine": "scrub_oak"}, "oak-1", true)
	_goals.report("tree_grown", {"mine": "scrub_oak", "level": "budding"}, "oak-1", true)
	await process_frame
	var seen: Array[String] = []
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline and not bar.lines().is_empty():
		var text := " | ".join(bar.lines())
		if seen.is_empty() or seen[-1] != text:
			seen.append(text)
		await process_frame
	_expect(bar.lines().is_empty(), "empty after the last goal")
	_expect(seen == ["GOAL COMPLETE · Configure", "GOAL COMPLETE · Major A", "GOAL COMPLETE · Major B"],
			"notices in order, majors replacing their last step: %s" % [seen])
	_expect(_goals.is_complete("fixture_major_b"), "the game goes on: goals done, nothing ended")
	_goals.report("machine_configured", {"machine": "mudpit_burbler"}, "burbler-1", false)


func _fixture() -> Array:
	var text := FileAccess.get_file_as_string(FIXTURE)
	return JSON.parse_string(text).get("goals", [])


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
