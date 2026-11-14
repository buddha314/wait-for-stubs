extends SceneTree
## The horizon and the moving sky (add-sky-motion-and-mountains):
## echoed seeded mountain rings, the travelling moon, and Sky3D's sun, stars and
## clouds moving with simulation time.
##   godot --headless --path . -s tests/test_sky.gd

const MOUNTAINS := "res://scenes/mountains/mountain_rings.tscn"
const MAIN := "res://scenes/main/main.tscn"
const SAMPLES := 720

var _failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_mountains()
	await _check_sky()
	if _failures.is_empty():
		print("test_sky: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: ", failure)
		quit(1)


func _check_mountains() -> void:
	var a := _rings()
	var b := _rings()
	var same := true
	for i in SAMPLES:
		var theta := TAU * i / SAMPLES
		for r in 3:
			same = same and a.ridge_height(r, theta) == b.ridge_height(r, theta)
	_expect(same, "same seed, same ridge heights")
	_expect(is_equal_approx(a.ridge_height(0, 0.0), a.ridge_height(0, TAU)), "skyline seam closes")

	# Ring 0 stays in stubby-music's 8–30 m at 480 m (about 1–3.6°).
	var low := INF
	var high := -INF
	for i in SAMPLES:
		var h := a.ridge_height(0, TAU * i / SAMPLES)
		low = minf(low, h)
		high = maxf(high, h)
	_expect(low >= 7.5 and high <= 31.0, "near ring 8–30 m (got %.1f–%.1f)" % [low, high])

	# Each ring is an attenuated, shifted echo of ring 0.
	var shift := deg_to_rad(a.echo_shift_degrees)
	for r in [1, 2]:
		var xs := PackedFloat64Array()
		var ys := PackedFloat64Array()
		for i in SAMPLES:
			var theta := TAU * i / SAMPLES
			xs.append(a.elevation_degrees(0, theta))
			ys.append(a.elevation_degrees(r, theta + r * shift))
		_expect(_correlation(xs, ys) > 0.99, "ring %d correlates with ring 0 shifted" % r)
		_expect(_range(ys) < _range(xs), "ring %d's amplitude is smaller" % r)
	# Every ring shows: a farther ring's ridge stands above the nearer one at most bearings.
	for r in [1, 2]:
		var above := 0
		for i in SAMPLES:
			var theta := TAU * i / SAMPLES
			if a.elevation_degrees(r, theta) > a.elevation_degrees(r - 1, theta):
				above += 1
		_expect(above > SAMPLES / 2, "ring %d shows over ring %d at most bearings (%d%%)" % [r, r - 1, above * 100 / SAMPLES])
	# Real echoes: 2R/c.
	for r in 3:
		var want: float = [2.80, 3.44, 4.08][r]
		_expect(absf(a.echo_delay(r) - want) / want < 0.01, "ring %d echo %.2f s" % [r, a.echo_delay(r)])
	a.free()
	b.free()


func _rings() -> MountainRings:
	var rings := (load(MOUNTAINS) as PackedScene).instantiate() as MountainRings
	root.add_child(rings)
	root.remove_child(rings)
	return rings


func _check_sky() -> void:
	var main := (load(MAIN) as PackedScene).instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	var calendar := root.get_node("Calendar")
	var moon := main.get_node("MoonPath") as MoonPath
	var start := moon.bearing_altitude_at(calendar.solar_hour())
	_expect(absf(start.x - 60.0) < 1.0 and absf(start.y - 20.0) < 1.0,
			"moon starts at bearing 60°, 20° up (got %.1f°, %.1f°)" % [start.x, start.y])
	var dir0 := moon.direction_at(calendar.solar_hour())
	var later: float = calendar.solar_hour() + 3.0
	_expect(is_equal_approx(moon.hour_angle_at(later) - moon.hour_angle_at(calendar.solar_hour()), deg_to_rad(45.0)),
			"3 simulated hours advance the hour angle 45°")
	_expect(rad_to_deg(dir0.angle_to(moon.direction_at(later))) > 20.0, "the moon travels more than 20° in 3 hours")
	# The data, not code: another start position.
	var other := MoonPath.horizontal(MoonPath.equatorial(deg_to_rad(100.0), deg_to_rad(10.0), deg_to_rad(37.0)).x,
			MoonPath.equatorial(deg_to_rad(100.0), deg_to_rad(10.0), deg_to_rad(37.0)).y, deg_to_rad(37.0))
	_expect(absf(rad_to_deg(asin(other.y)) - 10.0) < 0.5, "another start position round-trips")

	# The sky moves over 60 s of night: sun, stars, clouds and the moon on the dome.
	var dome: Node = main.get_node("Sky3D/SkyDome")
	var material: ShaderMaterial = dome.sky_material
	var before := [dome.sun_altitude, material.get_shader_parameter("star_rotation"),
			material.get_shader_parameter("cumulus_position"), dome.moon_altitude, dome.moon_azimuth]
	calendar.elapsed += 60.0
	for i in 30:
		await process_frame
	var after := [dome.sun_altitude, material.get_shader_parameter("star_rotation"),
			material.get_shader_parameter("cumulus_position"), dome.moon_altitude, dome.moon_azimuth]
	for i in ["sun", "stars", "clouds"].size():
		_expect(before[i] != after[i], "%s moved over a minute of night" % ["sun", "stars", "clouds"][i])
	_expect(before[3] != after[3] or before[4] != after[4], "the moon moved on the dome")
	main.queue_free()
	await process_frame


static func _correlation(xs: PackedFloat64Array, ys: PackedFloat64Array) -> float:
	var mx := 0.0
	var my := 0.0
	for i in xs.size():
		mx += xs[i]
		my += ys[i]
	mx /= xs.size()
	my /= ys.size()
	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for i in xs.size():
		sxy += (xs[i] - mx) * (ys[i] - my)
		sxx += (xs[i] - mx) * (xs[i] - mx)
		syy += (ys[i] - my) * (ys[i] - my)
	return sxy / sqrt(sxx * syy)


static func _range(values: PackedFloat64Array) -> float:
	var low := INF
	var high := -INF
	for v in values:
		low = minf(low, v)
		high = maxf(high, v)
	return high - low


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
