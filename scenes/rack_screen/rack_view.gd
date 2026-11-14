class_name RackView
extends Node3D
## The 3D rack inside the rack screen's SubViewport (its own World3D, so the game's
## sky, sun and fog never reach it). Built from a RackState and the machine's
## `configure` block using the real assets: rack_frame stretched to the slots' width,
## mounted modules, labelled slot outlines, cables and plugs. It draws and answers
## picking queries in viewport pixels; the screen (rack_screen.gd) owns the input.
## Faceplates face +Z; the camera looks along −Z.

const FRAME_PATH := "res://assets/hud/rack_frame/asset.json"
const FRAME_MODEL := "res://assets/hud/rack_frame/rack_frame.glb"
const LABELS_MODEL := "res://assets/hud/slot_labels/slot_labels.glb"
const PLUG_MODEL := "res://assets/cables/patch_plug/patch_plug.glb"
const OUTLINE_MODEL := "res://assets/hud/slot_outline_{hp}hp/slot_outline_{hp}hp.glb"
## A module's height (3U at ×10, before its crown), for slot hit-testing.
const MODULE_HEIGHT := 1.285
## Distance from the camera to the faceplates, and the plane a cable in hand rides on.
const CAMERA_Z := 4.0
const HAND_Z := 0.5
## Jack and knob pick radii in metres (the snap radius is in pixels, on the screen).
const KNOB_RADIUS := 0.09
## A ghost cable: the build-ghost colour, translucent (stubby-music rack.rs).
const GHOST_COLOR := Color(1.0, 0.83, 0.6, 0.22)
## Halo pulse: strength 0 → 2 over 1.2 s.
const HALO_PERIOD := 1.2
const HALO_PEAK := 2.0
## A held cable's sag follows on a critically damped spring of this rate (1/s).
const SPRING_RATE := 14.0

var state: RackState
var configure: Dictionary
## "place/param" -> {min, max, step} from the machine.
var overrides: Dictionary
## What the cable in hand looks like: {color, anchor: jack or {}, pointer: Vector2}.
## Empty when nothing is held.
var held: Dictionary = {}
## Returns the machine's BPM, for the placeholder lamp tick (_update_lamps).
var bpm_source: Callable
## Returns the heard beat phase (0..1) of the machine's voice, or −1 when silent.
var phase_source: Callable

var _frame: Dictionary
var _camera: Camera3D
var _rack: Node3D
var _cables: Node3D
var _held_node: Node3D
## Per place: {place, hp, x, module (Node3D or null), outline (Node3D or null)}.
var _places: Array[Dictionary] = []
var _rack_width := 0.0
## Per comb slot index: the cable's sampled points in world space (for picking).
var _comb_points: Dictionary[int, PackedVector3Array] = {}
## Halo materials per "place/port" and the meshes that use them.
var _halos: Dictionary[String, Dictionary] = {}
## Lamp and light materials per place: [{material, base}].
var _glow: Dictionary[String, Array] = {}
var _knob_bases: Dictionary[String, Basis] = {}
var _spring_c := Vector3.ZERO
var _spring_v := Vector3.ZERO
var _spring_ready := false
## Materials are cached, never made per draw: freeing a cable mesh together with
## the only reference to its material errors in Godot 4.8 beta.
var _materials: Dictionary[String, Material] = {}


func _ready() -> void:
	_frame = AssetProfile.load_json(FRAME_PATH)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.position = Vector3(0.0, 0.65, CAMERA_Z)
	_camera.current = true
	add_child(_camera)
	_add_lighting()


func build(rack_state: RackState, machine_configure: Dictionary, knob_overrides: Dictionary) -> void:
	state = rack_state
	configure = machine_configure
	overrides = knob_overrides
	held = {}
	if _rack:
		_rack.free()
	_rack = Node3D.new()
	_rack.name = "Rack"
	add_child(_rack)
	_cables = Node3D.new()
	_rack.add_child(_cables)
	_held_node = Node3D.new()
	_rack.add_child(_held_node)
	_places.clear()
	_halos.clear()
	_glow.clear()
	_knob_bases.clear()
	var hp_total := 0
	for place: Dictionary in configure.get("places", []):
		hp_total += int(place.hp)
	_rack_width = hp_total * RackModules.HP_METRES
	var x := -_rack_width / 2.0
	for place: Dictionary in configure.get("places", []):
		var width: float = int(place.hp) * RackModules.HP_METRES
		_places.append({"place": place.place, "hp": int(place.hp), "x": x + width / 2.0,
				"kind": place.get("kind", ""), "module": null, "outline": null})
		x += width
	_build_frame()
	refresh()


