@tool
class_name ScrubOak
extends Node3D
## A scrub oak (add-scrub-oak): the mine that will produce lightning bugs. Variant,
## yaw, scale, height stretch, lean, sway phase, leaf jitter and bloom tint all
## come from (world seed, instance_id), within the profile's per_instance ranges.
## `growth` (0 dormant .. 1 full bloom) is displayed from the profile's mapping; what
## raises it (clean water) comes with add-scrub-oak-production. Both LODs are used:
## the import script gives the model its visibility ranges, so nothing here sets
## them. Children are generated, never saved into scenes.
##
## Known upstream issue (docs/upstream/zero-scale-exports.md): the models ship their
## growth parts at scale 0, and Blender's exporter loses the transforms of the
## meshes inside them. Until stubby-music re-exports, the dormant state is right,
## but leaves and blooms can't be shown.

const PROFILE_PATH := "res://assets/flora/scrub_oak/asset.json"
const COLLIDERS_PATH := "res://assets/flora/scrub_oak/colliders.json"
## Sway cycles per second (the reeds' rate; the profile gives only the angle).
const SWAY_RATE := 0.25

@export var instance_id: String = "scrub_oak-0":
	set(value):
		instance_id = value
		if is_node_ready():
			_build()
## 0 dormant (winter) .. 1 full bloom. Defaults to the profile's `starts`.
@export_range(0.0, 1.0, 0.01) var growth := 0.0:
	set(value):
		growth = clampf(value, 0.0, 1.0)
		if is_node_ready():
			_apply_growth()

var _model: Node3D
var _profile: Dictionary
var _limbs: Array[Node3D] = []
var _limb_rest: Array[Basis] = []
var _sway_max := 0.0
var _phase := 0.0
var _time := 0.0
var _bark: StandardMaterial3D
var _leaf: StandardMaterial3D
var _bud: StandardMaterial3D
var _bud_emission := 1.0
var _leaf_jitter := 0.0


func _ready() -> void:
	_profile = AssetProfile.load_json(PROFILE_PATH)
	_build()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _limbs.is_empty():
		return
	_time += delta
	for i in _limbs.size():
		var angle := TAU * (_time * SWAY_RATE + _phase) + i
		var tilt := Vector3(sin(angle), 0.0, cos(angle * 0.7)) * _sway_max
		_limbs[i].transform.basis = _limb_rest[i] * Basis.from_euler(tilt)


func _build() -> void:
	if _model:
		_model.free()
	for child in get_children():
		if child is StaticBody3D:
			child.free()
	_limbs.clear()
	_limb_rest.clear()
	var per_instance: Dictionary = _profile.get("per_instance", {})
	var rng := WorldSeed.rng(instance_id)
	var variants: Array = _profile.get("variants", [])
	var model_path: String = variants[rng.randi() % variants.size()]
	_model = (load(_res_path(model_path)) as PackedScene).instantiate()
	add_child(_model)  # no owner: generated, never saved into the scene

	var yaw := AssetProfile.range_of(per_instance, "yaw_deg", Vector2(0, 360))
	var size := AssetProfile.range_of(per_instance, "scale", Vector2.ONE)
	var stretch := AssetProfile.range_of(per_instance, "height_stretch", Vector2.ONE)
	var lean := AssetProfile.range_of(per_instance, "lean_deg", Vector2.ZERO)
	var phase := AssetProfile.range_of(per_instance, "sway_phase", Vector2(0, 1))
	var s := rng.randf_range(size.x, size.y)
	var yaw_deg := rng.randf_range(yaw.x, yaw.y)
	var lean_deg := rng.randf_range(lean.x, lean.y)
	var lean_dir := rng.randf_range(0.0, TAU)
	_model.rotation = Vector3(deg_to_rad(lean_deg) * cos(lean_dir), deg_to_rad(yaw_deg), deg_to_rad(lean_deg) * sin(lean_dir))
	_model.scale = Vector3(s, s * rng.randf_range(stretch.x, stretch.y), s)
	_phase = rng.randf_range(phase.x, phase.y)
	_leaf_jitter = rng.randf_range(-1.0, 1.0) * float(per_instance.get("foliage_value_jitter", 0.0))
	var tints: Array = per_instance.get("bloom_tint", ["#c8f060"])
	var tint := Color.html(tints[rng.randi() % tints.size()])
	_sway_max = deg_to_rad(_profile.get("sway", {}).get("max_deg", 2.5))

	# LOD ranges come with the imported model (tools/import/asset_lod_import.gd).
	for limb in _named(_model, "Limb_"):
		_limbs.append(limb)
		_limb_rest.append(limb.transform.basis)
	_own_materials(tint)
	_add_collider(model_path)
	_apply_growth()



