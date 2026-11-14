extends CanvasLayer
## The common rack screen, opened by E on a MachineInteract (group "rack_screen",
## `open_rack(point)`). A Satisfactory-style window: title and header, the Relevant
## strip (left), the machine's rack in 3D (centre, RackView in its own world), the
## inventory grid (right) and key prompts. Ports stubby-music's machine_config.rs and
## rack.rs. The screen edits the machine's RackState and never talks to the audio
## engine. E or Esc closes it.
##
## Gestures (VCV Rack's): drag between jacks to patch; drag a cable off the comb, or
## click it to carry it; a cable in hand snaps to a jack within SNAP_PX; drag a
## plugged end to move it, or off any jack to unplug; right-click a plug to unplug it;
## drag or scroll a knob; drag an item onto its slot, click it, or press its number;
## right-click a module to remove it. A hint beside the pointer says what applies.
##
## A machine that opens a rack provides: rack_state, configure, knob_overrides(),
## rack_header() and bpm().

const SNAP_PX := 40.0
## Pixels of vertical drag for a knob's full range, and one scroll notch's share.
const KNOB_DRAG_PX := 240.0
const KNOB_SCROLL_STEP := 1.0 / 48.0
## A press that moves less than this is a click (carry the cable, don't drop it).
const CLICK_PX := 6.0
const PATCH_CABLE := "patch_cable"
const OWN_CABLE_COLOR := "bone"
const ICON_PATH := "res://assets/ui/icons/%s.png"
const SNAP_CLIPS := [
	"res://assets/audio/sfx/patch_snap/click_002.wav",
	"res://assets/audio/sfx/patch_snap/click_004.wav",
	"res://assets/audio/sfx/patch_snap/switch_001.wav",
]
const NOTICE_SECONDS := 2.0
const ITEM_ACTIONS := ["item_1", "item_2", "item_3", "item_4", "item_5",
		"item_6", "item_7", "item_8", "item_9", "item_10"]

## The machine whose rack is open, or null.
var machine: Node
var _relevant_items: Array[Dictionary] = []
## The knob being dragged: {place, param, start_norm, start_y} or {}.
var _knob_drag: Dictionary = {}
var _press_at := Vector2.ZERO
var _snap_index := 0
var _snap_ids: Array[int] = []  # sampler ids of SNAP_CLIPS, loaded on first use
var _notice_left := 0.0

@onready var _backdrop: ColorRect = $Backdrop
@onready var _title: Label = $Window/Rows/TitleBar/Title
@onready var _header: Label = $Window/Rows/TitleBar/Header
@onready var _relevant: GridContainer = $Window/Rows/Body/Left/Relevant
@onready var _grid: GridContainer = $Window/Rows/Body/Right/Grid
@onready var _centre: SubViewportContainer = $Window/Rows/Body/Rack/Centre
@onready var _view: RackView = $Window/Rows/Body/Rack/Centre/Viewport/RackView
## A transparent layer over the rack view that takes its mouse input and item drops.
## A SubViewportContainer forwards drag-and-drop into its SubViewport, so its own
## drop callbacks never run.
@onready var _input_layer: Control = $Window/Rows/Body/Rack/Input
@onready var _notice: Label = $Notice
## A helper line beside the pointer saying what the mouse would do here.
@onready var _hint: Label = $Hint


func _ready() -> void:
	add_to_group("rack_screen")
	visible = false
	var backdrop: Dictionary = AssetProfile.load_json(RackView.FRAME_PATH).get("screen", {}).get("backdrop", {})
	var material := _backdrop.material as ShaderMaterial
	material.set_shader_parameter("lod", log(float(backdrop.get("blur_px", 14.0))) / log(2.0))
	material.set_shader_parameter("dim_color", Color.html(backdrop.get("dim_color", "#0b0c10")))
	material.set_shader_parameter("dim", float(backdrop.get("dim", 0.55)))
	_input_layer.gui_input.connect(_on_rack_input)
	_input_layer.set_drag_forwarding(Callable(), _can_drop_item, _drop_item)
	_input_layer.mouse_exited.connect(func() -> void: _hint.visible = false)
	_centre.resized.connect(_view.fit)
	PlayerInventory.changed.connect(_refresh_items)


func open_rack(point: MachineInteract) -> void:
	machine = point.machine
	if machine == null or not "rack_state" in machine:
		push_error("RackScreen: %s has no rack_state" % point.machine)
		return
	var state: RackState = machine.rack_state
	_title.text = machine.configure.get("title", "MACHINE")
	_view.bpm_source = machine.bpm
	_view.phase_source = machine.beat_phase if machine.has_method("beat_phase") else Callable()
	_view.build(state, machine.configure, machine.knob_overrides())
	if not state.changed.is_connected(_on_state_changed):
		state.changed.connect(_on_state_changed)
	visible = true
	_view.set_process(true)
	_view.fit()
	_on_state_changed()
	_set_player_controls(false)


