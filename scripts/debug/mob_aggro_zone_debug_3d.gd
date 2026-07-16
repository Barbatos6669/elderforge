## Debug-only ground ring showing a mob's combat radius.
class_name MobAggroZoneDebug3D
extends MeshInstance3D

@export_range(0.01, 0.8, 0.01) var ring_width := 0.08
@export_range(12, 192, 1) var ring_segments := 128
@export_range(-0.1, 0.5, 0.005) var ground_offset := 0.045
@export var ring_color := Color(1.0, 0.55, 0.08, 0.88)
@export var fill_color := Color(1.0, 0.22, 0.04, 0.07)

var _radius := 0.0


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position = Vector3(position.x, ground_offset, position.z)
	visible = false


func set_radius(value: float) -> void:
	var next_radius := maxf(value, 0.0)
	if is_equal_approx(next_radius, _radius) and mesh != null:
		return

	_radius = next_radius
	_rebuild_mesh()


func get_radius() -> float:
	return _radius


func set_debug_visible(value: bool) -> void:
	visible = value and _radius > 0.0


func is_debug_visible() -> bool:
	return visible


func set_world_center(world_position: Vector3) -> void:
	global_position = Vector3(world_position.x, world_position.y + ground_offset, world_position.z)


func _rebuild_mesh() -> void:
	if _radius <= 0.0:
		mesh = null
		return

	var ring_mesh := ArrayMesh.new()
	var safe_segment_count := maxi(ring_segments, 12)
	var inner_radius := maxf(_radius - ring_width * 0.5, 0.01)
	var outer_radius := _radius + ring_width * 0.5
	_add_fill_surface(ring_mesh, inner_radius, safe_segment_count)
	_add_ring_surface(ring_mesh, outer_radius, inner_radius, safe_segment_count)
	ring_mesh.surface_set_material(0, _make_fill_material())
	ring_mesh.surface_set_material(1, _make_ring_material())
	mesh = ring_mesh


func _add_fill_surface(mesh_resource: ArrayMesh, radius: float, segment_count: int) -> void:
	var vertices := PackedVector3Array([Vector3.ZERO])
	var indices := PackedInt32Array()
	for segment_index in range(segment_count):
		var angle := TAU * float(segment_index) / float(segment_count)
		vertices.append(_ring_point(radius, angle))
	for segment_index in range(segment_count):
		var current_vertex := segment_index + 1
		var next_vertex := ((segment_index + 1) % segment_count) + 1
		indices.append_array([0, next_vertex, current_vertex])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh_resource.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _add_ring_surface(
	mesh_resource: ArrayMesh,
	outer_radius: float,
	inner_radius: float,
	segment_count: int
) -> void:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for segment_index in range(segment_count):
		var current_angle := TAU * float(segment_index) / float(segment_count)
		var next_angle := TAU * float(segment_index + 1) / float(segment_count)
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
	mesh_resource.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _ring_point(radius: float, angle: float) -> Vector3:
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func _make_ring_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = ring_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 2
	return material


func _make_fill_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = fill_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 1
	return material
