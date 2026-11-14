extends CanvasLayer
## The goal bar, upper right (add-goals-hub D5): the active major goal with its progress
## (steps done of total) and the active step's name and description. On completion it
## shows "GOAL COMPLETE · <name>" for NOTICE_SECONDS, then the active goals. Hidden
## while a screen has the player's controls. The top centre stays free (compass bar).

const NOTICE_SECONDS := 4.0
const WIDTH := 440.0
const TEXT := Color(0.95, 0.94, 0.87)
const DIM := Color(0.78, 0.76, 0.68)
const AMBER := Color(0.96, 0.67, 0.25)

var _panel: PanelContainer
var _major: Label
var _bar: ProgressBar
var _count: Label
var _step: Label
var _description: Label
var _notice: Label
## Names of completed goals waiting to be shown, oldest first.
var _notices: Array[String] = []
var _notice_left := 0.0
## The goal whose notice is showing.
var _current := ""
var _goals: Node


func _ready() -> void:
	_goals = get_node(^"/root/Goals")
	_build()
	_goals.goal_completed.connect(_on_goal_completed)
	_goals.active_changed.connect(_refresh)
	_refresh()


func _process(delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	var playing: bool = players.is_empty() or players[0].controls_enabled
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_show_next_notice()
	_panel.visible = playing and (_notice_left > 0.0 or not _goals.active_major().is_empty())


## The bar's text, line by line (for tests): notice, or major, count, step, description.
func lines() -> PackedStringArray:
	if not _panel.visible:
		return []
	if _notice_left > 0.0:
		return [_notice.text]
	return [_major.text, _count.text, _step.text, _description.text]


func _on_goal_completed(id: String) -> void:
	var name: String = _goals.goal_name(id)
	# A major goal completes with its last step: its notice replaces that step's.
	if _goals.goal(id).get("scale", "") == "major":
		var steps: Array = _goals.steps_of(id)
		var last: String = steps.back().name if not steps.is_empty() else ""
		var queued := _notices.rfind(last)
		if queued >= 0:
			_notices[queued] = name
			return
		if _notice_left > 0.0 and _current == last:
			_show_notice(name)
			return
	_notices.append(name)
	if _notice_left <= 0.0:
		_show_next_notice()


func _show_next_notice() -> void:
	if _notices.is_empty():
		_notice_left = 0.0
		_current = ""
		_set_notice_mode(false)
		_refresh()
		return
	_show_notice(_notices.pop_front())


func _show_notice(name: String) -> void:
	_current = name
	_notice.text = "GOAL COMPLETE · %s" % name
	_notice_left = NOTICE_SECONDS
	_set_notice_mode(true)


func _set_notice_mode(on: bool) -> void:
	_notice.visible = on
	for node: Control in [_major.get_parent(), _step, _description]:
		node.visible = not on


func _refresh() -> void:
	var major: Dictionary = _goals.active_major()
	if major.is_empty():
		return
	var total: int = _goals.steps_of(major.id).size()
	var done: int = _goals.steps_done(major.id)
	_major.text = String(major.name).to_upper()
	_bar.max_value = total
	_bar.value = done
	_count.text = "%d / %d" % [done, total]
	var step: Dictionary = _goals.active_step()
	_step.text = "› %s" % step.name if not step.is_empty() else ""
	_description.text = step.get("description", "")


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -WIDTH - 20.0
	_panel.offset_right = -20.0
	_panel.offset_top = 16.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.035, 0.025, 0.7)
	style.set_content_margin_all(10.0)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	_panel.add_child(rows)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	rows.add_child(header)
	_major = _label(18, TEXT)
	_major.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_major)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(90, 8)
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = AMBER
	var empty := StyleBoxFlat.new()
	empty.bg_color = Color(AMBER, 0.2)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", empty)
	header.add_child(_bar)
	_count = _label(16, DIM)
	header.add_child(_count)

	_step = _label(18, AMBER)
	rows.add_child(_step)
	_description = _label(15, DIM)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.custom_minimum_size.x = WIDTH - 20.0
	rows.add_child(_description)
	_notice = _label(18, AMBER)
	_notice.visible = false
	rows.add_child(_notice)


func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