## Re-reads the state: modules and outlines, knobs, display, cables, halos.
func refresh() -> void:
	if state == null:
		return
	for entry in _places:
		var want: String = state.mounted.get(entry.place, "")
		var have: Node3D = entry.module
		if have and have.get_meta("module_id", "") != want:
			have.free()
			entry.module = null
			_forget(entry.place)
		if want != "" and entry.module == null:
			entry.module = _mount_model(entry, want)
		if entry.outline:
			entry.outline.visible = want == ""
		elif want == "":
			entry.outline = _outline(entry)
	_update_knobs_and_display()
	_draw_cables()


## Drops the halos, glows and knob poses of a place whose module was removed.
func _forget(place: String) -> void:
	_glow.erase(place)
	for key: String in _halos.keys():
		if key.begins_with(place + "/"):
			_halos.erase(key)
	for key: String in _knob_bases.keys():
		if key.begins_with(place + "/"):
			_knob_bases.erase(key)


func _process(delta: float) -> void:
	if state == null:
		return
	_update_halos()
	_update_lamps()
	_update_held(delta)


# ------------------------------------------------------------------ building


func _add_lighting() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.6, 0.58)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_hdr_threshold = 1.4
	env.glow_bloom = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	# The profile's key light is a 2 m area light in Blender (x right, −y front, z up),
	# here an omni light at the same place (Godot has no area light) plus a soft fill.
	var key: Dictionary = _frame.get("screen", {}).get("key_light", {})
	var p: Array = key.get("position_m", [-1.2, -2.6, 1.9])
	var light := OmniLight3D.new()
	light.position = Vector3(p[0], p[2], -p[1])
	light.light_color = Color.html(key.get("color_srgb", "#ffd9b3"))
	light.light_energy = 2.2
	light.omni_range = 8.0
	light.omni_attenuation = 0.6
	light.shadow_enabled = true
	add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, 25.0, 0.0)
	fill.light_energy = 0.35
	add_child(fill)


func _build_frame() -> void:
	var frame := (load(FRAME_MODEL) as PackedScene).instantiate() as Node3D
	frame.name = "Frame"
	_rack.add_child(frame)
	var rails: Dictionary = _frame.rails
	for rail: String in rails.nodes:
		var node := frame.find_child(rail, true, false) as Node3D
		node.scale.x = (_rack_width + float(rails.rail_margin_m)) / float(rails.length_m)
	var inset: float = _frame.posts.post_inset_m
	(frame.find_child("PostL", true, false) as Node3D).position.x = -(_rack_width / 2.0 + inset)
	(frame.find_child("PostR", true, false) as Node3D).position.x = _rack_width / 2.0 + inset
	_frame_camera()


## Frames the rack's width, posts and comb, with the profile's extra height.
func _frame_camera() -> void:
	var inset: float = _frame.posts.post_inset_m
	var left := -(_rack_width / 2.0 + inset + 0.08)
	var right := _rack_width / 2.0 + inset + 0.34
	var bottom := -0.18
	var top := 1.5
	var margin := 0.06
	_camera.position.x = (left + right) / 2.0
	_camera.position.y = (bottom + top) / 2.0
	var height := top - bottom + 2.0 * margin
	var width := right - left + 2.0 * margin
	var view := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(16, 9)
	var aspect := view.x / maxf(view.y, 1.0)
	_camera.size = maxf(height, width / maxf(aspect, 0.01))


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE and _rack:
		_frame_camera()


## Re-frames after the viewport changes size.
func fit() -> void:
	if _rack:
		_frame_camera()


