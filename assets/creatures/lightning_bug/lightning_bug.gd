class_name LightningBug
extends Node3D
## A square-wave resource node. Invisible and silent between pulses; on each
## tick of its own seeded random clock it flashes white at a fresh hover height,
## turned broadside to the camera, and clicks (audible only within range).
##
## TODO(audio clock): stubby-music drives the flash from sample-timestamped
## audio-thread ticks. This uses frame time until the audio engine is ported.

const PROFILE_PATH := "res://assets/creatures/lightning_bug/asset.json"
const MIX_RATE := 44100
## Peak OmniLight3D energy at the top of a flash.
const PEAK_LIGHT_ENERGY := 2.5

## Stable identity. Seeds this bug's clock and hover heights.
@export var instance_id: String = "lightning_bug-0"

var _rng: RandomNumberGenerator
var _min_interval: float
var _max_interval: float
var _attack: float
var _flash: float
var _hover: Vector2
var _until_next: float
var _flash_elapsed := -1.0

@onready var _body: Node3D = $Body
@onready var _model: Node3D = $Body/Model
@onready var _light: OmniLight3D = $Body/Flash
@onready var _click: AudioStreamPlayer3D = $Body/Click
@onready var _pickup: ResourceNode = $Pickup


func _ready() -> void:
	var profile := AssetProfile.load_json(PROFILE_PATH)
	var clock: Dictionary = profile.get("clock", {})
	var click: Dictionary = profile.get("click", {})
	_min_interval = clock.get("min_interval_seconds", 0.65)
	_max_interval = clock.get("max_interval_seconds", 2.4)
	_attack = profile.get("attack_seconds", 0.015)
	_flash = profile.get("flash_seconds", 0.3)
	_hover = AssetProfile.range_of(profile, "hover_metres", Vector2(1.3, 1.7))
	var radius: float = click.get("hearing_radius_metres", 3.0)
	_light.omni_range = profile.get("light_range_metres", 3.0)
	_click.max_distance = radius
	_click.stream = _make_click(click)

	_pickup.instance_id = instance_id
	_pickup.collected_changed.connect(_on_collected_changed)
	_rng = WorldSeed.rng(instance_id)
	_set_envelope(0.0)
	_until_next = _rng.randf_range(_min_interval, _max_interval)


func _process(delta: float) -> void:
	_until_next -= delta
	if _until_next <= 0.0:
		_until_next += _rng.randf_range(_min_interval, _max_interval)
		# The clock keeps time while collected; the bug just stays dark.
		if not _pickup.collected:
			_start_flash()
	if _flash_elapsed >= 0.0:
		_flash_elapsed += delta
		if _flash_elapsed >= _flash:
			_flash_elapsed = -1.0
			_set_envelope(0.0)
		else:
			_set_envelope(_envelope(_flash_elapsed))


func _start_flash() -> void:
	_flash_elapsed = 0.0
	_body.position.y = _rng.randf_range(_hover.x, _hover.y)
	_face_broadside()
	_click.play()


func _on_collected_changed(collected: bool) -> void:
	if collected:
		_flash_elapsed = -1.0
		_set_envelope(0.0)
		_click.stop()


## Linear attack to 1, then linear decay to 0 by the end of the flash.
func _envelope(t: float) -> float:
	if t < _attack:
		return t / _attack
	return clampf(1.0 - (t - _attack) / (_flash - _attack), 0.0, 1.0)


func _set_envelope(level: float) -> void:
	_body.visible = level > 0.0
	_model.scale = Vector3.ONE * level
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


## Square VCO -> envelope -> VCA, rendered once into a 16-bit mono sample.
func _make_click(click: Dictionary) -> AudioStreamWAV:
	var freq: float = click.get("freq_hz", 2200.0)
	var attack: float = click.get("attack_seconds", 0.015)
	var decay: float = click.get("decay_seconds", 0.285)
	var gain: float = click.get("gain", 0.12)
	var frames := int((attack + decay) * MIX_RATE)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var t := float(i) / MIX_RATE
		var level := t / attack if t < attack else 1.0 - (t - attack) / decay
		var square := 1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0
		data.encode_s16(i * 2, int(square * level * gain * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
