class_name StreamBuilder
extends Node3D
## Stream build mode, like a Satisfactory conveyor (add-stream-building). Q enters and
## leaves (Esc leaves too); E does nothing meanwhile. The free port nearest the aim
## point within 3 m is the candidate and shows its halo; left click anchors there. A
## hologram curves from the anchor to the aim point in whole segments, tinted valid or
## invalid; left click lays it (spending its reeds, all or nothing) and anchors at the
## new end; right click drops the anchor. Outside build mode, F dismantles the
## segment in the crosshair and refunds it.

const PORT_REACH := 3.0
const DISMANTLE_REACH := 8.0
## Re-plan only when the aim moves this far, and at most every REPLAN_S: re-bending
## an 8-segment hologram costs ~8 ms in GDScript (docs/research/stream-bending.md).
const REPLAN_M := 0.25
const REPLAN_S := 0.1
const HOLOGRAM_PROFILE := "res://assets/streams/stream_hologram/asset.json"
const CHEVRON_SPACING := 0.5

var active := false
var anchor: StreamPort
var candidate: StreamPort
var plan: StreamPath
var plan_valid := false
## {item, need, have} while a plan is anchored, else {}.
var cost := {}

var _hologram: Node3D
var _hologram_bender: StreamBender
var _materials := {}  # "valid"/"invalid" -> {source material: tinted copy}
var _flow_tiles: Array[Dictionary] = []  # {mi, source, start}
var _planned_aim := Vector3.INF
var _planned_segments := 0
var _scroll := 0.0
var _replanned_at := -1.0
## Where laid streams go.
var streams_root: Node3D


func _ready() -> void:
	add_to_group("stream_builder")
	_hologram = Node3D.new()
	_hologram.name = "Hologram"
	add_child(_hologram)
	streams_root = Node3D.new()
	streams_root.name = "Streams"
	add_child(streams_root)


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _screen_open() -> bool:
	for group in ["rack_screen", "inventory_screen"]:
		for screen: Node in get_tree().get_nodes_in_group(group):
			if screen.is_open():
				return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	var player := _player()
	if player == null:
		return
	if event.is_action_pressed("build", false):
		if active:
			set_active(false)
		elif player.controls_enabled and not _screen_open():
			set_active(true)
		get_viewport().set_input_as_handled()
	elif not active and event.is_action_pressed("dismantle", false) \
			and player.controls_enabled and not _screen_open():
		dismantle_aimed()
		get_viewport().set_input_as_handled()
	elif active and event.is_action_pressed("release_cursor"):
		set_active(false)
	elif active and event.is_action_pressed("build_place", false) \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		place()
		get_viewport().set_input_as_handled()
	elif active and event.is_action_pressed("build_cancel", false):
		drop_anchor()
		get_viewport().set_input_as_handled()


func set_active(on: bool) -> void:
	active = on
	var player := _player()
	if player:
		player.building = on
	if not on:
		drop_anchor()
		_set_candidate(null)


func _process(delta: float) -> void:
	if active and _screen_open():
		set_active(false)
	if not active:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	if anchor == null:
		_set_candidate(_nearest_port(camera))
	else:
		_set_candidate(null)
		_update_plan(aim(camera, anchor.global_position))
		_scroll_chevrons(delta)


## Where the camera's ray meets the plane at `from`'s height, at most 32 m from it
## (looking at or above the horizon aims at the limit), as streams.rs `aim`.
static func aim_from(camera_transform: Transform3D, from: Vector3) -> Vector3:
	var origin := camera_transform.origin
	var ray := -camera_transform.basis.z
	var hit: Vector3
	if ray.y < -0.01:
		hit = origin + ray * ((from.y - origin.y) / ray.y)
	else:
		var flat := Vector3(ray.x, 0.0, ray.z).normalized()
		hit = Vector3(origin.x, from.y, origin.z) + flat * StreamPath.MAX_PLAN * 2.0
	var offset := Vector3(hit.x - from.x, 0.0, hit.z - from.z).limit_length(StreamPath.MAX_PLAN)
	return Vector3(from.x + offset.x, from.y, from.z + offset.z)


