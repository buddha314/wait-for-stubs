class_name AssetLod
extends RefCounted
## Authored levels of detail, as Godot recommends for artist-made LOD meshes:
## visibility ranges ("HLOD", docs: tutorials/3d/visibility_ranges). stubby-music's
## models carry their levels as `<id>_LOD0` (near) and `<id>_LOD1` (far) nodes inside
## one glTF. Every mesh under LOD0 ends at `far` metres and every mesh under LOD1
## begins there, with a margin for hysteresis. FADE_SELF crossfades the two; the
## docs note it renders transparent only during the fade. Godot's automatic mesh
## LOD (import default) still thins the near meshes on top of this. Called at import
## by tools/import/asset_lod_import.gd, so scenes don't need to call it.

const MARGIN := 2.0


static func apply(model: Node, far: float) -> void:
	_set_range(model.find_child("*_LOD0", true, false), 0.0, far)
	_set_range(model.find_child("*_LOD1", true, false), far, 0.0)


static func _set_range(root: Node, begin: float, end: float) -> void:
	if root == null:
		return
	for mesh: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
		mesh.visibility_range_begin = begin
		mesh.visibility_range_begin_margin = MARGIN if begin > 0.0 else 0.0
		mesh.visibility_range_end = end
		mesh.visibility_range_end_margin = MARGIN if end > 0.0 else 0.0
		mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
