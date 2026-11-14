extends Node
## Simulation time, ported from stubby-music's calendar.rs. A 60-minute cycle:
## 45 minutes of day, then 15 of night. Separate from sample-timed music.
## Sky3D renders the sky; this decides what time it is (see main.gd).

const DAY_SECONDS := 2700.0
const CYCLE_SECONDS := 3600.0
## Where the game starts in the cycle. Bevy's opening is at night: this is
## solar midnight, 7.5 minutes before dawn.
const START_SECONDS := 3150.0

## Simulation speeds (add-time-speed-controls; stubby-music's list, no 32×).
const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0, 64.0]
## A frame adds at most this × speed of calendar time, so a hitch can't skip a night.
const MAX_FRAME_SECONDS := 0.1

signal night_started
signal speed_changed(speed: float)

var elapsed: float = START_SECONDS
## Simulation speed: calendar seconds per real second. Only simulation time follows it
## (sky, day/night, replenishment, growth); the player, UI and all audio never do.
var speed: float = 1.0:
	set(value):
		if speed != value:
			speed = value
			speed_changed.emit(speed)
var _was_night: bool = true


func _ready() -> void:
	_was_night = is_night()


func _process(frame_delta: float) -> void:
	advance(frame_delta)


## Adds one frame's calendar time (the frame delta × speed, capped).
func advance(frame_delta: float) -> void:
	elapsed += delta(frame_delta)
	var night := is_night()
	if night and not _was_night:
		night_started.emit()
	_was_night = night


## Calendar seconds for a frame of `frame_delta` real seconds: for rates that follow
## simulation time (plant growth). Capped at MAX_FRAME_SECONDS × speed.
func delta(frame_delta: float) -> float:
	return minf(frame_delta, MAX_FRAME_SECONDS) * speed


## One step faster, stopping at 64×.
func faster() -> void:
	speed = SPEEDS[mini(_step() + 1, SPEEDS.size() - 1)]


## One step slower, stopping at ¼×.
func slower() -> void:
	speed = SPEEDS[maxi(_step() - 1, 0)]


func reset_speed() -> void:
	speed = 1.0


## Speed as text: "¼×", "½×", "1×" … "64×".
static func speed_text(value: float) -> String:
	if is_equal_approx(value, 0.25):
		return "¼×"
	if is_equal_approx(value, 0.5):
		return "½×"
	return "%d×" % int(value)


## Index of the current speed in SPEEDS (the nearest one).
func _step() -> int:
	var best := 0
	for i in SPEEDS.size():
		if absf(SPEEDS[i] - speed) < absf(SPEEDS[best] - speed):
			best = i
	return best


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
