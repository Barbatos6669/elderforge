## Fades specific mesh pieces when they visually block the local player.
##
## Use this for tree canopies, roofs, tall banners, and other art that should
## get out of the camera's way. Optional mesh swapping supports artist-made
## de-render versions of trees and buildings.
class_name OccludableVisual3D
extends Node

const OCCLUSION_SHADER := preload("res://assets/materials/occlusion/pixel_occlusion_fade.gdshader")
const PLAYER_OCCLUSION_SOURCE_GROUP := "player_occlusion_sources"

## Enables or disables this component without removing it from a prefab.
@export var occlusion_enabled := true
## Lets the player silhouette know this visual is currently hiding the player.
@export var drives_player_silhouette := true
## Imported scene or visual root that contains target meshes.
@export var model_root_path: NodePath
## Optional world root for occlusion math. Defaults to this node's parent.
@export var occluder_root_path: NodePath
## Mesh names that should fade when they block the player.
@export var target_mesh_names: PackedStringArray = PackedStringArray()
## Scene group used to find the local player character.
@export var player_group_name := "player"

@export_group("Fade")
## Visibility retained while occluded. Low values make the texture very transparent.
@export_range(0.0, 1.0, 0.01) var occluded_visibility := 0.12
## Seconds to hide the target meshes once they block the player.
@export_range(0.01, 2.0, 0.01) var hide_seconds := 0.75
## Seconds to restore the target meshes after they stop blocking the player.
@export_range(0.01, 2.0, 0.01) var show_seconds := 0.55
## Uses blocky cutout chunks instead of a smooth texture alpha fade.
@export var use_pixel_dither := false
## Larger values make the occlusion chunks smaller when pixel dither is enabled.
@export_range(1.0, 64.0, 0.5) var pixel_scale := 6.5
## Texture alpha below this value is discarded when a target mesh uses transparency.
@export_range(0.0, 1.0, 0.01) var alpha_scissor_threshold := 0.3

@export_group("Occlusion Mesh Swap")
## Meshes hidden while the player is behind this object.
@export var hide_while_occluded_mesh_names: PackedStringArray = PackedStringArray()
## Meshes shown while the player is behind this object, such as artist-made de-render versions.
@export var show_while_occluded_mesh_names: PackedStringArray = PackedStringArray()

@export_group("Detection")
## Limits the expensive screen/depth occlusion test rate. Fade animation still updates smoothly.
@export_range(1.0, 60.0, 1.0) var occlusion_check_hz := 12.0
## Skips player-occlusion checks when the player is far away from this visual.
@export_range(0.0, 300.0, 1.0, "suffix:m") var max_occlusion_check_distance := 55.0
## Vertical anchor used when projecting this object to screen space.
@export_range(0.0, 20.0, 0.1) var occluder_anchor_height := 2.35
## Vertical anchor used when projecting the player to screen space.
@export_range(0.0, 4.0, 0.1) var player_anchor_height := 1.0
## Near-screen overlap radius for close occlusion.
@export_range(10.0, 600.0, 1.0) var screen_radius_pixels := 145.0
## Half-width of the screen-space lane behind the object.
@export_range(10.0, 800.0, 1.0) var screen_column_half_width_pixels := 360.0
## Half-width, in world meters, of the camera-facing occlusion lane.
@export_range(0.1, 30.0, 0.1) var world_column_half_width := 8.0
## Maximum behind-distance, in world meters. Set to 0 to disable the cap.
@export_range(0.0, 100.0, 0.5) var world_max_behind_distance := 30.0
## Small depth cushion so fading does not flicker when depths are nearly equal.
@export_range(0.0, 5.0, 0.01) var depth_margin := 0.15
## If the parent resource is depleted, stop applying player occlusion.
@export var disable_when_parent_depleted := true

var _current_visibility := 1.0
var _target_visibility := 1.0
var _is_currently_occluding := false
var _behind_distance := 0.0
var _primary_occlusion_materials: Array[ShaderMaterial] = []
var _hide_while_occluded_meshes: Array[MeshInstance3D] = []
var _show_while_occluded_meshes: Array[MeshInstance3D] = []
var _tracked_player: Node3D
var _occlusion_check_elapsed := 0.0
var _last_applied_visibility := -1.0
var _last_mesh_swap_state := false


func _ready() -> void:
	if not occlusion_enabled:
		return

	if drives_player_silhouette:
		add_to_group(PLAYER_OCCLUSION_SOURCE_GROUP)
	_occlusion_check_elapsed = randf_range(0.0, _occlusion_check_interval())
	call_deferred("_setup_occlusion_materials")


func _process(delta: float) -> void:
	if not occlusion_enabled or _is_parent_resource_depleted():
		_set_occlusion_state(false)
	else:
		_occlusion_check_elapsed += maxf(delta, 0.0)
		if _occlusion_check_elapsed >= _occlusion_check_interval():
			_occlusion_check_elapsed = 0.0
			_set_occlusion_state(_is_occluding_player())

	_apply_mesh_swap(_is_currently_occluding)
	_update_visibility(delta)


