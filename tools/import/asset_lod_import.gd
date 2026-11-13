@tool
extends EditorScenePostImport
## Import script for every stubby-music model (the project's default scene import
## script, and set on existing models' .import files). Godot's recommended split:
## automatic mesh LOD thins meshes by itself, and artist-made LOD levels use
## visibility ranges (docs: tutorials/3d/visibility_ranges). stubby-music's models
## carry their levels as `<id>_LOD0`/`<id>_LOD1` nodes; their switch distance is
## `far_lod.distance_m` in the asset profile that lists the model. This sets the
## ranges once, at import, so any instance of the model (a scene, or the raw .glb
## dropped into a level) swaps detail by itself. Models without LOD nodes are left
## unchanged. It also restores parts the generators pose hidden (`start_scale`).
## Re-run with `godot --headless --path . --import` after changing it.

const ASSETS := "res://assets/"


func _post_import(scene: Node) -> Object:
	_apply_start_scales(scene)
	if scene.find_child("*_LOD1", true, false) == null:
		return scene
	var source := get_source_file()
	var far := _far_lod_for(source)
	if far <= 0.0:
		push_warning("asset_lod_import: %s has LOD nodes but no profile far_lod; left unchanged" % source)
		return scene
	AssetLod.apply(scene, far)
	scene.set_meta("far_lod_m", far)
	return scene


## Parts the generators pose hidden (scale 0) are exported at scale 1 so their
## children keep real transforms, and tagged with the glTF extra `start_scale`
## (tools/blender/export_gltf.py). Put them back, so the model ships posed as authored.
static func _apply_start_scales(node: Node) -> void:
	if node is Node3D and node.has_meta("extras"):
		var extras: Variant = node.get_meta("extras")
		if extras is Dictionary and extras.has("start_scale"):
			(node as Node3D).scale = Vector3.ONE * float(extras.start_scale)
	for child in node.get_children():
		_apply_start_scales(child)


## far_lod.distance_m from the asset.json whose `model` or `variants` lists `source`.
static func _far_lod_for(source: String) -> float:
	for profile_path in _profiles(ASSETS):
		var profile := AssetProfile.load_json(profile_path)
		var far: float = profile.get("far_lod", {}).get("distance_m", 0.0)
		if far <= 0.0:
			continue
		var models: Array = profile.get("variants", [])
		if profile.has("model"):
			models.append(profile.model)
		for model: String in models:
			if ASSETS + model == source:
				return far
	return 0.0


static func _profiles(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for file in dir.get_files():
		if file == "asset.json":
			out.append(dir_path.path_join(file))
	for sub in dir.get_directories():
		if sub != "models":
			out.append_array(_profiles(dir_path.path_join(sub)))
	return out
