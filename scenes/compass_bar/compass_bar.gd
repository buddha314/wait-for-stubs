class_name CompassBar
extends CanvasLayer
## The compass bar, top centre, as in Satisfactory (add-compass-bar): cardinal letters,
## smaller intercardinals and 15° ticks scroll with the view; a caret marks the
## heading. Bearings run clockwise from north (−Z); east is +X, where the sun rises.
## The heading comes from the active camera, so an XR headset works the same. Hidden
## while a screen has the player's controls, like the goal bar. No markers yet.

## Width of the bar, in pixels, and the bearings it spans.
const WIDTH := 320.0
const SPAN_DEGREES := 180.0
const TOP := 12.0
const HEIGHT := 32.0
const TICK_DEGREES := 15
const TEXT := Color(0.95, 0.94, 0.9)
const SHADOW := Color(0.0, 0.0, 0.0, 0.6)
const AMBER := Color(0.96, 0.67, 0.25)
const LABELS := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}

var _bar: Control
## The heading drawn last, in degrees (for tests).
var heading := 0.0


func _ready() -> void:
	_bar = Control.new()
	_bar.name = "Bar"
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_bar.position = Vector2(-WIDTH * 0.5, TOP)
	_bar.size = Vector2(WIDTH, HEIGHT)
	_bar.draw.connect(_draw_bar)
	add_child(_bar)


func _process(_delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	_bar.visible = players.is_empty() or players[0].controls_enabled
	var camera := get_viewport().get_camera_3d()
	if camera:
		heading = bearing_of(-camera.global_basis.z)
	_bar.queue_redraw()


## The compass bearing of a direction, in degrees [0, 360): 0 north (−Z), 90 east (+X).
## Pitch is ignored.
static func bearing_of(direction: Vector3) -> float:
	return fposmod(rad_to_deg(atan2(direction.x, -direction.z)), 360.0)


## Where a bearing sits on the bar, in pixels from its left edge, or NAN off the bar.
static func x_of(bearing: float, at_heading: float) -> float:
	var offset := fposmod(bearing - at_heading + 180.0, 360.0) - 180.0
	if absf(offset) > SPAN_DEGREES * 0.5:
		return NAN
	return WIDTH * 0.5 + offset * WIDTH / SPAN_DEGREES


## The letter nearest the centre of the bar (for tests): "E" when facing east.
func centre_label() -> String:
	var best := ""
	var best_offset := INF
	for bearing: int in LABELS:
		var offset := absf(fposmod(bearing - heading + 180.0, 360.0) - 180.0)
		if offset < best_offset:
			best = LABELS[bearing]
			best_offset = offset
	return best


## Fades the outer quarter of each side, as Satisfactory's bar does.
static func _fade(x: float) -> float:
	var edge := minf(x, WIDTH - x) / (WIDTH * 0.25)
	return clampf(edge, 0.0, 1.0)


func _draw_bar() -> void:
	var font := _bar.get_theme_default_font()
	var base := HEIGHT - 4.0
	# The baseline, fading at the ends.
	for i in 16:
		var x0 := WIDTH * i / 16.0
		var x1 := WIDTH * (i + 1) / 16.0
		var a := _fade((x0 + x1) * 0.5)
		_bar.draw_line(Vector2(x0, base), Vector2(x1, base), Color(TEXT, 0.35 * a), 1.0)
	for bearing in range(0, 360, TICK_DEGREES):
		var x := x_of(bearing, heading)
		if is_nan(x):
			continue
		var a := _fade(x)
		if LABELS.has(bearing):
			var label: String = LABELS[bearing]
			var cardinal := label.length() == 1
			var size := 18 if cardinal else 13
			var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			var at := Vector2(x - width * 0.5, base - 8.0)
			_bar.draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(SHADOW, SHADOW.a * a))
			_bar.draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(TEXT, a))
		else:
			_bar.draw_line(Vector2(x, base - 6.0), Vector2(x, base), Color(TEXT, 0.7 * a), 1.0)
	# The caret: the heading, in the signal amber.
	var c := WIDTH * 0.5
	_bar.draw_colored_polygon(PackedVector2Array([
		Vector2(c - 5.0, base + 7.0), Vector2(c + 5.0, base + 7.0), Vector2(c, base + 1.0)]), AMBER)
