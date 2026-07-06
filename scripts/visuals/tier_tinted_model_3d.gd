## Applies a tier color tint to every mesh under this node.
##
## Use this when several tiers share the same imported model but still need to
## read clearly in the world. The original model material is duplicated per
## mesh surface so one tier cannot accidentally recolor another tier instance.
class_name TierTintedModel3D
extends Node3D

## Color blended into the source model materials.
@export var tint_color := Color(0.72, 0.72, 0.72, 1.0)
## Higher values make the tier color stronger while preserving texture detail.
@export_range(0.0, 1.0, 0.01) var tint_strength := 0.55
## Material values used only when an imported mesh has no material to duplicate.
@export_range(0.0, 1.0, 0.01) var fallback_roughness := 0.82


func _ready() -> void:
	_apply_tint_recursive(self)


func _apply_tint_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		_apply_tint_to_mesh(node as MeshInstance3D)

	for child in node.get_children():
		_apply_tint_recursive(child)


func _apply_tint_to_mesh(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return

	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var source_material := mesh_instance.get_surface_override_material(surface_index)
		if source_material == null:
			source_material = mesh_instance.mesh.surface_get_material(surface_index)

		mesh_instance.set_surface_override_material(surface_index, _make_tinted_material(source_material))


func _make_tinted_material(source_material: Material) -> Material:
	if source_material is StandardMaterial3D:
		var material := source_material.duplicate() as StandardMaterial3D
		material.albedo_color = material.albedo_color.lerp(tint_color, tint_strength)
		return material

	var fallback := StandardMaterial3D.new()
	fallback.albedo_color = tint_color
	fallback.roughness = fallback_roughness
	return fallback
