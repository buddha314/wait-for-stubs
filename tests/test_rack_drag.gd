extends SceneTree
## Real-mouse regression test for the rack screen: drags go through Godot's GUI
## (Input.parse_input_event), not straight into the screen's handlers. It warps the
## real pointer with each event, because Godot's drag-and-drop reads the real
## pointer (without that, the result depends on where the desktop cursor happens
## to be). Needs a window, because the headless display server doesn't track the
## mouse:
##   godot --path . -s tests/test_rack_drag.gd
## Regression: dropping an item on the rack did nothing, because a
## SubViewportContainer forwards drag-and-drop into its SubViewport; the screen now
## takes drops and clicks on a transparent Input layer over the view.

const BURBLER := "res://scenes/mudpit_burbler/mudpit_burbler.tscn"
const SCREEN := "res://scenes/rack_screen/rack_screen.tscn"

var _failures: PackedStringArray = []


func _initialize() -> void:
	# The project's viewport size, so window and viewport coordinates agree.
	root.size = Vector2i(1920, 1080)
	_run.call_deferred()


func _run() -> void:
	root.get_node("Inventory").give("square_wave", 1)
	var burbler := (load(BURBLER) as PackedScene).instantiate()
	burbler.instance_id = "mudpit_burbler-drag-test"
	root.add_child(burbler)
	var screen := (load(SCREEN) as PackedScene).instantiate()
	root.add_child(screen)
	await process_frame
	screen.open_rack(burbler.find_child("MachineInteract", true, false))
	for i in 3:
		await process_frame
	var state: RackState = burbler.rack_state
	var layer: Control = screen._input_layer
	var view: RackView = screen._view
	var origin := layer.get_global_rect().position

	# Drag the square wave from the Relevant strip onto the VCO slot.
	var from: Vector2 = (screen._relevant.get_child(0) as Control).get_global_rect().get_center()
	await _drag(from, origin + view.place_centre("vco"))
	_expect(state.mounted.get("vco", "") == "square_vco", "dragging the square wave mounts the VCO")
	if not state.mounted.has("vco"):
		_finish()  # the rest needs the VCO
		return
	await process_frame

	# Drag a patch of the player's own from PHASE to V/OCT.
	var phase := origin + view.to_screen(view.jack_node({"place": "clock", "port": "phase"}).global_position)
	var voct := origin + view.to_screen(view.jack_node({"place": "vco", "port": "voct"}).global_position)
	await _drag(phase, voct)
	_expect(state.joins({"place": "clock", "port": "phase"}, {"place": "vco", "port": "voct"}),
			"dragging between jacks patches")

	# Right-click the V/OCT plug through the GUI: it unplugs, and the patch cable returns.
	var held_cables: int = root.get_node("Inventory").quantity("patch_cable")
	await _motion(voct, false)
	_expect(screen._hint.visible and screen._hint.text.contains("[RMB] unplug"), "hovering a plug shows the unplug hint")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = voct
	right.global_position = voct
	await _send(right)
	right = right.duplicate()
	right.pressed = false
	await _send(right)
	_expect(not state.joins({"place": "clock", "port": "phase"}, {"place": "vco", "port": "voct"}),
			"right-click unplugs")
	_expect(root.get_node("Inventory").quantity("patch_cable") == held_cables + 1, "own cable returned")

	# Drag the volume knob up 120 px from 0.
	state.set_knob("volume/gain", 0.0)
	var knob := origin + view.to_screen((view.find_child("Knob_gain", true, false) as Node3D).global_position)
	await _drag(knob, knob + Vector2(0, -120))
	_expect(absf(state.knob("volume/gain") - 0.5) < 0.02, "dragging a knob turns it (gain %s)" % state.knob("volume/gain"))

	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("test_rack_drag: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: ", failure)
		quit(1)


func _drag(from: Vector2, to: Vector2) -> void:
	await _motion(from, false)
	await _button(from, true)
	for i in 12:
		await _motion(from.lerp(to, (i + 1) / 12.0), true)
	await _button(to, false)
	await process_frame


func _motion(at: Vector2, held: bool) -> void:
	# Godot's drag-and-drop reads the real pointer, so move it with the event.
	Input.warp_mouse(at)
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = Vector2(4, 4)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	await _send(event)


func _button(at: Vector2, pressed: bool) -> void:
	Input.warp_mouse(at)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	await _send(event)


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
