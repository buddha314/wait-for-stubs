extends SceneTree
## The targeted pickup's outline (add-collectible-outline): only the target is
## outlined, it moves with the target, collection / screens / build mode clear it,
## an uncollectable target is still outlined, a bug between flashes shows a dark body
## for it, and the colour comes from the data file.
##   godot --headless --path . -s tests/test_collectible_outline.gd

const PLAYER := "res://scenes/player/player.tscn"
const SETTINGS := "res://assets/ui/collectible_outline.json"

var _failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var floor := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	floor.add_child(floor_shape)
	root.add_child(floor)

	var clump: Node3D = load("res://assets/flora/reeds/reed_clump.tscn").instantiate()
	clump.instance_id = "reed_clump-outline-test"
	var shell: Node3D = load("res://assets/creatures/snail_shell/snail_shell.tscn").instantiate()
	shell.instance_id = "snail_shell-outline-test"
	var bug: Node3D = load("res://assets/creatures/lightning_bug/lightning_bug.tscn").instantiate()
	bug.instance_id = "lightning_bug-outline-test"
	root.add_child(clump)
	root.add_child(shell)
	root.add_child(bug)
	clump.position = Vector3(1.0, 0.0, 0.0)
	shell.position = Vector3(20.0, 0.0, 0.0)
	bug.position = Vector3(40.0, 0.0, 0.0)

	var player: Node3D = (load(PLAYER) as PackedScene).instantiate()
	root.add_child(player)
	var outline: Node = player.get_node("CollectibleOutline")
	var clump_pickup: Node = clump.get_node("Pickup")
	var shell_pickup: Node = shell.get_node("Pickup")
	var bug_pickup: Node = bug.get_node("Pickup")

	await _stand(player, Vector3.ZERO)
	_expect(outline.outlined == clump_pickup, "the targeted reed clump is outlined")
	_expect(_overlaid(clump_pickup) and not _overlaid(shell_pickup), "only the target's meshes carry the outline")
	var expected := Color.html(AssetProfile.load_json(SETTINGS).color)
	var material: StandardMaterial3D = clump_pickup.outline_meshes()[0].material_overlay
	if material == null:
		material = StandardMaterial3D.new()  # already failed above; keep going
	_expect(material.stencil_mode == BaseMaterial3D.STENCIL_MODE_OUTLINE, "a stencil outline")
	_expect(material.stencil_color.is_equal_approx(expected), "colour from the data file (%s)" % material.stencil_color.to_html())
	_expect(material.stencil_outline_thickness > 0.0, "a visible thickness")
	_expect(clump_pickup.outline_meshes().all(func(m: MeshInstance3D) -> bool: return not m.name.contains("Stubble")), "the stubble is never outlined")

	await _stand(player, Vector3(19.0, 0.0, 0.0))
	_expect(outline.outlined == shell_pickup and _overlaid(shell_pickup) and not _overlaid(clump_pickup), "turning to the shell moves the outline")

	# The crosshair wins over distance: a clump nearer than the shell, the view on the shell.
	clump.position = Vector3(18.6, 0.0, 0.0)
	await _stand(player, Vector3(19.0, 0.0, 1.5))
	_aim(player, shell_pickup.global_position)
	await _stand(player, Vector3(19.0, 0.0, 1.5))
	_expect(player.target == shell_pickup, "the shell under the crosshair is the target, not the nearer clump")
	_aim(player, player.global_position + Vector3(0.0, 10.0, -1.0))
	await _stand(player, Vector3(19.0, 0.0, 1.5))
	_expect(player.target == clump_pickup, "looking at the sky, the nearest pickup is the target")
	clump.position = Vector3(1.0, 0.0, 0.0)
	player.rotation = Vector3.ZERO
	player.get_node("Head").rotation = Vector3.ZERO

	player.controls_enabled = false
	await process_frame
	await process_frame
	_expect(outline.outlined == null and not _overlaid(shell_pickup), "no outline while a screen has the controls")
	player.controls_enabled = true
	await process_frame
	await process_frame
	_expect(outline.outlined == shell_pickup, "back when the screen closes")

	player.building = true
	await _stand(player, Vector3(19.0, 0.0, 0.0))
	_expect(outline.outlined == null, "no outline in build mode")
	player.building = false

	await _stand(player, Vector3(19.0, 0.0, 0.0))
	shell_pickup.interact()
	await process_frame
	await process_frame
	_expect(shell_pickup.collected and outline.outlined == null and not _overlaid(shell_pickup), "collecting clears the outline")

	# A sound with the recorder put away: still outlined; the tip explains why.
	player.get_node("Head/Hand").held = &""
	await _stand(player, Vector3(39.0, 0.0, 0.0))
	_expect(outline.outlined == bug_pickup, "an uncollectable bug is still outlined")
	var model: Node3D = bug.get_node("Body/Model")
	_expect(bug.get_node("Body").visible and model.scale.is_equal_approx(Vector3.ONE), "a targeted bug keeps its body for the outline")
	_expect(bug_pickup.outline_meshes().all(func(m: MeshInstance3D) -> bool: return m.material_override != null) \
			or bug.pending_flashes() > 0, "between flashes it's a dark silhouette")

	await _stand(player, Vector3(60.0, 0.0, 0.0))
	_expect(outline.outlined == null and not _overlaid(bug_pickup), "walking away clears the outline")
	_expect(not bug.get_node("Body").visible or bug.flashes > 0, "the untargeted bug goes dark again")

	if _failures.is_empty():
		print("test_collectible_outline: OK")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		quit(1)


func _stand(player: Node3D, at: Vector3) -> void:
	player.global_position = at
	for i in 4:
		await physics_frame
	# process_frame fires before nodes process: wait past one full process step.
	await process_frame
	await process_frame


func _aim(player: Node3D, at: Vector3) -> void:
	var head: Node3D = player.get_node("Head")
	var offset := at - head.global_position
	player.rotation.y = atan2(-offset.x, -offset.z)
	head.rotation.x = atan2(offset.y, Vector2(offset.x, offset.z).length())


func _overlaid(pickup: Node) -> bool:
	var meshes: Array = pickup.outline_meshes()
	return meshes.size() > 0 and meshes.all(func(m: MeshInstance3D) -> bool: return m.material_overlay != null)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
