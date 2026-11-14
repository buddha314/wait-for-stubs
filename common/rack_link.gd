class_name RackLink
extends Rack
## Plays a machine's RackState on the audio engine (add-rack-audio-engine 9.2). The
## rack screen edits the RackState; this mirrors every change into stubby-rack's Rack:
## mounted modules become engine modules (kind from the module's `engine.json`),
## cables become engine cables, knobs become parameters. The patch is real: the
## machine sounds only when its cables make a signal path, as on hardware.
##
## The voice leaves through a RackEmitter on the machine's normalled output
## (configure.normalled_output), muted while a cable is plugged into that jack.

const ENGINE_PATH := "res://assets/modules/%s/engine.json"

var state: RackState
var emitter: RackEmitter

var _seed_id := ""
var _kinds: Dictionary[String, String] = {}  # place -> module id it was built for
var _cables: Dictionary[String, Dictionary] = {}  # "to.place/to.port" -> cable
var _sent: Dictionary[String, float] = {}  # "place/param" -> value sent
## Step sequencers: place -> [[heard usec, step], ...] still to be heard, and the step
## heard last (add-snail-shell-sequencer D4).
var _steps_pending: Dictionary[String, Array] = {}
var _step_heard: Dictionary[String, int] = {}


## Links `rack_state`; the voice plays from `at` (global position). `seed_id` seeds
## random modules per place. Call after adding this node to the tree.
func setup(rack_state: RackState, seed_id: String, at: Vector3, hearing_radius: float) -> void:
	state = rack_state
	_seed_id = seed_id
	var normalled: Dictionary = state.configure.get("normalled_output", {})
	emitter = RackEmitter.new()
	emitter.name = "Voice"
	emitter.module = normalled.get("place", "")
	emitter.output = normalled.get("port", "out")
	emitter.max_distance = hearing_radius
	emitter.unit_size = 6.0
	emitter.bus = AudioBuses.WORLD
	emitter.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	# The engine's audio is ±5 V and a stem's full scale is ±10 V: +6 dB keeps a full
	# GAIN at full scale, as the pre-rendered voice was.
	emitter.volume_db = 6.02
	add_child(emitter)
	emitter.global_position = at
	state.changed.connect(sync)
	RackServer.clock_ticked.connect(_on_clock_ticked)
	sync()


func _exit_tree() -> void:
	if RackServer.clock_ticked.is_connected(_on_clock_ticked):
		RackServer.clock_ticked.disconnect(_on_clock_ticked)


## A step sequencer's advance is a tick whose index is the step: keep it until heard.
func _on_clock_ticked(module_id: int, sample: int, index: int) -> void:
	for place: String in _kinds:
		if AssetProfile.load_json(ENGINE_PATH % _kinds[place]).get("kind", "") != "step_sequencer":
			continue
		if get_module_id(place) == module_id:
			var at: int = RackServer.sample_to_ticks_usec(sample)
			_steps_pending.get_or_add(place, []).append([at if at >= 0 else Time.get_ticks_usec(), index])
			return


## The step (0-based) of the sequencer at `place` being heard now, or -1 before its
## first step is heard.
func current_step(place: String) -> int:
	var pending: Array = _steps_pending.get(place, [])
	var now := Time.get_ticks_usec()
	while not pending.is_empty() and int(pending[0][0]) <= now:
		_step_heard[place] = int(pending.pop_front()[1])
	return _step_heard.get(place, -1)


