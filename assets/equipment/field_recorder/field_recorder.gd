class_name FieldRecorder
extends Node3D
## The handheld stereo field recorder (add-field-recorder). It shows two things:
## - the record light (`Light_rec`) answers collection: `capture()` starts an
##   attack/decay envelope from the profile's rest strength to its peak and back
##   (design D4). It never blinks at a rate of its own.
## - the level meter (`Screen/Level_0`–`Level_7`) shows the world and music audio
##   reaching the listener: the peak of the World bus, held and falling at 24 dB/s
##   (design D5). It is a display only; it never times or makes a sound.
## The windguard's fur shells cast no shadows (profile `windguard.shells_cast_shadows`).
## The meter shows the total level without direction until the engine reports
## per-emitter levels (add-rack-audio-engine 8.2; task 4.4 weights them by `Capture`).

const PROFILE_PATH := "res://assets/equipment/field_recorder/asset.json"
const ATTACK_SECONDS := 0.05
const DECAY_SECONDS := 0.4
## The meter's span: bar n (0–7) lights at or above −48 + 6·n dBFS (design D5), so
## −45 dBFS (a bug's click 2 m away) lights one bar and −6 dBFS lights all eight.
const METER_FLOOR_DB := -48.0
const METER_STEP_DB := 6.0
const METER_FALL_DB_PER_SECOND := 24.0
const SILENCE_DB := -200.0
## The LED's body at rest, as a fraction of its authored colour (dark but visible).
const LED_REST_ALBEDO := 0.3
const FUR_SHELL_PREFIX := "FieldRecorder_FurShell"

## The bus the meter reads (world and music stems; the UI stem is elsewhere).
@export var meter_bus: StringName = AudioBuses.WORLD

## Record-light strength now (emission energy), between rest and peak.
var light_strength := 0.0
## The meter's held level, dBFS.
var level_db := SILENCE_DB

var _rest := 0.0
var _peak := 8.0
## 1 while the light is rising, else falling. `_k` is 0 at rest, 1 at peak.
var _rising := false
var _k := 0.0
var _core: StandardMaterial3D
var _core_albedo: Color
var _halos: Array[MeshInstance3D] = []
var _halo_materials: Array[StandardMaterial3D] = []
var _halo_alphas: Array[float] = []
var _bars: Array[MeshInstance3D] = []
var _bar_lit: Material
var _bar_dim: Material

@onready var _model: Node3D = $Model


func _ready() -> void:
	var profile := AssetProfile.load_json(PROFILE_PATH)
	var root := _model.get_node("FieldRecorder_Root")
	if not profile.get("windguard", {}).get("shells_cast_shadows", false):
		_fur_casts_no_shadow(root.get_node("Windguard"))
	_setup_light(root.get_node("Light_rec"), profile)
	_setup_meter(root.get_node("Screen"))
	_apply_light()
	_apply_meter()


## E collected a pickup: the light rises to peak, then decays to rest.
func capture() -> void:
	_rising = true


## Lit bars, lowest first (for tests).
func lit_bars() -> int:
	var lit := 0
	for bar in _bars:
		if bar.material_override == _bar_lit:
			lit += 1
	return lit


## How many bars a level lights (0–8).
static func bars_for(db: float) -> int:
	if db < METER_FLOOR_DB:
		return 0
	return mini(int(floor((db - METER_FLOOR_DB) / METER_STEP_DB)) + 1, 8)


func _process(delta: float) -> void:
	if _rising:
		_k = minf(1.0, _k + delta / ATTACK_SECONDS)
		_rising = _k < 1.0
	else:
		_k = maxf(0.0, _k - delta / DECAY_SECONDS)
	_apply_light()

	var bus := AudioServer.get_bus_index(meter_bus)
	var now := SILENCE_DB
	if bus >= 0:
		now = maxf(AudioServer.get_bus_peak_volume_left_db(bus, 0),
				AudioServer.get_bus_peak_volume_right_db(bus, 0))
	level_db = maxf(now, maxf(SILENCE_DB, level_db - METER_FALL_DB_PER_SECOND * delta))
	_apply_meter()


func _fur_casts_no_shadow(node: Node) -> void:
	for child in node.get_children():
		if child is GeometryInstance3D and (child.name.begins_with(FUR_SHELL_PREFIX)
				or String(node.name).begins_with(FUR_SHELL_PREFIX)):
			(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_fur_casts_no_shadow(child)


func _setup_light(light: Node3D, profile: Dictionary) -> void:
	var extras: Dictionary = light.get_meta("extras", {})
	for row: Dictionary in profile.get("lights", []):
		if row.get("node") == light.name:
			extras.merge(row)
	_rest = float(extras.get("rest_strength", 0.0))
	_peak = float(extras.get("peak_strength", 8.0))
	for child in light.get_children():
		var mesh := child as MeshInstance3D
		if mesh == null:
			continue
		# Per-instance copies: the imported materials are shared.
		var material := (mesh.get_active_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		mesh.material_override = material
		if material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
			_core = material
			_core_albedo = material.albedo_color
		else:
			_halos.append(mesh)
			_halo_materials.append(material)
			_halo_alphas.append(material.albedo_color.a)


func _apply_light() -> void:
	light_strength = lerpf(_rest, _peak, _k)
	if _core:
		_core.emission_energy_multiplier = light_strength
		var body := lerpf(LED_REST_ALBEDO, 1.0, _k)
		_core.albedo_color = Color(_core_albedo.r * body, _core_albedo.g * body,
				_core_albedo.b * body, _core_albedo.a)
	for i in _halos.size():
		_halos[i].visible = _k > 0.0
		_halo_materials[i].albedo_color.a = _halo_alphas[i] * _k


func _setup_meter(screen: Node3D) -> void:
	var count := int(screen.get_meta("extras", {}).get("levels", 8))
	for n in count:
		_bars.append(screen.get_node("Level_%d" % n) as MeshInstance3D)
	# The model is authored mid-scale: low bars lit (Display), high bars dim.
	_bar_lit = _bars[0].get_active_material(0)
	_bar_dim = _bars[_bars.size() - 1].get_active_material(0)


func _apply_meter() -> void:
	var lit := bars_for(level_db)
	for n in _bars.size():
		var material := _bar_lit if n < lit else _bar_dim
		if _bars[n].material_override != material:
			_bars[n].material_override = material