func _mount_model(entry: Dictionary, module: String) -> Node3D:
	var model := (load(RackModules.model_path(module)) as PackedScene).instantiate() as Node3D
	model.set_meta("module_id", module)
	model.position.x = entry.x
	_rack.add_child(model)
	var profile := RackModules.profile(module)
	# Knobs turn about their local Y (out of the panel); remember the rest pose.
	for p: Dictionary in profile.get("params", []):
		var knob := model.find_child(p.node, true, false) as Node3D
		if knob:
			_knob_bases["%s/%s" % [entry.place, p.param]] = knob.transform.basis
	# Halos: hidden until a patch invites them; own unlit material each.
	for port: Dictionary in profile.get("ports", []):
		var halo := model.find_child("Jack_%s_Halo" % port.port, true, false) as Node3D
		if halo == null:
			continue
		# Opaque: alpha-blended rings sort badly against the bushings and nuts.
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		for mesh in _meshes(halo):
			for i in mesh.mesh.get_surface_count():
				mesh.set_surface_override_material(i, material)
		halo.visible = false
		_halos["%s/%s" % [entry.place, port.port]] = {"node": halo, "material": material}
	# Glowing parts (the lamp, LEDs) get their own copies of their materials, so the
	# rack can scale their emission between rest and peak.
	var glows: Array = []
	var lamp: Dictionary = profile.get("lamp", {})
	if not lamp.is_empty():
		glows.append_array(_own_materials(model.find_child(lamp.node, true, false), "lamp", lamp))
	for light: Dictionary in profile.get("lights", []):
		glows.append_array(_own_materials(model.find_child(light.node, true, false), light.light, light))
	_glow[entry.place] = glows
	return model


func _own_materials(node: Node, light: String, spec: Dictionary) -> Array:
	var out := []
	if node == null:
		return out
	for mesh in _meshes(node):
		for i in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(i) as StandardMaterial3D
			if source == null or not source.emission_enabled:
				continue
			var copy := source.duplicate() as StandardMaterial3D
			mesh.set_surface_override_material(i, copy)
			out.append({"material": copy, "base": source.emission_energy_multiplier,
					"light": light, "rest": float(spec.get("rest_strength", 0.0)),
					"peak": float(spec.get("peak_strength", 1.0))})
	return out


func _outline(entry: Dictionary) -> Node3D:
	var path := OUTLINE_MODEL.format({"hp": entry.hp})
	if not ResourceLoader.exists(path):
		return null
	var outline := (load(path) as PackedScene).instantiate() as Node3D
	outline.position.x = entry.x
	_rack.add_child(outline)
	var anchor := outline.find_child("Label", true, false) as Node3D
	var labels := (load(LABELS_MODEL) as PackedScene).instantiate() as Node3D
	var wanted := labels.find_child("Label_" + String(entry.kind), true, false) as Node3D
	if wanted and anchor:
		for child in labels.find_child("SlotLabel_Root", true, false).get_children():
			child.visible = child == wanted
		labels.position = anchor.position
		outline.add_child(labels)
	else:
		labels.free()
	return outline


# ------------------------------------------------------------------ updates


func _update_knobs_and_display() -> void:
	for entry in _places:
		var model: Node3D = entry.module
		if model == null:
			continue
		var module: String = model.get_meta("module_id")
		var profile := RackModules.profile(module)
		for p: Dictionary in profile.get("params", []):
			var key := "%s/%s" % [entry.place, p.param]
			var knob := model.find_child(p.node, true, false) as Node3D
			if knob == null or not _knob_bases.has(key):
				continue
			var spec := knob_param(entry.place, p.param)
			var value := state.knob(key, knob_default(spec))
			knob.transform.basis = _knob_bases[key] * Basis(Vector3.UP, -RackModules.knob_angle(value, spec))
		var display: Dictionary = profile.get("display", {})
		if display.is_empty():
			continue
		var value := state.knob("%s/%s" % [entry.place, display.shows], 0.0)
		var lit := RackModules.lit_segments(value, display)
		for d in int(display.digits):
			for segment: String in display.segments:
				var node := model.find_child(display.segment_node.format(
						{"digit": d, "segment": segment}), true, false) as Node3D
				if node:
					node.visible = [d, segment] in lit


