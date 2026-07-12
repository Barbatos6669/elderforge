## Applies the experimental toon shader across a loaded 3D scene for art tests.
##
## This is intentionally runtime-only: it sets surface override materials after
## the scene loads, so imported assets and source materials remain untouched.
## Disable this node when we want to compare against the original asset look.
class_name SceneToonMaterialPass
extends Node

const TOON_SHADER := preload("res://assets/materials/characters/experimental_toon.gdshader")
const APPLIED_META_KEY := &"scene_toon_material_pass_applied"

## Master toggle for this visual experiment.
@export var enabled := true
## Target roots resolved from this node's parent scene root. Leave this empty to
## scan the whole scene, which keeps newly hand-placed level props from being
## missed when they are accidentally dropped outside `World`.
@export var target_root_paths: Array[NodePath] = []
## Existing shader materials usually power special effects, water, terrain, or
## dissolve behavior. Leave them alone unless we are doing a very aggressive test.
@export var replace_existing_shader_materials := false
## Transparent materials are usually rings, markers, particles, foliage cards,
## or UI-in-world effects. Keeping them out avoids mangled visual feedback.
@export var replace_transparent_materials := false
## Name fragments skipped on this pass. The check also walks parent names.
@export var excluded_name_fragments := PackedStringArray([
	"atmosphere",
	"channel",
	"click",
	"cursor",
	"debug",
	"derender",
	"dissolve",
	"fade",
	"grid",
	"highlight",
	"hover",
	"indicator",
	"nameplate",
	"particle",
	"ring",
	"selection",
	"shadow",
	"silhouette",
	"water",
])

@export_range(1.0, 6.0, 1.0) var shade_steps := 3.0
@export_range(0.0, 1.0, 0.05) var step_softness := 0.14
@export var shadow_color := Color(0.24, 0.26, 0.28, 1.0)
@export_range(0.0, 1.0, 0.05) var shadow_strength := 0.34
@export var use_rim := true
@export var rim_color := Color(0.95, 0.84, 0.54, 1.0)
@export_range(0.5, 8.0, 0.1) var rim_power := 3.0
@export_range(0.0, 1.0, 0.05) var rim_strength := 0.08
@export_range(0.0, 1.0, 0.05) var fallback_roughness := 1.0
@export var fallback_color := Color(0.68, 0.62, 0.54, 1.0)
@export var use_black_outline := true
@export var outline_color := Color(0.015, 0.012, 0.01, 1.0)
@export_range(0.0, 0.08, 0.001) var outline_width := 0.014

var _scene_root: Node
var _excluded_fragments_lower := PackedStringArray()


func _ready() -> void:
	if not enabled:
		return

	_scene_root = get_parent()
	_cache_exclusion_fragments()
	call_deferred("_apply_after_scene_ready")


func apply_now() -> void:
	## Allows the pass to be re-run manually from the inspector.
	if not enabled:
		return

	_scene_root = get_parent()
	_cache_exclusion_fragments()
	_apply_to_target_roots()


func _apply_after_scene_ready() -> void:
	# Inherited scene children and instanced GLB meshes are safest to touch after
	# one frame, once their own _ready calls have had a chance to build visuals.
	await get_tree().process_frame
	_apply_to_target_roots()


func _apply_to_target_roots() -> void:
	if _scene_root == null:
		_scene_root = get_parent()
	if _scene_root == null:
		return

	if target_root_paths.is_empty():
		_apply_to_node(_scene_root)
		return

	for path in target_root_paths:
		var target := _scene_root.get_node_or_null(path)
		if target != null:
			_apply_to_node(target)


func _apply_to_node(node: Node) -> void:
	if _is_excluded(node):
		return

	if node is MeshInstance3D:
		_apply_to_mesh_instance(node as MeshInstance3D)

	for child in node.get_children():
		_apply_to_node(child)


func _apply_to_mesh_instance(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return

	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var source_material := _get_source_material(mesh_instance, surface_index)
		if not _should_replace_material(source_material):
			continue

		var toon_material := _make_toon_material(source_material)
		mesh_instance.set_surface_override_material(surface_index, toon_material)

	mesh_instance.set_meta(APPLIED_META_KEY, true)


func _get_source_material(mesh_instance: MeshInstance3D, surface_index: int) -> Material:
	var source_material := mesh_instance.get_surface_override_material(surface_index)
	if source_material != null:
		return source_material

	return mesh_instance.mesh.surface_get_material(surface_index)


func _should_replace_material(source_material: Material) -> bool:
	if source_material is ShaderMaterial and not replace_existing_shader_materials:
		return false

	if not replace_transparent_materials and _is_transparent_material(source_material):
		return false

	return true


func _is_transparent_material(source_material: Material) -> bool:
	if source_material is BaseMaterial3D:
		var base_material := source_material as BaseMaterial3D
		if base_material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return true

	if source_material is StandardMaterial3D:
		var standard_material := source_material as StandardMaterial3D
		return standard_material.albedo_color.a < 0.99

	return false


func _make_toon_material(source_material: Material) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TOON_SHADER

	var albedo_color := fallback_color
	var albedo_texture: Texture2D = null
	var roughness := fallback_roughness
	var specular := 0.0

	if source_material is BaseMaterial3D:
		var base_material := source_material as BaseMaterial3D
		albedo_color = _sanitize_color(base_material.albedo_color)
		albedo_texture = base_material.albedo_texture
		roughness = maxf(base_material.roughness, fallback_roughness)
		specular = 0.0
		material.resource_name = "%s Toon Test" % base_material.resource_name
	elif source_material != null:
		material.resource_name = "%s Toon Test" % source_material.resource_name

	material.set_shader_parameter("albedo_color", albedo_color)
	material.set_shader_parameter("use_albedo_texture", albedo_texture != null)
	if albedo_texture != null:
		material.set_shader_parameter("albedo_texture", albedo_texture)
		material.set_shader_parameter("texture_blend", 1.0)
	material.set_shader_parameter("shade_steps", shade_steps)
	material.set_shader_parameter("step_softness", step_softness)
	material.set_shader_parameter("shadow_color", shadow_color)
	material.set_shader_parameter("shadow_strength", shadow_strength)
	material.set_shader_parameter("use_rim", use_rim)
	material.set_shader_parameter("rim_color", rim_color)
	material.set_shader_parameter("rim_power", rim_power)
	material.set_shader_parameter("rim_strength", rim_strength)
	material.set_shader_parameter("roughness", roughness)
	material.set_shader_parameter("specular", specular)
	if use_black_outline:
		material.next_pass = CharacterToonMaterials.make_outline_material(outline_width, outline_color)
	return material


func _is_excluded(node: Node) -> bool:
	var current := node
	while current != null and current != _scene_root.get_parent():
		var current_name := String(current.name).to_lower()
		for fragment in _excluded_fragments_lower:
			if fragment != "" and current_name.contains(fragment):
				return true
		if current == _scene_root:
			break
		current = current.get_parent()

	return false


func _cache_exclusion_fragments() -> void:
	_excluded_fragments_lower.clear()
	for fragment in excluded_name_fragments:
		_excluded_fragments_lower.append(String(fragment).to_lower())


func _sanitize_color(color: Color) -> Color:
	if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a):
		return fallback_color

	return Color(
		clampf(color.r, 0.0, 1.0),
		clampf(color.g, 0.0, 1.0),
		clampf(color.b, 0.0, 1.0),
		clampf(color.a, 0.0, 1.0)
	)
