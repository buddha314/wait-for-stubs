extends SceneTree
## Simulation speed (add-time-speed-controls): the steps and keys, the frame cap, what
## follows the calendar (reeds, oak growth) and what never does (walking, audio clocks).
##   godot --headless --path . -s tests/test_time_speed.gd

const PLAYER := "res://scenes/player/player.tscn"
const REEDS := "res://assets/flora/reeds/reed_clump.tscn"
const OAK := "res://assets/flora/scrub_oak/scrub_oak.tscn"
const BURBLER := "res://assets/machines/mudpit_burbler/mudpit_burbler.tscn"
const FRAME := 1.0 / 60.0

## A flowing stream at the origin, found by GrowthLevels.water_at's duck typing.
const FAKE_STREAM := """extends Node
func flowing() -> bool:
	return true
func closest_point(_at: Vector3) -> Vector3:
	return Vector3.ZERO
func clarity() -> float:
	return 0.0
"""

var _failures: PackedStringArray = []
var _cal: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_cal = root.get_node("Calendar")

	# Steps, ends and reset.
	_expect(_cal.speed == 1.0, "a new game starts at 1×")
	for i in 3:
		_cal.faster()
	_expect(_cal.speed == 8.0, "three steps up from 1× is 8× (%s)" % _cal.speed)
	_cal.slower()
	_expect(_cal.speed == 4.0, "one down is 4×")
	for i in 8:
		_cal.faster()
	_expect(_cal.speed == 64.0, "stops at 64×")
	_cal.reset_speed()
	for i in 8:
		_cal.slower()
	_expect(_cal.speed == 0.25, "stops at ¼×")
	_cal.reset_speed()

	# Simulated frames (the autoload's own _process is held off meanwhile).
	_cal.set_process(false)
	var start: float = _cal.elapsed
	_cal.speed = 64.0
	var frames := 0
	while _cal.is_night() and frames < 100000:
		_cal.advance(FRAME)
		frames += 1
	_expect(absf(frames * FRAME - 7.03) < 0.1, "64× reaches day in about 7 s (%.2f s)" % (frames * FRAME))
	var before: float = _cal.elapsed
	_cal.advance(2.0)
	_expect(is_equal_approx(_cal.elapsed - before, 6.4), "a 2 s frame at 64× advances 6.4 s (%.2f)" % (_cal.elapsed - before))
	var nights := [0]  # an array: lambdas capture locals by value
	var count := func() -> void: nights[0] += 1
	_cal.night_started.connect(count)
	_cal.elapsed = 2690.0  # 10 s before dusk
	_cal._was_night = false
	for i in 120:
		_cal.advance(FRAME)
	_cal.night_started.disconnect(count)
	_expect(nights[0] == 1, "night_started once per crossing at 64× (%d)" % nights[0])
	_cal.elapsed = start
	_cal._was_night = _cal.is_night()
	_cal.reset_speed()

	# The readout.
	var hud_script: GDScript = load("res://scenes/hud/hud.gd")
	_expect(hud_script.time_text(true, 3.2, 64.0) == "NIGHT 03:12 · 64×", "readout: '%s'" % hud_script.time_text(true, 3.2, 64.0))
	_expect(hud_script.time_text(false, 13.5, 0.25) == "DAY 13:30 · ¼×", "readout: '%s'" % hud_script.time_text(false, 13.5, 0.25))

	# Keys through the input map; ignored while a screen has the controls.
	var floor := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	floor.add_child(floor_shape)
	root.add_child(floor)
	var player: Node = (load(PLAYER) as PackedScene).instantiate()
	root.add_child(player)
	await physics_frame
	await _press(&"time_faster")
	await _press(&"time_faster")
	_expect(_cal.speed == 4.0, "] twice: 4× (%s)" % _cal.speed)
	await _press(&"time_slower")
	_expect(_cal.speed == 2.0, "[ once: 2×")
	await _press(&"time_reset")
	_expect(_cal.speed == 1.0, "\\ resets to 1×")
	player.controls_enabled = false  # what the rack screen does
	await _press(&"time_faster")
	_expect(_cal.speed == 1.0, "] does nothing while a screen has the controls")
	player.controls_enabled = true

	# Walking is the same at 64× as at 1×.
	var walked_1 := await _walk(player, 1.0)
	var walked_64 := await _walk(player, 64.0)
	_expect(walked_1 > 1.0 and absf(walked_64 - walked_1) < 0.05, "walking 0.5 s: %.2f m at 1×, %.2f m at 64×" % [walked_1, walked_64])

	# Audio clocks never follow: the burbler's tempo and the engine's rate at 64×.
	var burbler := (load(BURBLER) as PackedScene).instantiate()
	burbler.instance_id = "mudpit_burbler-time-test"
	burbler.position = Vector3(0, 0, 60)
	root.add_child(burbler)
	await process_frame
	var bpm: float = burbler.bpm()
	_cal.speed = 64.0
	await process_frame
	_expect(burbler.bpm() == bpm and RackServer.get_sample_rate() == 48000, "tempo and sample rate unchanged at 64×")
	_cal.reset_speed()

	# Reeds that regrow after 60 s return after about 15 s at 4×.
	var reeds := (load(REEDS) as PackedScene).instantiate()
	reeds.instance_id = "reed_clump-time-test"
	reeds.position = Vector3(0, 0, -40)
	root.add_child(reeds)
	await process_frame
	var pickup: Node = reeds.get_node("Pickup")
	pickup.interact()
	_expect(pickup.collected, "reeds collected")
	_cal.speed = 4.0
	for i in int(14.5 / FRAME):
		_cal.advance(FRAME)
	await process_frame
	_expect(pickup.collected, "still regrowing after 14.5 s at 4×")
	for i in int(1.0 / FRAME):
		_cal.advance(FRAME)
	await process_frame
	await process_frame
	_expect(not pickup.collected, "back after 15.5 s at 4×")
	_cal.reset_speed()

	# An oak by flowing water grows faster at 16× than at 1×.
	var stream := Node.new()
	var stream_script := GDScript.new()
	stream_script.source_code = FAKE_STREAM
	stream_script.reload()
	stream.set_script(stream_script)
	stream.add_to_group("laid_stream")
	root.add_child(stream)
	var grown_1 := await _grow(1.0)
	var grown_16 := await _grow(16.0)
	_expect(grown_1 > 0.0 and grown_16 > grown_1 * 4.0, "oak growth in 1 s: %.4f at 1×, %.4f at 16×" % [grown_1, grown_16])
	_cal.reset_speed()

	if _failures.is_empty():
		print("test_time_speed: OK")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		quit(1)


## Metres walked forward in 0.5 s of physics at `speed`.
func _walk(player: Node, speed: float) -> float:
	_cal.speed = speed
	player.global_position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await physics_frame
	var from: Vector3 = player.global_position
	Input.parse_input_event(_action(&"move_forward", true))
	for i in 30:
		await physics_frame
	Input.parse_input_event(_action(&"move_forward", false))
	await physics_frame
	var to: Vector3 = player.global_position
	return Vector2(to.x - from.x, to.z - from.z).length()


## Growth a fresh oak at the origin gains in about 1 s of frames at `speed`.
func _grow(speed: float) -> float:
	_cal.speed = speed
	var oak := (load(OAK) as PackedScene).instantiate()
	oak.instance_id = "scrub_oak-time-test-%d" % int(speed)
	root.add_child(oak)
	await process_frame
	await create_timer(0.6).timeout  # the first water check
	var from: float = oak.growth
	var started := Time.get_ticks_msec()
	await create_timer(1.0).timeout
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	var grown: float = (oak.growth - from) / seconds
	oak.queue_free()
	await process_frame
	return grown


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
