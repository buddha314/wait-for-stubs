extends SceneTree
## Snail shells (add-snail-shell-sequencer): placed round a reed bed from the seed, same
## seed same places; E collects one with an empty hand; it never comes back.
##   godot --headless --path . -s tests/test_snail_shell.gd

const BED := "res://scenes/reed_bed/reed_bed.tscn"

var _failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := _shells("reed_bed-shell-test", 3)
	var b := _shells("reed_bed-shell-test", 3)
	var c := _shells("reed_bed-other", 3)
	_expect(a.size() == 3, "three shells at the bed (%d)" % a.size())
	_expect(a == b, "same seed, same places")
	_expect(a != c, "another bed, other places")
	_expect(a.all(func(p: Vector3) -> bool: return Vector2(p.x, p.z).length() > 2.0), "shells lie outside the bed's radius, on the mud: %s" % [a])

	# Collect with an empty hand (no Hand in the tree: shells aren't sounds).
	var inventory := root.get_node("PlayerInventory")
	var calendar := root.get_node("Calendar")
	var bed: Node3D = load(BED).instantiate()
	bed.bed_id = "reed_bed-collect-test"
	bed.count = 1
	bed.shells = 1
	root.add_child(bed)
	await process_frame
	var shell: Node3D = bed.get_children().filter(_is_shell)[0]
	var pickup: Node = shell.get_node("Pickup")
	var before: int = inventory.quantity("snail_shell")
	pickup.interact()
	_expect(pickup.collected and inventory.quantity("snail_shell") == before + 1, "E collects a shell empty-handed")
	_expect(not shell.get_node("Model").visible, "a collected shell is gone from the mud")
	calendar.elapsed += 3.0 * calendar.CYCLE_SECONDS
	for i in 3:
		await process_frame
	_expect(pickup.collected, "a shell never comes back")

	if _failures.is_empty():
		print("test_snail_shell: OK")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		quit(1)


## Shell positions (relative to the bed) for a bed id.
func _shells(bed_id: String, count: int) -> Array[Vector3]:
	var bed: Node3D = load(BED).instantiate()
	bed.bed_id = bed_id
	bed.radius = 2.0
	bed.count = 1
	bed.shells = count
	root.add_child(bed)
	var out: Array[Vector3] = []
	for child in bed.get_children():
		if _is_shell(child):
			out.append(child.position)
	bed.free()
	return out


## By scene path: naming the SnailShell class would stop this -s script compiling.
func _is_shell(node: Node) -> bool:
	return node.scene_file_path.ends_with("snail_shell.tscn")


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
