class_name LaidStream
extends Node3D
## A laid mud stream (add-stream-building): its StreamPath, bent stream_segment
## meshes for segments first .. last of the plan it was laid from, a pick area per
## segment on the interact layer (F dismantles by aim), and a StreamPort at its free
## end. `upstream` is what feeds it (a burbler or another LaidStream); it flows when
## the walk upstream reaches a sounding burbler (D8).

signal changed

const BUILDABLE := "stream_segment"
const INTERACT_LAYER := 1 << 2  # physics layer 3, "interact"

static var _segment_bender: StreamBender

var path: StreamPath
## The plan's segment length (its length / its segment count).
var span := 4.0
## Segments [first, last] of the plan this stream covers.
var first := 0
var last := 0
## A MudpitBurbler or LaidStream, or null (a part cut off by a dismantle).
var upstream: Node
var end_port: StreamPort
## Where the stream starts, along the source chain (for notes carried across joins).
var start_distance := 0.0


static func bender() -> StreamBender:
	if _segment_bender == null:
		_segment_bender = StreamBender.load_asset(StreamBender.SEGMENT)
	return _segment_bender


## Lays segments first..last of `plan` (each `plan_span` long), fed by `from`.
func setup(plan: StreamPath, plan_span: float, first_segment: int, last_segment: int, from: Node, along: float) -> void:
	path = plan
	span = plan_span
	first = first_segment
	last = last_segment
	upstream = from
	start_distance = along
	name = "Stream"
	_build()


func segment_count() -> int:
	return last - first + 1


## Arc length of this stream's start and end along its path.
func start_s() -> float:
	return first * span


func end_s() -> float:
	return (last + 1) * span


func length() -> float:
	return end_s() - start_s()


func _build() -> void:
	for k in range(first, last + 1):
		var segment := Node3D.new()
		segment.name = "Segment%d" % k
		segment.set_meta("segment", k)
		add_child(segment)
		for piece: Dictionary in bender().bend(path, k * span, span, k == last):
			var mi := MeshInstance3D.new()
			mi.name = piece.name
			mi.mesh = piece.mesh
			if piece.role == "halo_out":
				mi.visible = false
				mi.add_to_group("stream_end_halo")
			segment.add_child(mi)
		segment.add_child(_pick_area(k))
	end_port = StreamPort.new()
	end_port.name = "EndPort"
	end_port.owner_node = self
	var end := path.frame(end_s())
	end_port.transform = end
	end_port.halo = Node3D.new()  # the halo meshes are bent into the last segment
	add_child(end_port)


## A box over segment k, on the interact layer, for F's aim ray.
func _pick_area(k: int) -> Area3D:
	var area := Area3D.new()
	area.name = "Pick"
	area.collision_layer = INTERACT_LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("stream", self)
	area.set_meta("segment", k)
	var mid := path.frame((k + 0.5) * span)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(span, 0.6, 2.2)
	shape.shape = box
	shape.transform = Transform3D(mid.basis, mid.origin + Vector3.UP * 0.2)
	area.add_child(shape)
	return area


## Shows or hides the free end's halo (it's the build candidate).
func set_end_highlighted(on: bool) -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		if node.is_in_group("stream_end_halo"):
			(node as MeshInstance3D).visible = on


## The burbler this stream is fed by, walking upstream; null if cut off.
func source() -> Node:
	var node: Variant = upstream
	var guard := 0
	while is_instance_valid(node) and node is LaidStream and guard < 1000:
		node = (node as LaidStream).upstream
		guard += 1
	return node if is_instance_valid(node) and not node is LaidStream else null


## True while its source burbler sounds.
func flowing() -> bool:
	var src := source()
	return src != null and src.get("sounding") == true


## Removes segment k: refunds it, splits the stream around the gap. The part upstream
## keeps its source and gets a free end; the part downstream loses its source.
## Returns the new downstream part (or null).
func dismantle(k: int) -> LaidStream:
	if k < first or k > last:
		return null
	PlayerInventory.refund(Rules.build_cost(BUILDABLE))
	var parent := get_parent()
	var downstream: LaidStream = null
	var fed: Array[LaidStream] = []
	for node in get_tree().get_nodes_in_group("laid_stream"):
		if node != self and (node as LaidStream).upstream == self:
			fed.append(node)
	if k < last:
		downstream = LaidStream.new()
		downstream.setup(path, span, k + 1, last, null, start_distance + (k + 1 - first) * span)
		parent.add_child(downstream)
		downstream.end_port.connected = end_port.connected
		for child in fed:
			child.upstream = downstream
	if k > first:
		var up := LaidStream.new()
		up.setup(path, span, first, k - 1, upstream, start_distance)
		parent.add_child(up)  # keeps `upstream`; its end becomes the free port at the gap
	else:
		_free_upstream_port()
	queue_free()
	changed.emit()
	return downstream