func close() -> void:
	_drop_held()
	_hint.visible = false
	if machine:
		var state: RackState = machine.rack_state
		if state.changed.is_connected(_on_state_changed):
			state.changed.disconnect(_on_state_changed)
	visible = false
	_view.set_process(false)
	machine = null
	_knob_drag = {}
	_set_player_controls(true)


func is_open() -> bool:
	return visible and machine != null


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("interact", false) or event.is_action_pressed("release_cursor"):
		get_viewport().set_input_as_handled()
		close()
		return
	for i in ITEM_ACTIONS.size():
		if event.is_action_pressed(ITEM_ACTIONS[i], false):
			get_viewport().set_input_as_handled()
			if i < _relevant_items.size():
				insert(_relevant_items[i].item)


func _process(delta: float) -> void:
	if _notice_left > 0.0:
		_notice_left -= delta
		_notice.visible = _notice_left > 0.0


func _state() -> RackState:
	return machine.rack_state


func _on_state_changed() -> void:
	if not is_open():
		return
	_header.text = machine.rack_header()
	_view.refresh()
	_refresh_items()


func show_notice(text: String) -> void:
	_notice.text = text
	_notice.visible = true
	_notice_left = NOTICE_SECONDS


# ------------------------------------------------------------------ items


## Items the player holds that an open place accepts, in place order.
func relevant_items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not is_open():
		return out
	for place: Dictionary in machine.configure.get("places", []):
		if place.get("fixed", false) or _state().mounted.has(place.place):
			continue
		for accept: Dictionary in place.get("accepts", []):
			if PlayerInventory.quantity(accept.item) > 0 and out.all(func(r: Dictionary) -> bool: return r.item != accept.item):
				out.append({"item": accept.item, "place": place.place, "module": accept.module})
	return out


## Mounts one `item` into the first open place that accepts it. True if mounted.
func insert(item: String, place_name: String = "") -> bool:
	for place: Dictionary in machine.configure.get("places", []):
		if place_name != "" and place.place != place_name:
			continue
		if place.get("fixed", false) or _state().mounted.has(place.place):
			continue
		for accept: Dictionary in place.get("accepts", []):
			if accept.item == item and PlayerInventory.take(item):
				_state().mount(place.place, accept.module)
				return true
	return false


## Unplugs the cable in `jack` ({place, port}) entirely: a comb cable hangs back on
## the comb, a player cable returns to the inventory (or stays plugged if the
## inventory is full). True if a cable was unplugged.
func unplug(jack: Dictionary) -> bool:
	if jack.is_empty():
		return false
	var cable := _state().cable_at(jack)
	if cable.is_empty():
		return false
	if cable.source == "inventory" and not PlayerInventory.give(PATCH_CABLE):
		show_notice("INVENTORY FULL")
		return true
	_state().remove_cable(cable)
	_play_snap()
	return true


## Removes a non-fixed module: unplugs its cables, returns its item. True if removed.
func remove(place_name: String) -> bool:
	var state := _state()
	var place := state.place_of(place_name)
	if place.is_empty() or place.get("fixed", false) or not state.mounted.has(place_name):
		return false
	var item := ""
	for accept: Dictionary in place.get("accepts", []):
		if accept.module == state.mounted[place_name]:
			item = accept.item
	if item != "" and not PlayerInventory.has_room(item):
		show_notice("INVENTORY FULL")
		return false
	for cable in state.unmount(place_name):
		if cable.source == "inventory":
			PlayerInventory.give(PATCH_CABLE)
	if item != "":
		PlayerInventory.give(item)
	return true


func _refresh_items() -> void:
	if not is_open():
		return
	_relevant_items = relevant_items()
	for child in _relevant.get_children():
		child.free()
	for i in _relevant_items.size():
		var item: String = _relevant_items[i].item
		var box := _item_box(item, PlayerInventory.quantity(item), str((i + 1) % 10))
		var button := Button.new()
		button.flat = true
		button.set_anchors_preset(Control.PRESET_FULL_RECT)
		button.pressed.connect(insert.bind(item))
		button.set_drag_forwarding(_drag_item.bind(item), Callable(), Callable())
		box.add_child(button)
		_relevant.add_child(box)
	for child in _grid.get_children():
		child.free()
	var held := PlayerInventory.items.keys()
	for i in PlayerInventory.STACKS:
		var box: Control
		if i < held.size():
			box = _item_box(held[i], PlayerInventory.quantity(held[i]), "")
			box.set_drag_forwarding(_drag_item.bind(held[i]), Callable(), Callable())
		else:
			box = _item_box("", 0, "")
		_grid.add_child(box)


