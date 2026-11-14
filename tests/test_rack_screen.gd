extends SceneTree
## Drives the burbler's rack screen headless with synthesized input:
## seeded tempo, mounting by number key, patching both comb cables by click and
## drag, completion, the BPM knob, and removing the VCO.
##   godot --headless --path . -s tests/test_rack_screen.gd

const BURBLER := "res://assets/machines/mudpit_burbler/mudpit_burbler.tscn"
const SCREEN := "res://scenes/rack_screen/rack_screen.tscn"

var _failures: PackedStringArray = []
var _configured := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var inventory := root.get_node("Inventory")
	var burbler := (load(BURBLER) as PackedScene).instantiate()
	burbler.instance_id = "mudpit_burbler-test"
	root.add_child(burbler)
	var screen := (load(SCREEN) as PackedScene).instantiate()
	root.add_child(screen)
	await process_frame

	# Seeded tempo: a whole multiple of the 1 BPM master in the 56–64 window, stable.
	var bpm: float = burbler.bpm()
	_expect(bpm >= 56.0 and bpm <= 64.0 and bpm == roundf(bpm), "seeded bpm %s in 56..64" % bpm)
	_expect(burbler.seeded_bpm() == bpm, "same seed, same tempo")

	var state: RackState = burbler.rack_state
	state.configured.connect(func() -> void: _configured += 1)
	inventory.give("square_wave", 2)
	var cables_before: int = inventory.quantity("patch_cable")
	screen.open_rack(burbler.find_child("MachineInteract", true, false))
	await process_frame
	await process_frame
	_expect(screen.is_open(), "rack opens")
	_expect(screen.relevant_items().size() == 1, "square wave is relevant")
	var waiting: Dictionary = screen._view.waiting_jacks()
	_expect(waiting.has("clock/gate") and waiting.has("volume/trig"), "GATE → TRIG invited before the VCO")
	_expect(not waiting.has("vco/out") and not waiting.has("volume/in"), "no guidance on the VCO's patch until it's in")
	_expect(not screen._view._halos.is_empty(), "halos found on the fixed modules")
	_expect(state.mounted.has("clock") and state.mounted.has("volume"), "fixed modules mounted")

	# [1] mounts a Square VCO from one square wave.
	_action("item_1")
	await process_frame
	_expect(state.mounted.get("vco", "") == "square_vco", "item_1 mounts the square VCO")
	_expect(inventory.quantity("square_wave") == 1, "one square wave used")
	await process_frame

	var view: RackView = screen._view
	# Verdigris comb cable: click it to carry, plug GATE (released 25 px off), then TRIG.
	var comb_pixel := view.to_screen(view._comb_points[0][12])
	_click(screen, comb_pixel)
	_expect(not view.held.is_empty(), "clicking the comb carries a cable")
	_release_at(screen, _jack(view, "clock", "gate") + Vector2(25, 0))
	_expect(view.held.get("anchor", {}).get("port", "") == "gate", "snaps into GATE from 25 px")
	_release_at(screen, _jack(view, "volume", "trig"))
	_expect(state.cables.size() == 1 and state.joins({"place": "clock", "port": "gate"},
			{"place": "volume", "port": "trig"}), "GATE → TRIG patched")
	_expect(_configured == 0 and not burbler.sounding, "half patched is not configured")
	var link: RackLink = burbler.link
	_expect(link.has_module("clock") and link.has_module("vco") and link.has_module("volume"),
			"mounted modules are engine modules")
	_expect(link.to_patch().cables.size() == 1, "half patched: one engine cable (the VCA gets no signal)")

	# Rust comb cable by drag: comb → OUT, then drag to IN.
	await process_frame
	comb_pixel = view.to_screen(view._comb_points[1][12])
	_mouse(screen, comb_pixel, true)
	_motion(screen, _jack(view, "vco", "out"))
	_mouse(screen, _jack(view, "vco", "out"), false)
	_motion(screen, _jack(view, "volume", "in"))
	_mouse(screen, _jack(view, "volume", "in"), true)
	_mouse(screen, _jack(view, "volume", "in"), false)
	_expect(state.cables.size() == 2, "OUT → IN patched")
	_expect(_configured == 1 and burbler.sounding, "configured once, burbler sounding")
	_expect(inventory.quantity("patch_cable") == cables_before, "comb cables are free")
	_expect(state.cables[1].from.port == "out", "cable stored output first")
	_expect(burbler.outlet_carries_voice(), "volume OUT normalled to the outlet")
	_expect(link.to_patch().cables.size() == 2, "fully patched: the engine has both cables")
	_expect(link.emitter.is_bound() and not link.emitter.stream_paused, "the voice plays from the outlet")
	_expect(is_equal_approx(link.get_param("clock", "multiple"), roundf(burbler.bpm())),
			"the clock runs at ×bpm of the 1 BPM master")
	# The engine's clock ticks on its exact grid (×bpm of the master), heard in real time.
	var clock_id: int = link.get_module_id("clock")
	var ticks: Array[int] = []
	var on_tick := func(id: int, sample: int, _i: int) -> void:
		if id == clock_id:
			ticks.append(sample)
	RackServer.clock_ticked.connect(on_tick)
	await create_timer(60.0 / burbler.bpm() * 2.5).timeout
	RackServer.clock_ticked.disconnect(on_tick)
	var spacing: float = 48000.0 * 60.0 / burbler.bpm()
	# Tick k is at ceil(k × samples-per-tick): exact, never accumulated.
	_expect(ticks.size() >= 2 and ticks.all(func(t: int) -> bool:
			return t == int(ceilf(roundf(t / spacing) * spacing - 1e-6))),
			"clock ticks land on its grid: %s" % [ticks])
	_expect(burbler.beat_phase() >= 0.0, "the lamp reads the heard beat")

	# An occupied input refuses a second cable.
	_expect(not screen.can_plug({"place": "clock", "port": "gate"}, {"place": "volume", "port": "in"}),
			"occupied input refuses")

	# BPM knob: one scroll notch up is one whole BPM.
	screen.turn_knob("clock", "bpm", screen.KNOB_SCROLL_STEP)
	_expect(burbler.bpm() == bpm + 1.0, "scroll steps the bpm by 1")
	_expect(is_equal_approx(link.get_param("clock", "multiple"), bpm + 1.0), "the engine clock follows the knob")
	_expect(screen._header.text.begins_with("%d BPM" % (bpm + 1.0)), "header follows the knob")
	for i in 400:
		screen.turn_knob("clock", "bpm", 1.0)
	_expect(burbler.bpm() == 180.0, "bpm stops at 180")

	# Gain: a 120 px upward drag from 0 is half.
	state.set_knob("volume/gain", 0.0)
	var knob_pixel := view.to_screen((view.find_child("Knob_gain", true, false) as Node3D).global_position)
	_mouse(screen, knob_pixel, true)
	_motion(screen, knob_pixel + Vector2(0, -120))
	_mouse(screen, knob_pixel + Vector2(0, -120), false)
	_expect(absf(state.knob("volume/gain") - 0.5) < 0.01, "120 px drag sets gain 0.5 (got %s)" % state.knob("volume/gain"))

	# Right-click a plug: the hint says so, and the cable unplugs and goes home.
	_expect(screen.hint_at(_jack(view, "volume", "in")).contains("[RMB] unplug"), "hint over a plug offers unplug")
	_expect(screen.hint_at(_jack(view, "vco", "voct")).contains("patch"), "hint over a free jack offers patching")
	var right_in := InputEventMouseButton.new()
	right_in.button_index = MOUSE_BUTTON_RIGHT
	right_in.pressed = true
	right_in.position = _jack(view, "volume", "in")
	screen._on_rack_input(right_in)
	_expect(state.cables.size() == 1 and not state.comb_in_use(1), "right-click unplugs; rust back on the comb")
	_expect(state.mounted.has("vco"), "right-click on a plug doesn't remove the module")
	_expect(link.to_patch().cables.size() == 1, "unplugging by right-click unplugs the engine cable")
	# Re-patch OUT → IN for the drag-off check below.
	_mouse(screen, view.to_screen(view._comb_points[1][12]), true)
	_motion(screen, _jack(view, "vco", "out"))
	_mouse(screen, _jack(view, "vco", "out"), false)
	_motion(screen, _jack(view, "volume", "in"))
	_mouse(screen, _jack(view, "volume", "in"), true)
	_mouse(screen, _jack(view, "volume", "in"), false)
	_expect(state.cables.size() == 2 and link.to_patch().cables.size() == 2, "re-patched and sounding again")

	# Unplug by dragging the TRIG end off into empty space: the comb cable goes home.
	_mouse(screen, _jack(view, "volume", "trig"), true)
	_motion(screen, Vector2(5, 5))
	_mouse(screen, Vector2(5, 5), false)
	_expect(state.cables.size() == 1 and not burbler.sounding, "unplugged; no longer sounding")
	_expect(link.to_patch().cables.size() < 2, "unplugging silences the voice")
	_expect(not state.comb_in_use(0), "verdigris back on the comb")

	# Right-click the VCO: its cable unplugs and the square wave comes back.
	var vco_pixel := view.place_centre("vco")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = vco_pixel
	screen._on_rack_input(right)
	_expect(not state.mounted.has("vco"), "VCO removed")
	_expect(state.cables.is_empty(), "its cables unplugged")
	_expect(inventory.quantity("square_wave") == 2, "square wave returned")

	# Drag-and-drop: a square wave dropped on the empty VCO slot mounts it.
	var slot_pixel := view.place_centre("vco")
	_expect(view.place_at(slot_pixel) == "vco", "slot under the pointer is the VCO place")
	_expect(not screen._can_drop_item(slot_pixel, {"item": "patch_cable"}), "a patch cable can't mount")
	_expect(screen._can_drop_item(slot_pixel, {"item": "square_wave"}), "square wave can drop on its slot")
	screen._drop_item(slot_pixel, {"item": "square_wave"})
	_expect(state.mounted.get("vco", "") == "square_vco" and inventory.quantity("square_wave") == 1,
			"dropping mounts the VCO")
	await process_frame

	# A patch of the player's own: drag PHASE → V/OCT uses one patch cable; unplug returns it.
	_mouse(screen, _jack(view, "clock", "phase"), true)
	_motion(screen, _jack(view, "vco", "voct"))
	_mouse(screen, _jack(view, "vco", "voct"), false)
	_expect(state.cables.size() == 1 and state.cables[0].source == "inventory", "own cable patched")
	_expect(inventory.quantity("patch_cable") == cables_before - 1, "own cable used one patch cable")
	_mouse(screen, _jack(view, "vco", "voct"), true)
	_motion(screen, Vector2(5, 5))
	_mouse(screen, Vector2(5, 5), false)
	_expect(state.cables.is_empty() and inventory.quantity("patch_cable") == cables_before,
			"unplugged own cable returns to the inventory")

	# Esc closes and returns control.
	_action("release_cursor")
	_expect(not screen.is_open(), "Esc closes")

	# Plugging snapped through the rack sampler on the UI stem, not a raw player.
	_expect(screen._snap_ids.size() == 3 and screen._snap_ids.all(func(i: int) -> bool: return i >= 0),
			"snap clips load into the rack sampler: %s" % [screen._snap_ids])

	if _failures.is_empty():
		print("test_rack_screen: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: ", failure)
		quit(1)


func _jack(view: RackView, place: String, port: String) -> Vector2:
	return view.to_screen(view.jack_node({"place": place, "port": port}).global_position)


func _action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _mouse(screen: Node, at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	screen._on_rack_input(event)


func _motion(screen: Node, at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	screen._on_rack_input(event)


func _click(screen: Node, at: Vector2) -> void:
	_mouse(screen, at, true)
	_mouse(screen, at, false)


## Moves the carried cable to `at` and releases there (click mode).
func _release_at(screen: Node, at: Vector2) -> void:
	_motion(screen, at)
	_mouse(screen, at, true)
	_mouse(screen, at, false)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
