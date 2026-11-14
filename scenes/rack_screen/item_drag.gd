class_name ItemDrag
extends RefCounted
## What the rack screen drags: an inventory item, by id. An object, not a Dictionary,
## because every GLoot grid item in the window (the Tab inventory) compares the
## viewport's drag data with its own item on each drag, and Godot 4.8 errors when it
## compares a Dictionary with an Object.

var item: String


func _init(item_id: String) -> void:
	item = item_id