func _item_box(item: String, count: int, key: String) -> Control:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(72, 72)
	box.tooltip_text = Rules.item_name(item) if item != "" else ""
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.06, 0.7)
	style.border_color = Color(1, 0.702, 0.314, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	box.add_theme_stylebox_override("panel", style)
	if item == "":
		return box
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(ICON_PATH % item):
		icon.texture = load(ICON_PATH % item)
	box.add_child(icon)
	var label := Label.new()
	label.text = ("[%s]" % key if key != "" else "") + "\n\nx%d" % count
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.906, 0.898, 0.867))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	return box


func _drag_item(_at: Vector2, item: String) -> Variant:
	var preview := TextureRect.new()
	if ResourceLoader.exists(ICON_PATH % item):
		preview.texture = load(ICON_PATH % item)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(56, 56)
	preview.size = Vector2(56, 56)
	preview.position = -preview.size / 2.0
	var holder := Control.new()
	holder.add_child(preview)
	_centre.set_drag_preview(holder)
	return ItemDrag.new(item)


func _can_drop_item(at: Vector2, data: Variant) -> bool:
	if data is not ItemDrag:
		return false
	var place := _view.place_at(_to_viewport(at))
	if place == "" or _state().mounted.has(place):
		return false
	for accept: Dictionary in _state().place_of(place).get("accepts", []):
		if accept.item == data.item:
			return true
	return false


func _drop_item(at: Vector2, data: Variant) -> void:
	insert(data.item, _view.place_at(_to_viewport(at)))


# ------------------------------------------------------------------ rack input


func _to_viewport(at: Vector2) -> Vector2:
	return at / float(_centre.stretch_shrink)


