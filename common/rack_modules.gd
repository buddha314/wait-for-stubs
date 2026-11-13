class_name RackModules
extends RefCounted
## Module profiles (assets/modules/<id>/asset.json) as the rack reads them: ports,
## knob parameters and their tapers, the seven-segment display. Ports
## stubby-music's synth_modules.rs (knob_angle, lit_segments) and rack.rs
## (knob_norm, knob_value).

## Width of one HP at the modules' ×10 scale, in metres.
const HP_METRES := 0.0508


static func profile(module: String) -> Dictionary:
	return AssetProfile.load_json("res://assets/modules/%s/asset.json" % module)


static func model_path(module: String) -> String:
	return "res://assets/models/modules/%s.glb" % module


## The port entry ({node, port, direction}) or {}.
static func port(module: String, port_name: String) -> Dictionary:
	for entry: Dictionary in profile(module).get("ports", []):
		if entry.port == port_name:
			return entry
	return {}


static func is_output(module: String, port_name: String) -> bool:
	return port(module, port_name).get("direction", "") == "out"


## The knob parameter entry, with any machine override ({min, max, step}) applied.
static func param(module: String, param_name: String, override: Dictionary = {}) -> Dictionary:
	for entry: Dictionary in profile(module).get("params", []):
		if entry.param == param_name:
			var merged := entry.duplicate()
			merged.merge(override, true)
			return merged
	return {}


## A value's position along its knob, 0..1, following the knob's taper.
static func knob_norm(value: float, p: Dictionary) -> float:
	var lo: float = p.min
	var hi: float = p.max
	var v := clampf(value, lo, hi)
	if p.get("taper", "linear") == "log" and lo > 0.0:
		return log(v / lo) / log(hi / lo)
	return (v - lo) / (hi - lo)


## The value at a position along a knob, 0..1, snapped to the knob's step if any.
static func knob_value(norm: float, p: Dictionary) -> float:
	var n := clampf(norm, 0.0, 1.0)
	var lo: float = p.min
	var hi: float = p.max
	var v := lo * pow(hi / lo, n) if p.get("taper", "linear") == "log" and lo > 0.0 \
			else lerpf(lo, hi, n)
	var step: float = p.get("step", 0.0)
	return clampf(snappedf(v, step), lo, hi) if step > 0.0 else v


## Knob angle in radians, clockwise positive seen from the front.
static func knob_angle(value: float, p: Dictionary) -> float:
	return (knob_norm(value, p) - 0.5) * deg_to_rad(p.get("rotation_degrees", 300.0))


## [[digit, segment], ...] lit for a value on a right-aligned display.
static func lit_segments(value: float, display: Dictionary) -> Array:
	var digits := int(display.digits)
	var top := int(pow(10, digits)) - 1
	var text := str(clampi(roundi(maxf(value, 0.0)), 0, top)).lpad(digits)
	var table: Dictionary = display.digit_segments
	var lit := []
	for d in digits:
		for segment: String in table.get(text[d], ""):
			lit.append([d, segment])
	return lit
