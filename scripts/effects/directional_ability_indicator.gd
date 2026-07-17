## Ground preview for cursor-aimed directional abilities.
##
## Geometry is generated at runtime so every movement ability can choose its own
## distance and width without requiring a separate mesh asset.
class_name DirectionalAbilityIndicator
extends Node3D

const KIND_NONE := &"none"
const KIND_DIRECTION := &"direction"
const KIND_SWING := &"swing"
const KIND_LEAP := &"leap"

@export var fill_color := Color(1.0, 0.78, 0.18, 0.30)
@export var outline_color := Color(1.0, 0.86, 0.35, 0.82)
@export_range(0.0, 0.5, 0.005) var ground_offset := 0.07

var _outline_mesh: MeshInstance3D
var _fill_mesh: MeshInstance3D
var _origin_disc: MeshInstance3D
var _landing_outline_mesh: MeshInstance3D
var _landing_fill_mesh: MeshInstance3D
var _last_distance := -1.0
var _last_width := -1.0
var _last_arc_radius := -1.0
var _last_arc_degrees := -1.0
var _last_landing_radius := -1.0
var _kind: StringName = KIND_NONE


func _ready() -> void:
	position.y = ground_offset
	_build_nodes()
	hide_indicator()


## Shows an arrow aligned to a world-space horizontal direction.
func show_direction(direction: Vector3, distance: float, width: float) -> void:
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	if flat_direction.length_squared() <= 0.0001:
		return

	var safe_distance := maxf(distance, 0.5)
	var safe_width := maxf(width, 0.2)
	if (
		_kind != KIND_DIRECTION
		or not is_equal_approx(safe_distance, _last_distance)
		or not is_equal_approx(safe_width, _last_width)
	):
		_rebuild_geometry(safe_distance, safe_width)

	flat_direction = flat_direction.normalized()
	rotation.y = atan2(-flat_direction.x, -flat_direction.z)
	_set_travel_visible(true)
	_origin_disc.visible = true
	_set_landing_visible(false)
	_kind = KIND_DIRECTION
	visible = true


## Shows the complete area covered by an aimed directional sword sweep.
func show_swing_arc(direction: Vector3, radius: float, arc_degrees: float) -> void:
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	if flat_direction.length_squared() <= 0.0001:
		return

	var safe_radius := maxf(radius, 0.5)
	var safe_arc_degrees := clampf(arc_degrees, 20.0, 360.0)
	if (
		_kind != KIND_SWING
		or not is_equal_approx(safe_radius, _last_arc_radius)
		or not is_equal_approx(safe_arc_degrees, _last_arc_degrees)
	):
		_rebuild_swing_arc(safe_radius, safe_arc_degrees)

	flat_direction = flat_direction.normalized()
	rotation.y = atan2(-flat_direction.x, -flat_direction.z)
	_set_travel_visible(true)
	_origin_disc.visible = false
	_set_landing_visible(false)
	_kind = KIND_SWING
	visible = true


## Shows the collision-aware travel path and the circular landing damage area.
func show_leap(direction: Vector3, distance: float, landing_radius: float, width: float) -> void:
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	if flat_direction.length_squared() <= 0.0001:
		return

	var safe_distance := maxf(distance, 0.0)
	var safe_width := maxf(width, 0.2)
	var safe_landing_radius := maxf(landing_radius, 0.15)
	var show_travel_path := safe_distance >= 0.5
	if show_travel_path and (
		_kind != KIND_LEAP
		or not is_equal_approx(safe_distance, _last_distance)
		or not is_equal_approx(safe_width, _last_width)
	):
		_rebuild_geometry(safe_distance, safe_width)
	if not is_equal_approx(safe_landing_radius, _last_landing_radius):
		_rebuild_landing_circle(safe_landing_radius)

	flat_direction = flat_direction.normalized()
	rotation.y = atan2(-flat_direction.x, -flat_direction.z)
	_landing_outline_mesh.position = Vector3(0.0, 0.006, -safe_distance)
	_landing_fill_mesh.position = Vector3(0.0, 0.014, -safe_distance)
	_set_travel_visible(show_travel_path)
	_origin_disc.visible = show_travel_path
	_set_landing_visible(true)
	_kind = KIND_LEAP
	visible = true


func hide_indicator() -> void:
	visible = false
	_kind = KIND_NONE


func is_showing() -> bool:
	return visible


func get_indicator_kind() -> StringName:
	return _kind


