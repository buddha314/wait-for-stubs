class_name PatchCable
extends RefCounted
## Patch cable geometry, ported from VCV Rack via stubby-music
## (tools/blender/create_patch_cable.py cable_curve(), rack.rs tube()): a quadratic
## Bézier between two attach points, slumping downward with no fixed length, swept
## into a tube. Rebuild only when an end moves.

const PROFILE_PATH := "res://assets/cables/patch_plug/asset.json"
const SAMPLES := 24


static func profile() -> Dictionary:
	return AssetProfile.load_json(PROFILE_PATH)


static func color(name: String) -> Color:
	return Color.html(profile().colors.get(name, "#cfc6b2"))


## The VCV control point: midpoint + down × (1 − tension) × (slump_base + span).
static func control_point(a: Vector3, b: Vector3, down: Vector3 = Vector3.DOWN) -> Vector3:
	var cable: Dictionary = profile().cable
	var tension: float = cable.tension
	var slump: float = cable.slump_base_m
	return (a + b) / 2.0 + down * (1.0 - tension) * (slump + a.distance_to(b))


static func bezier(a: Vector3, c: Vector3, b: Vector3, samples: int = SAMPLES) -> PackedVector3Array:
	var points := PackedVector3Array()
	for i in samples + 1:
		var t := float(i) / samples
		points.append(a * (1.0 - t) * (1.0 - t) + c * 2.0 * (1.0 - t) * t + b * t * t)
	return points


## A tube along `points` with parallel-transported frames, so it never twists.
static func tube(points: PackedVector3Array, radius: float, sides: int = 0) -> ArrayMesh:
	if sides <= 0:
		sides = int(profile().cable.sides)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := points.size()
	var normal := Vector3.ZERO
	for i in count:
		var tangent := (points[mini(i + 1, count - 1)] - points[maxi(i - 1, 0)]).normalized()
		if tangent == Vector3.ZERO:
			tangent = Vector3.RIGHT
		if normal == Vector3.ZERO:
			normal = tangent.cross(Vector3.FORWARD if absf(tangent.z) < 0.9 else Vector3.UP).normalized()
		else:
			normal = (normal - tangent * normal.dot(tangent)).normalized()
		var side := tangent.cross(normal)
		for k in sides + 1:
			var angle := TAU * k / sides
			var direction := normal * cos(angle) + side * sin(angle)
			st.set_normal(direction)
			st.set_uv(Vector2(float(k) / sides, float(i) / (count - 1)))
			st.add_vertex(points[i] + direction * radius)
	var ring := sides + 1
	for i in count - 1:
		for k in sides:
			var a := i * ring + k
			var b := a + ring
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(b)
			st.add_index(a + 1)
			st.add_index(b + 1)
			st.add_index(b)
	return st.commit()
