extends CanvasLayer
## Reticle, the one interaction prompt ("[E] Collect lightning bug") and the
## status lines at the bottom left, as in stubby-music's resources.rs.

const INTERACT_KEY := "E"

@export var player: Player

@onready var _prompt: Control = $Prompt
@onready var _prompt_label: Label = $Prompt/Panel/Label
@onready var _status: Label = $Status


func _ready() -> void:
	player.target_changed.connect(_on_target_changed)
	Inventory.changed.connect(_refresh_status)
	_on_target_changed(null)


func _process(_delta: float) -> void:
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
	var held: PackedStringArray = []
	for item: String in Inventory.items:
		held.append("%d %s" % [Inventory.quantity(item), Rules.item_name(item).to_lower()])
	var text := "%s\nInventory: %s\n%s" % [prompt, ", ".join(held), Inventory.feedback]
	if _status.text != text:
		_status.text = text
