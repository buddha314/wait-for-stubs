class_name GrowthLevels
extends RefCounted
## A growing asset's bloom levels (its `growth.json`, beside its asset.json): each level
## is a growth value reached by water of at least some clarity. Mud (clarity 0) reaches
## only the lowest level; cleaner water reaches higher ones. While watered, growth rises
## toward the cap the water allows; without water it eases back toward dormant.

var levels: Array[Dictionary] = []
var water_reach := 3.0
var rise_per_second := 0.005
var ease_per_second := 0.001


static func load_for(path: String) -> GrowthLevels:
	var data := AssetProfile.load_json(path)
	var g := GrowthLevels.new()
	for level: Dictionary in data.get("levels", []):
		g.levels.append(level)
	g.levels.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.growth < b.growth)
	g.water_reach = float(data.get("water_reach_m", 3.0))
	g.rise_per_second = float(data.get("rise_per_minute", 0.3)) / 60.0
	g.ease_per_second = float(data.get("ease_per_minute", 0.05)) / 60.0
	return g


## The highest growth water of `clarity` can reach (0 when there's no water: < 0).
func cap(clarity: float) -> float:
	var best := 0.0
	if clarity < 0.0:
		return best
	for level in levels:
		if clarity + 1e-6 >= float(level.min_clarity):
			best = maxf(best, float(level.growth))
	return best


## The name of the highest level `growth` has reached ("dormant" below the first).
func level_name(growth: float) -> String:
	var name := "dormant"
	for level in levels:
		if growth + 1e-6 >= float(level.growth):
			name = level.name
	return name


## One step of growth toward what the water allows (`clarity` < 0: no water).
func step(growth: float, clarity: float, seconds: float) -> float:
	var target := cap(clarity)
	if growth < target:
		return minf(target, growth + rise_per_second * seconds)
	if growth > target:
		return maxf(target, growth - ease_per_second * seconds)
	return growth


## The clearest water a flowing stream brings within `reach` metres (horizontally) of
## `at`, or -1 if none. Streams are found by group, untyped (LaidStream needs autoloads).
static func water_at(tree: SceneTree, at: Vector3, reach: float) -> float:
	var best := -1.0
	for stream: Node in tree.get_nodes_in_group("laid_stream"):
		if not stream.flowing():
			continue
		var p: Vector3 = stream.closest_point(at)
		if Vector2(p.x - at.x, p.z - at.z).length() <= reach:
			best = maxf(best, float(stream.clarity()))
	return best
