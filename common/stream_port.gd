class_name StreamPort
extends Node3D
## Where a stream can start (add-stream-building D2): the burbler's mouth or a laid
## stream's free end. Group `stream_port`; the builder scans the group (a few ports, no
## physics). The halo shows only while this port is the build candidate.

## The machine or stream this port belongs to.
var owner_node: Node
## True once a stream leaves from here.
var connected := false
## Shown while this port is the candidate.
var halo: Node3D


func _enter_tree() -> void:
	add_to_group("stream_port")


## Flow leaves along this node's +X, kept horizontal.
func flow_direction() -> Vector3:
	var x := global_basis.x
	return Vector3(x.x, 0.0, x.z).normalized()


func set_highlighted(on: bool) -> void:
	if halo:
		halo.scale = Vector3.ONE if on else Vector3.ZERO
		halo.visible = on
