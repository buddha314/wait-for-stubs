class_name StreamPath
extends RefCounted
## A stream's centre line (add-stream-building D3, ported from stubby-music's
## streams.rs Path): a cubic Bézier that leaves its port along the port's flow
## direction and curves to the aim point, held in a Curve3D whose baked arc-length
## table gives every position along it. The frame is horizontal (flow direction, Y up,
## side = flow × up), so it can't flip.

const SEGMENT_LENGTH := 4.0
const MAX_PLAN := 32.0
const MIN_RADIUS := 2.0

var curve := Curve3D.new()
var points: PackedVector3Array
## Frames by arc length in FRAME_STEP steps, shared by every mesh bent onto this path.
var _frames := {}
const FRAME_STEP := 0.01


## From `from` (leaving along `direction`) to `to` (kept at the port's height).
static func plan(from: Vector3, direction: Vector3, to: Vector3) -> StreamPath:
	var path := StreamPath.new()
	var d0 := Vector3(direction.x, 0.0, direction.z).normalized()
	if d0.is_zero_approx():
		d0 = Vector3.RIGHT
	var p0 := from
	var p3 := Vector3(to.x, from.y, to.z)
	var reach := p0.distance_to(p3)
	var p1 := p0 + d0 * reach / 3.0
	var d1 := (p3 - p1).normalized() if not (p3 - p1).is_zero_approx() else d0
	var p2 := p3 - d1 * reach / 3.0
	path.points = PackedVector3Array([p0, p1, p2, p3])
	path.curve.bake_interval = 0.05
	path.curve.add_point(p0, Vector3.ZERO, p1 - p0)
	path.curve.add_point(p3, p2 - p3, Vector3.ZERO)
	return path


func length() -> float:
	return curve.get_baked_length()


## [position, flow direction] at arc length `s`, extended straight past either end.
func at(s: float) -> Array:
	var total := length()
	var clamped := clampf(s, 0.0, total)
	var p := curve.sample_baked(clamped, true)
	var d := direction(clamped)
	return [p + d * (s - clamped), d]


## The horizontal flow direction at arc length `s`.
func direction(s: float) -> Vector3:
	var total := length()
	var h := 0.02
	var a := curve.sample_baked(clampf(s - h, 0.0, total), true)
	var b := curve.sample_baked(clampf(s + h, 0.0, total), true)
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	if d.length_squared() < 1e-10:
		d = Vector3(points[1].x - points[0].x, 0.0, points[1].z - points[0].z)
	return d.normalized() if not d.is_zero_approx() else Vector3.RIGHT


## The local frame at `s`: x along the flow, y up, z to the side (flow × up).
func frame(s: float) -> Transform3D:
	var pd := at(s)
	var d: Vector3 = pd[1]
	return Transform3D(Basis(d, Vector3.UP, d.cross(Vector3.UP)), pd[0])


## The frame at the nearest FRAME_STEP of arc length (cached).
func cached_frame(s: float) -> Transform3D:
	var key := roundi(s / FRAME_STEP)
	var f: Variant = _frames.get(key)
	if f == null:
		f = frame(key * FRAME_STEP)
		_frames[key] = f
	return f


## The tightest bend radius along the path (64 steps, as streams.rs).
func min_radius() -> float:
	var steps := 64
	var ds := length() / steps
	var smallest := INF
	var previous := direction(0.0)
	for i in range(1, steps + 1):
		var d := direction(ds * i)
		var angle := previous.angle_to(d)
		if angle > 1e-4:
			smallest = minf(smallest, ds / angle)
		previous = d
	return smallest


## Whole segments along it: max(1, round(L / 4)).
func segment_count() -> int:
	return maxi(1, roundi(length() / SEGMENT_LENGTH))


## A buildable shape: at least 3/4 of a segment and no bend tighter than 2 m.
func shape_ok() -> bool:
	return length() >= SEGMENT_LENGTH * 0.75 and min_radius() >= MIN_RADIUS


## The point on the path nearest `p` (global), for the voice and for sinks.
func closest_point(p: Vector3) -> Vector3:
	return curve.get_closest_point(p)
