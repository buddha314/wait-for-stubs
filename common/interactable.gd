class_name Interactable
extends Area3D
## A point E can act on. The player's reach (scenes/player) overlaps these on
## the "interact" physics layer; the nearest available one, measured
## horizontally, is the target. A small marker of its own, so it can sit
## beside visuals whose scale animates (a physics shape can't scale to zero).

const LAYER := 1 << 2  # "interact", layer 3
const MARKER_RADIUS := 0.25

## True: holding E acts every tick (pickups). False: once per press (machines).
var hold_repeats := false


func _init() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true
	var sphere := SphereShape3D.new()
	sphere.radius = MARKER_RADIUS
	var shape := CollisionShape3D.new()
	shape.shape = sphere
	add_child(shape)


## What E would do, shown after "[E] ". Empty means unavailable.
func interact_action() -> String:
	return ""


func interact() -> void:
	pass
