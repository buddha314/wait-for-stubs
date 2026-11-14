class_name HandItem
extends Node3D
## One item the hand can hold: posed in the editor under `Hand`, shown only while held.
## Each item has its own input action that brings it up and puts it away.

## The item's id, e.g. "field_recorder".
@export var item_id: StringName
## The action that toggles this item, e.g. "field_recorder" (H).
@export var action: StringName