## Removing the first segment frees the port it was laid from.
func _free_upstream_port() -> void:
	if upstream is LaidStream:
		(upstream as LaidStream).end_port.connected = false
	elif upstream != null and is_instance_valid(upstream) and upstream.has_method("stream_port"):
		upstream.stream_port().connected = false


func _enter_tree() -> void:
	add_to_group("laid_stream")


## The point of this stream nearest `p` (global).
func closest_point(p: Vector3) -> Vector3:
	var s := clampf(path.curve.get_closest_offset(p), start_s(), end_s())
	return path.at(s)[0]


# ------------------------------------------------------------------ flow

var _notes: Array[MultiMeshInstance3D] = []
var _bars: Array[MultiMeshInstance3D] = []
var _staff: Array[MeshInstance3D] = []
var _wave := {}


func _ready() -> void:
	_notes = _instancer("Pulse_0")
	_bars = _instancer("Bar_0")
	for mi in find_children("Stream_Staff*", "MeshInstance3D", true, false):
		_staff.append(mi)
	_wave = AssetProfile.load_json("res://assets/streams/stream_segment/asset.json").get("staff", {}).get("wave", {})


func _instancer(group: String) -> Array[MultiMeshInstance3D]:
	var out: Array[MultiMeshInstance3D] = []
	for part: Dictionary in bender().groups.get(group, []):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = part.mesh
		var mmi := MultiMeshInstance3D.new()
		mmi.name = group
		mmi.multimesh = mm
		mmi.set_meta("part", part.transform)
		add_child(mmi)
		out.append(mmi)
	return out


func _process(_delta: float) -> void:
	var src := source()
	var flow: StreamFlow = src.flow if src != null and flowing() else null
	_show(_notes, _note_distances(flow), "Pulse_0", flow)
	_show(_bars, flow.bars() if flow else PackedFloat32Array(), "Bar_0", flow)
	var phase := TAU * (flow.flowed if flow else 0.0) / float(_wave.get("wavelength_m", 2.0))
	for mi in _staff:
		if mi.mesh.get_blend_shape_count() >= 2:
			mi.set_blend_shape_value(0, cos(phase) if flow else 0.0)
			mi.set_blend_shape_value(1, -sin(phase) if flow else 0.0)


func _note_distances(flow: StreamFlow) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if flow:
		for note in flow.notes:
			out.append(note.distance)
	return out


## Places instances at the chain distances that fall on this stream, riding the staff wave.
func _show(parts: Array[MultiMeshInstance3D], distances: PackedFloat32Array, group: String, flow: StreamFlow) -> void:
	var origin: Transform3D = bender().group_origins.get(group, Transform3D.IDENTITY)
	var on: Array[Transform3D] = []
	var amplitude := float(_wave.get("amplitude_m", 0.07))
	var wavelength := float(_wave.get("wavelength_m", 2.0))
	var phase := TAU * (flow.flowed if flow else 0.0) / wavelength
	for d in distances:
		var local := d - start_distance
		if local < 0.0 or local > length():
			continue
		var s := start_s() + local
		var x := fposmod(s, span) * StreamPath.SEGMENT_LENGTH / span
		var lift := amplitude * sin(TAU * x / wavelength - phase)
		var f := path.frame(s)
		on.append(f * Transform3D(Basis.IDENTITY, Vector3(0.0, origin.origin.y + lift, origin.origin.z)))
	for mmi in parts:
		var mm := mmi.multimesh
		mm.instance_count = on.size()
		var part: Transform3D = mmi.get_meta("part")
		for i in on.size():
			mm.set_instance_transform(i, on[i] * part)


## Notes shown now (for tests).
func notes_shown() -> int:
	return _notes[0].multimesh.instance_count if not _notes.is_empty() else 0
