## Hostile ground warning for mob abilities.
##
## Mobs spawn this during ability wind-up so players can read incoming danger
## before impact. Geometry is generated at runtime to keep ability data simple.
class_name AbilityTelegraph3D
extends Node3D

const KIND_NONE := &"none"
const KIND_CIRCLE := &"circle"
const KIND_DIRECTION := &"direction"
const KIND_SWING := &"swing"

@export var fill_color := Color(1.0, 0.05, 0.02, 0.28)
@export var outline_color := Color(1.0, 0.14, 0.04, 0.88)
@export_range(0.0, 0.5, 0.005) var ground_offset := 0.09
@export_range(12, 96, 1) var circle_segments := 64
@export_range(0.02, 0.5, 0.01) var outline_width := 0.08

var _outline_mesh: MeshInstance3D
var _fill_mesh: MeshInstance3D
var _follow_target: Node3D
var _remaining_seconds := 0.0
var _duration_seconds := 0.0
var _elapsed_seconds := 0.0
var _kind: StringName = KIND_NONE
var _swing_radius := 0.0
var _swing_start_angle := -PI
var _swing_end_angle := 0.0
var _swing_progress := 0.0


func _ready() -> void:
	_ensure_nodes()
	hide_telegraph()


func _process(delta: float) -> void:
	var elapsed_delta := maxf(delta, 0.0)
	if _follow_target != null and is_instance_valid(_follow_target):
		_set_ground_position(_follow_target.global_position)

	if _kind == KIND_SWING:
		_elapsed_seconds = minf(_elapsed_seconds + elapsed_delta, _duration_seconds)
		_update_swing_fill()

	_remaining_seconds = maxf(_remaining_seconds - elapsed_delta, 0.0)
	if _remaining_seconds <= 0.0:
		hide_telegraph()


func show_following_circle(target: Node3D, radius: float, duration_seconds: float) -> void:
	if target == null:
		return

	_ensure_nodes()
	_kind = KIND_CIRCLE
	_follow_target = target
	_set_duration(duration_seconds)
	_set_ground_position(target.global_position)
	rotation = Vector3.ZERO
	_rebuild_circle(maxf(radius, 0.15))
	visible = true
	set_process(true)


func show_circle(center: Vector3, radius: float, duration_seconds: float) -> void:
	_ensure_nodes()
	_kind = KIND_CIRCLE
	_follow_target = null
	_set_duration(duration_seconds)
	_set_ground_position(center)
	rotation = Vector3.ZERO
	_rebuild_circle(maxf(radius, 0.15))
	visible = true
	set_process(true)


func show_direction(origin: Vector3, direction: Vector3, distance: float, width: float, duration_seconds: float) -> void:
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	if flat_direction.length_squared() <= 0.0001:
		return

	_ensure_nodes()
	_kind = KIND_DIRECTION
	_follow_target = null
	_set_duration(duration_seconds)
	_set_ground_position(origin)
	flat_direction = flat_direction.normalized()
	rotation.y = atan2(-flat_direction.x, -flat_direction.z)
	_rebuild_direction(maxf(distance, 0.4), maxf(width, 0.2))
	visible = true
	set_process(true)


func show_swing_arc(
	origin: Vector3,
	direction: Vector3,
	radius: float,
	duration_seconds: float,
	arc_degrees: float = 180.0,
	reverse_fill: bool = false
) -> void:
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	if flat_direction.length_squared() <= 0.0001:
		return

	_ensure_nodes()
	_kind = KIND_SWING
	_follow_target = null
	_set_duration(duration_seconds)
	_swing_radius = maxf(radius, 0.35)
	var half_arc := deg_to_rad(clampf(arc_degrees, 20.0, 360.0)) * 0.5
	if reverse_fill:
		_swing_start_angle = -PI * 0.5 + half_arc
		_swing_end_angle = -PI * 0.5 - half_arc
	else:
		_swing_start_angle = -PI * 0.5 - half_arc
		_swing_end_angle = -PI * 0.5 + half_arc
	_swing_progress = 0.0
	_set_ground_position(origin)
	flat_direction = flat_direction.normalized()
	rotation.y = atan2(-flat_direction.x, -flat_direction.z)
	_outline_mesh.mesh = _make_arc_band_mesh(
		_swing_start_angle,
		_swing_end_angle,
		_swing_radius,
		maxf(_swing_radius - outline_width, 0.01),
		outline_color
	)
	_update_swing_fill()
	visible = true
	set_process(true)


func hide_telegraph() -> void:
	visible = false
	_follow_target = null
	_remaining_seconds = 0.0
	_duration_seconds = 0.0
	_elapsed_seconds = 0.0
	_kind = KIND_NONE
	_swing_progress = 0.0
	set_process(false)


func is_showing() -> bool:
	return visible


func get_telegraph_kind() -> StringName:
	return _kind


func get_fill_progress() -> float:
	return _swing_progress if _kind == KIND_SWING else 1.0


func get_swing_fill_direction() -> float:
	return signf(_swing_end_angle - _swing_start_angle) if _kind == KIND_SWING else 0.0


func _ensure_nodes() -> void:
	if _outline_mesh != null and is_instance_valid(_outline_mesh):
		return

	_outline_mesh = MeshInstance3D.new()
	_outline_mesh.name = "Outline"
	_outline_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_outline_mesh)

	_fill_mesh = MeshInstance3D.new()
	_fill_mesh.name = "Fill"
	_fill_mesh.position.y = 0.006
	_fill_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fill_mesh)


