## Drives the playable level's sun, moon, sky, ambient light, and light fog.
##
## The cycle is visual-only for now. It intentionally lives at the level shell
## layer so future maps can inherit the same rhythm and override only colors,
## speed, or light paths in the Inspector.
class_name DayNightCycle3D
extends Node

signal time_changed(hour: float, normalized_day: float)

@export_group("Clock")
## Enables the runtime clock. Disable to freeze lighting at `start_hour`.
@export var cycle_enabled := true
## Real seconds for one full in-game day.
@export_range(30.0, 7200.0, 1.0) var day_length_seconds := 600.0
## Initial in-game hour, from 0 to 24.
@export_range(0.0, 24.0, 0.1) var start_hour := 9.0
## Multiplier for temporary testing. Keep at 1.0 for normal playtests.
@export_range(0.0, 20.0, 0.1) var time_scale := 1.0
## Hour when sunlight starts rising.
@export_range(0.0, 24.0, 0.1) var sunrise_hour := 6.0
## Hour when sunlight falls below the horizon.
@export_range(0.0, 24.0, 0.1) var sunset_hour := 18.0

@export_group("Scene Paths")
@export var key_sun_path: NodePath = NodePath("../BasicLevelLighting/KeySun")
@export var sky_fill_path: NodePath = NodePath("../BasicLevelLighting/SkyFill")
@export var moon_path: NodePath = NodePath("../BasicLevelLighting/RimMoon")
@export var spawn_warmth_path: NodePath = NodePath("../BasicLevelLighting/SpawnWarmth")
@export var world_environment_path: NodePath = NodePath("../../../../WorldEnvironment")

@export_group("Sun And Moon")
## Horizontal direction for the noon sun. Adjust this to tune shadow direction.
@export_range(-180.0, 180.0, 1.0) var sun_azimuth_offset_degrees := 145.0
## Highest sun angle reached at noon.
@export_range(5.0, 85.0, 1.0) var sun_max_altitude_degrees := 58.0
## Lowest sun angle reached at midnight.
@export_range(-45.0, -1.0, 1.0) var sun_min_altitude_degrees := -16.0
@export var day_sun_color := Color(1.0, 0.86, 0.58, 1.0)
@export var dawn_sun_color := Color(1.0, 0.48, 0.22, 1.0)
@export var night_sun_color := Color(0.24, 0.34, 0.58, 1.0)
@export_range(0.0, 6.0, 0.05) var day_sun_energy := 2.45
@export_range(0.0, 2.0, 0.05) var dawn_sun_energy_boost := 0.42
@export_range(0.0, 2.0, 0.05) var night_moon_energy := 0.42

@export_group("Environment")
@export var day_sky_top := Color(0.25, 0.46, 0.82, 1.0)
@export var day_sky_horizon := Color(0.66, 0.76, 0.82, 1.0)
@export var dawn_sky_top := Color(0.18, 0.12, 0.28, 1.0)
@export var dawn_sky_horizon := Color(0.92, 0.42, 0.22, 1.0)
@export var night_sky_top := Color(0.018, 0.034, 0.058, 1.0)
@export var night_sky_horizon := Color(0.10, 0.13, 0.18, 1.0)
@export var day_ambient_color := Color(0.52, 0.58, 0.56, 1.0)
@export var night_ambient_color := Color(0.18, 0.23, 0.34, 1.0)
@export_range(0.0, 2.0, 0.01) var day_ambient_energy := 0.62
@export_range(0.0, 2.0, 0.01) var night_ambient_energy := 0.22
@export_range(0.0, 0.1, 0.0005) var day_fog_density := 0.004
@export_range(0.0, 0.1, 0.0005) var night_fog_density := 0.011

var _time_of_day := 0.0
var _key_sun: DirectionalLight3D
var _sky_fill: DirectionalLight3D
var _moon: DirectionalLight3D
var _spawn_warmth: OmniLight3D
var _world_environment: WorldEnvironment


func _ready() -> void:
	add_to_group("day_night_cycle")
	_time_of_day = fposmod(start_hour, 24.0)
	_cache_scene_nodes()
	_apply_cycle()


func _process(delta: float) -> void:
	if not cycle_enabled or day_length_seconds <= 0.0 or time_scale <= 0.0:
		return

	var hours_per_second := 24.0 / day_length_seconds
	set_time_of_day(_time_of_day + delta * hours_per_second * time_scale)


## Sets the current in-game hour and refreshes every driven visual.
func set_time_of_day(hour: float) -> void:
	_time_of_day = fposmod(hour, 24.0)
	_apply_cycle()
	time_changed.emit(_time_of_day, get_normalized_day())


## Returns the current in-game hour.
func get_time_of_day() -> float:
	return _time_of_day


## Returns 0.0 at midnight and approaches 1.0 before the next midnight.
func get_normalized_day() -> float:
	return _time_of_day / 24.0


func _cache_scene_nodes() -> void:
	_key_sun = get_node_or_null(key_sun_path) as DirectionalLight3D
	_sky_fill = get_node_or_null(sky_fill_path) as DirectionalLight3D
	_moon = get_node_or_null(moon_path) as DirectionalLight3D
	_spawn_warmth = get_node_or_null(spawn_warmth_path) as OmniLight3D
	_world_environment = get_node_or_null(world_environment_path) as WorldEnvironment


