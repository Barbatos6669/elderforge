## Reusable hover feedback for 3D gameplay objects.
##
## This node owns hover detection and applies an optional mesh material overlay.
## It can still render a feet ring for debugging or special cases, but target
## selection rings live in SelectionFeedback3D.
class_name HoverFeedback3D
extends MeshInstance3D

## Visual root used for screen-space hover bounds and optional mesh overlay.
@export var visuals_path: NodePath
## Optional collision object used for ray hover fallback.
@export var hover_target_path: NodePath
## Keeps hover visuals visible for tuning.
@export var force_hover: bool = false

@export_group("Hover Detection")
## Tests whether the cursor is inside the projected visual mesh bounds.
@export var use_screen_bounds_hover: bool = true
## Extra pixels added around the projected mesh bounds.
@export_range(0.0, 80.0, 1.0) var screen_hover_padding_pixels: float = 4.0
## Tests distance to a simple projected feet-to-head body line.
@export var use_screen_body_line_hover: bool = true
## Radius around the projected body line in pixels.
@export_range(8.0, 250.0, 1.0) var screen_body_line_radius_pixels: float = 42.0
## Height above the parent origin used as the top of the body line.
@export_range(0.0, 3.0, 0.05) var screen_body_line_height: float = 1.85
## Tests a physics ray against the hover target as a fallback.
@export var use_ray_hover: bool = true
## Maximum distance for the mouse hover raycast.
@export var hover_ray_length: float = 1000.0
## Physics layers checked by the hover raycast.
@export_flags_3d_physics var hover_collision_mask: int = 1

@export_group("Ring")
## Shows this node's generated feet ring while hovered.
@export var show_ring_on_hover: bool = false
## Keeps this node's generated feet ring visible while the hover target is selected.
@export var show_ring_when_selected: bool = false
## Radius of the ring at the object's feet.
@export_range(0.1, 3.0, 0.01) var ring_radius: float = 0.55
## Thickness of the ring band.
@export_range(0.01, 0.5, 0.01) var ring_width: float = 0.08
## Local Y offset used to sit just above the floor.
@export_range(-0.1, 0.3, 0.005) var ring_y_offset: float = 0.08
## Number of segments in the generated ring mesh.
@export_range(12, 192, 1) var ring_segments: int = 96
## Color of the visible ring.
@export var ring_color: Color = Color(0.25, 1.0, 0.16, 1.0)
## Uses `get_relationship_color()` on the hover target when available.
@export var use_target_relationship_color: bool = true

@export_group("Mesh Overlay")
## Optional material applied as `material_overlay` while hovered.
@export var highlight_material: Material

var _hover_target: CollisionObject3D
var _mesh_instances: Array[MeshInstance3D] = []
var _original_overlays := {}
var _is_hovered := false
var _is_ring_visible := false
var _ring_material: StandardMaterial3D
var _runtime_highlight_material: Material


func _ready() -> void:
	_hover_target = _find_hover_target()
	if highlight_material != null:
		_runtime_highlight_material = highlight_material.duplicate(true) as Material
	_collect_visual_meshes()
	_rebuild_ring()
	_apply_feedback_color(_get_feedback_color())
	_set_hovered(false)
	_set_ring_visible(false)


func _process(_delta: float) -> void:
	if _mesh_instances.is_empty():
		_collect_visual_meshes()

	var should_hover := force_hover or _is_mouse_hovering()
	var should_show_ring := (
		(show_ring_on_hover and should_hover)
		or (show_ring_when_selected and _is_target_selected())
	)
	if should_show_ring:
		_apply_feedback_color(_get_feedback_color())
	_set_hovered(should_hover)
	_set_ring_visible(should_show_ring)


func _exit_tree() -> void:
	_apply_mesh_overlay(false)


func _find_hover_target() -> CollisionObject3D:
	if hover_target_path != NodePath(""):
		return get_node_or_null(hover_target_path) as CollisionObject3D

	var parent_node := get_parent()
	if parent_node != null:
		var sibling_selectable := parent_node.get_node_or_null("Selectable") as CollisionObject3D
		if sibling_selectable != null:
			return sibling_selectable

	return get_parent() as CollisionObject3D


func _collect_visual_meshes() -> void:
	_mesh_instances.clear()
	_original_overlays.clear()

	var visuals_root := get_node_or_null(visuals_path) if visuals_path != NodePath("") else null
	if visuals_root == null:
		var parent_node := get_parent()
		if parent_node != null:
			visuals_root = parent_node.get_node_or_null("Visuals")

	if visuals_root == null:
		return

	_collect_meshes_recursive(visuals_root)


func _collect_meshes_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		_mesh_instances.append(mesh_instance)
		_original_overlays[mesh_instance] = mesh_instance.material_overlay

	for child in node.get_children():
		_collect_meshes_recursive(child)


func _rebuild_ring() -> void:
	mesh = _build_ring_mesh(ring_radius, ring_width, ring_segments)
	_ring_material = _build_ring_material()
	material_override = _ring_material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position = Vector3(position.x, ring_y_offset, position.z)


func _set_hovered(value: bool) -> void:
	if value == _is_hovered:
		return

	_is_hovered = value
	if _is_hovered:
		_apply_feedback_color(_get_feedback_color())
	_apply_mesh_overlay(_is_hovered)


func _set_ring_visible(value: bool) -> void:
	if value == _is_ring_visible and visible == value:
		return

	_is_ring_visible = value
	visible = _is_ring_visible


func _is_mouse_hovering() -> bool:
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d()
	if camera == null:
		return false

	if use_screen_bounds_hover and _is_mouse_inside_projected_visual_bounds(viewport, camera):
		return true

	if use_screen_body_line_hover and _is_mouse_near_projected_body_line(viewport, camera):
		return true

	if use_ray_hover and _ray_hits_hover_target(viewport, camera):
		return true

	return false


