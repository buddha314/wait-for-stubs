extends SceneTree
## The field recorder (add-field-recorder): the asset's nodes, H in the hand, the
## starting hand, sound gating, the record light and the level meter.
##   godot --headless --path . -s tests/test_field_recorder.gd

const PLAYER := "res://scenes/player/player.tscn"
const BUG := "res://assets/creatures/lightning_bug/lightning_bug.tscn"
const REEDS := "res://assets/flora/reeds/reed_clump.tscn"
const BURBLER := "res://assets/machines/mudpit_burbler/mudpit_burbler.tscn"
const SCREEN := "res://scenes/rack_screen/rack_screen.tscn"
const MODEL := "res://assets/equipment/field_recorder/field_recorder.glb"

var _failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_asset()

	var floor := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	floor.add_child(floor_shape)
	root.add_child(floor)
	var player: Node = (load(PLAYER) as PackedScene).instantiate()
	root.add_child(player)
	await physics_frame
	var hand: Node = player.get_node("Head/Hand")
	var item: Node3D = hand.item(&"field_recorder")
	var recorder: Node = item.get_node("FieldRecorder")

	# A new game starts with the recorder in hand, at stubby-music's pose.
	_expect(hand.held == &"field_recorder" and item.visible, "a new game starts with the recorder in hand")
	_expect(item.position.is_equal_approx(Vector3(0.17, -0.165, -0.42)), "held at stubby-music's position")
	_expect(item.rotation.distance_to(Vector3(-0.7, 0.35, 0.12)) < 1e-3, "rotation Y·X·Z (0.35, −0.7, 0.12): %s" % item.rotation)
	var shells := recorder.find_children("FieldRecorder_FurShell*", "GeometryInstance3D", true, false)
	_expect(shells.size() == 14, "14 fur shells (%d)" % shells.size())
	_expect(shells.all(func(g: GeometryInstance3D) -> bool: return g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF), "fur shells cast no shadows")
	var sock := recorder.find_child("FieldRecorder_WindguardSock", true, false) as GeometryInstance3D
	_expect(sock.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "the sock casts")

	# The silent opening: all bars dark, the light at rest.
	for i in 20:
		await process_frame
	_expect(recorder.lit_bars() == 0, "silent opening: all bars dark (%d lit, %.1f dB)" % [recorder.lit_bars(), recorder.level_db])
	_expect(recorder.light_strength == 0.0, "the light rests dark")
	_expect(recorder.bars_for(-3.0) == 8 and recorder.bars_for(-9.0) == 7 \
			and recorder.bars_for(-48.1) == 0 and recorder.bars_for(-45.0) == 1, "bar n lights at −48 + 6n dBFS")

	# The UI stem (the plug-in snap through the engine's sampler) doesn't move the meter.
	RackServer.ensure_driver()  # made with the first Rack in a game; none exists yet here
	var started := Time.get_ticks_msec() + 3000
	while int(RackServer.get_driver_stats().get("renders", 0)) < 4 and Time.get_ticks_msec() < started:
		await process_frame
	var snap: int = RackServer.load_sample(load("res://assets/audio/sfx/patch_snap/click_002.wav"))
	var most_ui_bars := 0
	for i in 5:
		RackServer.play_sample(snap)
		var until := Time.get_ticks_msec() + 400
		while Time.get_ticks_msec() < until:
			await process_frame
			most_ui_bars = maxi(most_ui_bars, recorder.lit_bars())
	# The snap lasts a few ms and a bus peak covers only the latest mix block, so a
	# frame-rate read can miss it: check the routing itself, not the snap's level.
	var ui_player: Node = root.get_node_or_null("RackDriver/UiPlayer")
	_expect(ui_player != null and ui_player.bus == &"UI", "the engine's UI stem plays on the UI bus")
	_expect(recorder.meter_bus == &"World", "the meter reads the World bus")
	_expect(most_ui_bars == 0, "the UI stem doesn't move the meter (%d bars)" % most_ui_bars)

	# H toggles the recorder.
	await _press(&"field_recorder")
	_expect(hand.held == &"" and not item.visible, "H puts the recorder away")
	await _press(&"field_recorder")
	_expect(hand.held == &"field_recorder" and item.visible, "H brings it back up")

	# H does nothing while the rack screen has the controls.
	var burbler := (load(BURBLER) as PackedScene).instantiate()
	burbler.instance_id = "mudpit_burbler-recorder-test"
	burbler.position = Vector3(0, 0, 40)
	root.add_child(burbler)
	var screen := (load(SCREEN) as PackedScene).instantiate()
	root.add_child(screen)
	await process_frame
	screen.open_rack(burbler.find_child("MachineInteract", true, false))
	await process_frame
	_expect(screen.is_open() and not player.controls_enabled, "the rack screen takes the controls")
	await _press(&"field_recorder")
	_expect(hand.held == &"field_recorder", "H does nothing with the rack screen open")
	screen.close()
	await process_frame
	_expect(player.controls_enabled, "the rack screen gives the controls back")

	# Sounds need the recorder; reeds don't.
	var rules := root.get_node("Rules")
	var inventory := root.get_node("PlayerInventory")
	_expect(rules.yields_sound("lightning_bug") and not rules.yields_sound("reed_clump"), "a bug yields a sound, reeds don't")
	var bug := (load(BUG) as PackedScene).instantiate()
	bug.instance_id = "lightning_bug-recorder-test"
	bug.position = Vector3(2, 0, 0)
	root.add_child(bug)
	var reeds := (load(REEDS) as PackedScene).instantiate()
	reeds.instance_id = "reed_clump-recorder-test"
	reeds.position = Vector3(0, 0, -30)
	root.add_child(reeds)
	await process_frame
	var bug_pickup: Node = bug.get_node("Pickup")
	_expect(bug.get("_voice").bus == &"World", "a bug's voice plays on the World bus")
	var reed_pickup: Node = reeds.get_node("Pickup")

	await _press(&"field_recorder")
	var waves: int = inventory.quantity("square_wave")
	bug_pickup.interact()
	_expect(not bug_pickup.collected and inventory.quantity("square_wave") == waves, "empty-handed: the bug is not collected")
	_expect(inventory.feedback == "Hold the field recorder to collect sounds · [H]", "the tip names H: '%s'" % inventory.feedback)
	var reed_count: int = inventory.quantity("reed")
	reed_pickup.interact()
	_expect(reed_pickup.collected and inventory.quantity("reed") > reed_count, "empty-handed: reeds are collected")
	_expect(recorder.light_strength == 0.0, "no light while nothing collects with the recorder")

	# The meter: the bug clicks 2 m from the listener; bars rise and fall back.
	await _press(&"field_recorder")
	var most := 0
	var fell := false
	var deadline := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < deadline and not fell:
		await process_frame
		var lit: int = recorder.lit_bars()
		most = maxi(most, lit)
		fell = most > 0 and lit < most
	_expect(most > 0, "a click 2 m away lights bars (most %d)" % most)
	_expect(fell, "the bars fall back after the click")

	# E collects the bug with the recorder held: the light rises to peak, then rests.
	var peak := 0.0
	var collected_ticks := [0]  # an array: lambdas capture locals by value
	player.pickup_collected.connect(func() -> void: collected_ticks[0] += 1)
	Input.parse_input_event(_action(&"interact", true))
	for i in 20:
		await process_frame
		peak = maxf(peak, recorder.light_strength)
	Input.parse_input_event(_action(&"interact", false))
	_expect(bug_pickup.collected, "with the recorder in hand, E collects the bug")
	_expect(collected_ticks[0] == 1, "one pickup_collected for one bug (%d)" % collected_ticks[0])
	for i in 6:
		await process_frame
		peak = maxf(peak, recorder.light_strength)
	_expect(is_equal_approx(peak, 8.0), "the record light reaches its peak (%.2f)" % peak)
	await create_timer(1.0).timeout
	_expect(recorder.light_strength == 0.0, "the light is back at rest within 1 s (%.2f)" % recorder.light_strength)

	# Walking without collecting leaves it at rest.
	Input.parse_input_event(_action(&"move_forward", true))
	for i in 30:
		await physics_frame
	Input.parse_input_event(_action(&"move_forward", false))
	_expect(recorder.light_strength == 0.0 and player.collected_this_tick == false, "walking leaves the light at rest")

	if _failures.is_empty():
		print("test_field_recorder: OK")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		quit(1)


