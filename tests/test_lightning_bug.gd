extends SceneTree
## Lightning bugs on the audio engine (add-rack-audio-engine 9.1): each bug's seeded
## random clock ticks in the engine, the click is patched (square → envelope → VCA),
## the flash comes at the heard instant, and a collected bug stays dark and silent.
##   godot --headless --path . -s tests/test_lightning_bug.gd

const BUG := "res://assets/creatures/lightning_bug/lightning_bug.tscn"

var _failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := _bug("lightning_bug-test")
	var b := _bug("lightning_bug-test")
	var c := _bug("lightning_bug-other")
	var ticks := {}
	for bug: Node in [a, b, c]:
		ticks[bug.rack.get_module_id("clock")] = []
	var on_tick := func(id: int, sample: int, _i: int) -> void:
		if ticks.has(id):
			ticks[id].append(sample)
	RackServer.clock_ticked.connect(on_tick)
	_expect(a.rack.has_module("clock") and a.rack.has_module("vca"), "the bug's rack is built")
	_expect(a.rack.to_patch().cables.size() == 3, "clock → envelope → VCA ← VCO patched")
	await create_timer(6.0).timeout
	RackServer.clock_ticked.disconnect(on_tick)
	var ta: Array = ticks[a.rack.get_module_id("clock")]
	var tb: Array = ticks[b.rack.get_module_id("clock")]
	var tc: Array = ticks[c.rack.get_module_id("clock")]
	_expect(ta.size() >= 2, "the engine clock ticks (%d in 6 s)" % ta.size())
	_expect(a.flashes >= 1 and a.flashes <= ta.size(), "flashes follow ticks (%d flashes, %d ticks)" % [a.flashes, ta.size()])
	var gaps := func(t: Array) -> Array:
		var out := []
		for i in range(1, t.size()):
			out.append(t[i] - t[i - 1])
		return out
	var ga: Array = gaps.call(ta)
	var gb: Array = gaps.call(tb)
	var n := mini(ga.size(), gb.size())
	_expect(n >= 1 and ga.slice(0, n) == gb.slice(0, n), "same id, same seeded intervals")
	_expect(gaps.call(tc).slice(0, 1) != ga.slice(0, 1), "another id, other intervals")
	for gap: int in ga:
		_expect(gap >= int(0.65 * 48000) - 1 and gap <= int(2.4 * 48000) + 1, "interval %d within 0.65–2.4 s" % gap)

	# Collected: dark and silent, while the clock keeps time.
	a.get_node("Pickup").interact()
	_expect(a.get_node("Pickup").collected, "E collects the bug")
	var before: int = a.flashes
	await create_timer(3.0).timeout
	_expect(a.flashes == before and a.pending_flashes() == 0, "a collected bug doesn't flash")
	_expect(a.get("_voice").stream_paused, "a collected bug is silent")

	if _failures.is_empty():
		print("test_lightning_bug: OK")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		quit(1)


func _bug(id: String) -> Node:
	var bug := (load(BUG) as PackedScene).instantiate()
	bug.instance_id = id
	root.add_child(bug)
	return bug


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