func _apply_cycle() -> void:
	var sun_height := _sun_height()
	var day_factor := _smooth_factor(0.0, 0.18, maxf(sun_height, 0.0))
	var moon_factor := _smooth_factor(0.0, 0.22, maxf(-sun_height, 0.0))
	var dawn_factor := maxf(
		_time_bell(sunrise_hour, 1.4),
		_time_bell(sunset_hour, 1.4)
	)

	_apply_directional_lights(sun_height, day_factor, moon_factor, dawn_factor)
	_apply_spawn_warmth(moon_factor)
	_apply_environment(day_factor, moon_factor, dawn_factor)


func _apply_directional_lights(
	sun_height: float,
	day_factor: float,
	moon_factor: float,
	dawn_factor: float
) -> void:
	var sun_altitude := lerpf(sun_min_altitude_degrees, sun_max_altitude_degrees, clampf((sun_height + 1.0) * 0.5, 0.0, 1.0))
	var sun_azimuth := sun_azimuth_offset_degrees + get_normalized_day() * 360.0
	var moon_altitude := lerpf(sun_min_altitude_degrees, 48.0, moon_factor)
	var moon_azimuth := sun_azimuth + 180.0

	if _key_sun != null:
		_orient_directional_light(_key_sun, sun_altitude, sun_azimuth)
		var daylight_color := day_sun_color.lerp(dawn_sun_color, dawn_factor)
		_key_sun.light_color = night_sun_color.lerp(daylight_color, day_factor)
		_key_sun.light_energy = maxf(
			day_sun_energy * day_factor,
			dawn_sun_energy_boost * dawn_factor
		)
		_key_sun.shadow_enabled = _key_sun.light_energy > 0.08

	if _sky_fill != null:
		_sky_fill.light_color = night_ambient_color.lerp(day_ambient_color, day_factor)
		_sky_fill.light_energy = lerpf(0.08, 0.26, day_factor)

	if _moon != null:
		_orient_directional_light(_moon, moon_altitude, moon_azimuth)
		_moon.light_energy = night_moon_energy * moon_factor


func _apply_spawn_warmth(moon_factor: float) -> void:
	if _spawn_warmth == null:
		return

	_spawn_warmth.light_energy = lerpf(0.32, 0.74, moon_factor)
	_spawn_warmth.light_color = Color(1.0, 0.66, 0.36, 1.0)


func _apply_environment(day_factor: float, moon_factor: float, dawn_factor: float) -> void:
	if _world_environment == null or _world_environment.environment == null:
		return

	var environment := _world_environment.environment
	var sky_top := night_sky_top.lerp(day_sky_top, day_factor).lerp(dawn_sky_top, dawn_factor * 0.65)
	var sky_horizon := night_sky_horizon.lerp(day_sky_horizon, day_factor).lerp(dawn_sky_horizon, dawn_factor)
	var ambient_color := night_ambient_color.lerp(day_ambient_color, day_factor)

	environment.background_color = sky_horizon
	environment.ambient_light_color = ambient_color
	environment.ambient_light_energy = lerpf(night_ambient_energy, day_ambient_energy, day_factor)
	environment.fog_light_color = sky_horizon
	environment.fog_light_energy = lerpf(0.16, 0.32, day_factor)
	environment.fog_density = lerpf(day_fog_density, night_fog_density, moon_factor)
	environment.tonemap_exposure = lerpf(0.92, 1.16, day_factor)

	var sky := environment.sky
	if sky == null or sky.sky_material == null:
		return

	var sky_material := sky.sky_material as ProceduralSkyMaterial
	if sky_material == null:
		return

	sky_material.sky_top_color = sky_top
	sky_material.sky_horizon_color = sky_horizon
	sky_material.ground_bottom_color = Color(0.025, 0.04, 0.035, 1.0).lerp(Color(0.08, 0.14, 0.09, 1.0), day_factor)
	sky_material.ground_horizon_color = Color(0.06, 0.08, 0.075, 1.0).lerp(Color(0.16, 0.24, 0.14, 1.0), day_factor)
	sky_material.sky_energy_multiplier = lerpf(0.42, 1.18, day_factor)


func _orient_directional_light(light: DirectionalLight3D, altitude_degrees: float, azimuth_degrees: float) -> void:
	var altitude := deg_to_rad(altitude_degrees)
	var azimuth := deg_to_rad(azimuth_degrees)
	var direction := Vector3(
		cos(altitude) * sin(azimuth),
		-sin(altitude),
		cos(altitude) * cos(azimuth)
	).normalized()
	if direction.length_squared() <= 0.0001:
		return

	light.look_at(light.global_position + direction, Vector3.UP)


func _sun_height() -> float:
	var daylight_length := maxf(sunset_hour - sunrise_hour, 0.1)
	var phase := ((_time_of_day - sunrise_hour) / daylight_length) * PI
	return sin(phase)


func _time_bell(center_hour: float, width_hours: float) -> float:
	if width_hours <= 0.0:
		return 0.0

	var distance := _hour_distance(_time_of_day, center_hour)
	return 1.0 - _smooth_factor(0.0, width_hours, distance)


func _hour_distance(a: float, b: float) -> float:
	return absf(fposmod(a - b + 12.0, 24.0) - 12.0)


func _smooth_factor(edge_0: float, edge_1: float, value: float) -> float:
	if is_equal_approx(edge_0, edge_1):
		return 0.0

	var t := clampf((value - edge_0) / (edge_1 - edge_0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
