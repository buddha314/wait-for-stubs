@tool
class_name ReedClump
extends Node3D
## One harvestable clump of reeds (resource: reed). Variant, yaw, scale, height
## and sway phase all come from (world seed, instance_id). Walk-through: no
## collider. Near/far detail swaps at the profile's far_lod distance.

const PROFILE_PATH := "res://assets/flora/reeds/asset.json"
const VARIANTS: Array[PackedScene] = [
	preload("res://assets/models/flora/reeds/reed_clump_0.glb"),
	preload("res://assets/models/flora/reeds/reed_clump_1.glb"),
	preload("res://assets/models/flora/reeds/reed_clump_2.glb"),
	preload("res://assets/models/flora/reeds/reed_clump_3.glb"),
]
const LOD_MARGIN := 2.0
## Row id in resources.json.
const RESOURCE_ID := "reed_clump"
## Sway cycles per second.
const SWAY_RATE := 0.35

@export var instance_id: String = "reed_clump-0":
	set(value):
		instance_id = value
		if is_node_ready():
			_build()

var _model: Node3D
var _pickup: ResourceNode
var _standing: Node3D
var _stubble: Node3D
var _far: Node3D
var _regrow_from := 0.1
var _sway: Array[Node3D] = []
var _sway_max := 0.0
var _phase := 0.0
var _time := 0.0


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _sway.is_empty():
		return
	if _pickup and _pickup.collected:
		# Regrowing: the standing reeds rise from stubble height over the interval.
		var grown := lerpf(_regrow_from, 1.0, _pickup.replenish_progress())
		_standing.scale = Vector3(1.0, grown, 1.0)
	_time += delta
	for i in _sway.size():
		var angle := TAU * (_time * SWAY_RATE + _phase) + i
		_sway[i].rotation = Vector3(sin(angle), 0.0, cos(angle * 0.7)) * _sway_max


func _build() -> void:
	if _model:
		_model.free()
	if _pickup:
		_pickup.free()
		_pickup = null
	_sway.clear()
	var profile := AssetProfile.load_json(PROFILE_PATH)
	var per_instance: Dictionary = profile.get("per_instance", {})
	var rng := WorldSeed.rng(instance_id)

	_model = VARIANTS[rng.randi() % VARIANTS.size()].instantiate()
	add_child(_model)  # no owner: generated, never saved into the scene

	var yaw := AssetProfile.range_of(per_instance, "yaw_deg", Vector2(0, 360))
	var size := AssetProfile.range_of(per_instance, "scale", Vector2.ONE)
	var stretch := AssetProfile.range_of(per_instance, "height_stretch", Vector2.ONE)
	var phase := AssetProfile.range_of(per_instance, "sway_phase", Vector2(0, 1))
	var s := rng.randf_range(size.x, size.y)
	_model.rotation_degrees.y = rng.randf_range(yaw.x, yaw.y)
	_model.scale = Vector3(s, s * rng.randf_range(stretch.x, stretch.y), s)
	_phase = rng.randf_range(phase.x, phase.y)
	_sway_max = deg_to_rad(profile.get("sway", {}).get("max_deg", 4.0))

	var far: float = profile.get("far_lod", {}).get("distance_m", 30.0)
	_set_lod(_model.find_child("*_LOD0", true, false), 0.0, far)
	_set_lod(_model.find_child("*_LOD1", true, false), far, 0.0)
	for node in _model.find_children("Sway_*", "Node3D", true, false):
		_sway.append(node)
	_standing = _model.find_child("Standing", true, false)
	_stubble = _model.find_child("Stubble", true, false)
	_far = _model.find_child("*_LOD1", true, false)
	_regrow_from = profile.get("regrow", {}).get("from_scale", 0.1)

	if Engine.is_editor_hint():
		return
	_pickup = ResourceNode.new()
	_pickup.name = "Pickup"
	_pickup.resource_id = RESOURCE_ID
	_pickup.instance_id = instance_id
	var interact: Node3D = _model.find_child("Interact", true, false)
	_pickup.position = interact.position * _model.scale if interact else Vector3.UP * 0.7
	_pickup.collected_changed.connect(_on_collected_changed)
	add_child(_pickup)


## Harvested: cut to stubble (the far billboard hides), then regrow in _process.
func _on_collected_changed(collected: bool) -> void:
	_standing.scale = Vector3(1.0, _regrow_from, 1.0) if collected else Vector3.ONE
	for node: Node3D in [_stubble] + _stubble.find_children("*", "Node3D", true, false):
		node.scale = Vector3.ONE if collected else Vector3.ZERO
	if _far:
		_far.visible = not collected


func _set_lod(root: Node, begin: float, end: float) -> void:
	if root == null:
		return
	for mesh: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
		mesh.visibility_range_begin = begin
		mesh.visibility_range_begin_margin = LOD_MARGIN if begin > 0.0 else 0.0
		mesh.visibility_range_end = end
		mesh.visibility_range_end_margin = LOD_MARGIN if end > 0.0 else 0.0
		mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
