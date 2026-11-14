extends SceneTree
## Asset contract for the rack screen: every node a rack profile names must exist
## in its glb. Ports stubby-music's crates/stubby_game/tests/module_assets.rs.
## Run after every asset rsync from stubby-music:
##   godot --headless --path . -s tests/test_rack_assets.gd

const MODULES := ["burbler_clock", "volume", "square_vco", "sine_vco", "saw_vco",
		"triangle_vco", "clock_lamp", "snail_sequencer"]
## Modules shown on a HUD rack: their jacks need a halo for patch guidance.
const HUD_MODULES := ["burbler_clock", "volume", "square_vco", "snail_sequencer"]
const SLOT_KINDS := ["clock", "vco", "vcf", "vca", "seq"]
const SLOT_HPS := [4, 6, 8, 10, 12, 14, 16]

var _failures: PackedStringArray = []


func _initialize() -> void:
	for id: String in MODULES:
		_check_module(id)
	_check_rack_frame()
	_check("hud/slot_labels", SLOT_KINDS.map(func(k: String) -> String: return "Label_" + k))
	for hp: int in SLOT_HPS:
		_check("hud/slot_outline_%dhp" % hp, [])
	var plug := AssetProfile.load_json("res://assets/cables/patch_plug/asset.json")
	_check("cables/patch_plug", [plug.attach_node])
	var burbler := AssetProfile.load_json("res://assets/machines/mudpit_burbler/asset.json")
	_check("machines/mudpit_burbler", [burbler.configure.interact.node])
	for place: Dictionary in burbler.configure.places:
		var modules: Array = [place.module] if place.has("module") else \
				place.get("accepts", []).map(func(a: Dictionary) -> String: return a.module)
		for module: String in modules:
			if module not in MODULES:
				_failures.append("burbler place %s names unknown module %s" % [place.place, module])
	if _failures.is_empty():
		print("test_rack_assets: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: ", failure)
		quit(1)


func _check_module(id: String) -> void:
	var profile := AssetProfile.load_json("res://assets/modules/%s/asset.json" % id)
	var nodes: Array[String] = []
	for key: String in ["ports", "params", "lights", "buttons"]:
		for entry: Dictionary in profile.get(key, []):
			nodes.append(entry.node)
	if id in HUD_MODULES:
		for port: Dictionary in profile.get("ports", []):
			nodes.append("Jack_%s_Halo" % port.port)
	if profile.has("lamp"):
		nodes.append(profile.lamp.node)
	var display: Dictionary = profile.get("display", {})
	if not display.is_empty():
		nodes.append(display.node)
		for digit in int(display.digits):
			for segment: String in display.segments:
				nodes.append(display.segment_node.format({"digit": digit, "segment": segment}))
	_check("modules/" + id, nodes)


func _check_rack_frame() -> void:
	var frame := AssetProfile.load_json("res://assets/hud/rack_frame/asset.json")
	var nodes: Array = frame.rails.nodes + frame.posts.nodes
	var comb: Dictionary = frame.cable_comb
	nodes.append(comb.node)
	for n in int(comb.slots):
		nodes.append(comb.slot_node.format({"n": n}))
		for rest: String in comb.plug_rest:
			nodes.append(rest.format({"n": n}))
	_check("hud/rack_frame", nodes)


func _check(model: String, nodes: Array) -> void:
	# "modules/volume" → res://assets/modules/volume/volume.glb (one folder per asset).
	var path := "res://assets/%s/%s.glb" % [model, model.get_file()]
	var scene := load(path) as PackedScene
	if scene == null:
		_failures.append("%s does not load" % path)
		return
	var root := scene.instantiate()
	for node_name: String in nodes:
		if root.find_child(node_name, true, false) == null:
			_failures.append("%s has no node %s" % [path, node_name])
	root.free()