func aim(camera: Camera3D, from: Vector3) -> Vector3:
	return aim_from(camera.global_transform, from)


func _free_ports() -> Array[StreamPort]:
	var out: Array[StreamPort] = []
	for port: StreamPort in get_tree().get_nodes_in_group("stream_port"):
		if not port.connected and is_instance_valid(port.owner_node):
			out.append(port)
	return out


func _nearest_port(camera: Camera3D) -> StreamPort:
	var best: StreamPort = null
	var best_d := PORT_REACH
	for port in _free_ports():
		var p := port.global_position
		var a := aim(camera, p)
		var d := Vector2(a.x - p.x, a.z - p.z).length()
		if d <= best_d:
			best = port
			best_d = d
	return best


func _set_candidate(port: StreamPort) -> void:
	if port == candidate:
		return
	if candidate and is_instance_valid(candidate):
		_highlight(candidate, false)
	candidate = port
	if candidate:
		_highlight(candidate, true)


static func _highlight(port: StreamPort, on: bool) -> void:
	if port.owner_node is LaidStream:
		(port.owner_node as LaidStream).set_end_highlighted(on)
	else:
		port.set_highlighted(on)


## Left click: anchor on the candidate, or lay a valid plan.
func place() -> void:
	if anchor == null:
		if candidate:
			anchor = candidate
			_set_candidate(null)
			_planned_aim = Vector3.INF
			_replanned_at = -1.0
		return
	if plan == null or not plan_valid:
		return
	lay()


func drop_anchor() -> void:
	anchor = null
	plan = null
	plan_valid = false
	cost = {}
	_clear_hologram()


## Plans from the anchor to `target` (global); re-bends the hologram when it changed.
func _update_plan(target: Vector3) -> void:
	if not is_instance_valid(anchor) or anchor.connected:
		drop_anchor()
		return
	var now := Time.get_ticks_msec() / 1000.0
	if plan and (target.distance_to(_planned_aim) < REPLAN_M or now - _replanned_at < REPLAN_S):
		_refresh_cost()
		return
	_planned_aim = target
	_replanned_at = now
	plan = StreamPath.plan(anchor.global_position, anchor.flow_direction(), target)
	_refresh_cost()
	_show_hologram()


func _refresh_cost() -> void:
	var n := plan.segment_count()
	var per := Rules.build_cost(LaidStream.BUILDABLE)
	var stack: Dictionary = per[0] if not per.is_empty() else {"item": "", "quantity": 0}
	cost = {"item": stack.item, "need": int(stack.quantity) * n, "have": PlayerInventory.quantity(stack.item)}
	var valid := plan.shape_ok() and PlayerInventory.can_afford(per, n)
	if valid != plan_valid:
		plan_valid = valid
		_tint_hologram()
	plan_valid = valid


func _bender() -> StreamBender:
	if _hologram_bender == null:
		_hologram_bender = StreamBender.load_asset(StreamBender.HOLOGRAM)
	return _hologram_bender


func _clear_hologram() -> void:
	for child in _hologram.get_children():
		child.free()
	_flow_tiles.clear()


func _show_hologram() -> void:
	_clear_hologram()
	var n := plan.segment_count()
	var span := plan.length() / n
	for k in n:
		for piece: Dictionary in _bender().bend(plan, k * span, span, k == n - 1):
			var mi := MeshInstance3D.new()
			mi.name = "%s_%d" % [piece.name, k]
			mi.mesh = piece.mesh
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_hologram.add_child(mi)
			if piece.role == "flow":
				var source: ArrayMesh
				for p: Dictionary in _bender().pieces:
					if p.name == piece.name:
						source = p.mesh
				_flow_tiles.append({"mi": mi, "source": source, "start": k * span, "span": span})
	_tint_hologram()


