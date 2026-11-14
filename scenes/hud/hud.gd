extends CanvasLayer
## Reticle, the one interaction prompt ("[E] Collect lightning bug") and the
## status lines at the bottom left, as in stubby-music's resources.rs.

const INTERACT_KEY := "E"
const NOTICE_SECONDS := 2.0

@export var player: Player

@onready var _prompt: Control = $Prompt
@onready var _prompt_label: Label = $Prompt/Panel/Label
@onready var _status: Label = $Status

## The "INVENTORY FULL" notice, with the item's icon (add-inventory-screen).
var _notice: HBoxContainer
var _notice_icon: TextureRect
var _notice_left := 0.0


func _ready() -> void:
	player.target_changed.connect(_on_target_changed)
	PlayerInventory.changed.connect(_refresh_status)
	PlayerInventory.refused.connect(_show_full)
	_build_notice()
	_build_build_hud()
	_build_time()
	_on_target_changed(null)


## Build mode label and the plan's cost under the reticle (add-stream-building).
var _build_label: Label
var _cost: HBoxContainer
var _cost_icon: TextureRect
var _cost_text: Label
const COST_WARN := Color(1.0, 0.35, 0.27)


func _process(delta: float) -> void:
	_update_build()
	_update_time()
	if _notice_left > 0.0:
		_notice_left -= delta
		_notice.visible = _notice_left > 0.0
	# The target's action can change without the target changing (collected).
	_on_target_changed(player.target)


static func prompt_text(action: String) -> String:
	return "[%s] %s" % [INTERACT_KEY, action]


func _on_target_changed(target: Interactable) -> void:
	var action := target.interact_action() if target and player.controls_enabled else ""
	_prompt.visible = not action.is_empty()
	if _prompt.visible:
		_prompt_label.text = prompt_text(action)
	_refresh_status()


func _refresh_status() -> void:
	var prompt := "Explore for resources | approach within 3 m"
	if _prompt.visible:
		prompt = prompt_text("Collect (hold for nearby pickups)") \
				if player.target is ResourceNode else _prompt_label.text
	# Item counts live on the Tab screen, not here (add-inventory-screen).
	var text := "%s\n%s" % [prompt, PlayerInventory.feedback]
	if _status.text != text:
		_status.text = text


func _build_notice() -> void:
	_notice = HBoxContainer.new()
	_notice.name = "FullNotice"
	_notice.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notice.position = Vector2(-120, 96)
	_notice.visible = false
	_notice_icon = TextureRect.new()
	_notice_icon.custom_minimum_size = Vector2(40, 40)
	_notice_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_notice_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_notice.add_child(_notice_icon)
	var label := Label.new()
	label.text = "INVENTORY FULL"
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.3))
	_notice.add_child(label)
	add_child(_notice)


## Shows the notice, with the refused item's icon.
func _show_full(item: String) -> void:
	var icon := PlayerInventory.ICON_PATH % item
	_notice_icon.texture = load(icon) if ResourceLoader.exists(icon) else null
	_notice_left = NOTICE_SECONDS
	_notice.visible = true


## True while the full notice shows (for tests).
func full_notice_visible() -> bool:
	return _notice.visible


func _build_build_hud() -> void:
	_build_label = Label.new()
	_build_label.name = "BuildMode"
	_build_label.text = "BUILD  ·  stream     [Q] leave   [LMB] anchor / lay   [RMB] drop"
	_build_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_build_label.position = Vector2(-260, 56)  # below the compass bar (add-compass-bar)
	_build_label.visible = false
	add_child(_build_label)
	_cost = HBoxContainer.new()
	_cost.name = "Cost"
	_cost.set_anchors_preset(Control.PRESET_CENTER)
	_cost.position = Vector2(-40, 28)
	_cost.visible = false
	_cost_icon = TextureRect.new()
	_cost_icon.custom_minimum_size = Vector2(28, 28)
	_cost_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cost_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cost.add_child(_cost_icon)
	_cost_text = Label.new()
	_cost.add_child(_cost_text)
	add_child(_cost)


## The cost readout: icon and need / have, warning colour when short. No hint text.
func _update_build() -> void:
	var builder := get_tree().get_first_node_in_group("stream_builder") as StreamBuilder
	var active := builder != null and builder.active
	_build_label.visible = active
	var cost: Dictionary = builder.cost if active else {}
	_cost.visible = not cost.is_empty()
	if _cost.visible:
		_cost_text.text = "%d / %d" % [cost.need, cost.have]
		_cost_text.add_theme_color_override("font_color", COST_WARN if cost.have < cost.need else Color.WHITE)
		var icon := PlayerInventory.ICON_PATH % cost.item
		if ResourceLoader.exists(icon) and (_cost_icon.texture == null or _cost_icon.texture.resource_path != icon):
			_cost_icon.texture = load(icon)


## The cost readout's text and whether it warns (for tests).
func cost_readout() -> Array:
	return [_cost.visible, _cost_text.text, _cost_text.get_theme_color("font_color") == COST_WARN]


## The time readout, top left (add-time-speed-controls D5): phase, solar time, speed.
var _time: Label


func _build_time() -> void:
	_time = Label.new()
	_time.name = "TimeReadout"
	_time.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_time.position = Vector2(20, 16)
	add_child(_time)


static func time_text(night: bool, hour: float, speed: float) -> String:
	var minutes := int(hour * 60.0) % (24 * 60)
	return "%s %02d:%02d · %s" % ["NIGHT" if night else "DAY", int(minutes / 60.0), minutes % 60,
			Calendar.speed_text(speed)]


func _update_time() -> void:
	var text := time_text(Calendar.is_night(), Calendar.solar_hour(), Calendar.speed)
	if _time.text != text:
		_time.text = text


## The readout's text (for tests).
func time_readout() -> String:
	return _time.text
