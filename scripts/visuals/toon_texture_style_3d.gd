## Applies our prototype toon material settings while preserving source textures.
##
## This is useful for imported environment art that already has texture atlases.
## It keeps the original albedo/normal/ORM data, then nudges the material toward
## the same simple, low-poly read as the placeholder character.
class_name ToonTextureStyle3D
extends Node3D

## Root of the imported model that should receive the style pass.
@export var model_root_path: NodePath = NodePath("Visual")
## Minimum roughness keeps props matte and game-like.
@export_range(0.0, 1.0, 0.01) var minimum_roughness := 0.82
## Nearest filtering helps texture atlases read cleaner in the prototype camera.
@export var use_nearest_texture_filter := true


func _ready() -> void:
	call_deferred("_apply_style")


func _apply_style() -> void:
	var model_root := get_node_or_null(model_root_path)
	if model_root == null:
		return

	_apply_to_meshes(model_root)


func _apply_to_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		_apply_to_mesh_instance(node as MeshInstance3D)

	for child in node.get_children():
		_apply_to_meshes(child)


func _apply_to_mesh_instance(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return

	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var source_material := mesh_instance.get_surface_override_material(surface_index)
		if source_material == null:
			source_material = mesh_instance.mesh.surface_get_material(surface_index)

		mesh_instance.set_surface_override_material(surface_index, _make_toon_material(source_material))


func _make_toon_material(source_material: Material) -> Material:
	if source_material is StandardMaterial3D:
		var material := source_material.duplicate() as StandardMaterial3D
		material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		material.roughness = maxf(material.roughness, minimum_roughness)
		if use_nearest_texture_filter:
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		return material

	if source_material is ShaderMaterial:
		return source_material.duplicate(true)

	var fallback := StandardMaterial3D.new()
	fallback.albedo_color = Color(0.68, 0.62, 0.54, 1.0)
	fallback.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	fallback.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	fallback.roughness = minimum_roughness
	if use_nearest_texture_filter:
		fallback.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return fallback