## Every hologram material takes the valid or invalid colour (asset.json states).
func _tint_hologram() -> void:
	var state := "valid" if plan_valid else "invalid"
	for mi: MeshInstance3D in _hologram.get_children():
		for s in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, _tinted(mi.mesh.surface_get_material(s), state))


func _tinted(source: Material, state: String) -> Material:
	if source == null:
		return null
	if not _materials.has(state):
		_materials[state] = {}
	if _materials[state].has(source):
		return _materials[state][source]
	var profile := AssetProfile.load_json(HOLOGRAM_PROFILE)
	var color := Color.html(profile.get("states", {}).get(state, {}).get("color", "#ffffff"))
	var spec: Dictionary = profile.get("materials", {}).get(source.resource_name, {})
	var m := (source as StandardMaterial3D).duplicate() as StandardMaterial3D if source is StandardMaterial3D else StandardMaterial3D.new()
	m.albedo_color = Color(color, float(spec.get("alpha", m.albedo_color.a)))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = float(spec.get("emission_strength", 1.0))
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materials[state][source] = m
	return m


## Chevrons scroll downstream at the plan's flow speed, wrapping at their spacing.
func _scroll_chevrons(delta: float) -> void:
	if _flow_tiles.is_empty():
		return
	_scroll = fposmod(_scroll + delta * flow_speed(), CHEVRON_SPACING)
	for tile: Dictionary in _flow_tiles:
		var mesh := StreamBender.bend_mesh(tile.source, plan, tile.start + _scroll - CHEVRON_SPACING, tile.span)
		var mi: MeshInstance3D = tile.mi
		var overrides: Array = []
		for s in mi.mesh.get_surface_count():
			overrides.append(mi.get_surface_override_material(s))
		mi.mesh = mesh
		for s in overrides.size():
			mi.set_surface_override_material(s, overrides[s])


## The planned stream's speed: one note spacing per beat of its source's clock.
func flow_speed() -> float:
	var src: Node = anchor.owner_node if anchor else null
	if src is LaidStream:
		src = (src as LaidStream).source()
	var bpm: float = src.bpm() if src and src.has_method("bpm") else 60.0
	return StreamFlow.note_spacing() * bpm / 60.0


## Spends the plan's reeds and lays it from the anchor; the new end is the next anchor.
func lay() -> LaidStream:
	var n := plan.segment_count()
	if not PlayerInventory.spend(Rules.build_cost(LaidStream.BUILDABLE), n):
		return null
	var from: Node = anchor.owner_node
	var along := 0.0
	if from is LaidStream:
		along = (from as LaidStream).start_distance + (from as LaidStream).length()
	var stream := LaidStream.new()
	stream.setup(plan, plan.length() / n, 0, n - 1, from, along)
	streams_root.add_child(stream)
	_highlight(anchor, false)
	anchor.connected = true
	anchor = stream.end_port
	plan = null
	_planned_aim = Vector3.INF
	_replanned_at = -1.0
	_clear_hologram()
	return stream


## F: removes the laid segment in the crosshair (within reach) and refunds it.
func dismantle_aimed() -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var hit := pick_segment(camera.global_transform)
	if hit.is_empty():
		return false
	(hit.stream as LaidStream).dismantle(hit.segment)
	return true


## The stream segment a ray from `from` (its -Z) hits within reach: {stream, segment}.
func pick_segment(from: Transform3D) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from.origin, from.origin - from.basis.z * DISMANTLE_REACH,
			LaidStream.INTERACT_LAYER)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not (hit.collider as Object).has_meta("stream"):
		return {}
	var stream: Variant = hit.collider.get_meta("stream")
	if not is_instance_valid(stream):
		return {}
	return {"stream": stream, "segment": hit.collider.get_meta("segment")}
