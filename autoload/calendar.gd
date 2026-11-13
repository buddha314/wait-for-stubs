extends Node
## Simulation time, ported from stubby-music's calendar.rs. A 60-minute cycle:
## 45 minutes of day, then 15 of night. Separate from sample-timed music.
## Sky3D renders the sky; this decides what time it is (see main.gd).

const DAY_SECONDS := 2700.0
const CYCLE_SECONDS := 3600.0
## Where the game starts in the cycle. Bevy's opening is at night: this is
## solar midnight, 7.5 minutes before dawn.
const START_SECONDS := 3150.0

signal night_started

var elapsed: float = START_SECONDS
var _was_night: bool = true


func _ready() -> void:
	_was_night = is_night()


func _process(delta: float) -> void:
	elapsed += delta
	var night := is_night()
	if night and not _was_night:
		night_started.emit()
	_was_night = night


func is_night() -> bool:
	return fmod(elapsed, CYCLE_SECONDS) >= DAY_SECONDS


## Nights begun since the start of time, counting the current one. A resource
## with "next_night" replenishment returns once this exceeds its harvest value.
func nights_started() -> int:
	var cycles := int(elapsed / CYCLE_SECONDS)
	return cycles + (1 if is_night() else 0)


## Local solar time in hours [0, 24). Day maps 06:00 -> 18:00 over 45 minutes,
## night maps 18:00 -> 06:00 over 15 minutes, matching Bevy's sun hour angle.
func solar_hour() -> float:
	var s := fmod(elapsed, CYCLE_SECONDS)
	var hour := 6.0 + 12.0 * s / DAY_SECONDS if s < DAY_SECONDS \
			else 18.0 + 12.0 * (s - DAY_SECONDS) / (CYCLE_SECONDS - DAY_SECONDS)
	return fmod(hour, 24.0)
