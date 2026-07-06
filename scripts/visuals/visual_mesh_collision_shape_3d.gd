## Builds a concave collision shape from a visual mesh hierarchy.
##
## Use this on static world geometry, such as ground pieces, where the collider
## should follow the imported model instead of a simple box. Concave shapes are
## intended for StaticBody3D terrain/props, not moving physics bodies.
@tool
class_name VisualMeshCollisionShape3D
extends CollisionShape3D

## Node that contains the MeshInstance3D children used to build the collider.
@export var visual_root_path: NodePath = NodePath("../Visual")
## Invisible meshes are skipped by default so hidden editor helpers do not collide.
@export var include_invisible_meshes := false
## Rebuild when the node enters the scene tree.
@export var rebuild_on_ready := true
## Imported meshes do not always have physics-friendly triangle winding. Enabling
## this keeps ground usable even when the visible faces point the other way.
@export var backface_collision := true


func _ready() -> void:
	if rebuild_on_ready:
		call_deferred("rebuild_shape_from_visual")


## Rebuilds the collision shape from every triangle under visual_root_path.
func rebuild_shape_from_visual() -> void:
	var visual_root := get_node_or_null(visual_root_path)
	if visual_root == null:
		return

	var triangles := PackedVector3Array()
	_append_mesh_triangles(visual_root, triangles)
	if triangles.is_empty():
		return

	var concave_shape := ConcavePolygonShape3D.new()
	concave_shape.data = triangles
	concave_shape.backface_collision = backface_collision
	shape = concave_shape


func _append_mesh_triangles(node: Node, triangles: PackedVector3Array) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if include_invisible_meshes or mesh_instance.visible:
			_append_mesh_instance_triangles(mesh_instance, triangles)

	for child in node.get_children():
		_append_mesh_triangles(child, triangles)


func _append_mesh_instance_triangles(mesh_instance: MeshInstance3D, triangles: PackedVector3Array) -> void:
	var mesh := mesh_instance.mesh
	if mesh == null:
		return

	var mesh_to_collision := global_transform.affine_inverse() * mesh_instance.global_transform
	for surface_index in range(mesh.get_surface_count()):
		if mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
			continue

		var arrays := mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

		if indices.is_empty():
			_append_unindexed_triangles(vertices, mesh_to_collision, triangles)
		else:
			_append_indexed_triangles(vertices, indices, mesh_to_collision, triangles)


func _append_unindexed_triangles(
	vertices: PackedVector3Array,
	mesh_to_collision: Transform3D,
	triangles: PackedVector3Array
) -> void:
	for vertex_index in range(0, vertices.size() - 2, 3):
		triangles.append(mesh_to_collision * vertices[vertex_index])
		triangles.append(mesh_to_collision * vertices[vertex_index + 1])
		triangles.append(mesh_to_collision * vertices[vertex_index + 2])


func _append_indexed_triangles(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	mesh_to_collision: Transform3D,
	triangles: PackedVector3Array
) -> void:
	for index_position in range(0, indices.size() - 2, 3):
		var first_index := indices[index_position]
		var second_index := indices[index_position + 1]
		var third_index := indices[index_position + 2]
		if not _triangle_indices_are_valid(vertices, first_index, second_index, third_index):
			continue

		triangles.append(mesh_to_collision * vertices[first_index])
		triangles.append(mesh_to_collision * vertices[second_index])
		triangles.append(mesh_to_collision * vertices[third_index])


func _triangle_indices_are_valid(vertices: PackedVector3Array, first_index: int, second_index: int, third_index: int) -> bool:
	var vertex_count := vertices.size()
	return (
		first_index >= 0
		and second_index >= 0
		and third_index >= 0
		and first_index < vertex_count
		and second_index < vertex_count
		and third_index < vertex_count
	)
