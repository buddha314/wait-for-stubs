class_name InventoryScreen
extends CanvasLayer
## The Tab inventory screen (add-inventory-screen): the player's 16 boxes as a grid
## (GLoot's CtrlInventoryGrid on PlayerInventory.boxes), each with its icon and count,
## and the hovered or selected item's name and description. Tab or Esc closes it.
## While open, the cursor is free and the player stops, as with the rack screen;
## opening it closes the rack screen. Item names come from the catalog.

const FIELD := Vector2(72, 72)
const SPACING := 6

var _grid: CtrlInventoryGrid
var _name: Label
var _description: Label


func _ready() -> void:
	add_to_group("inventory_screen")
	layer = 10
	visible = false
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.043, 0.047, 0.063, 0.72)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	centre.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "INVENTORY"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	_grid = CtrlInventoryGrid.new()
	_grid.field_dimensions = FIELD
	_grid.item_spacing = SPACING
	_grid.custom_minimum_size = Vector2(
			PlayerInventory.GRID.x * (FIELD.x + SPACING), PlayerInventory.GRID.y * (FIELD.y + SPACING))
	_grid.inventory = PlayerInventory.boxes
	_grid.item_mouse_entered.connect(_show_item)
	_grid.inventory_item_selected.connect(_show_item)
	row.add_child(_grid)
	var detail := VBoxContainer.new()
	detail.custom_minimum_size = Vector2(320, 0)
	row.add_child(detail)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 22)
	detail.add_child(_name)
	_description = Label.new()
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.custom_minimum_size = Vector2(320, 0)
	detail.add_child(_description)
	var hint := Label.new()
	hint.text = "[Tab] close"
	hint.modulate = Color(1, 1, 1, 0.6)
	box.add_child(hint)


func is_open() -> bool:
	return visible


func open() -> void:
	for rack: Node in get_tree().get_nodes_in_group("rack_screen"):
		if rack.is_open():
			rack.close()
	visible = true
	_name.text = ""
	_description.text = "Hover a box to see what it holds."
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_player_controls(false)


func close() -> void:
	visible = false
	_grid.deselect_inventory_items()
	_set_player_controls(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory", false):
		get_viewport().set_input_as_handled()
		if is_open():
			close()
		else:
			open()
	elif is_open() and event.is_action_pressed("release_cursor"):
		get_viewport().set_input_as_handled()
		close()


func _show_item(item: InventoryItem) -> void:
	if item == null:
		return
	var id := item.get_prototype().get_prototype_id()
	_name.text = "%s  ×%d" % [Rules.item_name(id), PlayerInventory.quantity(id)]
	_description.text = Rules.item_description(id)


func _set_player_controls(enabled: bool) -> void:
	for player: Player in get_tree().get_nodes_in_group("player"):
		player.controls_enabled = enabled
