class_name Hand
extends Node3D
## The player's hand (add-field-recorder D1, D6): holds at most one item. Each child
## HandItem is posed in the editor and has its own action; pressing it brings that
## item up (putting away whatever was held) or puts it away if it is already held.
## Ignored while a screen has the controls. A new game starts with `start_held`.

## Emitted when the held item changes (empty: nothing held).
signal held_changed(item_id: StringName)

## The item a new game starts with in the hand.
@export var start_held: StringName = &"field_recorder"

## The held item's id, or empty.
var held: StringName = &"":
	set(value):
		if held != value:
			held = value
			_show_held()
			held_changed.emit(held)

var _player: Player


func _ready() -> void:
	add_to_group("hand")
	var node := get_parent()
	while node and not node is Player:
		node = node.get_parent()
	_player = node as Player
	if _player:
		_player.pickup_collected.connect(_on_pickup_collected)
	held = start_held
	_show_held()


## True if the hand in this tree holds `item_id`.
static func holds(tree: SceneTree, item_id: StringName) -> bool:
	var hand := tree.get_first_node_in_group("hand") as Hand
	return hand != null and hand.held == item_id


## The key bound to an action, as text ("H"), read from the input map.
static func key_label(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key:
			var code := key.keycode if key.keycode != KEY_NONE else key.physical_keycode
			return OS.get_keycode_string(code)
	return String(action)


## The child posed for `item_id`, or null.
func item(item_id: StringName) -> HandItem:
	for child in get_children():
		if child is HandItem and child.item_id == item_id:
			return child
	return null


func _unhandled_input(event: InputEvent) -> void:
	if _player and not _player.controls_enabled:
		return
	for child in get_children():
		var hand_item := child as HandItem
		if hand_item and event.is_action_pressed(hand_item.action, false):
			held = &"" if held == hand_item.item_id else hand_item.item_id
			get_viewport().set_input_as_handled()
			return


func _show_held() -> void:
	for child in get_children():
		if child is HandItem:
			child.visible = child.item_id == held


## The record light answers collection while the recorder is held.
func _on_pickup_collected() -> void:
	var held_item := item(held)
	if held_item:
		for child in held_item.get_children():
			if child.has_method("capture"):
				child.capture()