## Brings the engine in line with the RackState.
func sync() -> void:
	# Modules: remove what's gone or changed, then add what's new.
	for place: String in _kinds.keys():
		if state.mounted.get(place, "") != _kinds[place]:
			_steps_pending.erase(place)
			_step_heard.erase(place)
			_drop_cables_on(place)
			remove_module(place)
			_kinds.erase(place)
			for key: String in _sent.keys():
				if key.begins_with(place + "/"):
					_sent.erase(key)
	for place: String in state.mounted:
		if _kinds.has(place):
			continue
		var module: String = state.mounted[place]
		var engine := AssetProfile.load_json(ENGINE_PATH % module)
		if engine.is_empty() or not add_module(place, engine.kind, {}, WorldSeed.rng("%s/%s" % [_seed_id, place]).randi()):
			push_error("RackLink: no engine kind for module %s" % module)
			continue
		_kinds[place] = module
	# Cables: one per input jack.
	var wanted: Dictionary[String, Dictionary] = {}
	for cable: Dictionary in state.cables:
		if _kinds.has(cable.from.place) and _kinds.has(cable.to.place):
			wanted["%s/%s" % [cable.to.place, cable.to.port]] = cable
	for key: String in _cables.keys():
		var old: Dictionary = _cables[key]
		if not wanted.has(key) or not _same_cable(wanted[key], old):
			disconnect_cable(old.to.place, old.to.port)
			_cables.erase(key)
	for key: String in wanted:
		if not _cables.has(key):
			var c: Dictionary = wanted[key]
			if connect_cable(c.from.place, c.from.port, c.to.place, c.to.port):
				_cables[key] = c
	# Knobs.
	for key: String in state.knobs:
		var place := key.get_slice("/", 0)
		if not _kinds.has(place):
			continue
		var param := key.get_slice("/", 1)
		var value: float = state.knobs[key]
		var mapping: Dictionary = AssetProfile.load_json(ENGINE_PATH % _kinds[place]).get("params", {}).get(param, {})
		if mapping.has("param"):
			param = mapping.param
			if mapping.get("per_master_bpm", false):
				value = roundf(value / MudpitBurbler.master_bpm())
		var sent_key := "%s/%s" % [place, param]
		if _sent.get(sent_key, NAN) != value:
			set_param(place, param, value)
			_sent[sent_key] = value
	# The normalled output plays only while nothing is plugged into it.
	var normalled: Dictionary = state.configure.get("normalled_output", {})
	emitter.stream_paused = state.is_patched(normalled)


func _drop_cables_on(place: String) -> void:
	for key: String in _cables.keys():
		var c: Dictionary = _cables[key]
		if c.from.place == place or c.to.place == place:
			_cables.erase(key)


static func _same_cable(a: Dictionary, b: Dictionary) -> bool:
	return a.from.place == b.from.place and a.from.port == b.from.port \
			and a.to.place == b.to.place and a.to.port == b.to.port


## The master-clock beat being heard now (the engine's position less what's still in
## the output buffers), or -1 before audio starts.
static func heard_master_beats() -> float:
	var sample: int = RackServer.now_sample()
	var heard_at: int = RackServer.sample_to_ticks_usec(sample)
	if heard_at < 0:
		return -1.0
	var rate: float = RackServer.get_sample_rate()
	var behind := float(heard_at - Time.get_ticks_usec()) * rate / 1e6
	var pos: Dictionary = RackServer.get_position()
	return maxf(0.0, float(pos.beats) - behind * float(pos.bpm) / (60.0 * rate))


## The master sample being heard now (the engine's position less what's still in the
## output buffers), or -1 before audio starts.
static func heard_sample() -> float:
	var sample: int = RackServer.now_sample()
	var heard_at: int = RackServer.sample_to_ticks_usec(sample)
	if heard_at < 0:
		return -1.0
	var behind := float(heard_at - Time.get_ticks_usec()) * RackServer.get_sample_rate() / 1e6
	return maxf(0.0, float(sample) - behind)


## The wall-clock delay (seconds) until master sample `sample` is heard (0 if past).
static func seconds_until_heard(sample: int) -> float:
	var at: int = RackServer.sample_to_ticks_usec(sample)
	return maxf(0.0, float(at - Time.get_ticks_usec()) / 1e6) if at >= 0 else 0.0