func _on_rack_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventMouseButton:
		var pixel := _to_viewport(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press(pixel)
			else:
				_release(pixel)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if not _view.held.is_empty():
				_drop_held()
			elif not unplug(_view.jack_at(pixel, _jack_radius_px())):
				remove(_view.place_at(pixel))
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var knob := _view.knob_at(pixel)
			if not knob.is_empty():
				var direction := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
				turn_knob(knob.place, knob.param, direction * KNOB_SCROLL_STEP)
		_update_hint(pixel, event.global_position)
		_input_layer.accept_event()
	elif event is InputEventMouseMotion:
		var pixel := _to_viewport(event.position)
		if not _knob_drag.is_empty():
			var norm: float = _knob_drag.start_norm + (_knob_drag.start_y - pixel.y) / KNOB_DRAG_PX
			_set_knob_norm(_knob_drag.place, _knob_drag.param, norm)
		if not _view.held.is_empty():
			_view.held.pointer = pixel
			_view.held.snap = _snap_target(pixel)
		_update_hint(pixel, event.global_position)
		_input_layer.accept_event()


## What the mouse would do at `pixel`, or "" if nothing.
func hint_at(pixel: Vector2) -> String:
	var held := _view.held
	if not held.is_empty():
		return "release on a jack to plug in  ·  [RMB] put the cable back"
	var jack := _view.jack_at(pixel, _jack_radius_px())
	if not jack.is_empty():
		if _state().is_patched(jack):
			return "[RMB] unplug  ·  drag to move the plug"
		return "drag to another jack to patch"
	if not _view.knob_at(pixel).is_empty():
		return "drag up/down or scroll to turn"
	if _view.comb_cable_at(pixel, 12.0) >= 0:
		return "drag or click to take the cable"
	var place := _view.place_at(pixel)
	if place != "" and _state().mounted.has(place) and not _state().place_of(place).get("fixed", false):
		return "[RMB] remove the module"
	return ""


func _update_hint(pixel: Vector2, screen_position: Vector2) -> void:
	_hint.text = hint_at(pixel)
	_hint.visible = _hint.text != ""
	_hint.position = screen_position + Vector2(18, 14)


func _press(pixel: Vector2) -> void:
	_press_at = pixel
	var held := _view.held
	if not held.is_empty():
		return  # carried cable: the release decides
	var knob := _view.knob_at(pixel)
	if not knob.is_empty():
		var spec := _view.knob_param(knob.place, knob.param)
		var value := _state().knob("%s/%s" % [knob.place, knob.param], RackView.knob_default(spec))
		_knob_drag = {"place": knob.place, "param": knob.param,
				"start_norm": RackModules.knob_norm(value, spec), "start_y": pixel.y}
		return
	var jack := _view.jack_at(pixel, _jack_radius_px())
	if not jack.is_empty():
		var cable := _state().cable_at(jack)
		if not cable.is_empty():
			# Pick up this end; the other stays plugged.
			_state().remove_cable(cable)
			var other: Dictionary = cable.to if RackState._same(cable.from, jack) else cable.from
			_hold({"color": cable.color, "source": cable.source, "anchor": other}, pixel)
		elif PlayerInventory.quantity(PATCH_CABLE) > 0:
			_hold({"color": OWN_CABLE_COLOR, "source": "inventory", "anchor": jack, "new": true}, pixel)
		else:
			show_notice("No patch cables")
		return
	var comb := _view.comb_cable_at(pixel, 12.0)
	if comb >= 0:
		var cables: Array = machine.configure.get("cables", [])
		_hold({"color": cables[comb].color, "source": "comb:%d" % comb, "anchor": {}}, pixel)


func _release(pixel: Vector2) -> void:
	if not _knob_drag.is_empty():
		_knob_drag = {}
		return
	var held := _view.held
	if held.is_empty():
		return
	var snap: Dictionary = _snap_target(pixel)
	var anchor: Dictionary = held.anchor
	if not snap.is_empty():
		if anchor.is_empty():
			held.anchor = snap  # first end plugged; the other follows the pointer
			held.snap = {}
			_play_snap()
			_view.refresh()
		else:
			_complete(held, anchor, snap)
		return
	if pixel.distance_to(_press_at) < CLICK_PX:
		return  # a click: keep carrying
	_drop_held()


## A jack the cable in hand can plug into near `pixel`, or {}.
func _snap_target(pixel: Vector2) -> Dictionary:
	var anchor: Dictionary = _view.held.get("anchor", {})
	return _view.jack_at(pixel, SNAP_PX, func(jack: Dictionary) -> bool:
		return can_plug(anchor, jack))


## True if a cable from `anchor` ({} for a free cable) can plug into `jack`.
func can_plug(anchor: Dictionary, jack: Dictionary) -> bool:
	var state := _state()
	var module: String = state.mounted.get(jack.place, "")
	var output := RackModules.is_output(module, jack.port)
	if not output and state.is_patched(jack):
		return false  # an input takes one cable
	if anchor.is_empty():
		return true
	if RackState._same(anchor, jack):
		return false
	var anchor_output := RackModules.is_output(state.mounted.get(anchor.place, ""), anchor.port)
	return anchor_output != output


func _complete(held: Dictionary, a: Dictionary, b: Dictionary) -> void:
	var state := _state()
	if held.get("new", false) and not PlayerInventory.take(PATCH_CABLE):
		show_notice("No patch cables")
		_view.held = {}
		_view.refresh()
		return
	var a_out := RackModules.is_output(state.mounted.get(a.place, ""), a.port)
	_view.held = {}
	state.add_cable({"color": held.color, "source": held.source,
			"from": a if a_out else b, "to": b if a_out else a})
	_play_snap()


func _hold(cable: Dictionary, pixel: Vector2) -> void:
	cable.pointer = pixel
	cable.snap = {}
	_view.held = cable
	_view.refresh()


## Lets go of the cable in hand: a comb cable hangs back on the comb; a player
## cable returns to the inventory (or stays where it was if the inventory is full).
func _drop_held() -> void:
	var held := _view.held
	if held.is_empty():
		return
	_view.held = {}
	if held.source == "inventory" and not held.get("new", false):
		if not PlayerInventory.give(PATCH_CABLE):
			show_notice("INVENTORY FULL")
	if machine:
		_view.refresh()


func _jack_radius_px() -> float:
	return maxf(10.0, 0.04 * _view.pixels_per_metre())


## The plug-in snap: one of the CC0 clips through the rack's sampler on the UI stem,
## so it shares the master clock and stays audible while paused (add-rack-audio-engine 5.5).
func _play_snap() -> void:
	if _snap_ids.is_empty():
		for path: String in SNAP_CLIPS:
			_snap_ids.append(RackServer.load_sample(load(path)))
	RackServer.play_sample(_snap_ids[_snap_index % _snap_ids.size()])
	_snap_index += 1


# ------------------------------------------------------------------ knobs


func turn_knob(place: String, param_name: String, turn: float) -> void:
	var spec := _view.knob_param(place, param_name)
	var key := "%s/%s" % [place, param_name]
	var norm := RackModules.knob_norm(_state().knob(key, RackView.knob_default(spec)), spec)
	var step: float = spec.get("step", 0.0)
	if step > 0.0:
		# A stepped knob moves at least one step per notch.
		var value := _state().knob(key, RackView.knob_default(spec)) + signf(turn) * step
		_state().set_knob(key, clampf(value, spec.min, spec.max))
		return
	_set_knob_norm(place, param_name, norm + turn)


func _set_knob_norm(place: String, param_name: String, norm: float) -> void:
	var spec := _view.knob_param(place, param_name)
	_state().set_knob("%s/%s" % [place, param_name], RackModules.knob_value(norm, spec))


func _set_player_controls(enabled: bool) -> void:
	for player: Player in get_tree().get_nodes_in_group("player"):
		player.controls_enabled = enabled
