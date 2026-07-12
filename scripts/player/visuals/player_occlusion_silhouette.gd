## Shows a readable character silhouette when scenery blocks the camera.
##
## The component raycasts from the active camera toward a few body sample points.
## If a building, wall, resource trunk, or other world collider sits between the
## camera and the player, a depth-disabled shader pass is added to the player's
## character materials. This keeps hover outlines free to use `material_overlay`.
class_name PlayerOcclusionSilhouette
extends Node

const SILHOUETTE_SHADER := preload("res://assets/materials/characters/character_occlusion_silhouette.gdshader")
const SILHOUETTE_OUTLINE_SHADER := preload("res://assets/materials/characters/character_occlusion_silhouette_outline.gdshader")

## Root of the visible character model. Keep this on the character, not UI.
@export var model_root_path: NodePath = NodePath("../Visuals/BaseCharacter")
## Collision layers that can hide the player. Layer 1 is world/buildings; layer 2 is bodies/resources.
@export_flags_3d_physics var occluder_collision_mask: int = 3
## Visual occluders, such as fading leaves, can report occlusion without needing a collider.
@export var visual_occlusion_source_group := "player_occlusion_sources"
## Body points sampled from the player origin. Multiple points reduce flicker.
@export var sample_offsets: Array[Vector3] = [
	Vector3(0.0, 0.65, 0.0),
	Vector3(0.0, 1.1, 0.0),
	Vector3(0.0, 1.55, 0.0),
]
## Shortens the ray so it does not accidentally count the player itself as an occluder.
@export_range(0.0, 1.0, 0.01) var end_padding: float = 0.08
## Seconds to fade the silhouette in.
@export_range(0.01, 1.0, 0.01) var fade_in_seconds: float = 0.08
## Seconds to fade the silhouette out.
@export_range(0.01, 1.0, 0.01) var fade_out_seconds: float = 0.12
## Warm through-object body fill, similar to the readable MMO silhouette style.
@export var silhouette_color: Color = Color(1.0, 0.72, 0.24, 0.68)
## Thin colored body edge used while occluded.
@export var outline_color: Color = Color(0.18, 1.0, 0.58, 0.92)
## Width of the expanded outline pass.
@export_range(0.0, 0.18, 0.001) var outline_width: float = 0.026
## Extra brightness on the filled silhouette.
@export_range(0.0, 2.0, 0.01) var fill_strength: float = 0.86

@export_group("Performance")
## Limits raycasts and visual-occluder scans. The silhouette fade still updates every frame.
@export_range(1.0, 60.0, 1.0) var occlusion_check_hz := 15.0

var _character: Node3D
var _silhouette_material: ShaderMaterial
var _silhouette_outline_material: ShaderMaterial
var _tracked_materials: Array[Material] = []
var _original_next_passes := {}
var _excluded_rids: Array[RID] = []
var _current_alpha := 0.0
var _target_alpha := 0.0
var _occlusion_check_elapsed := 0.0
var _last_occlusion_state := false
var _last_applied_alpha := -1.0
var _next_pass_enabled := false


func _ready() -> void:
	_character = get_parent() as Node3D
	_build_silhouette_material()
	call_deferred("_initialize_targets")


func _process(delta: float) -> void:
	if _character == null or _tracked_materials.is_empty():
		return

	_occlusion_check_elapsed += maxf(delta, 0.0)
	if _occlusion_check_elapsed >= _occlusion_check_interval():
		_occlusion_check_elapsed = 0.0
		_last_occlusion_state = _is_player_occluded()

	_target_alpha = silhouette_color.a if _last_occlusion_state else 0.0
	var duration := fade_in_seconds if _target_alpha > _current_alpha else fade_out_seconds
	_current_alpha = move_toward(_current_alpha, _target_alpha, delta / maxf(duration, 0.001))
	_apply_silhouette_alpha(_current_alpha)


func _exit_tree() -> void:
	_restore_next_passes()


## Recollects materials after the character model changes.
func refresh_targets() -> void:
	_collect_excluded_rids()
	_collect_target_materials()
	_apply_silhouette_alpha(_current_alpha, true)


func _initialize_targets() -> void:
	_collect_excluded_rids()
	_collect_target_materials()
	_last_occlusion_state = _is_player_occluded()
	_target_alpha = silhouette_color.a if _last_occlusion_state else 0.0
	_apply_silhouette_alpha(_current_alpha, true)


