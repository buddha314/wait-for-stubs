class_name WorldSeed
extends RefCounted
## The world seed. The same seed always produces the same world.
## Override at launch with `godot --path . -- --seed=7`.

const DEFAULT := 42

static var _value: int = DEFAULT
static var _resolved := false


static func value() -> int:
	if not _resolved:
		_resolved = true
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--seed="):
				_value = arg.trim_prefix("--seed=").to_int()
	return _value


## A generator for one instance, stable for (world seed, key). Never use the
## global randf()/randi(): they are not reproducible.
static func rng(key: String) -> RandomNumberGenerator:
	var generator := RandomNumberGenerator.new()
	generator.seed = hash("%d:%s" % [value(), key])
	return generator
