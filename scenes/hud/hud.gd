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
	_on_target_changed(null)


func _process(delta: float) -> void:
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
