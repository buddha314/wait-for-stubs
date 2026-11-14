extends SceneTree
## Streams (add-stream-building): costs, the plan curve, bending, laying, chaining,
## dismantling, and the flow of notes and bar lines from clock ticks.
##   godot --headless --path . -s tests/test_streams.gd

var _failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var rules := root.get_node("Rules")
	var inv := root.get_node("PlayerInventory")

	# Costs are rules; bad rows are rejected with the file, id and field.
	var cost: Array = rules.build_cost("stream_segment")
	_expect(cost.size() == 1 and cost[0].item == "reed" and int(cost[0].quantity) == 6, "a segment costs 6 reed")
	rules._load_buildables([{"id": "bad", "cost": [{"item": "reeed", "quantity": 1}]}])
	_expect(rules.errors.size() >= 1 and rules.errors[-1].begins_with("buildables.json: bad: cost:"), "unknown cost item named: %s" % [rules.errors])
	_expect(rules.build_cost("bad").is_empty(), "an invalid buildable isn't loaded")

	# All or nothing.
	inv.give("reed", 13)
	_expect(inv.spend(cost, 2) and inv.quantity("reed") == 1, "13 reeds, build 2: 1 left")
	inv.give("reed", 11)
	_expect(not inv.spend(cost, 3) and inv.quantity("reed") == 12, "12 reeds, build 3: nothing taken")
	var short: Array = inv.shortfall(cost, 3)
	_expect(short.size() == 1 and int(short[0].quantity) == 6, "short by 6 reed")
	inv.take("reed", 12)
	inv.refund(cost)
	_expect(inv.quantity("reed") == 6, "a refund returns 6")
	inv.take("reed", 6)

	# The plan leaves along the port and ends at the aim (streams.rs tests).
	var from := Vector3(0, 0.07, 0)
	var p := StreamPath.plan(from, Vector3.RIGHT, Vector3(6, 0, 8))
	_expect(p.direction(0.0).dot(Vector3.RIGHT) > 0.99, "leaves along the port's direction")
	_expect((p.at(p.length())[0] as Vector3).distance_to(Vector3(6, 0.07, 8)) < 0.05, "ends at the aim, at the port's height")
	_expect(p.segment_count() == roundi(p.length() / 4.0), "N = round(L / 4)")
	var back := StreamPath.plan(from, Vector3.RIGHT, Vector3(-3, 0, 0))
	_expect(not back.shape_ok(), "doubling back 3 m behind is too tight")
	var ten := StreamPath.plan(from, Vector3.RIGHT, Vector3(8, 0, 6))
	_expect(ten.segment_count() == 3 and ten.shape_ok(), "10 m off to the side: 3 valid segments (L=%.2f)" % ten.length())

	# Bending a straight path keeps the segment shape.
	var straight := StreamPath.plan(Vector3.ZERO, Vector3.RIGHT, Vector3(4, 0, 0))
	var bender: StreamBender = load("res://scenes/stream/laid_stream.gd").bender()
	var piece: Dictionary = bender.pieces.filter(func(x: Dictionary) -> bool: return x.name == "Stream_Bed")[0]
	var bent := StreamBender.bend_mesh(piece.mesh, straight, 0.0, 4.0)
	var a: PackedVector3Array = piece.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var b: PackedVector3Array = bent.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var worst := 0.0
	for i in a.size():
		worst = maxf(worst, a[i].distance_to(b[i]))
	_expect(worst < 0.01, "a straight bend keeps the shape (worst %.4f m)" % worst)
	var staff: Dictionary = bender.pieces.filter(func(x: Dictionary) -> bool: return x.name == "Stream_StaffLine0")[0]
	_expect(StreamBender.bend_mesh(staff.mesh, ten, 0.0, 4.0).get_blend_shape_count() == 2, "the staff keeps its two blend shapes")

	# In the opening: lay from the burbler's mouth, chain, dismantle.
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var builder: Node = main.get_node("StreamBuilder")
	var burbler: Node = main.get_node("MudpitBurbler")
	var mouth: StreamPort = burbler.stream_port()
	_expect(mouth != null and not mouth.connected and mouth.is_in_group("stream_port"), "the burbler's mouth is a free port")
	_expect(mouth.halo != null and not mouth.halo.visible, "no halo outside build mode")
	builder.set_active(true)
	_expect(main.get_node("Player").building, "E is off in build mode")
	builder.anchor = mouth
	var t0 := Time.get_ticks_usec()
	builder._update_plan(mouth.global_position + mouth.flow_direction() * 8.0)
	var plan_ms := (Time.get_ticks_usec() - t0) / 1000.0
	_expect(builder.plan.segment_count() == 2, "an 8 m plan is 2 segments")
	_expect(not builder.plan_valid and builder.cost.need == 12 and builder.cost.have == 0, "no reeds: invalid, 12 / 0")
	inv.give("reed", 24)
	builder._refresh_cost()
	_expect(builder.plan_valid, "with 24 reeds the plan is valid")
	var stream: Node = builder.lay()
	_expect(stream != null and inv.quantity("reed") == 12, "laying spends 12 of 24")
	_expect(mouth.connected and builder.anchor == stream.end_port, "the mouth is taken; the new end is the anchor")
	_expect(stream.end_port.global_position.distance_to(stream.path.at(stream.end_s())[0]) < 0.01, "the end port is at the stream's end")
	# Chain on: the join has no gap.
	builder._replanned_at = -1.0
	builder._update_plan(stream.end_port.global_position + stream.end_port.flow_direction() * 8.0)
	var next: Node = builder.lay()
	_expect(next != null and next.upstream == stream and stream.end_port.connected, "a stream chains from the free end")
	_expect((next.path.at(0.0)[0] as Vector3).distance_to(stream.path.at(stream.end_s())[0]) < 0.001, "no gap at the join")
	_expect(inv.quantity("reed") == 0, "24 reeds laid 4 segments")
	print("plan + hologram for 2 segments: %.1f ms" % plan_ms)
	builder._planned_aim = Vector3.INF
	builder._replanned_at = -1.0
	t0 = Time.get_ticks_usec()
	builder._update_plan(next.end_port.global_position + next.end_port.flow_direction() * 31.0)
	print("plan + hologram for %d segments: %.1f ms" % [builder.plan.segment_count(), (Time.get_ticks_usec() - t0) / 1000.0])
	t0 = Time.get_ticks_usec()
	builder._scroll_chevrons(0.016)
	print("chevron scroll for %d segments: %.1f ms" % [builder.plan.segment_count(), (Time.get_ticks_usec() - t0) / 1000.0])
	builder.drop_anchor()

	# Dismantle the second segment of the first stream (segment index 1 of 0..1).
	var downstream: Variant = stream.dismantle(1)
	await process_frame
	_expect(inv.quantity("reed") == 6, "dismantling refunds 6")
	var first: Node = null
	for s: Node in main.get_tree().get_nodes_in_group("laid_stream"):
		if s.upstream == burbler:
			first = s
	_expect(first != null and first.segment_count() == 1 and not first.end_port.connected, "upstream keeps 1 segment and a free end")
	_expect(downstream == null and next.source() == null, "the stream below the gap loses its source")

	# Flow: ×60 at 48 kHz, 1 m spacing, bars every 4 notes, retune without a jump.
	var flow := StreamFlow.new()
	for k in 9:
		flow.add_tick(k * 48000, k)
	flow.advance(8 * 48000, 48000.0)
	var ds: Array = flow.notes.map(func(n: Dictionary) -> float: return n.distance)
	_expect(ds.size() == 9 and is_equal_approx(ds[0], 8.0) and is_equal_approx(ds[-1], 0.0), "notes 1 m apart (%s)" % [ds])
	var bars := flow.bars()
	_expect(bars.size() == 3 and is_equal_approx(bars[0] - bars[1], 4.0), "bar lines 4 m apart, half a spacing past the downbeat (%s)" % [bars])
	var before: float = flow.notes[0].distance
	flow.advance(8 * 48000 + 24000, 24000.0)  # retuned to ×120: half a second is one beat
	_expect(is_equal_approx(flow.notes[0].distance, before + 1.0), "×120: 2 m/s, no jump")
	var fast := StreamFlow.new()
	var slow := StreamFlow.new()
	fast.add_tick(0, 0)
	slow.add_tick(0, 0)
	for i in range(0, 145):
		fast.advance(48000.0 * i / 144.0, 48000.0)
	for i in range(0, 31):
		slow.advance(48000.0 * i / 30.0, 48000.0)
	_expect(is_equal_approx(fast.notes[0].distance, slow.notes[0].distance), "same distance at 144 and 30 fps")

	# A sounding burbler's notes show on its stream.
	burbler.sounding = true
	burbler.flow.add_tick(0, 0)
	burbler.flow.advance(48000.0 * 0.5, 48000.0)
	await process_frame
	_expect(first.notes_shown() == 1, "a note rides the flowing stream")
	burbler.sounding = false

	# Growth levels: mud reaches only the first level; cleaner water reaches more.
	var levels := GrowthLevels.load_for("res://assets/flora/scrub_oak/growth.json")
	_expect(is_equal_approx(levels.cap(0.0), 0.3) and is_equal_approx(levels.cap(0.5), 0.7)
			and is_equal_approx(levels.cap(1.0), 1.0) and levels.cap(-1.0) == 0.0, "mud → 0.3, silty → 0.7, clear → 1.0")
	_expect(levels.level_name(0.3) == "budding" and levels.level_name(0.1) == "dormant", "level names")
	_expect(is_equal_approx(levels.step(0.9, 0.0, 1200.0), 0.3), "bloomed past what mud allows, it eases back to budding")

	# Lead the burbler's stream to the nearest oak: it wakes to budding, no further.
	var oak: Node3D = null
	for o: Node3D in main.find_children("*", "ScrubOak", true, false):
		if oak == null or o.global_position.distance_to(mouth.global_position) < oak.global_position.distance_to(mouth.global_position):
			oak = o
	for st: Node in main.get_tree().get_nodes_in_group("laid_stream"):
		st.queue_free()
	await process_frame
	mouth.connected = false
	inv.give("reed", 99)
	builder.anchor = mouth
	var reached := false
	for i in 8:
		builder._replanned_at = -1.0
		var port: Node3D = builder.anchor
		builder._update_plan(oak.global_position)
		if not builder.plan_valid:
			builder._replanned_at = -1.0
			builder._update_plan(port.global_position + port.global_basis.x * 6.0)
		var laid: Node = builder.lay()
		if laid == null:
			break
		if Vector2(laid.end_port.global_position.x - oak.global_position.x, laid.end_port.global_position.z - oak.global_position.z).length() < 2.5:
			reached = true
			break
	_expect(reached, "a stream reaches the oak (%.1f m from the mouth)" % oak.global_position.distance_to(mouth.global_position))
	burbler.sounding = true
	oak._water_left = 0.0
	oak._water(1.0)
	_expect(oak.watered and is_equal_approx(oak.water_clarity, 0.0), "the oak is watered with mud")
	var goals := root.get_node("Goals")
	_expect(goals.holds("tree_watered", {"mine": "scrub_oak"}), "a watered oak reports tree_watered")
	for i in 30:
		oak._water(10.0)
	_expect(is_equal_approx(oak.growth, 0.3) and oak.bloom_level() == "budding", "mud wakes it to budding and no further (%.2f)" % oak.growth)
	_expect(goals.holds("tree_grown", {"mine": "scrub_oak", "level": "budding"}) \
			and not goals.holds("tree_grown", {"mine": "scrub_oak", "level": "leafed"}), "a budding oak reports tree_grown budding, not leafed")
	burbler.sounding = false
	oak._water_left = 0.0
	oak._water(60.0)
	_expect(not oak.watered and oak.growth < 0.3, "without water it eases back")
	main.free()

	if _failures.is_empty():
		print("test_streams: OK")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		quit(1)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