func _is_mouse_inside_projected_visual_bounds(viewport: Viewport, camera: Camera3D) -> bool:
	var bounds := _project_visual_bounds(camera)
	if bounds.size == Vector2.ZERO:
		return false

	var padding := Vector2.ONE * screen_hover_padding_pixels
	bounds.position -= padding
	bounds.size += padding * 2.0
	return bounds.has_point(viewport.get_mouse_position())


func _is_mouse_near_projected_body_line(viewport: Viewport, camera: Camera3D) -> bool:
	var body_origin := _body_origin()
	var feet_position := body_origin + Vector3.UP * 0.1
	var head_position := body_origin + Vector3.UP * screen_body_line_height
	if camera.is_position_behind(feet_position) and camera.is_position_behind(head_position):
		return false

	var mouse_position := viewport.get_mouse_position()
	var feet_screen_position := camera.unproject_position(feet_position)
	var head_screen_position := camera.unproject_position(head_position)
	return (
		_distance_to_screen_segment(mouse_position, feet_screen_position, head_screen_position)
		<= screen_body_line_radius_pixels
	)


func _body_origin() -> Vector3:
	if _hover_target != null:
		return _hover_target.global_position

	var parent_3d := get_parent() as Node3D
	return parent_3d.global_position if parent_3d != null else global_position


func _project_visual_bounds(camera: Camera3D) -> Rect2:
	var has_point := false
	var min_point := Vector2.ZERO
	var max_point := Vector2.ZERO

	for mesh_instance in _mesh_instances:
		if not is_instance_valid(mesh_instance) or mesh_instance.mesh == null:
			continue

		for corner in _mesh_aabb_corners(mesh_instance.mesh.get_aabb()):
			var world_corner := mesh_instance.global_transform * corner
			if camera.is_position_behind(world_corner):
				continue

			var screen_point := camera.unproject_position(world_corner)
			if not has_point:
				min_point = screen_point
				max_point = screen_point
				has_point = true
			else:
				min_point = min_point.min(screen_point)
				max_point = max_point.max(screen_point)

	if not has_point:
		return Rect2()

	return Rect2(min_point, max_point - min_point)


func _distance_to_screen_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> float:
	var segment := segment_end - segment_start
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.001:
		return point.distance_to(segment_start)

	var point_offset := point - segment_start
	var segment_t := clampf(point_offset.dot(segment) / segment_length_squared, 0.0, 1.0)
	var closest_point := segment_start + segment * segment_t
	return point.distance_to(closest_point)


func _mesh_aabb_corners(aabb: AABB) -> Array[Vector3]:
	var position := aabb.position
	var end := aabb.end
	return [
		Vector3(position.x, position.y, position.z),
		Vector3(end.x, position.y, position.z),
		Vector3(position.x, end.y, position.z),
		Vector3(end.x, end.y, position.z),
		Vector3(position.x, position.y, end.z),
		Vector3(end.x, position.y, end.z),
		Vector3(position.x, end.y, end.z),
		Vector3(end.x, end.y, end.z),
	]


func _ray_hits_hover_target(viewport: Viewport, camera: Camera3D) -> bool:
	if _hover_target == null:
		_hover_target = _find_hover_target()
		if _hover_target == null:
			return false

	var mouse_position := viewport.get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	var ray_end := ray_origin + ray_direction * hover_ray_length
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, hover_collision_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hit := _hover_target.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.has("collider") and hit["collider"] == _hover_target


func _apply_mesh_overlay(enabled: bool) -> void:
	for mesh_instance in _mesh_instances:
		if not is_instance_valid(mesh_instance):
			continue

		if enabled and _runtime_highlight_material != null:
			mesh_instance.material_overlay = _runtime_highlight_material
		else:
			mesh_instance.material_overlay = _original_overlays.get(mesh_instance)


func _get_feedback_color() -> Color:
	if not use_target_relationship_color:
		return ring_color

	if _hover_target == null:
		_hover_target = _find_hover_target()

	if _hover_target != null and _hover_target.has_method("get_relationship_color"):
		return _hover_target.get_relationship_color()

	return ring_color


func _is_target_selected() -> bool:
	if _hover_target == null:
		_hover_target = _find_hover_target()

	if _hover_target != null and _hover_target.has_method("is_selected"):
		return _hover_target.call("is_selected") == true

	return false


func _apply_feedback_color(color: Color) -> void:
	if _ring_material != null:
		_ring_material.albedo_color = color
		_ring_material.emission = color

	var shader_material := _runtime_highlight_material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter("outline_color", color)
		return

	var standard_material := _runtime_highlight_material as StandardMaterial3D
	if standard_material != null:
		standard_material.albedo_color = color
		standard_material.emission_enabled = true
		standard_material.emission = color


func _build_ring_mesh(radius: float, width: float, segment_count: int) -> ArrayMesh:
	var mesh_resource := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var safe_segment_count := maxi(segment_count, 3)
	var outer_radius := radius + width * 0.5
	var inner_radius := maxf(radius - width * 0.5, 0.01)

	for segment_index in range(safe_segment_count):
		var current_angle := TAU * float(segment_index) / float(safe_segment_count)
		var next_angle := TAU * float(segment_index + 1) / float(safe_segment_count)
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
	return mesh_resource


func _ring_point(radius: float, angle: float) -> Vector3:
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func _build_ring_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = ring_color
	material.emission_enabled = true
	material.emission = ring_color
	material.emission_energy_multiplier = 1.6
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
