extends SceneTree
## The Snail sequencer in the burbler's rack (add-snail-shell-sequencer): mounting from a
## shell (all steps dark), step buttons reaching the state and the engine, the optional
## place, "configured" through the sequencer, a patch loop, and the heard step moving.
##   godot --headless --path . -s tests/test_snail_sequencer.gd

const BURBLER := "res://assets/machines/mudpit_burbler/mudpit_burbler.tscn"
const SCREEN := "res://scenes/rack_screen/rack_screen.tscn"

var _failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var inventory := root.get_node("PlayerInventory")
	var burbler := (load(BURBLER) as PackedScene).instantiate()
	burbler.instance_id = "mudpit_burbler-seq-test"
	root.add_child(burbler)
	var screen := (load(SCREEN) as PackedScene).instantiate()
	root.add_child(screen)
	await process_frame
	var state: RackState = burbler.rack_state
	inventory.give("square_wave", 1)
	inventory.give("snail_shell", 1)
	screen.open_rack(burbler.find_child("MachineInteract", true, false))
	await process_frame

	# The optional place: VCO and both comb patches make it configured without a shell.
	_expect(screen.insert("square_wave", "vco"), "the VCO mounts")
	var gate_trig := _cable("clock", "gate", "volume", "trig")
	state.add_cable(gate_trig)
	state.add_cable(_cable("vco", "out", "volume", "in"))
	_expect(state.is_complete() and burbler.sounding, "configured without the optional sequencer")

	# Mount the shell: a Snail sequencer with every step dark.
	_expect(screen.relevant_items().any(func(i: Dictionary) -> bool: return i.item == "snail_shell"), "the shell is relevant")
	_expect(screen.insert("snail_shell", "seq"), "the shell mounts")
	_expect(state.mounted.get("seq", "") == "snail_sequencer" and inventory.quantity("snail_shell") == 0, "a Snail sequencer, the shell used")
	var view: Node = screen._view
	for n in range(1, 5):
		_expect(state.knob("seq/gate_%d" % n, 0.0) == 0.0 and view.step_light("seq", n) == 0.0, "step %d starts dark" % n)

	# Step buttons: the state, the engine, and surviving a close and reopen.
	screen.toggle_button("seq", "gate_2")
	screen.toggle_button("seq", "gate_4")
	await process_frame
	_expect(state.knob("seq/gate_2") == 1.0 and state.knob("seq/gate_4") == 1.0 and state.knob("seq/gate_1", 0.0) == 0.0, "steps 2 and 4 lit")
	_expect(burbler.link._sent.get("seq/gate_2") == 1.0 and burbler.link._sent.get("seq/gate_4") == 1.0, "the engine has steps 2 and 4 on")
	_expect(view.step_light("seq", 2) == 1.0 or view.step_source.call("seq") == 1, "a lit step's light is on (unless the playhead is on it)")
	screen.close()
	screen.open_rack(burbler.find_child("MachineInteract", true, false))
	await process_frame
	_expect(state.knob("seq/gate_2") == 1.0, "a lit step stays lit after reopening")
	screen.toggle_button("seq", "gate_4")
	_expect(state.knob("seq/gate_4") == 0.0, "pushing again clears it")
	screen.toggle_button("seq", "gate_4")

	# Through the sequencer: clock GATE → CLOCK, sequencer GATE → volume TRIG.
	state.remove_cable(gate_trig)
	_expect(not state.is_complete() and not burbler.sounding, "without GATE → TRIG it isn't configured")
	state.add_cable(_cable("clock", "gate", "seq", "clock"))
	state.add_cable(_cable("seq", "gate", "volume", "trig"))
	_expect(state.is_complete() and burbler.sounding, "configured through the sequencer")
	_expect(view.waiting_jacks().is_empty(), "no guidance left once the path is made")

	# The heard step advances on the burbler's clock.
	var seen: Array[int] = []
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline and seen.size() < 3:
		var step: int = burbler.link.current_step("seq")
		if step >= 0 and (seen.is_empty() or seen[-1] != step):
			seen.append(step)
		await process_frame
	_expect(seen.size() >= 3, "the heard step moves with the clock: %s" % [seen])
	var ok := true
	for i in range(1, seen.size()):
		ok = ok and seen[i] == (seen[i - 1] + 1) % 4
	_expect(ok, "steps go one at a time and wrap after 4: %s" % [seen])

	# A loop can't hang completion: sequencer GATE → its own RESET, no clock in.
	state.remove_cable(state.cable_at({"place": "seq", "port": "clock"}))
	state.add_cable(_cable("seq", "gate", "seq", "reset"))
	_expect(not state.feeds({"place": "clock", "port": "gate"}, {"place": "volume", "port": "trig"}), "a loop without the clock doesn't feed TRIG")

	if _failures.is_empty():
		print("test_snail_sequencer: OK")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		quit(1)


func _cable(from_place: String, from_port: String, to_place: String, to_port: String) -> Dictionary:
	return {"color": "verdigris", "from": {"place": from_place, "port": from_port},
			"to": {"place": to_place, "port": to_port}, "source": "inventory"}


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
