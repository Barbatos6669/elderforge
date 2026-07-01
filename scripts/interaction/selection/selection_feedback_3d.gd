## Shows a ground ring while a selectable object is selected.
class_name SelectionFeedback3D
extends MeshInstance3D

## Selectable node whose selected state controls this ring.
@export var selectable_path: NodePath
## Radius of the selected target ring.
@export_range(0.1, 3.0, 0.01) var ring_radius: float = 0.72
## Thickness of the selected target ring.
@export_range(0.01, 0.5, 0.01) var ring_width: float = 0.09
## Local Y offset used to sit just above the floor.
@export_range(-0.1, 0.3, 0.005) var ring_y_offset: float = 0.09
## Number of segments in the generated ring mesh.
@export_range(12, 192, 1) var ring_segments: int = 96
## Fallback color of the selected target ring.
@export var ring_color: Color = Color(1.0, 0.82, 0.18, 1.0)
## Uses `get_relationship_color()` on the selectable when available.
@export var use_selectable_relationship_color: bool = true
## Base translucent color used to fill the ring interior.
@export var fill_color: Color = Color(1.0, 1.0, 1.0, 0.18)
## How much the fill borrows from the relationship/ring color.
@export_range(0.0, 1.0, 0.01) var fill_selection_color_mix: float = 0.35

var _selectable: Node
var _ring_material: StandardMaterial3D
var _fill_material: StandardMaterial3D


func _ready() -> void:
	_rebuild_ring()
	call_deferred("_connect_selectable")


func _process(_delta: float) -> void:
	_sync_selection_visibility()


func _rebuild_ring() -> void:
	var ring_mesh := _build_ring_mesh(ring_radius, ring_width, ring_segments)
	_ring_material = _build_ring_material()
	_fill_material = _build_fill_material()
	ring_mesh.surface_set_material(0, _fill_material)
	ring_mesh.surface_set_material(1, _ring_material)
	mesh = ring_mesh
	material_override = null
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position = Vector3(position.x, ring_y_offset, position.z)
	visible = false


func _connect_selectable() -> void:
	_selectable = get_node_or_null(selectable_path) if selectable_path != NodePath("") else null
	if _selectable == null:
		var parent_node := get_parent()
		if parent_node != null:
			_selectable = parent_node.get_node_or_null("Selectable")

	if _selectable == null:
		return
	if _selectable.has_signal("selection_changed"):
		_selectable.selection_changed.connect(_on_selection_changed)

	_apply_ring_color(_get_selection_color())
	_sync_selection_visibility()


func _on_selection_changed(is_selected: bool) -> void:
	if is_selected:
		_apply_ring_color(_get_selection_color())
	visible = is_selected


func _sync_selection_visibility() -> void:
	if _selectable == null:
		_connect_selectable()

	if _selectable != null and _selectable.has_method("is_selected"):
		var selected: bool = _selectable.is_selected()
		if selected:
			_apply_ring_color(_get_selection_color())
		visible = selected


func _get_selection_color() -> Color:
	if (
		use_selectable_relationship_color
		and _selectable != null
		and _selectable.has_method("get_relationship_color")
	):
		return _selectable.get_relationship_color()

	return ring_color


func _apply_ring_color(color: Color) -> void:
	if _ring_material == null:
		return

	_ring_material.albedo_color = color
	_ring_material.emission = color
	_apply_fill_color(color)


func _apply_fill_color(selection_color: Color) -> void:
	if _fill_material == null:
		return

	var tinted_fill := fill_color.lerp(selection_color, fill_selection_color_mix)
	tinted_fill.a = fill_color.a
	_fill_material.albedo_color = tinted_fill


func _build_ring_mesh(radius: float, width: float, segment_count: int) -> ArrayMesh:
	var mesh_resource := ArrayMesh.new()
	var safe_segment_count := maxi(segment_count, 3)
	var outer_radius := radius + width * 0.5
	var inner_radius := maxf(radius - width * 0.5, 0.01)

	_add_fill_surface(mesh_resource, inner_radius, safe_segment_count)
	_add_ring_surface(mesh_resource, outer_radius, inner_radius, safe_segment_count)
	return mesh_resource


func _add_fill_surface(mesh_resource: ArrayMesh, radius: float, segment_count: int) -> void:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	vertices.append(Vector3.ZERO)

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


func _build_ring_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = ring_color
	material.emission_enabled = true
	material.emission = ring_color
	material.emission_energy_multiplier = 1.4
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _build_fill_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = fill_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