func _build_silhouette_material() -> void:
	_silhouette_material = ShaderMaterial.new()
	_silhouette_material.shader = SILHOUETTE_SHADER
	_silhouette_material.set_shader_parameter("silhouette_color", Color(silhouette_color.r, silhouette_color.g, silhouette_color.b, 0.0))
	_silhouette_material.set_shader_parameter("fill_strength", fill_strength)

	_silhouette_outline_material = ShaderMaterial.new()
	_silhouette_outline_material.shader = SILHOUETTE_OUTLINE_SHADER
	_silhouette_outline_material.set_shader_parameter("outline_color", Color(outline_color.r, outline_color.g, outline_color.b, 0.0))
	_silhouette_outline_material.set_shader_parameter("outline_width", outline_width)
	_silhouette_material.next_pass = _silhouette_outline_material


func _collect_excluded_rids() -> void:
	_excluded_rids.clear()
	if _character == null:
		return

	_collect_excluded_rids_recursive(_character)


func _collect_excluded_rids_recursive(node: Node) -> void:
	if node is CollisionObject3D:
		_excluded_rids.append((node as CollisionObject3D).get_rid())

	for child in node.get_children():
		_collect_excluded_rids_recursive(child)


func _collect_target_materials() -> void:
	_restore_next_passes()
	_tracked_materials.clear()
	_original_next_passes.clear()

	var model_root := get_node_or_null(model_root_path)
	if model_root == null:
		return

	_collect_materials_recursive(model_root)


func _collect_materials_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		_register_mesh_materials(node as MeshInstance3D)

	for child in node.get_children():
		_collect_materials_recursive(child)


func _register_mesh_materials(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return

	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var material := mesh_instance.get_surface_override_material(surface_index)
		if material == null:
			material = mesh_instance.mesh.surface_get_material(surface_index)

		if material != null and not _tracked_materials.has(material):
			_tracked_materials.append(material)
			_original_next_passes[material] = material.next_pass


func _is_player_occluded() -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null or _character == null:
		return false

	if _is_occluded_by_visual_source():
		return true

	for sample_offset in sample_offsets:
		if _ray_hits_occluder(camera.global_position, _character.global_position + sample_offset):
			return true

	return false


func _is_occluded_by_visual_source() -> bool:
	if visual_occlusion_source_group.is_empty() or not is_inside_tree():
		return false

	for source in get_tree().get_nodes_in_group(visual_occlusion_source_group):
		if source == null or source == self or source == _character:
			continue
		if source.has_method("is_occluding_local_player") and bool(source.call("is_occluding_local_player")):
			return true

	return false


func _ray_hits_occluder(ray_start: Vector3, sample_position: Vector3) -> bool:
	var ray_vector := sample_position - ray_start
	var ray_length := ray_vector.length()
	if ray_length <= end_padding:
		return false

	var ray_end := ray_start + ray_vector.normalized() * (ray_length - end_padding)
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end, occluder_collision_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = _excluded_rids

	var space_state := _character.get_world_3d().direct_space_state
	var hit := space_state.intersect_ray(query)
	return not hit.is_empty()


func _apply_silhouette_alpha(alpha: float, force: bool = false) -> void:
	if _silhouette_material == null:
		return

	var safe_alpha := clampf(alpha, 0.0, silhouette_color.a)
	var should_enable := safe_alpha > 0.01
	if not force and absf(safe_alpha - _last_applied_alpha) <= 0.002 and should_enable == _next_pass_enabled:
		return

	_last_applied_alpha = safe_alpha
	_silhouette_material.set_shader_parameter(
		"silhouette_color",
		Color(silhouette_color.r, silhouette_color.g, silhouette_color.b, safe_alpha)
	)
	_silhouette_material.set_shader_parameter("fill_strength", fill_strength)
	if _silhouette_outline_material != null:
		var outline_alpha := outline_color.a * (safe_alpha / maxf(silhouette_color.a, 0.001))
		_silhouette_outline_material.set_shader_parameter(
			"outline_color",
			Color(outline_color.r, outline_color.g, outline_color.b, outline_alpha)
		)
		_silhouette_outline_material.set_shader_parameter("outline_width", outline_width)

	for material in _tracked_materials:
		if material == null:
			continue

		if should_enable and (force or not _next_pass_enabled):
			if force or material.next_pass != _silhouette_material:
				material.next_pass = _silhouette_material
		elif not should_enable and (force or _next_pass_enabled or material.next_pass == _silhouette_material):
			material.next_pass = _original_next_passes.get(material)

	_next_pass_enabled = should_enable


func _restore_next_passes() -> void:
	for material in _original_next_passes.keys():
		if material != null and material.next_pass == _silhouette_material:
			material.next_pass = _original_next_passes[material]


func _occlusion_check_interval() -> float:
	return 1.0 / maxf(occlusion_check_hz, 1.0)