func knob_param(place: String, param_name: String) -> Dictionary:
	var module: String = state.mounted.get(place, "")
	return RackModules.param(module, param_name, overrides.get("%s/%s" % [place, param_name], {}))


static func knob_default(spec: Dictionary) -> float:
	var fallback: Variant = spec.get("default")
	return float(fallback) if fallback is float or fallback is int else float(spec.get("min", 0.0))


## Jacks of every suggested patch still waiting whose two modules are mounted.
func waiting_jacks() -> Dictionary:
	var out := {}
	for cable: Dictionary in configure.get("cables", []):
		if not _patch_ready(cable):
			continue
		for jack: Dictionary in [cable.from, cable.to]:
			var key := "%s/%s" % [jack.place, jack.port]
			if not state.is_patched(jack) and not out.has(key):
				out[key] = PatchCable.color(cable.color)
	return out


func _update_halos() -> void:
	var waiting := waiting_jacks()
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU / HALO_PERIOD)
	for key: String in _halos:
		var halo: Dictionary = _halos[key]
		var on := waiting.has(key)
		(halo.node as Node3D).visible = on
		if on:
			var c: Color = waiting[key]
			var material: StandardMaterial3D = halo.material
			material.albedo_color = c.lerp(Color.WHITE, 0.15 * pulse)
			material.emission = c
			material.emission_energy_multiplier = HALO_PEAK * pulse


## Flashes clock lamps and gate lights on the beat. While the machine sounds, the
## beat is the engine's heard phase (`phase_source`, from the master clock); while
## silent, a wall-time tick at the machine's BPM keeps the lamp alive. Visual only.
func _update_lamps() -> void:
	var bpm := float(bpm_source.call()) if bpm_source.is_valid() else 0.0
	var phase := float(phase_source.call()) if phase_source.is_valid() else -1.0
	for place: String in _glow:
		for glow: Dictionary in _glow[place]:
			var level := 0.0
			if bpm > 0.0 and glow.light in ["lamp", "gate"]:
				level = _placeholder_envelope(bpm, phase)
			var strength: float = lerpf(glow.rest, glow.peak, level)
			(glow.material as StandardMaterial3D).emission_energy_multiplier = \
					glow.base * strength / maxf(glow.peak, 0.0001)


## 0..1 flash envelope (15 ms attack, 250 ms decay) on the beat: from the engine's
## heard phase when the machine sounds, else from wall time.
static func _placeholder_envelope(bpm: float, phase: float = -1.0) -> float:
	var beat := 60.0 / bpm
	var since := phase * beat if phase >= 0.0 else fmod(Time.get_ticks_usec() / 1e6, beat)
	if since < 0.015:
		return since / 0.015
	return maxf(0.0, 1.0 - (since - 0.015) / 0.25)


# ------------------------------------------------------------------ cables


func jack_node(jack: Dictionary) -> Node3D:
	for entry in _places:
		if entry.place == jack.place and entry.module:
			var model: Node3D = entry.module
			var port := RackModules.port(model.get_meta("module_id"), jack.port)
			if not port.is_empty():
				return model.find_child(port.node, true, false) as Node3D
	return null


