## Applies stable low-poly foliage rendering to imported tree meshes.
##
## Imported foliage can accidentally keep alpha/blend settings from older leaf
## card workflows. For mesh-built leaves, this helper forces an opaque,
## shadow-casting material pass while preserving the authored base color/texture.
class_name FoliageVisualStyle3D
extends Node

## Imported model root that contains the foliage mesh instances.
@export var model_root_path: NodePath
## Mesh names that should receive the foliage material pass.
@export var mesh_names: PackedStringArray = PackedStringArray()
## Low-poly leaves often need both sides visible after Blender edits.
@export var disable_backface_culling := true
## Use toon diffuse so the foliage matches the rest of the prototype style.
@export var use_toon_diffuse := true
## Force all target meshes to cast shadows.
@export var force_shadow_casting := true


func _ready() -> void:
	call_deferred("_apply_foliage_style")


func _apply_foliage_style() -> void:
	var model_root := _get_model_root()
	if model_root == null:
		return

	var mesh_lookup := _names_to_lookup(mesh_names)
	for mesh_instance in _collect_mesh_instances(model_root):
		if not mesh_lookup.is_empty() and not mesh_lookup.has(String(mesh_instance.name)):
			continue

		_apply_to_mesh(mesh_instance)


func _apply_to_mesh(mesh_instance: MeshInstance3D) -> void:
	if force_shadow_casting:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	if mesh_instance.mesh == null:
		return

	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var source_material := mesh_instance.get_surface_override_material(surface_index)
		if source_material == null:
			source_material = mesh_instance.mesh.surface_get_material(surface_index)

		var foliage_material := _make_foliage_material(source_material)
		mesh_instance.set_surface_override_material(surface_index, foliage_material)


func _make_foliage_material(source_material: Material) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	if source_material is StandardMaterial3D:
		material = (source_material as StandardMaterial3D).duplicate(true) as StandardMaterial3D

	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.alpha_scissor_threshold = 0.0
	if disable_backface_culling:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if use_toon_diffuse:
		material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.roughness = 1.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return material


func _get_model_root() -> Node:
	if model_root_path != NodePath(""):
		return get_node_or_null(model_root_path)

	return get_parent()


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