func _build_nodes() -> void:
	_outline_mesh = MeshInstance3D.new()
	_outline_mesh.name = "Outline"
	_outline_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_outline_mesh)

	_fill_mesh = MeshInstance3D.new()
	_fill_mesh.name = "Fill"
	_fill_mesh.position.y = 0.008
	_fill_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fill_mesh)

	_origin_disc = MeshInstance3D.new()
	_origin_disc.name = "OriginDisc"
	_origin_disc.position = Vector3(0.0, 0.004, -0.12)
	_origin_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var disc := CylinderMesh.new()
	disc.top_radius = 0.48
	disc.bottom_radius = 0.48
	disc.height = 0.012
	disc.radial_segments = 40
	disc.material = _make_material(Color(fill_color, minf(fill_color.a * 0.75, 1.0)))
	_origin_disc.mesh = disc
	add_child(_origin_disc)

	_landing_outline_mesh = MeshInstance3D.new()
	_landing_outline_mesh.name = "LandingOutline"
	_landing_outline_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_landing_outline_mesh)

	_landing_fill_mesh = MeshInstance3D.new()
	_landing_fill_mesh.name = "LandingFill"
	_landing_fill_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_landing_fill_mesh)
	_set_landing_visible(false)


func _rebuild_geometry(distance: float, width: float) -> void:
	_last_distance = distance
	_last_width = width
	_outline_mesh.mesh = _make_arrow_mesh(distance, width * 1.14, outline_color)
	_fill_mesh.mesh = _make_arrow_mesh(distance - 0.04, width, fill_color)


func _rebuild_swing_arc(radius: float, arc_degrees: float) -> void:
	_last_arc_radius = radius
	_last_arc_degrees = arc_degrees
	var half_arc := deg_to_rad(arc_degrees) * 0.5
	var start_angle := -PI * 0.5 - half_arc
	var end_angle := -PI * 0.5 + half_arc
	_outline_mesh.mesh = _make_arc_band_mesh(
		start_angle,
		end_angle,
		radius + 0.06,
		maxf(radius - 0.04, 0.01),
		outline_color
	)
	_fill_mesh.mesh = _make_sector_mesh(start_angle, end_angle, radius, fill_color)


func _rebuild_landing_circle(radius: float) -> void:
	_last_landing_radius = radius
	_landing_outline_mesh.mesh = _make_arc_band_mesh(
		0.0,
		TAU,
		radius + 0.07,
		maxf(radius - 0.03, 0.01),
		outline_color
	)
	_landing_fill_mesh.mesh = _make_sector_mesh(0.0, TAU, radius, fill_color)


func _set_landing_visible(is_visible: bool) -> void:
	if _landing_outline_mesh != null:
		_landing_outline_mesh.visible = is_visible
	if _landing_fill_mesh != null:
		_landing_fill_mesh.visible = is_visible


func _set_travel_visible(is_visible: bool) -> void:
	if _outline_mesh != null:
		_outline_mesh.visible = is_visible
	if _fill_mesh != null:
		_fill_mesh.visible = is_visible


func _make_arc_band_mesh(
	start_angle: float,
	end_angle: float,
	outer_radius: float,
	inner_radius: float,
	color: Color
) -> ArrayMesh:
	var angle_delta := end_angle - start_angle
	var segment_count := maxi(ceili(absf(angle_delta) / TAU * 64.0), 3)
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for index in range(segment_count):
		var current_angle := start_angle + angle_delta * float(index) / float(segment_count)
		var next_angle := start_angle + angle_delta * float(index + 1) / float(segment_count)
		var vertex_start := vertices.size()
		vertices.append(_arc_point(outer_radius, current_angle))
		vertices.append(_arc_point(outer_radius, next_angle))
		vertices.append(_arc_point(inner_radius, next_angle))
		vertices.append(_arc_point(inner_radius, current_angle))
		indices.append_array([
			vertex_start,
			vertex_start + 1,
			vertex_start + 2,
			vertex_start,
			vertex_start + 2,
			vertex_start + 3,
		])
	return _mesh_from_arrays(vertices, indices, color)


func _make_sector_mesh(start_angle: float, end_angle: float, radius: float, color: Color) -> ArrayMesh:
	var angle_delta := end_angle - start_angle
	var segment_count := maxi(ceili(absf(angle_delta) / TAU * 64.0), 1)
	var vertices := PackedVector3Array([Vector3.ZERO])
	var indices := PackedInt32Array()
	for index in range(segment_count + 1):
		var angle := start_angle + angle_delta * float(index) / float(segment_count)
		vertices.append(_arc_point(radius, angle))
	for index in range(1, vertices.size() - 1):
		indices.append_array([0, index, index + 1])
	return _mesh_from_arrays(vertices, indices, color)


func _mesh_from_arrays(vertices: PackedVector3Array, indices: PackedInt32Array, color: Color) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _make_material(color))
	return mesh


func _arc_point(radius: float, angle: float) -> Vector3:
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


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


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 2
	return material
