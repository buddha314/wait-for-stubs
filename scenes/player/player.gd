class_name Player
extends CharacterBody3D
## Grounded first-person walker, matching stubby-music's controls:
## WASD walk, mouse look, Space jump, hold C crouch, hold Left Shift sprint.
## Escape or focus loss releases the cursor; left click recaptures it.
## E acts on the nearest Interactable within REACH metres, measured
## horizontally; hold E to collect successive nearby pickups.

## Emitted when what E would act on changes (null: nothing in reach).
signal target_changed(target: Interactable)

const WALK_SPEED := 4.0
const SPRINT_SPEED := 8.0
const CROUCH_SPEED := 2.0
const JUMP_SPEED := 7.0
const GRAVITY := 20.0
const MOUSE_SENSITIVITY := 0.003
const PITCH_LIMIT := 1.54
const EYE_HEIGHT := 1.65
const CROUCH_EYE_HEIGHT := 1.0
## Eye-height change rate when crouching or standing, metres per second.
const CROUCH_RATE := 6.0
## Horizontal reach of E, in metres.
const REACH := 3.0

## What E would act on now, or null.
var target: Interactable
## False while a screen (e.g. a machine's rack) has the controls.
var controls_enabled := true:
	set(value):
		controls_enabled = value
		_fresh_press = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value else Input.MOUSE_MODE_VISIBLE
## True from an E press until it acts on something or shows the hint once.
var _fresh_press := false

@onready var _head: Node3D = $Head
@onready var _reach: Area3D = $Head/Reach


func _ready() -> void:
	add_to_group("player")
	_head.position.y = EYE_HEIGHT
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event.is_action_pressed("interact", false):
		_fresh_press = true
	if event.is_action_pressed("release_cursor"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		_head.rotation.x = clampf(
			_head.rotation.x - event.relative.y * MOUSE_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)


func _physics_process(delta: float) -> void:
	var crouched := Input.is_action_pressed("crouch")
	var speed := CROUCH_SPEED if crouched \
			else SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	var eye := CROUCH_EYE_HEIGHT if crouched else EYE_HEIGHT
	_head.position.y = move_toward(_head.position.y, eye, CROUCH_RATE * delta)

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") \
			if controls_enabled else Vector2.ZERO
	var direction := transform.basis * Vector3(input.x, 0.0, input.y)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if is_on_floor():
		if controls_enabled and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_SPEED
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_choose_target()
	if not controls_enabled:
		return
	if not Input.is_action_pressed("interact"):
		_fresh_press = false
	elif target and (target.hold_repeats or _fresh_press):
		_fresh_press = false
		target.interact()
	elif target:
		pass  # a machine already acted on this press
	elif _fresh_press:
		_fresh_press = false
		Inventory.set_feedback("Move within 3 m of an available resource to collect.")


func _choose_target() -> void:
	var eye := _head.global_position
	var best: Interactable = null
	var best_distance := REACH * REACH
	for area in _reach.get_overlapping_areas():
		var candidate := area as Interactable
		if candidate == null or candidate.interact_action().is_empty():
			continue
		var offset := candidate.global_position - eye
		var distance := offset.x * offset.x + offset.z * offset.z
		if distance <= best_distance:
			best = candidate
			best_distance = distance
	if best != target:
		target = best
		target_changed.emit(target)
