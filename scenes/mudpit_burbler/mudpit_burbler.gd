class_name MudpitBurbler
extends StaticBody3D
## A clock mine: the first machine. E at its Interact point configures it.

const PROFILE_PATH := "res://assets/machines/mudpit_burbler/asset.json"

@onready var _model: Node3D = $Model


func _ready() -> void:
	var configure: Dictionary = AssetProfile.load_json(PROFILE_PATH).get("configure", {})
	var node_name: String = configure.get("interact", {}).get("node", "Interact")
	var point := MachineInteract.new()
	point.name = "MachineInteract"
	point.configure = configure
	point.machine = self
	var anchor: Node3D = _model.find_child(node_name, true, false)
	if anchor == null:
		push_error("MudpitBurbler: model has no %s node" % node_name)
		anchor = _model
	anchor.add_child(point)