## Per-instance copies of the materials growth or the instance tint changes.
func _own_materials(tint: Color) -> void:
	var copies: Dictionary[String, StandardMaterial3D] = {}
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(i) as StandardMaterial3D
			if source == null or source.resource_name not in \
					["ScrubOak_Bark", "ScrubOak_Leaf", "ScrubOak_Bud", "ScrubOak_Catkin", "ScrubOak_CatkinHalo"]:
				continue
			if not copies.has(source.resource_name):
				var copy := source.duplicate() as StandardMaterial3D
				if source.resource_name.begins_with("ScrubOak_Catkin"):
					copy.albedo_color = Color(tint, copy.albedo_color.a)
					if copy.emission_enabled:
						copy.emission = tint
				copies[source.resource_name] = copy
			mesh.set_surface_override_material(i, copies[source.resource_name])
	_bark = copies.get("ScrubOak_Bark")
	_leaf = copies.get("ScrubOak_Leaf")
	_bud = copies.get("ScrubOak_Bud")
	if _bud:
		_bud.emission_enabled = true
		_bud_emission = 1.5


func _add_collider(model_path: String) -> void:
	var models: Dictionary = AssetProfile.load_json(COLLIDERS_PATH).get("models", {})
	var shapes: Array = models.get(model_path, {}).get("colliders", [])
	if shapes.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "Collider"
	add_child(body)
	for spec: Dictionary in shapes:
		if spec.get("shape", "") != "Cylinder":
			continue
		var cylinder := CylinderShape3D.new()
		cylinder.radius = float(spec.radius) * _model.scale.x
		cylinder.height = float(spec.height) * _model.scale.y
		var shape := CollisionShape3D.new()
		shape.shape = cylinder
		var at: Array = spec.get("translation", [0, 0, 0])
		shape.position = Vector3(at[0], at[1], at[2]) * _model.scale
		body.add_child(shape)


## The profile's growth mapping: each change is a smoothstep over [from, to].
func _apply_growth() -> void:
	if _model == null:
		return
	var growth_profile: Dictionary = _profile.get("growth", {})
	var ramps: Dictionary = growth_profile.get("ramps", {})
	var colors: Dictionary = growth_profile.get("colors", {})
	for node in _named(_model, "Dead_"):
		node.scale = Vector3.ONE * (1.0 - _ramp(ramps, "dead_leaves_fall"))
	var swell := _ramp(ramps, "buds_swell")
	for node in _named(_model, "Bud_"):
		node.scale = Vector3.ONE * maxf((0.4 + 0.6 * swell) * (1.0 - _ramp(ramps, "buds_open")), 0.0001)
	var leaf_out := _ramp(ramps, "leaf_out")
	for node in _named(_model, "Foliage_"):
		node.scale = Vector3.ONE * maxf(leaf_out, 0.0001)
	var far_foliage := _model.find_child("ScrubOak_Far_Foliage_Node", true, false) as Node3D
	if far_foliage:
		far_foliage.scale = Vector3.ONE * maxf(leaf_out, 0.0001)
	var blooms := _named(_model, "Bloom_")
	var bloom: Array = ramps.get("bloom", [0.72, 0.97])
	var span: float = ramps.get("bloom_open_span", 0.03)
	for i in blooms.size():
		var order := float(blooms[i].get_meta("extras", {}).get("order", i))
		var start := lerpf(bloom[0], bloom[1], order / maxf(blooms.size(), 1))
		blooms[i].scale = Vector3.ONE * maxf(smoothstep(start, start + span, growth), 0.0001)
	if _bark:
		_bark.albedo_color = Color.html(colors.get("bark_dormant", "#625d57")).lerp(
				Color.html(colors.get("bark_alive", "#4b4037")), _ramp(ramps, "bark_wakes"))
	if _leaf:
		var leaf := Color.html(colors.get("leaf_young", "#7b8c3c")).lerp(
				Color.html(colors.get("leaf_mature", "#36412a")), _ramp(ramps, "leaf_matures"))
		_leaf.albedo_color = Color.from_hsv(leaf.h, leaf.s, clampf(leaf.v + _leaf_jitter, 0.0, 1.0))
	if _bud:
		_bud.emission = Color.html(colors.get("bud", "#9a6a48"))
		_bud.emission_energy_multiplier = _bud_emission * swell


func _ramp(ramps: Dictionary, key: String) -> float:
	var pair: Array = ramps.get(key, [0.0, 1.0])
	return smoothstep(pair[0], pair[1], growth)


## Nodes named exactly `<prefix><number>` (not their child meshes).
static func _named(root: Node, prefix: String) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in root.find_children(prefix + "*", "Node3D", true, false):
		if String(node.name).trim_prefix(prefix).is_valid_int():
			out.append(node)
	return out


## Profile model paths are relative to res://assets/.
static func _res_path(model: String) -> String:
	return "res://assets/" + model
