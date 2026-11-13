class_name RackState
extends Resource
## One machine's rack as data: what is mounted in each place, each knob's value, and
## each cable. The rack screen edits it; the audio engine (add-rack-audio-engine 9.2)
## turns it into a RackPatch. It never talks to the engine itself. Every edit emits
## `changed` (Resource's own signal); completing the configuration's suggested patches
## emits `configured` once per completion.

signal configured

## place -> module id
@export var mounted: Dictionary[String, String] = {}
## "place/param" -> value
@export var knobs: Dictionary[String, float] = {}
## Each cable: {color, from: {place, port}, to: {place, port}, source}.
## `from` is always the output end. `source` is "comb:<n>" (a spare cable from the
## rack's comb, free) or "inventory" (one of the player's patch cables).
@export var cables: Array[Dictionary] = []
## The machine's `configure` block (places, cables), for the completion check.
var configure: Dictionary = {}

var _complete := false


## Fixed modules mounted, knobs at `defaults` ("place/param" -> value).
func setup(machine_configure: Dictionary, defaults: Dictionary) -> void:
	configure = machine_configure
	for place: Dictionary in configure.get("places", []):
		if place.get("fixed", false):
			mounted[place.place] = place.module
	for key: String in defaults:
		knobs[key] = defaults[key]
	_complete = is_complete()


func place_of(name: String) -> Dictionary:
	for place: Dictionary in configure.get("places", []):
		if place.place == name:
			return place
	return {}


func mount(place: String, module: String) -> void:
	mounted[place] = module
	_changed()


## Removes a non-fixed module and every cable on it. Returns the removed cables.
func unmount(place: String) -> Array[Dictionary]:
	var removed: Array[Dictionary] = []
	if place_of(place).get("fixed", false) or not mounted.has(place):
		return removed
	for index in range(cables.size() - 1, -1, -1):
		var cable := cables[index]
		if cable.from.place == place or cable.to.place == place:
			removed.append(cable)
			cables.remove_at(index)
	mounted.erase(place)
	_changed()
	return removed


func knob(key: String, fallback: float = 0.0) -> float:
	return knobs.get(key, fallback)


func set_knob(key: String, value: float) -> void:
	if knobs.get(key) != value:
		knobs[key] = value
		_changed()


## The cable plugged into this jack ({place, port}), or {} if none. For an output
## with several cables, the most recently patched one.
func cable_at(jack: Dictionary) -> Dictionary:
	for index in range(cables.size() - 1, -1, -1):
		var cable := cables[index]
		if _same(cable.from, jack) or _same(cable.to, jack):
			return cable
	return {}


func is_patched(jack: Dictionary) -> bool:
	return not cable_at(jack).is_empty()


## True when some cable joins these two jacks, whichever its colour.
func joins(a: Dictionary, b: Dictionary) -> bool:
	for cable in cables:
		if (_same(cable.from, a) and _same(cable.to, b)) \
				or (_same(cable.from, b) and _same(cable.to, a)):
			return true
	return false


func comb_in_use(n: int) -> bool:
	for cable in cables:
		if cable.source == "comb:%d" % n:
			return true
	return false


func add_cable(cable: Dictionary) -> void:
	cables.append(cable)
	_changed()


func remove_cable(cable: Dictionary) -> void:
	var index := cables.find(cable)
	if index >= 0:
		cables.remove_at(index)
		_changed()


## Every place filled and every suggested patch made, by any cables.
func is_complete() -> bool:
	if configure.is_empty():
		return false
	for place: Dictionary in configure.get("places", []):
		if not mounted.has(place.place):
			return false
	for suggested: Dictionary in configure.get("cables", []):
		if not joins(suggested.from, suggested.to):
			return false
	return true


func _changed() -> void:
	emit_changed()
	var complete := is_complete()
	if complete and not _complete:
		_complete = true
		configured.emit()
	elif not complete:
		_complete = false


static func _same(a: Dictionary, b: Dictionary) -> bool:
	return a.get("place") == b.get("place") and a.get("port") == b.get("port")
