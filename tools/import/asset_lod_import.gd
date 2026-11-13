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
## unchanged. Re-run with `godot --headless --path . --import` after changing it.

const ASSETS := "res://assets/"


func _post_import(scene: Node) -> Object:
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
			if ASSETS + model.trim_suffix("#Scene0") == source:
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
