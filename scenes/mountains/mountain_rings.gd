@tool
class_name MountainRings
extends Node3D
## Distant mountains enclosing the basin: seeded ridge rings, ported from
## stubby-music's setup() (three rings at 480 + 110·layer m). The nearest ring's
## skyline is a seeded waveform (whole-cycle harmonics plus gentle roughness), and
## each farther ring is an echo of it: shifted round the circle, smaller, a little
## higher in the view, hazier. They're real reflectors too, with echo delays of 2R/c
## (add-sky-motion-and-mountains). Generated at load and never saved into scenes.

## Harmonics (whole cycles round the ring, so the skyline closes seamlessly).
const HARMONICS := [3, 5, 8, 13]
## Value-noise knots round the ring for the roughness.
const ROUGH_KNOTS := 96
## How far below ground each ring starts, in metres.
const BASE_DEPTH := 3.0

@export var rings_id := "mountains":
	set(value):
		rings_id = value
		_regenerate()
@export_range(100.0, 3000.0, 10.0, "suffix:m") var radius := 480.0:
	set(value):
		radius = value
		_regenerate()
@export_range(10.0, 1000.0, 10.0, "suffix:m") var ring_spacing := 110.0:
	set(value):
		ring_spacing = value
		_regenerate()
@export_range(1, 6) var ring_count := 3:
	set(value):
		ring_count = value
		_regenerate()
@export_range(32, 1024) var segments := 384:
	set(value):
		segments = value
		_regenerate()
## The nearest ring's lowest and highest elevation, in degrees (stubby-music's
## 8–30 m at 480 m is about 1–3.6°).
@export var near_elevation_degrees := Vector2(1.0, 3.6):
	set(value):
		near_elevation_degrees = value
		_regenerate()
## Each echo shifts round the ring by this many degrees.
@export_range(0.0, 90.0, 0.5) var echo_shift_degrees := 14.0:
	set(value):
		echo_shift_degrees = value
		_regenerate()
## Each echo keeps this share of the previous ring's amplitude...
@export_range(0.1, 1.0, 0.01) var echo_decay := 0.62:
	set(value):
		echo_decay = value
		_regenerate()
## ...and its base stands this many degrees higher, so it shows over the nearer ring.
@export_range(0.0, 5.0, 0.05) var echo_rise_degrees := 1.1:
	set(value):
		echo_rise_degrees = value
		_regenerate()
## Ridge roughness, as a share of the waveform.
@export_range(0.0, 1.0, 0.01) var roughness := 0.22:
	set(value):
		roughness = value
		_regenerate()
@export var near_color := Color(0.18, 0.17, 0.20):
	set(value):
		near_color = value
		_regenerate()
## The colour the farthest ring fades toward (aerial perspective).
@export var haze_color := Color(0.42, 0.40, 0.44):
	set(value):
		haze_color = value
		_regenerate()

var _phases: PackedFloat64Array
var _knots: PackedFloat64Array


func _ready() -> void:
	_generate()


func _regenerate() -> void:
	if is_node_ready():
		_generate()


## Distance of ring `r` from the origin, in metres.
func ring_radius(r: int) -> float:
	return radius + r * ring_spacing


## The base waveform at angle θ (radians), normalised to about 0..1.
func waveform(theta: float) -> float:
	var sum := 0.0
	var norm := 0.0
	for k in HARMONICS.size():
		var amplitude := 1.0 / (k + 1)
		sum += amplitude * sin(HARMONICS[k] * theta + _phases[k])
		norm += amplitude
	var wave := sum / norm  # −1..1
	var rough := _rough(theta) * 2.0 - 1.0
	return clampf(0.5 + 0.5 * lerpf(wave, rough, roughness), 0.0, 1.0)


## Ring `r`'s ridge elevation angle at θ, in degrees: an echo of ring 0.
func elevation_degrees(r: int, theta: float) -> float:
	var low := near_elevation_degrees.x
	var span := near_elevation_degrees.y - near_elevation_degrees.x
	var amp := span * pow(echo_decay, r)
	var base := low + r * echo_rise_degrees
	return base + amp * waveform(theta - r * deg_to_rad(echo_shift_degrees))


## Ring `r`'s ridge height above ground at θ, in metres.
func ridge_height(r: int, theta: float) -> float:
	return ring_radius(r) * tan(deg_to_rad(elevation_degrees(r, theta)))


## Round-trip echo delay off ring `r`, in seconds, at `speed_of_sound` m/s.
func echo_delay(r: int, speed_of_sound: float = 343.0) -> float:
	return 2.0 * ring_radius(r) / speed_of_sound


func _generate() -> void:
	for child in get_children():
		child.free()
	var rng := WorldSeed.rng(rings_id)
	_phases = PackedFloat64Array()
	for k in HARMONICS.size():
		_phases.append(rng.randf_range(0.0, TAU))
	_knots = PackedFloat64Array()
	for i in ROUGH_KNOTS:
		_knots.append(rng.randf())
	for r in ring_count:
		var mesh := MeshInstance3D.new()
		mesh.name = "Ring%d" % r
		mesh.mesh = _ring_mesh(r)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		var t := float(r) / maxf(ring_count - 1, 1)
		material.albedo_color = near_color.lerp(haze_color, t * 0.75)
		material.roughness = 1.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material_override = material
		add_child(mesh)  # no owner: generated, never saved


func _ring_mesh(r: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radius_r := ring_radius(r)
	for i in segments + 1:
		var theta := TAU * i / segments
		var out := Vector3(cos(theta), 0.0, sin(theta))
		# Normals face the basin, so the rings catch the sun and moon from inside.
		st.set_normal(-out)
		st.set_uv(Vector2(float(i) / segments, 1.0))
		st.add_vertex(out * radius_r + Vector3.DOWN * BASE_DEPTH)
		st.set_normal(-out)
		st.set_uv(Vector2(float(i) / segments, 0.0))
		st.add_vertex(out * radius_r + Vector3.UP * ridge_height(r, theta))
	for i in segments:
		var a := i * 2
		st.add_index(a)
		st.add_index(a + 1)
		st.add_index(a + 2)
		st.add_index(a + 1)
		st.add_index(a + 3)
		st.add_index(a + 2)
	return st.commit()


## Smooth periodic value noise round the ring, 0..1.
func _rough(theta: float) -> float:
	var x := fposmod(theta / TAU, 1.0) * ROUGH_KNOTS
	var i := int(x) % ROUGH_KNOTS
	var f := x - floorf(x)
	var s := f * f * (3.0 - 2.0 * f)
	return lerpf(_knots[i], _knots[(i + 1) % ROUGH_KNOTS], s)
