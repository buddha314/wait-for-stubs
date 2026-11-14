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
## This machine's id in mines.json, for goal conditions.
const MACHINE_ID := "mudpit_burbler"

## The rack, as data. Survives closing and reopening the screen.
var rack_state: RackState
## The profile's `configure` block.
var configure: Dictionary
## True while the rack is fully patched (every suggested cable made).
var sounding := false
## The rack on the audio engine: the patch itself makes the sound.
var link: RackLink
## The mouth: where its stream starts (add-stream-building).
var _port: StreamPort
## The notes and bar lines it sends down its streams while it sounds.
var flow := StreamFlow.new()

var _bpm_range: Dictionary
var _hearing_radius := 30.0

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
	_add_link()
	_add_port()
	flow.beats_per_bar = int(ProjectSettings.get_setting("audio/master_clock/beats_per_bar", 4))
	RackServer.clock_ticked.connect(_on_clock_ticked)


## Tells the goal tracker whether this machine is configured (add-goals-hub D4). By
## path: naming the Goals autoload would stop `-s` tests that type this class compiling.
func _report_goal(holds: bool) -> void:
	var goals := get_node_or_null(^"/root/Goals")
	if goals:
		goals.report("machine_configured", {"machine": MACHINE_ID}, instance_id, holds)


func _exit_tree() -> void:
	_report_goal(false)
	if RackServer.clock_ticked.is_connected(_on_clock_ticked):
		RackServer.clock_ticked.disconnect(_on_clock_ticked)


## Each tick of its clock while it sounds is a note at the mouth.
func _on_clock_ticked(module_id: int, sample: int, index: int) -> void:
	if sounding and module_id == link.get_module_id("clock"):
		flow.add_tick(sample, index)


func _process(_delta: float) -> void:
	if not sounding:
		return
	var heard := RackLink.heard_sample()
	if heard >= 0.0:
		flow.advance(heard, RackServer.get_sample_rate() * 60.0 / bpm())
	_place_voice()


## The voice comes from the nearest point of the burbler or its flowing streams (D9).
func _place_voice() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or link == null:
		return
	var listener := camera.global_position
	var mouth := _port.global_position if _port else global_position
	var best := mouth
	for stream: Node in get_tree().get_nodes_in_group("laid_stream"):  # untyped: LaidStream needs autoloads
		if stream.source() == self:
			var p: Vector3 = stream.closest_point(listener)
			if p.distance_squared_to(listener) < best.distance_squared_to(listener):
				best = p
	link.emitter.global_position = best


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
		if not sounding:
			flow.clear()
		sounding_changed.emit(sounding)
		_report_goal(sounding)


## Phase within the clock's beat as heard (0..1) while the voice reaches the outlet,
## else −1: the master clock's heard position × the clock's multiple. The rack lamp
## follows it, so light and sound agree.
func beat_phase() -> float:
	if not outlet_carries_voice():
		return -1.0
	var beats := RackLink.heard_master_beats()
	return fposmod(beats * roundf(bpm() / master_bpm()), 1.0) if beats >= 0.0 else -1.0


## The engine rack, its voice at the outlet (`Outlet_0`).
func _add_link() -> void:
	link = RackLink.new()
	link.name = "RackLink"
	add_child(link)
	var outlet: Node3D = _model.find_child("Outlet_0", true, false)
	link.setup(rack_state, instance_id, (outlet if outlet else _model).global_position, _hearing_radius)


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


## The burbler's mouth as a stream port: at Outlet_0, 7 cm down (the stream bed's
## height), flowing along the outlet's +X; its halo is Outlet_0_Halo.
func _add_port() -> void:
	var outlet: Node3D = _model.find_child("Outlet_0", true, false)
	if outlet == null:
		push_error("MudpitBurbler: model has no Outlet_0")
		return
	_port = StreamPort.new()
	_port.name = "StreamPort"
	_port.owner_node = self
	add_child(_port)
	var x := outlet.global_basis.x
	var flow_dir := Vector3(x.x, 0.0, x.z).normalized()
	_port.global_transform = Transform3D(Basis(flow_dir, Vector3.UP, flow_dir.cross(Vector3.UP)),
			outlet.global_position - Vector3.UP * 0.07)
	_port.halo = _model.find_child("Outlet_0_Halo", true, false)
	_port.set_highlighted(false)


func stream_port() -> StreamPort:
	return _port
