## Utility for attaching rigged imported meshes to an existing character skeleton.
##
## Universal Base Character hair and outfits ship as GLTF scenes with their own
## armature hierarchy. At runtime we only want the MeshInstance3D nodes, bound to
## the live player skeleton so gameplay animations drive every visible piece.
class_name CharacterRigAttachment
extends RefCounted


static func bind_scene_to_skeleton(
	scene_path: String,
	target_skeleton: Skeleton3D,
	root_name: String,
	warning_context := "attachment"
) -> Node3D:
	if target_skeleton == null:
		push_warning("Cannot bind %s because the target skeleton is missing." % warning_context)
		return null

	if scene_path.is_empty():
		return null

	if not ResourceLoader.exists(scene_path):
		push_warning("Could not find %s scene: %s" % [warning_context, scene_path])
		return null

	var scene := ResourceLoader.load(scene_path) as PackedScene
	if scene == null:
		push_warning("Could not load %s scene: %s" % [warning_context, scene_path])
		return null

	var imported_root := scene.instantiate() as Node3D
	if imported_root == null:
		push_warning("%s scene root must be Node3D: %s" % [warning_context.capitalize(), scene_path])
		return null

	var attachment_root := Node3D.new()
	attachment_root.name = root_name
	target_skeleton.add_child(attachment_root, true)
	attachment_root.add_child(imported_root, true)

	for mesh_instance in collect_mesh_instances(imported_root):
		_bind_mesh_to_skeleton(mesh_instance, attachment_root, target_skeleton)

	imported_root.queue_free()
	return attachment_root


static func collect_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if node == null:
		return meshes

	_collect_mesh_instances_recursive(node, meshes)
	return meshes


static func _collect_mesh_instances_recursive(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)

	for child in node.get_children():
		_collect_mesh_instances_recursive(child, meshes)


static func _bind_mesh_to_skeleton(mesh_instance: MeshInstance3D, root: Node3D, target_skeleton: Skeleton3D) -> void:
	var source_global_transform := mesh_instance.global_transform
	var source_parent := mesh_instance.get_parent()
	if source_parent != null:
		source_parent.remove_child(mesh_instance)

	mesh_instance.owner = null
	root.add_child(mesh_instance, true)
	mesh_instance.global_transform = source_global_transform
	mesh_instance.skeleton = mesh_instance.get_path_to(target_skeleton)