## The glb carries the nodes and extras the game relies on (task 1.1).
func _check_asset() -> void:
	var model: Node3D = (load(MODEL) as PackedScene).instantiate()
	var r := model.get_node("FieldRecorder_Root")
	for path in ["Grip", "Capture", "Windguard", "Light_rec", "Screen", "Windguard/FieldRecorder_WindguardSock"]:
		_expect(r.has_node(path), "model has %s" % path)
	_expect(r.get_node("Grip").get_meta("extras", {}).get("socket") == "hand", "Grip: socket hand")
	_expect(r.get_node("Capture").get_meta("extras", {}).get("pattern") == "xy_stereo", "Capture: xy_stereo")
	var light: Dictionary = r.get_node("Light_rec").get_meta("extras", {})
	_expect(light.get("rest_strength") == 0.0 and light.get("peak_strength") == 8.0, "Light_rec: rest 0, peak 8")
	var core := r.get_node("Light_rec/FieldRecorder_LightCore") as MeshInstance3D
	_expect(core.mesh.surface_get_material(0).resource_name == "FieldRecorder_RecLight", "the light core uses FieldRecorder_RecLight")
	_expect(int(r.get_node("Screen").get_meta("extras", {}).get("levels", 0)) == 8, "Screen: 8 levels")
	for n in 8:
		_expect(r.get_node("Screen/Level_%d" % n) is MeshInstance3D, "Level_%d is a mesh" % n)
	for n in range(1, 15):
		_expect(r.has_node("Windguard/FieldRecorder_FurShell%d" % n), "fur shell %d" % n)
	model.free()


func _press(action: StringName) -> void:
	Input.parse_input_event(_action(action, true))
	Input.parse_input_event(_action(action, false))
	await process_frame
	await process_frame


func _action(action: StringName, pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	return event


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
