class_name StreamBender
extends RefCounted
## Bends an authored 4 m stream asset onto a StreamPath (add-stream-building D4,
## ported from streams.rs `bend`). Each glTF mesh is read once into the asset's root
## space; bending maps a vertex's x in [0, 4] to arc length start .. start + span and
## places it at frame.origin + up·y + side·z. Normals, tangents and blend shapes (the
## staff's WaveSin/WaveCos) bend with the same frame, and the authored materials are
## kept. Bar_0 and Pulse_0 (the notes) are kept apart, unbent, for instancing.

const SEGMENT := "res://assets/streams/stream_segment/stream_segment.glb"
const HOLOGRAM := "res://assets/streams/stream_hologram/stream_hologram.glb"
## Frames come from the path's shared cache (1 cm of arc, StreamPath.cached_frame).

## Each piece: {name, mesh: ArrayMesh (root space), role: "body" | "halo_out" | "flow"}
## ("flow": the hologram's chevrons, re-bent with a shift to scroll).
var pieces: Array[Dictionary] = []
## Unbent meshes of named groups (for MultiMesh notes): group -> Array[{mesh, transform}]
## (transform relative to the group node), and each group node's place in the asset.
var groups: Dictionary = {}
var group_origins: Dictionary = {}


static func load_asset(path: String) -> StreamBender:
	var bender := StreamBender.new()
	var scene := (load(path) as PackedScene).instantiate() as Node3D
	bender._collect(scene, scene)
	scene.free()
	return bender


func _collect(root: Node3D, node: Node) -> void:
	for child in node.get_children():
		_collect(root, child)
	if not node is MeshInstance3D:
		return
	var mi := node as MeshInstance3D
	var to_root := _relative(root, mi)
	var role := "body"
	var group := ""
	for ancestor in ["Port_in_Halo", "Port_in_Ring", "Port_out_Halo", "Port_out_Ring", "Bar_0", "Pulse_0", "Flow"]:
		if _has_ancestor(mi, ancestor, root):
			group = ancestor
	match group:
		"Port_out_Halo", "Port_out_Ring":
			role = "halo_out"
		"Port_in_Halo", "Port_in_Ring":
			role = "skip"
		"Flow":
			role = "flow"
		"Bar_0", "Pulse_0":
			role = "skip"
			if not groups.has(group):
				groups[group] = []
				group_origins[group] = _relative(root, _find(root, group))
			groups[group].append({"mesh": mi.mesh, "transform": _relative(_find(root, group), mi)})
	if role == "skip":
		return
	pieces.append({"name": String(mi.name), "mesh": _baked(mi.mesh, to_root, mi), "role": role})


## A copy of `mesh` with `xform` applied to every vertex (root space), its materials
## (including surface overrides) set on the surfaces.
static func _baked(mesh: Mesh, xform: Transform3D, mi: MeshInstance3D) -> ArrayMesh:
	var out := ArrayMesh.new()
	var src := mesh as ArrayMesh
	if src:
		out.blend_shape_mode = src.blend_shape_mode
		for b in src.get_blend_shape_count():
			out.add_blend_shape(src.get_blend_shape_name(b))
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		_transform_arrays(arrays, xform, false)
		var shapes: Array = src.surface_get_blend_shape_arrays(s) if src else []
		for shape: Array in shapes:
			_transform_arrays(shape, xform, src.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_RELATIVE)
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays, shapes)
		var material := mi.get_surface_override_material(s)
		out.surface_set_material(s, material if material else mesh.surface_get_material(s))
	return out


