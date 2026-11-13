extends CanvasLayer
## A machine's configuration screen, opened by E on a MachineInteract. For now
## it lists the rack's places from the machine profile (what's fixed, what an
## empty slot accepts, the patch steps). It's a stand-in for stubby-music's 3D
## Eurorack HUD (machine_config.rs/rack.rs): mounting and patching come later.
## E or Esc closes it.

const LABEL_COLOR := Color(0.95, 0.94, 0.87)
const DIM_COLOR := Color(0.7, 0.68, 0.6)

var _open_point: MachineInteract

@onready var _title: Label = $Center/Panel/Rows/Title
@onready var _places: VBoxContainer = $Center/Panel/Rows/Places
@onready var _patch: Label = $Center/Panel/Rows/Patch


func _ready() -> void:
	add_to_group("rack_screen")
	visible = false


func open_rack(point: MachineInteract) -> void:
	_open_point = point
	var configure := point.configure
	_title.text = configure.get("title", "MACHINE")
	for child in _places.get_children():
		child.free()
	for place: Dictionary in configure.get("places", []):
		_places.add_child(_place_row(place))
	var steps: PackedStringArray = []
	for cable: Dictionary in configure.get("cables", []):
		steps.append("%d. %s" % [cable.get("step", steps.size() + 1), cable.get("hint", "")])
	_patch.text = "Patch:\n" + "\n".join(steps) if not steps.is_empty() else ""
	visible = true
	_set_player_controls(false)


func close() -> void:
	visible = false
	_open_point = null
	_set_player_controls(true)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact", false) or event.is_action_pressed("release_cursor"):
		get_viewport().set_input_as_handled()
		close()


func _place_row(place: Dictionary) -> HBoxContainer:
	var name := "%s · %d HP" % [String(place.get("place", "?")).to_upper(), int(place.get("hp", 0))]
	var detail: String
	if place.get("fixed", false):
		detail = "%s (fixed)" % _module_name(place.get("module", ""))
	else:
		var options: PackedStringArray = []
		for accept: Dictionary in place.get("accepts", []):
			options.append("%s → %s (you have %d)" % [
				Rules.item_name(accept.item), _module_name(accept.module),
				Inventory.quantity(accept.item)])
		detail = "empty · takes " + ", ".join(options)
	var row := HBoxContainer.new()
	for text: String in [name, detail]:
		var label := Label.new()
		label.text = text
		label.add_theme_color_override("font_color", LABEL_COLOR)
		label.add_theme_font_size_override("font_size", 18)
		row.add_child(label)
	row.get_child(0).custom_minimum_size.x = 150.0
	return row


## Matches stubby-music rack.rs module_name().
static func _module_name(module: String) -> String:
	return "Square VCO" if module == "square_vco" else module.replace("_", " ")


func _set_player_controls(enabled: bool) -> void:
	for player: Player in get_tree().get_nodes_in_group("player"):
		player.controls_enabled = enabled
