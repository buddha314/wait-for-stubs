class_name MudpitBurbler
extends StaticBody3D
## A clock mine: the first machine. E at its Interact point opens its rack.
## Its tempo is a whole multiple of the master clock, seeded per instance from a
## window around 60 BPM (tempo.json); the rack's BPM knob changes it.

## Emitted when the burbler starts or stops sounding (its rack fully patched).
signal sounding_changed(sounding: bool)

const PROFILE_PATH := "res://assets/machines/mudpit_burbler/asset.json"
const TEMPO_PATH := "res://assets/machines/mudpit_burbler/tempo.json"
const VCO_FREQ_PATH := "res://assets/creatures/lightning_bug/asset.json"
## The rack place and knob that hold the tempo.
const BPM_KNOB := "clock/bpm"

## Unique per burbler; seeds its tempo. Changing it changes the burbler.
@export var instance_id := "mudpit_burbler"

## The rack, as data. Survives closing and reopening the screen.
var rack_state: RackState
## The profile's `configure` block.
var configure: Dictionary
## True while the rack is fully patched (the engine plays it once it exists).
var sounding := false

var _bpm_range: Dictionary
var _hearing_radius := 30.0
## STAND-IN voice until stubby-rack plays (BurblerVoice).
var _voice: BurblerVoice

@onready var _model: Node3D = $Model


func _ready() -> void:
	var profile := AssetProfile.load_json(PROFILE_PATH)
	configure = profile.get("configure", {})
	_bpm_range = profile.get("params", {}).get("bpm", {"min": 40.0, "max": 180.0})
	_hearing_radius = profile.get("hearing_radius_metres", 30.0)
	rack_state = RackState.new()
	rack_state.setup(configure, {
		BPM_KNOB: seeded_bpm(),
		"volume/gain": 0.25,
		"vco/freq": AssetProfile.load_json(VCO_FREQ_PATH).get("click", {}).get("freq_hz", 2200.0),
	})
	rack_state.changed.connect(_on_rack_changed)
	_add_interact_point()
	_add_voice()


## The starting tempo: master BPM × a seeded whole multiple from tempo.json.
func seeded_bpm() -> float:
	var window: Dictionary = AssetProfile.load_json(TEMPO_PATH).get("seed_multiple", {})
	var multiple := WorldSeed.rng(instance_id).randi_range(
			int(window.get("min", 60)), int(window.get("max", 60)))
	return multiple * master_bpm()


static func master_bpm() -> float:
	return ProjectSettings.get_setting("audio/master_clock/tempo_bpm", 1.0)


func bpm() -> float:
	return rack_state.knob(BPM_KNOB, 60.0)


## Machine overrides of module knob ranges ("place/param" -> {min, max, step}).
## The BPM knob steps in whole multiples of the master within params.bpm.
func knob_overrides() -> Dictionary:
	return {BPM_KNOB: {"min": _bpm_range.min, "max": _bpm_range.max, "step": master_bpm()}}


## The rack window's header line.
func rack_header() -> String:
	return "%d BPM  ·  configure" % roundi(bpm())


## True when the voice reaches the outlet (`Outlet_0`): the burbler sounds and
## nothing is plugged into the normalled output (configure.normalled_output).
func outlet_carries_voice() -> bool:
	var normalled: Dictionary = configure.get("normalled_output", {})
	return sounding and not rack_state.is_patched(normalled)


func _on_rack_changed() -> void:
	var now := rack_state.is_complete()
	if now != sounding:
		sounding = now
		sounding_changed.emit(sounding)


## Phase within the beat as heard (0..1) while the voice plays, else −1. The rack
## lamp's placeholder flash follows it, so light and sound agree.
func beat_phase() -> float:
	return _voice.heard_phase() if _voice else -1.0


## STAND-IN: a pre-rendered looping voice at the outlet (BurblerVoice).
func _add_voice() -> void:
	_voice = BurblerVoice.new()
	var outlet: Node3D = _model.find_child("Outlet_0", true, false)
	(outlet if outlet else _model).add_child(_voice)
	_voice.setup(self, _hearing_radius)


func _add_interact_point() -> void:
	var node_name: String = configure.get("interact", {}).get("node", "Interact")
	var point := MachineInteract.new()
	point.name = "MachineInteract"
	point.configure = configure
	point.machine = self
	var anchor: Node3D = _model.find_child(node_name, true, false)
	if anchor == null:
		push_error("MudpitBurbler: model has no %s node" % node_name)
		anchor = _model
	anchor.add_child(point)
