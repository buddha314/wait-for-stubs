class_name ResourceNode
extends Interactable
## A finite pickup: E harvests its resource's yields into the inventory. It
## stays collected until its replenishment policy (resources.json) restores it.
## The owning scene listens to `collected_changed` to update its visuals.

signal collected_changed(collected: bool)

## Row id in resources.json, e.g. "lightning_bug", "reed_clump".
@export var resource_id: String
## Stable instance identity, unique in the world.
@export var instance_id: String

var collected := false:
	set(value):
		if collected != value:
			collected = value
			set_process(value)
			collected_changed.emit(value)

var _harvested_at_seconds := 0.0
var _harvested_at_night := 0


func _ready() -> void:
	hold_repeats = true
	set_process(collected)


func interact_action() -> String:
	return "" if collected else "Collect %s" % Rules.resource_name(resource_id).to_lower()


func interact() -> void:
	if collected or not Inventory.harvest(resource_id):
		return
	_harvested_at_seconds = Calendar.elapsed
	_harvested_at_night = Calendar.nights_started()
	collected = true


## 0 when just harvested, 1 when it returns; 0 for policies without a duration.
func replenish_progress() -> float:
	var policy := Rules.replenishment(resource_id)
	if policy.get("kind") == "after":
		return clampf((Calendar.elapsed - _harvested_at_seconds) / float(policy.seconds), 0.0, 1.0)
	return 0.0


func _process(_delta: float) -> void:
	var policy := Rules.replenishment(resource_id)
	match policy.get("kind"):
		"next_night":
			if Calendar.nights_started() > _harvested_at_night:
				collected = false
		"after":
			if replenish_progress() >= 1.0:
				collected = false
