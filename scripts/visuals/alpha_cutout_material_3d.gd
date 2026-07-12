## Applies alpha-cutout rendering to named mesh surfaces inside an imported model.
##
## Some GLB materials import as fully opaque even when their PNG has an alpha
## channel. This helper fixes foliage/cards at the prefab level without editing
## the source model or extracted material.
class_name AlphaCutoutMaterial3D
extends Node

## Imported model root to search for mesh instances.
@export var model_root_path: NodePath
## Mesh names that should use alpha cutout rendering.
@export var mesh_names: PackedStringArray = PackedStringArray()
## Optional material name fragments. Use this when one mesh has both bark and
## leaves as separate surfaces, so bark can stay fully opaque.
@export var material_name_fragments: PackedStringArray = PackedStringArray()
## Alpha values below this are discarded.
@export_range(0.0, 1.0, 0.01) var alpha_scissor_threshold := 0.35
## Leaves usually need to render from both sides.
@export var disable_backface_culling := true
## After the alpha test, keep surviving pixels fully opaque. This prevents
## trunks and branches from showing through semi-transparent leaf color.
@export var force_opaque_after_cutout := true


func _ready() -> void:
	call_deferred("_apply_alpha_cutout")


func _apply_alpha_cutout() -> void:
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

		var cutout_material := _make_cutout_material(source_material)
		if cutout_material != null:
			mesh_instance.set_surface_override_material(surface_index, cutout_material)


func _make_cutout_material(source_material: Material) -> Material:
	if source_material is StandardMaterial3D:
		var material := source_material.duplicate(true) as StandardMaterial3D
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = alpha_scissor_threshold
		if force_opaque_after_cutout:
			material.albedo_color.a = 1.0
		if disable_backface_culling:
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		return material

	return source_material


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
