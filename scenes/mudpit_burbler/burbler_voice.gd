class_name BurblerVoice
extends AudioStreamPlayer3D
## STAND-IN (add-burbler-rack-screen D9b): the patched burbler's voice until
## stubby-rack can play the RackState (add-rack-audio-engine 9.2). Remove it then.
##
## It reproduces stubby-music's burbler voice: the clock's gate is high for the
## first half of each beat (PeriodicClock.gate_high), the gate opens the VCA
## directly with no envelope (rack.rs), and the VCA passes the Square VCO at its
## FREQ knob, scaled by the volume's GAIN knob. One beat of that is pre-rendered
## into a looping AudioStreamWAV. Godot's mixer loops it with sample accuracy, so
## nothing is timed from frame time. It is not locked to the master clock's phase;
## the engine will do that. It plays from the burbler, only while the rack is fully
## patched and its output is normalled to the outlet.

const MIX_RATE := 48000

var _burbler: MudpitBurbler
## The (bpm, freq, gain) the current loop was rendered for.
var _rendered := Vector3.ZERO


func setup(burbler: MudpitBurbler, hearing_radius: float) -> void:
	_burbler = burbler
	name = "BurblerVoice"
	max_distance = hearing_radius
	unit_size = 6.0
	attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	burbler.rack_state.changed.connect(refresh)
	refresh()


## Starts, stops or re-renders the voice to match the rack.
func refresh() -> void:
	if _burbler == null:
		return
	if not _burbler.outlet_carries_voice():
		stop()
		return
	var state := _burbler.rack_state
	var wanted := Vector3(_burbler.bpm(), state.knob("vco/freq", 2200.0), state.knob("volume/gain", 0.25))
	if wanted != _rendered or stream == null:
		_rendered = wanted
		stream = render_beat(wanted.x, wanted.y, wanted.z)
		play()
	elif not playing:
		play()


## Phase within the current beat, 0..1, as heard, or -1 when silent. Uses the
## playback position corrected for the mix and output latency (Godot's documented
## way to sync visuals to audio), so the rack lamp flashes with the sound.
func heard_phase() -> float:
	if not playing or stream == null:
		return -1.0
	var length := (stream as AudioStreamWAV).get_length()
	if length <= 0.0:
		return -1.0
	var t := get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	return fposmod(t, length) / length


## One beat at `bpm`: a square at `freq` Hz × `gain` for the gate's first half,
## then silence. 16-bit mono, looping over the whole beat.
static func render_beat(bpm: float, freq: float, gain: float) -> AudioStreamWAV:
	var frames := maxi(2, roundi(MIX_RATE * 60.0 / maxf(bpm, 1.0)))
	var gate := frames / 2
	var data := PackedByteArray()
	data.resize(frames * 2)
	var level := clampf(gain, 0.0, 1.0) * 32767.0
	for i in gate:
		var square := 1.0 if fmod(float(i) * freq / MIX_RATE, 1.0) < 0.5 else -1.0
		data.encode_s16(i * 2, int(square * level))
	# The second half stays zero: the gate is low.
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frames
	return wav
