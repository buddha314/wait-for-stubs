class_name MachineInteract
extends Interactable
## A machine's E point, placed on the model's `Interact` node. E opens the
## machine's rack screen (any node in group "rack_screen" with `open_rack`).

## The machine profile's "configure" block (asset.json).
var configure: Dictionary
## The machine this point belongs to.
var machine: Node3D


func interact_action() -> String:
	return configure.get("interact", {}).get("prompt", "")


func interact() -> void:
	get_tree().call_group("rack_screen", "open_rack", self)