static func _transform_arrays(arrays: Array, xform: Transform3D, offsets: bool) -> void:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if v.is_empty():
		return
	for i in v.size():
		v[i] = (xform.basis * v[i]) if offsets else (xform * v[i])
	arrays[Mesh.ARRAY_VERTEX] = v
	var normal_basis := xform.basis.inverse().transposed()
	if arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array and not arrays[Mesh.ARRAY_NORMAL].is_empty():
		var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in n.size():
			n[i] = (normal_basis * n[i]).normalized()
		arrays[Mesh.ARRAY_NORMAL] = n
	if arrays[Mesh.ARRAY_TANGENT] is PackedFloat32Array and not arrays[Mesh.ARRAY_TANGENT].is_empty():
		var t: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		for i in t.size() >> 2:
			var d := (xform.basis * Vector3(t[4 * i], t[4 * i + 1], t[4 * i + 2])).normalized()
			t[4 * i] = d.x
			t[4 * i + 1] = d.y
			t[4 * i + 2] = d.z
		arrays[Mesh.ARRAY_TANGENT] = t


## Bent copies of the pieces for one segment covering arc start .. start + span.
## `with_out_halo`: include the downstream port's halo (the last segment only).
func bend(path: StreamPath, start: float, span: float, with_out_halo: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for piece: Dictionary in pieces:
		if piece.role == "halo_out" and not with_out_halo:
			continue
		out.append({"name": piece.name, "mesh": bend_mesh(piece.mesh, path, start, span), "role": piece.role})
	return out


static func bend_mesh(source: ArrayMesh, path: StreamPath, start: float, span: float) -> ArrayMesh:
	var scale := span / StreamPath.SEGMENT_LENGTH
	var out := ArrayMesh.new()
	out.blend_shape_mode = source.blend_shape_mode
	for b in source.get_blend_shape_count():
		out.add_blend_shape(source.get_blend_shape_name(b))
	var relative := source.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_RELATIVE
	for s in source.get_surface_count():
		var arrays := source.surface_get_arrays(s)
		var base: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var frames: Array[Transform3D] = []
		frames.resize(base.size())
		for i in base.size():
			frames[i] = path.cached_frame(start + base[i].x * scale)
		_bend_arrays(arrays, frames, false)
		var shapes: Array = source.surface_get_blend_shape_arrays(s)
		for shape: Array in shapes:
			_bend_arrays(shape, frames, relative)
		out.add_surface_from_arrays(source.surface_get_primitive_type(s), arrays, shapes)
		out.surface_set_material(s, source.surface_get_material(s))
	return out


## Positions onto the frame (absolute) or rotated into it (relative offsets);
## normals and tangents rotate with the frame.
static func _bend_arrays(arrays: Array, frames: Array[Transform3D], offsets: bool) -> void:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in v.size():
		var f := frames[i]
		if offsets:
			v[i] = f.basis * v[i]
		else:
			v[i] = f.origin + f.basis * Vector3(0.0, v[i].y, v[i].z)
	arrays[Mesh.ARRAY_VERTEX] = v
	if arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array and not arrays[Mesh.ARRAY_NORMAL].is_empty():
		var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in n.size():
			n[i] = frames[i].basis * n[i]
		arrays[Mesh.ARRAY_NORMAL] = n
	if arrays[Mesh.ARRAY_TANGENT] is PackedFloat32Array and not arrays[Mesh.ARRAY_TANGENT].is_empty():
		var t: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		for i in t.size() >> 2:
			var d := frames[i].basis * Vector3(t[4 * i], t[4 * i + 1], t[4 * i + 2])
			t[4 * i] = d.x
			t[4 * i + 1] = d.y
			t[4 * i + 2] = d.z
		arrays[Mesh.ARRAY_TANGENT] = t


## `node`'s transform in `root`'s space. A part shipped hidden at scale 0 (the port
## halos, restored from `start_scale` at import) counts at its authored scale 1: the
## bent copy is shown or hidden instead.
static func _relative(root: Node3D, node: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			var t := (n as Node3D).transform
			if absf(t.basis.determinant()) < 1e-9:
				t.basis = Basis.from_euler((n as Node3D).rotation)
			xform = t * xform
		n = n.get_parent()
	return xform


static func _has_ancestor(node: Node, name_prefix: String, root: Node) -> bool:
	var n := node
	while n != null and n != root:
		if String(n.name).begins_with(name_prefix):
			return true
		n = n.get_parent()
	return false


static func _find(root: Node, name: String) -> Node3D:
	return root.find_child(name, true, false) as Node3D
