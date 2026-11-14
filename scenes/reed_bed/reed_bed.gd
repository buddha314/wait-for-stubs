@tool
class_name ReedBed
extends Node3D
## Scatters `count` reed clumps in a disc, deterministically from
## (world seed, bed_id). Runs in the editor too, so beds are visible while
## laying out a level. The clumps are generated, not saved into the scene.

const REED_CLUMP := preload("res://assets/flora/reeds/reed_clump.tscn")
const SNAIL_SHELL := preload("res://assets/creatures/snail_shell/snail_shell.tscn")
## Shells lie this far outside the bed's radius, on the open mud.
const SHELL_MARGIN := 0.7
const MAX_TRIES_PER_CLUMP := 30

@export var bed_id: String = "reed_bed-0":
	set(value):
		bed_id = value
		_rescatter()
@export_range(1, 64) var count: int = 10:
	set(value):
		count = value
		_rescatter()
@export_range(0.5, 30.0, 0.1, "suffix:m") var radius: float = 3.5:
	set(value):
		radius = value
		_rescatter()
## Snail shells on the mud at the bed's edge (add-snail-shell-sequencer). Their own
## seed (`<bed_id>/shells`), so adding shells never moves the reeds.
@export_range(0, 8) var shells: int = 0:
	set(value):
		shells = value
		_rescatter()
@export_range(0.0, 3.0, 0.05, "suffix:m") var min_spacing: float = 0.8:
	set(value):
		min_spacing = value
		_rescatter()


func _ready() -> void:
	_scatter()


func _rescatter() -> void:
	if is_node_ready():
		_scatter()


func _scatter() -> void:
	for child in get_children():
		if child is ReedClump or child is SnailShell:
			child.free()
	var rng := WorldSeed.rng(bed_id)
	var placed: Array[Vector2] = []
	for i in count:
		for _try in MAX_TRIES_PER_CLUMP:
			# Uniform over the disc.
			var p := Vector2.from_angle(rng.randf() * TAU) * radius * sqrt(rng.randf())
			if placed.all(func(q: Vector2) -> bool: return q.distance_to(p) >= min_spacing):
				placed.append(p)
				var clump: ReedClump = REED_CLUMP.instantiate()
				clump.instance_id = "%s/%d" % [bed_id, i]
				clump.position = Vector3(p.x, 0.0, p.y)
				add_child(clump)
				break
	_scatter_shells()


## Shells at seeded angles round the rim, children without an owner (never saved).
func _scatter_shells() -> void:
	var rng := WorldSeed.rng(bed_id + "/shells")
	for i in shells:
		var angle := rng.randf() * TAU
		var p := Vector2.from_angle(angle) * (radius + SHELL_MARGIN * (0.5 + rng.randf()))
		var shell: SnailShell = SNAIL_SHELL.instantiate()
		shell.instance_id = "%s/shell-%d" % [bed_id, i]
		shell.position = Vector3(p.x, 0.0, p.y)
		add_child(shell)
