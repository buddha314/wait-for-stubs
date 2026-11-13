class_name AssetProfile
extends RefCounted
## Loads the per-asset JSON profiles shipped in `assets/` (copied from
## stubby-music). Results are cached per path.

static var _cache: Dictionary[String, Dictionary] = {}


static func load_json(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is not Dictionary:
		push_error("AssetProfile: could not parse %s" % path)
		return {}
	_cache[path] = parsed
	return parsed


## A [min, max] pair from a profile as a Vector2, or `fallback` if missing.
static func range_of(profile: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var pair: Variant = profile.get(key)
	if pair is Array and pair.size() == 2:
		return Vector2(pair[0], pair[1])
	return fallback
