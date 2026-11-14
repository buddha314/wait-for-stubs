class_name LightningBug
extends Node3D
## A square-wave resource node. Invisible and silent between pulses. Its own seeded
## random clock runs on the audio engine (a bug's clock is the one kind that stays
## off the master grid): each tick clicks (square VCO → AD envelope → VCA, audible
## only within range) and, at the instant that click is heard, the bug flashes white
## at a fresh hover height, turned broadside to the camera. Collected, the clock keeps
## time but the bug stays dark and silent.

const PROFILE_PATH := "res://assets/creatures/lightning_bug/asset.json"
## Peak OmniLight3D energy at the top of a flash.
const PEAK_LIGHT_ENERGY := 2.5
## The VCA's output is ±5 V of a ±10 V stem: the click's gain is relative to that.
const STEM_PEAK := 0.5

## Stable identity. Seeds this bug's clock and hover heights.
@export var instance_id: String = "lightning_bug-0"

## The bug's rack: clock → envelope → VCA ← square VCO, heard from the body.
var rack: Rack
var _rng: RandomNumberGenerator
var _attack: float
var _flash: float
var _hover: Vector2
var _flash_elapsed := -1.0
## Wall-clock (Time.get_ticks_usec) instants at which a tick's click is heard.
var _pending: Array[int] = []
var _clock_id := 0
var _voice: RackEmitter
## The envelope level last shown.
var _level := 0.0
## The dark body shown between flashes while targeted (palette: Silhouette #100b19).
## Per bug, not static: a static Resource outlives the renderer at exit (4.8 beta).
var _silhouette_material: StandardMaterial3D = _silhouette()
## Flashes shown so far (for tests).
var flashes := 0

@onready var _body: Node3D = $Body
@onready var _model: Node3D = $Body/Model
@onready var _light: OmniLight3D = $Body/Flash
@onready var _pickup: ResourceNode = $Pickup


func _ready() -> void:
	var profile := AssetProfile.load_json(PROFILE_PATH)
	var clock: Dictionary = profile.get("clock", {})
	var click: Dictionary = profile.get("click", {})
	_attack = profile.get("attack_seconds", 0.015)
	_flash = profile.get("flash_seconds", 0.3)
	_hover = AssetProfile.range_of(profile, "hover_metres", Vector2(1.3, 1.7))
	_light.omni_range = profile.get("light_range_metres", 3.0)

	_pickup.instance_id = instance_id
	_pickup.outline_root = _model
	_pickup.collected_changed.connect(_on_collected_changed)
	_pickup.outline_changed.connect(func(_shown: bool) -> void: _set_envelope(_level))
	_rng = WorldSeed.rng(instance_id)
	_set_envelope(0.0)
	_build_rack(clock, click)


func _build_rack(clock: Dictionary, click: Dictionary) -> void:
	var rate: float = RackServer.get_sample_rate()
	rack = Rack.new()
	rack.name = "Voice"
	_voice = RackEmitter.new()
	_voice.module = "vca"
	_voice.max_distance = click.get("hearing_radius_metres", 3.0)
	_voice.unit_size = 1.0
	_voice.bus = AudioBuses.WORLD
	_voice.volume_db = linear_to_db(float(click.get("gain", 0.12)) / STEM_PEAK)
	rack.add_child(_voice)
	_body.add_child(rack)
	rack.add_module("clock", "random_clock", {
		"min_seconds": clock.get("min_interval_seconds", 0.65),
		"max_seconds": clock.get("max_interval_seconds", 2.4)}, _rng.randi())
	rack.add_module("env", "envelope", {
		"attack": 1.0 / (float(click.get("attack_seconds", 0.015)) * rate),
		"decay": 1.0 / (float(click.get("decay_seconds", 0.285)) * rate)})
	rack.add_module("osc", "vco_square", {"freq": click.get("freq_hz", 2200.0)})
	rack.add_module("vca", "vca")
	rack.connect_cable("clock", "trigger", "env", "gate")
	rack.connect_cable("env", "out", "vca", "cv")
	rack.connect_cable("osc", "out", "vca", "in")
	_clock_id = rack.get_module_id("clock")
	RackServer.clock_ticked.connect(_on_clock_ticked)


func _exit_tree() -> void:
	if RackServer.clock_ticked.is_connected(_on_clock_ticked):
		RackServer.clock_ticked.disconnect(_on_clock_ticked)


func _on_clock_ticked(module_id: int, sample: int, _index: int) -> void:
	if module_id != _clock_id or _pickup.collected:
		return
	var at: int = RackServer.sample_to_ticks_usec(sample)
	_pending.append(at if at >= 0 else Time.get_ticks_usec())


func _process(delta: float) -> void:
	# Flash when the click is heard (the sync point), not when the tick was rendered.
	if not _pending.is_empty() and Time.get_ticks_usec() >= _pending[0]:
		_pending.pop_front()
		_start_flash()
	if _flash_elapsed >= 0.0:
		_flash_elapsed += delta
		if _flash_elapsed >= _flash:
			_flash_elapsed = -1.0
			_set_envelope(0.0)
		else:
			_set_envelope(_envelope(_flash_elapsed))


func _start_flash() -> void:
	flashes += 1
	_flash_elapsed = 0.0
	_body.position.y = _rng.randf_range(_hover.x, _hover.y)
	_face_broadside()


func _on_collected_changed(collected: bool) -> void:
	# The clock keeps time while collected; the bug just stays dark and silent.
	_voice.stream_paused = collected
	if collected:
		_pending.clear()
		_flash_elapsed = -1.0
		_set_envelope(0.0)


## Flashes waiting to be seen (for tests).
func pending_flashes() -> int:
	return _pending.size()


## Linear attack to 1, then linear decay to 0 by the end of the flash.
func _envelope(t: float) -> float:
	if t < _attack:
		return t / _attack
	return clampf(1.0 - (t - _attack) / (_flash - _attack), 0.0, 1.0)


static func _silhouette() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#100b19")
	m.roughness = 1.0
	return m


## Targeted (add-collectible-outline): the body stays at full size so the outline
## has a shape, a dark silhouette between flashes and white while flashing.
func _set_envelope(level: float) -> void:
	_level = level
	var outlined := _pickup.outline_shown
	_body.visible = level > 0.0 or outlined
	_model.scale = Vector3.ONE * (1.0 if outlined else level)
	var dark := outlined and level <= 0.0
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = _silhouette_material if dark else null
	_light.light_energy = PEAK_LIGHT_ENERGY * level


## The body's long axis is local Z; end-on it vanishes. Point local +X at the
## camera so the player always sees it side-on.
func _face_broadside() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var to_camera := camera.global_position - _body.global_position
	if Vector2(to_camera.x, to_camera.z).length_squared() < 0.0001:
		return
	_body.global_rotation = Vector3(0.0, atan2(-to_camera.z, to_camera.x), 0.0)
