class_name CollectibleOutline
extends Node
## Draws a white outline around the pickup the player is aiming at, as in
## Satisfactory (add-collectible-outline). Only that one, only while it is
## uncollected, the controls are free and build mode is off. Uses Godot's built-in
## stencil outline as a material overlay on the pickup's `outline_meshes()`.
## A child of the Player.

const SETTINGS_PATH := "res://assets/ui/collectible_outline.json"

## The outline settings (colour, width in pixels), from SETTINGS_PATH.
var settings: Dictionary
## The pickup outlined now, or null.
var outlined: ResourceNode

## Outlined meshes and their own overlay (thickness differs per mesh).
var _meshes: Array[MeshInstance3D] = []
var _materials: Array[StandardMaterial3D] = []

@onready var _player: Player = get_parent() as Player


func _ready() -> void:
	settings = AssetProfile.load_json(SETTINGS_PATH)


## The overlay: draws nothing itself, writes the stencil, and outlines it.
static func build_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	m.stencil_mode = BaseMaterial3D.STENCIL_MODE_OUTLINE
	m.stencil_color = color
	return m


func _process(_delta: float) -> void:
	_show(_wanted())
	_fit_thickness()


func _wanted() -> ResourceNode:
	if _player == null or not _player.controls_enabled or _player.building:
		return null
	var pickup := _player.target as ResourceNode
	return pickup if pickup and not pickup.collected else null


func _show(pickup: ResourceNode) -> void:
	if pickup == outlined:
		return
	if is_instance_valid(outlined):
		outlined.outline_shown = false
	for mesh in _meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = null
	_meshes.clear()
	_materials.clear()
	outlined = pickup
	if pickup == null:
		return
	pickup.outline_shown = true  # first: an owner may reveal its body for the outline
	var color := Color.html(str(settings.get("color", "#ffffff")))
	for mesh in pickup.outline_meshes():
		var material := build_material(color)
		mesh.material_overlay = material
		_meshes.append(mesh)
		_materials.append(material)


## Keeps the outline `width_pixels` wide on screen, as in Satisfactory. The stencil
## outline grows the mesh by a distance in its own space, so convert pixels to metres
## at the mesh's distance, then divide by its scale.
func _fit_thickness() -> void:
	var camera := get_viewport().get_camera_3d() if _meshes.size() > 0 else null
	if camera == null:
		return
	var pixels := float(settings.get("width_pixels", 2.0))
	var metres_per_pixel_at_1m := 2.0 * tan(deg_to_rad(camera.fov) * 0.5) \
			/ maxf(get_viewport().get_visible_rect().size.y, 1.0)
	for i in _meshes.size():
		var mesh := _meshes[i]
		if not is_instance_valid(mesh):
			continue
		var scale := mesh.global_basis.get_scale()
		# The nearest part sets the width, so stalks next to the eye don't go thick.
		var aabb := mesh.get_aabb()
		var centre := mesh.global_transform * aabb.get_center()
		var radius := aabb.size.length() * 0.5 * maxf(absf(scale.x), maxf(absf(scale.y), absf(scale.z)))
		var distance := maxf(camera.global_position.distance_to(centre) - radius, camera.near)
		var mean_scale := (absf(scale.x) + absf(scale.y) + absf(scale.z)) / 3.0
		if mean_scale < 0.0001:
			continue  # scaled to nothing (a bug between flashes): nothing to draw
		_materials[i].stencil_outline_thickness = pixels * metres_per_pixel_at_1m * distance / mean_scale
