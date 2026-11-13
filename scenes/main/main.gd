extends Node3D
## Root of the opening: a silent desert mudflat that starts at night. The
## burbler and lightning bug placements are carried over from stubby-music's
## authored Jackdaw scene (jackdaw/assets/scene.bsn). The reed beds are new.

@onready var _sky: Sky3D = $Sky3D


func _process(_delta: float) -> void:
	# Calendar owns the clock (Bevy's 45 min day / 15 min night); Sky3D draws it.
	_sky.current_time = Calendar.solar_hour()
