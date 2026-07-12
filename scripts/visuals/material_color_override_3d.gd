## Recolors selected material surfaces inside an imported scene.
##
## Use this when an asset pack gives us clean material names, but we want one
## prefab to present a local gameplay color without editing the source model.
class_name MaterialColorOverride3D
extends Node

const SOLID_TEXTURE_ALPHA_SHADER_CODE := """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_toon, specular_disabled;

uniform sampler2D alpha_texture;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float alpha_cutoff = 0.2;

void fragment() {
	vec4 texel = texture(alpha_texture, UV);
	ALBEDO = tint_color.rgb;
	ALPHA = texel.a * tint_color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	ROUGHNESS = 1.0;
}
"""

static var _solid_texture_alpha_shader: Shader

## Imported model root to search for mesh instances.
@export var model_root_path: NodePath
## Optional mesh names to limit the pass to specific MeshInstance3D nodes.
@export var mesh_names: PackedStringArray = PackedStringArray()
## Optional material name fragments. For example, "Flowers" only recolors flower
## surfaces while leaving leaves, bark, stone, and other surfaces unchanged.
@export var material_name_fragments: PackedStringArray = PackedStringArray()
## Replacement color for matching surfaces.
@export var albedo_color := Color(1.0, 0.96, 0.88, 1.0)
## When true, source texture RGB is ignored, but its alpha mask is preserved.
@export var use_source_texture_alpha_only := true
## Alpha values below this are discarded when using masked materials.
@export_range(0.0, 1.0, 0.01) var alpha_scissor_threshold := 0.2
## Imported foliage and flowers are usually card-based and need both sides.
@export var disable_backface_culling := true
## Keep imported props in the same broad low-poly/toon material family.
@export var use_toon_diffuse := true
## Nearest filtering keeps small texture masks crisp in the isometric camera.
@export var use_nearest_texture_filter := true


func _ready() -> void:
	call_deferred("_apply_color_override")


func _apply_color_override() -> void:
	var model_root := _get_model_root()
	if model_root == null:
		return

	var mesh_lookup := _names_to_lookup(mesh_names)
	for mesh_instance in _collect_mesh_instances(model_root):
		if not mesh_lookup.is_empty() and not mesh_lookup.has(String(mesh_instance.name)):
			continue

		_apply_to_mesh(mesh_instance)


func _apply_to_mesh(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return

	var material_lookup := _fragments_to_lookup(material_name_fragments)
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var source_material := mesh_instance.get_surface_override_material(surface_index)
		if source_material == null:
			source_material = mesh_instance.mesh.surface_get_material(surface_index)

		if not _should_apply_to_material(source_material, material_lookup):
			continue

		mesh_instance.set_surface_override_material(surface_index, _make_override_material(source_material))


func _make_override_material(source_material: Material) -> Material:
	if use_source_texture_alpha_only and source_material is StandardMaterial3D:
		var standard_material := source_material as StandardMaterial3D
		if standard_material.albedo_texture != null:
			return _make_solid_texture_alpha_material(standard_material)

	var material := StandardMaterial3D.new()
	if source_material is StandardMaterial3D:
		material = (source_material as StandardMaterial3D).duplicate(true) as StandardMaterial3D

	material.albedo_color = albedo_color
	material.roughness = 1.0
	material.metallic = 0.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = alpha_scissor_threshold
	material.vertex_color_use_as_albedo = false
	material.albedo_texture = null

	if disable_backface_culling:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if use_toon_diffuse:
		material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if use_nearest_texture_filter:
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	return material


func _make_solid_texture_alpha_material(source_material: StandardMaterial3D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_name = "%s_color_override" % source_material.resource_name
	material.shader = _get_solid_texture_alpha_shader()
	material.set_shader_parameter("alpha_texture", source_material.albedo_texture)
	material.set_shader_parameter("tint_color", albedo_color)
	material.set_shader_parameter("alpha_cutoff", alpha_scissor_threshold)
	return material


static func _get_solid_texture_alpha_shader() -> Shader:
	if _solid_texture_alpha_shader == null:
		_solid_texture_alpha_shader = Shader.new()
		_solid_texture_alpha_shader.code = SOLID_TEXTURE_ALPHA_SHADER_CODE

	return _solid_texture_alpha_shader


func _should_apply_to_material(source_material: Material, material_lookup: PackedStringArray) -> bool:
	if material_lookup.is_empty():
		return true
	if source_material == null:
		return false

	var material_name := source_material.resource_name.to_lower()
	for fragment in material_lookup:
		if fragment != "" and material_name.contains(fragment):
			return true

	return false


func _get_model_root() -> Node:
	if model_root_path != NodePath(""):
		return get_node_or_null(model_root_path)

	return get_parent()


func _names_to_lookup(names: PackedStringArray) -> Dictionary:
	var lookup := {}
	for mesh_name in names:
		lookup[String(mesh_name)] = true
	return lookup


func _fragments_to_lookup(fragments: PackedStringArray) -> PackedStringArray:
	var lookup := PackedStringArray()
	for fragment in fragments:
		lookup.append(String(fragment).to_lower())
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
