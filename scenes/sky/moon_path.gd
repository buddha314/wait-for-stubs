class_name MoonPath
extends Node
## Moves Sky3D's moon across the sky, fixed among the stars, as Calendar time
## passes (add-sky-motion-and-mountains D3). Sky3D's own moon modes either place the
## moon by date (REALISTIC: at latitude 37° it can never stand where the opening
## view wants it) or force its cruder SIMPLE sun, so this drives SkyDome's moon
## coordinates directly, with `compute_moon_coords` off. Visual only: nothing
## musical is timed from it.
##
## The start bearing and altitude (at the Calendar's start) fix the moon's
## declination and hour angle; after that it turns 15° of hour angle per simulated
## hour, like the star field. The default (bearing 60°, 20° up: 30° left of the
## spawn view, which faces east to the sunrise; add-compass-bar) needs a declination
## near 35°, so it climbs from the north-east through the night and is still up at
## dawn; a real moon has |declination| ≤ 28.6°.

## Where the moon is at the start, as a compass bearing (0 north, 90 east).
@export_range(0.0, 360.0, 0.5) var start_bearing_degrees := 60.0
## Where the moon is at the start, in degrees above the horizon.
@export_range(-90.0, 90.0, 0.5) var start_altitude_degrees := 20.0
@export var sky_dome_path: NodePath = ^"../Sky3D/SkyDome"
@export var time_of_day_path: NodePath = ^"../Sky3D/TimeOfDay"

var declination := 0.0
var _start_hour_angle := 0.0
var _start_solar_hour := 0.0
var _latitude := 0.0
var _dome: Node


func _ready() -> void:
	var time_of_day := get_node_or_null(time_of_day_path)
	_latitude = time_of_day.latitude if time_of_day else deg_to_rad(37.0)
	_dome = get_node_or_null(sky_dome_path)
	_start_solar_hour = get_node("/root/Calendar").solar_hour()
	var fixed := equatorial(deg_to_rad(start_bearing_degrees), deg_to_rad(start_altitude_degrees), _latitude)
	declination = fixed.x
	_start_hour_angle = fixed.y


func _process(_delta: float) -> void:
	if _dome == null or not _dome.is_scene_built:
		return
	var dir := direction_at(get_node("/root/Calendar").solar_hour())
	_dome.moon_altitude = acos(clampf(dir.y, -1.0, 1.0))
	_dome.moon_azimuth = atan2(dir.x, dir.z)
	_dome.update_moon_coords()


## The moon's hour angle (radians, positive west) at a solar hour.
func hour_angle_at(solar_hour: float) -> float:
	var hours := fposmod(solar_hour - _start_solar_hour, 24.0)
	return _start_hour_angle + deg_to_rad(15.0) * hours


## World direction to the moon (+X east, +Y up, −Z north) at a solar hour.
func direction_at(solar_hour: float) -> Vector3:
	return horizontal(declination, hour_angle_at(solar_hour), _latitude)


## Compass bearing and altitude of the moon at a solar hour, in degrees.
func bearing_altitude_at(solar_hour: float) -> Vector2:
	var dir := direction_at(solar_hour)
	return Vector2(fposmod(rad_to_deg(atan2(dir.x, -dir.z)), 360.0), rad_to_deg(asin(clampf(dir.y, -1.0, 1.0))))


## (declination, hour angle) of a point seen at `bearing` and `altitude` (radians).
static func equatorial(bearing: float, altitude: float, latitude: float) -> Vector2:
	var north := cos(altitude) * cos(bearing)
	var east := cos(altitude) * sin(bearing)
	var up := sin(altitude)
	var sin_dec := sin(latitude) * up + cos(latitude) * north
	var dec := asin(clampf(sin_dec, -1.0, 1.0))
	# up = sinφ sinδ + cosφ cosδ cosH; east = −cosδ sinH
	var cos_h := (up - sin(latitude) * sin_dec) / maxf(cos(latitude) * cos(dec), 1e-6)
	var sin_h := -east / maxf(cos(dec), 1e-6)
	return Vector2(dec, atan2(sin_h, cos_h))


## World direction for a declination and hour angle (radians) at a latitude.
static func horizontal(dec: float, hour_angle: float, latitude: float) -> Vector3:
	var up := sin(latitude) * sin(dec) + cos(latitude) * cos(dec) * cos(hour_angle)
	var north := cos(latitude) * sin(dec) - sin(latitude) * cos(dec) * cos(hour_angle)
	var east := -cos(dec) * sin(hour_angle)
	return Vector3(east, up, -north)
