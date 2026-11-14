extends SceneTree
## The compass bar (add-compass-bar): bearings (north −Z, east +X, pitch ignored),
## where items sit on the bar, the opening facing east with "E" centred, hidden behind
## screens, and clear of the build-mode label.
##   godot --headless --path . -s tests/test_compass_bar.gd

var _failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var bar_script: Script = load("res://scenes/compass_bar/compass_bar.gd")
	_expect(is_equal_approx(bar_script.bearing_of(Vector3(0, 0, -1)), 0.0), "−Z is north (0°)")
	_expect(is_equal_approx(bar_script.bearing_of(Vector3(1, 0, 0)), 90.0), "+X is east (90°)")
	_expect(is_equal_approx(bar_script.bearing_of(Vector3(0, 0, 1)), 180.0), "+Z is south (180°)")
	_expect(is_equal_approx(bar_script.bearing_of(Vector3(-1, 0, 0)), 270.0), "−X is west (270°)")
	_expect(is_equal_approx(bar_script.bearing_of(Vector3(1, 3, 0)), 90.0), "pitch is ignored")
	var width: float = bar_script.WIDTH
	_expect(is_equal_approx(bar_script.x_of(90.0, 90.0), width * 0.5), "the heading sits at the centre")
	_expect(bar_script.x_of(0.0, 90.0) < width * 0.5 and bar_script.x_of(180.0, 90.0) > width * 0.5,
			"facing east, N is left of centre and S right")
	_expect(is_nan(bar_script.x_of(270.0, 90.0)), "the bearing behind is off the bar")
	_expect(bar_script.x_of(350.0, 10.0) < width * 0.5, "wraps through north")

	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	var player: Node3D = main.get_node("Player")
	var bar: Node = main.get_node("CompassBar")
	_expect(absf(bar_script.bearing_of(-player.global_basis.z) - 90.0) < 1.0, "the opening faces east")
	_expect(bar.centre_label() == "E", "the bar shows E at its centre at spawn (%s)" % bar.centre_label())
	var burbler: Node3D = main.get_node("MudpitBurbler")
	var to_burbler := burbler.global_position - player.global_position
	_expect(absf(bar_script.bearing_of(to_burbler) - 90.0) < 10.0, "the burbler is ahead, as in the original view")

	player.rotate_y(deg_to_rad(-90.0))
	await process_frame
	await process_frame
	_expect(bar.centre_label() == "S", "turning right 90° from east faces south")

	player.controls_enabled = false
	await process_frame
	_expect(not bar.get_node("Bar").visible, "hidden while a screen has the controls")
	player.controls_enabled = true
	await process_frame
	_expect(bar.get_node("Bar").visible, "back when the screen closes")

	var build_label: Control = main.get_node("HUD").get("_build_label")
	var bar_rect: Rect2 = bar.get_node("Bar").get_global_rect()
	_expect(build_label.get_global_rect().position.y >= bar_rect.end.y, "the build label sits below the bar")

	if _failures.is_empty():
		print("test_compass_bar: OK")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		quit(1)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