## Returns true while this visual is actively blocking the local player.
func is_occluding_local_player() -> bool:
	return drives_player_silhouette and occlusion_enabled and _is_currently_occluding


func _setup_occlusion_materials() -> void:
	_primary_occlusion_materials.clear()
	_hide_while_occluded_meshes.clear()
	_show_while_occluded_meshes.clear()

	var model_root := _get_model_root()
	if model_root == null:
		return

	var target_lookup := _names_to_lookup(target_mesh_names)
	var hide_while_occluded_lookup := _names_to_lookup(hide_while_occluded_mesh_names)
	var show_while_occluded_lookup := _names_to_lookup(show_while_occluded_mesh_names)
	for mesh_instance in _collect_mesh_instances(model_root):
		var mesh_name := String(mesh_instance.name)
		if not target_lookup.is_empty() and target_lookup.has(mesh_name):
			_apply_to_mesh(mesh_instance)
		if not hide_while_occluded_lookup.is_empty() and hide_while_occluded_lookup.has(mesh_name):
			_hide_while_occluded_meshes.append(mesh_instance)
		if not show_while_occluded_lookup.is_empty() and show_while_occluded_lookup.has(mesh_name):
			_show_while_occluded_meshes.append(mesh_instance)

	_apply_visibility(_current_visibility, true)
	_apply_mesh_swap(false, true)