func _set_ground_position(world_position: Vector3) -> void:
	global_position = Vector3(world_position.x, world_position.y + ground_offset, world_position.z)


func _set_duration(duration_seconds: float) -> void:
	_duration_seconds = maxf(duration_seconds, 0.05)
	_remaining_seconds = _duration_seconds
	_elapsed_seconds = 0.0
	_swing_progress = 0.0


func _rebuild_circle(radius: float) -> void:
	var fill := CylinderMesh.new()
	fill.top_radius = radius
	fill.bottom_radius = radius
	fill.height = 0.012
	fill.radial_segments = maxi(circle_segments, 12)
	fill.material = _make_material(fill_color)
	_fill_mesh.mesh = fill
	_outline_mesh.mesh = _make_ring_mesh(radius + outline_width * 0.5, radius, outline_color)


func _rebuild_direction(distance: float, width: float) -> void:
	_outline_mesh.mesh = _make_arrow_mesh(distance, width * 1.14, outline_color)
	_fill_mesh.mesh = _make_arrow_mesh(maxf(distance - 0.04, 0.4), width, fill_color)


func _update_swing_fill() -> void:
	if _duration_seconds <= 0.0:
		_swing_progress = 1.0
	else:
		_swing_progress = clampf(_elapsed_seconds / _duration_seconds, 0.0, 1.0)

	var fill_end_angle := lerpf(_swing_start_angle, _swing_end_angle, _swing_progress)
	_fill_mesh.mesh = _make_sector_mesh(_swing_start_angle, fill_end_angle, _swing_radius, fill_color)


func _make_ring_mesh(outer_radius: float, inner_radius: float, color: Color) -> ArrayMesh:
	var safe_segments := maxi(circle_segments, 12)
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for index in range(safe_segments):
		var current_angle := TAU * float(index) / float(safe_segments)
		var next_angle := TAU * float(index + 1) / float(safe_segments)
		var vertex_start := vertices.size()
		vertices.append(_ring_point(outer_radius, current_angle))
		vertices.append(_ring_point(outer_radius, next_angle))
		vertices.append(_ring_point(inner_radius, next_angle))
		vertices.append(_ring_point(inner_radius, current_angle))
		indices.append_array([
			vertex_start,
			vertex_start + 1,
			vertex_start + 2,
			vertex_start,
			vertex_start + 2,
			vertex_start + 3,
		])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _make_material(color))
	return mesh


func _make_arc_band_mesh(
	start_angle: float,
	end_angle: float,
	outer_radius: float,
	inner_radius: float,
	color: Color
) -> ArrayMesh:
	var angle_delta := end_angle - start_angle
	if absf(angle_delta) <= 0.001:
		return _make_empty_mesh(color)

	var safe_segments := maxi(ceili(absf(angle_delta) / TAU * float(circle_segments)), 3)
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for index in range(safe_segments):
		var current_angle := start_angle + angle_delta * float(index) / float(safe_segments)
		var next_angle := start_angle + angle_delta * float(index + 1) / float(safe_segments)
		var vertex_start := vertices.size()
		vertices.append(_ring_point(outer_radius, current_angle))
		vertices.append(_ring_point(outer_radius, next_angle))
		vertices.append(_ring_point(inner_radius, next_angle))
		vertices.append(_ring_point(inner_radius, current_angle))
		indices.append_array([
			vertex_start,
			vertex_start + 1,
			vertex_start + 2,
			vertex_start,
			vertex_start + 2,
			vertex_start + 3,
		])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _make_material(color))
	return mesh


func _make_sector_mesh(start_angle: float, end_angle: float, radius: float, color: Color) -> ArrayMesh:
	var angle_delta := end_angle - start_angle
	if absf(angle_delta) <= 0.001:
		return _make_empty_mesh(color)

	var safe_segments := maxi(ceili(absf(angle_delta) / TAU * float(circle_segments)), 1)
	var vertices := PackedVector3Array([Vector3.ZERO])
	var indices := PackedInt32Array()
	for index in range(safe_segments + 1):
		var angle := start_angle + angle_delta * float(index) / float(safe_segments)
		vertices.append(_ring_point(radius, angle))
	for index in range(1, vertices.size() - 1):
		indices.append_array([0, index, index + 1])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _make_material(color))
	return mesh


func _make_arrow_mesh(distance: float, width: float, color: Color) -> ArrayMesh:
	var start_distance := minf(0.42, distance * 0.20)
	var tip_length := clampf(distance * 0.28, 0.45, 1.0)
	var shaft_end := maxf(distance - tip_length, start_distance + 0.05)
	var shaft_half_width := width * 0.27
	var tip_half_width := width * 0.52
	var vertices := PackedVector3Array([
		Vector3(-shaft_half_width, 0.0, -start_distance),
		Vector3(shaft_half_width, 0.0, -start_distance),
		Vector3(-shaft_half_width, 0.0, -shaft_end),
		Vector3(shaft_half_width, 0.0, -shaft_end),
		Vector3(-tip_half_width, 0.0, -shaft_end),
		Vector3(tip_half_width, 0.0, -shaft_end),
		Vector3(0.0, 0.0, -distance),
	])
	var indices := PackedInt32Array([
		0, 2, 1,
		1, 2, 3,
		4, 6, 5,
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _make_material(color))
	return mesh


func _make_empty_mesh(_color: Color) -> ArrayMesh:
	return ArrayMesh.new()


func _ring_point(radius: float, angle: float) -> Vector3:
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 3
	return material