func _draw_cables() -> void:
	for child in _cables.get_children():
		child.free()
	_comb_points.clear()
	if not is_inside_tree():
		return
	var radius: float = PatchCable.profile().cable.radius_m
	for cable in state.cables:
		var a := jack_node(cable.from)
		var b := jack_node(cable.to)
		if a == null or b == null:
			continue
		var color := PatchCable.color(cable.color)
		var pa := _plug(a.global_transform, color, _cables)
		var pb := _plug(b.global_transform, color, _cables)
		_tube(pa, pb, PatchCable.control_point(pa, pb), radius, _cable_material(color), _cables)
	# Ghosts of the suggested patches still to make, once both their modules are in.
	var ghost := _ghost_material()
	for suggested: Dictionary in configure.get("cables", []):
		if not _patch_ready(suggested):
			continue
		var a := jack_node(suggested.from)
		var b := jack_node(suggested.to)
		if a and b:
			var pa := a.global_position + a.global_basis.y * 0.33
			var pb := b.global_position + b.global_basis.y * 0.33
			_tube(pa, pb, PatchCable.control_point(pa, pb), radius * 0.7, ghost, _cables)
	# Spare cables hang on the comb, folded over their slot, plugs tip down.
	var frame := _rack.get_node("Frame") as Node3D
	var comb: Dictionary = _frame.cable_comb
	var cables: Array = configure.get("cables", [])
	for n in cables.size():
		if state.comb_in_use(n) or held.get("source", "") == "comb:%d" % n:
			continue
		var slot := frame.find_child(comb.slot_node.format({"n": n}), true, false) as Node3D
		var rest_a := frame.find_child(comb.plug_rest[0].format({"n": n}), true, false) as Node3D
		var rest_b := frame.find_child(comb.plug_rest[1].format({"n": n}), true, false) as Node3D
		if slot == null or rest_a == null or rest_b == null:
			continue
		var color := PatchCable.color(cables[n].color)
		var pa := _plug(rest_a.global_transform, color, _cables)
		var pb := _plug(rest_b.global_transform, color, _cables)
		# Control point raised so the curve passes 3 cm over the comb slot.
		var over := slot.global_position + Vector3.UP * 0.03
		var c := 2.0 * over - (pa + pb) / 2.0
		_comb_points[n] = _tube(pa, pb, c, radius, _cable_material(color), _cables)


## A suggested patch not yet made whose two modules are both mounted.
func _patch_ready(suggested: Dictionary) -> bool:
	return state.mounted.has(suggested.from.place) and state.mounted.has(suggested.to.place) \
			and not state.joins(suggested.from, suggested.to)


## A plug at `where` (its sleeve along −Y, into the jack), tinted. Returns the
## world position of its Cable_attach.
func _plug(where: Transform3D, color: Color, parent: Node3D) -> Vector3:
	var plug := (load(PLUG_MODEL) as PackedScene).instantiate() as Node3D
	parent.add_child(plug)
	plug.global_transform = where
	var tint: Array = PatchCable.profile().get("tint", [])
	for mesh in _meshes(plug):
		for i in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(i) as StandardMaterial3D
			if source and source.resource_name in tint:
				var key := "%s:%s" % [source.resource_name, color.to_html()]
				if not _materials.has(key):
					var copy := source.duplicate() as StandardMaterial3D
					copy.albedo_color = color
					_materials[key] = copy
				mesh.set_surface_override_material(i, _materials[key])
	var attach := plug.find_child(PatchCable.profile().attach_node, true, false) as Node3D
	return attach.global_position if attach else where.origin


func _tube(a: Vector3, b: Vector3, c: Vector3, radius: float, material: Material,
		parent: Node3D) -> PackedVector3Array:
	var points := PatchCable.bezier(a, c, b)
	var mesh := MeshInstance3D.new()
	mesh.mesh = PatchCable.tube(points, radius)
	mesh.material_override = material
	parent.add_child(mesh)
	return points


func _cable_material(color: Color) -> Material:
	var key := "cable:" + color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.6
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[key] = material
	return _materials[key]


func _ghost_material() -> Material:
	if not _materials.has("ghost"):
		var ghost := StandardMaterial3D.new()
		ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ghost.albedo_color = GHOST_COLOR
		ghost.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials["ghost"] = ghost
	return _materials["ghost"]


