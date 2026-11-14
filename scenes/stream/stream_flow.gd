class_name StreamFlow
extends RefCounted
## What a sounding burbler sends down its streams (add-stream-building D6, D7): one note
## per tick of its clock, riding downstream one note spacing per clock beat, and a bar
## line half a spacing downstream of every downbeat note. Ticks come from the engine
## with their sample times (`add_tick`), never from frame time. Each note's distance is
## integrated from the *heard* clock position, so a retune changes the speed without
## moving a note, and the frame rate never matters. Distances are along the source
## chain from the burbler's mouth.

const FLOW_PATH := "res://assets/streams/stream_segment/flow.json"
## Notes further than this are dropped (well past any chain).
const MAX_DISTANCE := 1000.0

## {distance, downbeat} per note, oldest (furthest) first.
var notes: Array[Dictionary] = []
## Distance the water has flowed since the source started (drives the staff wave).
var flowed := 0.0
var spacing := note_spacing()
var beats_per_bar := 4

## Ticks not yet heard: {sample, index}.
var _waiting: Array[Dictionary] = []
var _last_heard := -1.0


static func note_spacing() -> float:
	return float(AssetProfile.load_json(FLOW_PATH).get("note_spacing_m", 1.0))


## A clock tick at master sample `sample` (its index from the clock).
func add_tick(sample: int, index: int) -> void:
	_waiting.append({"sample": sample, "index": index})


## Advances to the heard master sample `heard`, with the clock at `samples_per_beat`
## master samples per clock beat.
func advance(heard: float, samples_per_beat: float) -> void:
	if _last_heard < 0.0:
		_last_heard = heard
	var beats := maxf(0.0, heard - _last_heard) / samples_per_beat
	_last_heard = heard
	var moved := beats * spacing
	flowed += moved
	for note in notes:
		note.distance += moved
	while not _waiting.is_empty() and float(_waiting[0].sample) <= heard:
		var tick: Dictionary = _waiting.pop_front()
		var age := (heard - float(tick.sample)) / samples_per_beat
		notes.append({"distance": age * spacing, "downbeat": int(tick.index) % beats_per_bar == 0})
	while not notes.is_empty() and notes[0].distance > MAX_DISTANCE:
		notes.pop_front()


## Bar-line distances: half a spacing downstream of each downbeat note.
func bars() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for note in notes:
		if note.downbeat:
			out.append(note.distance + spacing * 0.5)
	return out


## The source fell silent: the stream lies quiet, so its notes clear.
func clear() -> void:
	notes.clear()
	_waiting.clear()
	_last_heard = -1.0
