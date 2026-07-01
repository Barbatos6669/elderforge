class_name PlayerVisualStyle
extends Node

@export var model_root_path: NodePath = NodePath("../Visuals/BaseCharacter")
@export var body_color: Color = Color(0.42, 0.58, 0.64, 1.0)
@export var hair_color: Color = Color(0.16, 0.11, 0.08, 1.0)
@export var eye_color: Color = Color(0.95, 0.88, 0.58, 1.0)

var _body_material: StandardMaterial3D
var _hair_material: StandardMaterial3D
var _eye_material: StandardMaterial3D


func _ready() -> void:
	call_deferred("_apply_style")


func _apply_style() -> void:
	var model_root := get_node_or_null(model_root_path)
	if model_root == null:
		return

	_body_material = _create_toon_material(body_color)
	_hair_material = _create_toon_material(hair_color)
	_eye_material = _create_toon_material(eye_color)

	_apply_to_meshes(model_root)


func _apply_to_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		_apply_to_mesh_instance(node as MeshInstance3D)

	for child in node.get_children():
		_apply_to_meshes(child)


func _apply_to_mesh_instance(mesh_instance: MeshInstance3D) -> void:
	var material := _material_for_mesh(mesh_instance)
	var surface_count := mesh_instance.mesh.get_surface_count() if mesh_instance.mesh != null else 0

	for surface_index in range(surface_count):
		mesh_instance.set_surface_override_material(surface_index, material)


func _material_for_mesh(mesh_instance: MeshInstance3D) -> StandardMaterial3D:
	var mesh_name := mesh_instance.name.to_lower()
	if mesh_name.contains("eye"):
		return _eye_material
	if mesh_name.contains("hair") or mesh_name.contains("eyebrow"):
		return _hair_material

	return _body_material


func _create_toon_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.roughness = 1.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return material