## Draws the cable in hand: from its anchor jack (or a plug hanging below the
## pointer, for a cable just taken off the comb) to a plug at the pointer, facing
## into the panel. The sag follows on a damped spring.
func _update_held(delta: float) -> void:
	for child in _held_node.get_children():
		child.free()
	if held.is_empty():
		_spring_ready = false
		return
	var color := PatchCable.color(held.color)
	var radius: float = PatchCable.profile().cable.radius_m
	var tip := pointer_world(held.pointer)
	var snapped: Dictionary = held.get("snap", {})
	var free_end: Transform3D
	if not snapped.is_empty() and jack_node(snapped):
		free_end = jack_node(snapped).global_transform
	else:
		# Head-on, as in VCV Rack: the sleeve points into the panel.
		free_end = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), tip)
	var b := _plug(free_end, color, _held_node)
	var a: Vector3
	var anchor: Dictionary = held.get("anchor", {})
	if not anchor.is_empty() and jack_node(anchor):
		a = _plug(jack_node(anchor).global_transform, color, _held_node)
	else:
		a = _plug(Transform3D(Basis(), tip + Vector3(0.03, -0.42, 0.0)), color, _held_node)
	var target := PatchCable.control_point(a, b)
	if not _spring_ready:
		_spring_c = target
		_spring_v = Vector3.ZERO
		_spring_ready = true
	# Critically damped spring toward the VCV control point.
	var w := SPRING_RATE
	var accel := (target - _spring_c) * w * w - _spring_v * 2.0 * w
	_spring_v += accel * delta
	_spring_c += _spring_v * delta
	_tube(a, b, _spring_c, radius, _cable_material(color), _held_node)


# ------------------------------------------------------------------ picking


func camera() -> Camera3D:
	return _camera


func to_screen(world: Vector3) -> Vector2:
	return _camera.unproject_position(world)


## Pixels per metre at the faceplates.
func pixels_per_metre() -> float:
	return get_viewport().get_visible_rect().size.y / _camera.size


## The point under `pixel` on the hand plane in front of the panels.
func pointer_world(pixel: Vector2) -> Vector3:
	return _camera.project_position(pixel, CAMERA_Z - HAND_Z)


## The nearest mounted jack within `radius_px` of `pixel`: {place, port} or {}.
## `filter` (optional) takes the jack and returns whether it is a candidate.
func jack_at(pixel: Vector2, radius_px: float, filter: Callable = Callable()) -> Dictionary:
	var best := {}
	var best_d := radius_px
	for entry in _places:
		var model: Node3D = entry.module
		if model == null:
			continue
		for port: Dictionary in RackModules.profile(model.get_meta("module_id")).get("ports", []):
			var jack := {"place": entry.place, "port": port.port}
			if filter.is_valid() and not filter.call(jack):
				continue
			var node := model.find_child(port.node, true, false) as Node3D
			var d := to_screen(node.global_position).distance_to(pixel)
			if d <= best_d:
				best_d = d
				best = jack
	return best


## The knob under `pixel`: {place, param} or {}.
func knob_at(pixel: Vector2) -> Dictionary:
	var radius := KNOB_RADIUS * pixels_per_metre()
	for entry in _places:
		var model: Node3D = entry.module
		if model == null:
			continue
		for p: Dictionary in RackModules.profile(model.get_meta("module_id")).get("params", []):
			var node := model.find_child(p.node, true, false) as Node3D
			if node and to_screen(node.global_position).distance_to(pixel) <= radius:
				return {"place": entry.place, "param": p.param}
	return {}


## The place whose slot is under `pixel`, or "".
func place_at(pixel: Vector2) -> String:
	for entry in _places:
		var half: float = entry.hp * RackModules.HP_METRES / 2.0
		var low := to_screen(Vector3(entry.x - half, 0.0, 0.17))
		var high := to_screen(Vector3(entry.x + half, MODULE_HEIGHT, 0.17))
		var rect := Rect2(Vector2(low.x, high.y), Vector2(high.x - low.x, low.y - high.y))
		if rect.has_point(pixel):
			return entry.place
	return ""


## The centre of a place's slot on screen.
func place_centre(place: String) -> Vector2:
	for entry in _places:
		if entry.place == place:
			return to_screen(Vector3(entry.x, MODULE_HEIGHT / 2.0, 0.17))
	return Vector2.ZERO


## The comb slot whose hanging cable is within `radius_px` of `pixel`, or −1.
func comb_cable_at(pixel: Vector2, radius_px: float) -> int:
	for n: int in _comb_points:
		for point in _comb_points[n]:
			if to_screen(point).distance_to(pixel) <= radius_px:
				return n
	return -1


static func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		out.append_array(_meshes(child))
	return out
