class_name SnailShell
extends Node3D
## An empty snail shell lying on the mud (add-snail-shell-sequencer): a find, collected
## with E into a `snail_shell` item (no recorder needed: a shell is not a sound). It
## never returns. In a rack it mounts as the four-step Snail sequencer. Shown at the
## profile's `world_scale`, lying on its side at a seeded angle.

const PROFILE_PATH := "res://assets/creatures/snail_shell/asset.json"
## How far the shell leans from upright, lying on the mud.
const LIE_DEGREES := 72.0

## Stable identity: seeds the angle it lies at.
@export var instance_id: String = "snail_shell-0"

@onready var _model: Node3D = $Model
@onready var _pickup: ResourceNode = $Pickup


func _ready() -> void:
	var profile := AssetProfile.load_json(PROFILE_PATH)
	var size := float(profile.get("world_scale", 1.0))
	var height := float(profile.get("size_metres", {}).get("height", 0.03)) * size
	var rng := WorldSeed.rng(instance_id)
	_model.scale = Vector3.ONE * size
	_model.rotation = Vector3(deg_to_rad(LIE_DEGREES), rng.randf() * TAU, 0.0)
	_model.position.y = height * 0.25
	_pickup.position.y = height * 0.3
	_pickup.instance_id = instance_id
	_pickup.outline_root = _model
	_pickup.collected_changed.connect(func(collected: bool) -> void: _model.visible = not collected)