func _apply_to_mesh(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return

	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var source_material := mesh_instance.get_surface_override_material(surface_index)
		if source_material == null:
			source_material = mesh_instance.mesh.surface_get_material(surface_index)

		var occlusion_material := _make_occlusion_material(source_material)
		mesh_instance.set_surface_override_material(surface_index, occlusion_material)
		_primary_occlusion_materials.append(occlusion_material)


func _make_occlusion_material(source_material: Material) -> ShaderMaterial:
	if source_material is ShaderMaterial:
		var shader_source := source_material as ShaderMaterial
		if shader_source.shader == OCCLUSION_SHADER:
			return shader_source.duplicate(true) as ShaderMaterial

	var material := ShaderMaterial.new()
	material.shader = OCCLUSION_SHADER

	var albedo_color := Color.WHITE
	var albedo_texture: Texture2D
	var roughness := 0.92
	if source_material is StandardMaterial3D:
		var standard_material := source_material as StandardMaterial3D
		albedo_color = standard_material.albedo_color
		albedo_texture = standard_material.albedo_texture
		roughness = maxf(standard_material.roughness, roughness)

	material.set_shader_parameter("use_albedo_texture", albedo_texture != null)
	if albedo_texture != null:
		material.set_shader_parameter("albedo_texture", albedo_texture)
	material.set_shader_parameter("albedo_tint", albedo_color)
	material.set_shader_parameter("occlusion_visibility", _current_visibility)
	material.set_shader_parameter("alpha_scissor_threshold", alpha_scissor_threshold)
	material.set_shader_parameter("use_pixel_dither", use_pixel_dither)
	material.set_shader_parameter("pixel_scale", pixel_scale)
	material.set_shader_parameter("material_roughness", roughness)
	var material_index := _primary_occlusion_materials.size()
	material.set_shader_parameter("pattern_seed", float(material_index + 1) * 19.37)
	return material


func _update_visibility(delta: float) -> void:
	var duration := hide_seconds if _target_visibility < _current_visibility else show_seconds
	var previous_visibility := _current_visibility
	var step := maxf(delta, 0.0) / maxf(duration, 0.01)
	_current_visibility = move_toward(_current_visibility, _target_visibility, step)
	if absf(previous_visibility - _current_visibility) > 0.001:
		_apply_visibility(_current_visibility)


func _apply_visibility(visibility: float, force: bool = false) -> void:
	var safe_visibility := clampf(visibility, 0.0, 1.0)
	if not force and absf(safe_visibility - _last_applied_visibility) <= 0.001:
		return

	_last_applied_visibility = safe_visibility
	for material in _primary_occlusion_materials:
		if material == null:
			continue

		material.set_shader_parameter("occlusion_visibility", safe_visibility)
		material.set_shader_parameter("alpha_scissor_threshold", alpha_scissor_threshold)
		material.set_shader_parameter("use_pixel_dither", use_pixel_dither)
		material.set_shader_parameter("pixel_scale", pixel_scale)


func _apply_mesh_swap(is_occluded: bool, force: bool = false) -> void:
	var should_swap := is_occluded and not _is_parent_resource_depleted()
	if not force and should_swap == _last_mesh_swap_state:
		return

	_last_mesh_swap_state = should_swap
	for mesh_instance in _hide_while_occluded_meshes:
		if mesh_instance == null or not is_instance_valid(mesh_instance):
			continue

		if not _is_parent_resource_depleted():
			mesh_instance.visible = not should_swap

	for mesh_instance in _show_while_occluded_meshes:
		if mesh_instance == null or not is_instance_valid(mesh_instance):
			continue

		mesh_instance.visible = should_swap


func _is_occluding_player() -> bool:
	var occluder := _get_occluder_root()
	var player := _get_tracked_player()
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d() if viewport != null else null
	if occluder == null or player == null or camera == null:
		_behind_distance = 0.0
		return false

	if max_occlusion_check_distance > 0.0:
		var max_distance_squared := max_occlusion_check_distance * max_occlusion_check_distance
		if occluder.global_position.distance_squared_to(player.global_position) > max_distance_squared:
			_behind_distance = 0.0
			return false

	var camera_forward := -camera.global_transform.basis.z.normalized()
	var occluder_depth := (occluder.global_position - camera.global_position).dot(camera_forward)
	var player_depth := (player.global_position - camera.global_position).dot(camera_forward)
	if player_depth <= occluder_depth + depth_margin:
		_behind_distance = 0.0
		return false

	var occluder_anchor := occluder.global_position + Vector3.UP * occluder_anchor_height
	var player_anchor := player.global_position + Vector3.UP * player_anchor_height
	if camera.is_position_behind(occluder_anchor) or camera.is_position_behind(player_anchor):
		_behind_distance = 0.0
		return false

	var occluder_screen_position := camera.unproject_position(occluder_anchor)
	var player_screen_position := camera.unproject_position(player_anchor)
	var screen_distance := occluder_screen_position.distance_to(player_screen_position)
	var screen_column_distance := absf(player_screen_position.x - occluder_screen_position.x)
	var behind_distance := _player_behind_distance(occluder, player, camera_forward)
	_behind_distance = maxf(behind_distance, 0.0)
	var is_inside_near_screen_radius := screen_distance <= screen_radius_pixels
	var is_inside_isometric_column := (
		screen_column_distance <= screen_column_half_width_pixels
		and _is_player_inside_world_occlusion_column(occluder, player, camera_forward, behind_distance)
	)
	return is_inside_near_screen_radius or is_inside_isometric_column


func _player_behind_distance(occluder: Node3D, player: Node3D, camera_forward: Vector3) -> float:
	var ground_forward := Vector3(camera_forward.x, 0.0, camera_forward.z)
	if ground_forward.length_squared() <= 0.0001:
		return -1.0

	ground_forward = ground_forward.normalized()
	var to_player := player.global_position - occluder.global_position
	to_player.y = 0.0
	return to_player.dot(ground_forward)


func _is_player_inside_world_occlusion_column(
	occluder: Node3D,
	player: Node3D,
	camera_forward: Vector3,
	behind_distance: float
) -> bool:
	if behind_distance <= depth_margin:
		return false
	if world_max_behind_distance > 0.0 and behind_distance > world_max_behind_distance:
		return false

	var ground_forward := Vector3(camera_forward.x, 0.0, camera_forward.z)
	if ground_forward.length_squared() <= 0.0001:
		return false

	ground_forward = ground_forward.normalized()
	var to_player := player.global_position - occluder.global_position
	to_player.y = 0.0
	var side_axis := Vector3(-ground_forward.z, 0.0, ground_forward.x)
	var lateral_distance := absf(to_player.dot(side_axis))
	return lateral_distance <= world_column_half_width


func _set_occlusion_state(is_occluding: bool) -> void:
	_is_currently_occluding = is_occluding
	_target_visibility = occluded_visibility if _is_currently_occluding else 1.0
	if not _is_currently_occluding:
		_behind_distance = 0.0


func _occlusion_check_interval() -> float:
	return 1.0 / maxf(occlusion_check_hz, 1.0)


func _get_model_root() -> Node:
	if model_root_path != NodePath(""):
		return get_node_or_null(model_root_path)

	return get_parent()


func _get_occluder_root() -> Node3D:
	if occluder_root_path != NodePath(""):
		return get_node_or_null(occluder_root_path) as Node3D

	return get_parent() as Node3D


func _get_tracked_player() -> Node3D:
	if _tracked_player != null and is_instance_valid(_tracked_player):
		return _tracked_player
	if not is_inside_tree():
		return null

	_tracked_player = get_tree().get_first_node_in_group(player_group_name) as Node3D
	return _tracked_player


func _is_parent_resource_depleted() -> bool:
	if not disable_when_parent_depleted:
		return false

	var parent := get_parent()
	return parent != null and parent.has_method("is_depleted") and bool(parent.call("is_depleted"))


func _names_to_lookup(names: PackedStringArray) -> Dictionary:
	var lookup := {}
	for mesh_name in names:
		lookup[String(mesh_name)] = true
	return lookup


func _collect_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances_recursive(root, meshes)
	return meshes


func _collect_mesh_instances_recursive(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)

	for child in node.get_children():
		_collect_mesh_instances_recursive(child, meshes)
