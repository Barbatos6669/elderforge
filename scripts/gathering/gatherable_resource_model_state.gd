## Controls which imported mesh pieces are visible for a gatherable resource.
##
## This component only cares about resource state: active or depleted. Player
## occlusion is handled separately by `OccludableVisual3D`, so art can keep a
## simple setup: full mesh pieces, depleted mesh pieces, and optional disabled
## helper meshes from the source GLB.
class_name GatherableResourceModelState
extends Node

## Imported scene or visual root that contains the named mesh pieces.
@export var model_root_path: NodePath
## Mesh names shown while the resource can still be gathered.
@export var active_mesh_names: PackedStringArray = PackedStringArray()
## Mesh names shown after all gather ticks are consumed.
@export var depleted_mesh_names: PackedStringArray = PackedStringArray()
## Imported helper meshes that should stay hidden in this resource prefab.
@export var disabled_mesh_names: PackedStringArray = PackedStringArray()


func _ready() -> void:
	call_deferred("_connect_resource_signals")
	call_deferred("_sync_visible_meshes")


func _connect_resource_signals() -> void:
	var resource := _get_resource()
	if resource == null:
		return

	if resource.has_signal("gather_tick_consumed"):
		resource.gather_tick_consumed.connect(_on_resource_tick_changed)
	if resource.has_signal("gather_tick_replenished"):
		resource.gather_tick_replenished.connect(_on_resource_tick_changed)
	if resource.has_signal("depleted"):
		resource.depleted.connect(_on_resource_state_changed)
	if resource.has_signal("fully_replenished"):
		resource.fully_replenished.connect(_on_resource_state_changed)


func _on_resource_state_changed() -> void:
	_sync_visible_meshes()


func _on_resource_tick_changed(_remaining_ticks: int, _max_ticks: int) -> void:
	_sync_visible_meshes()


func _sync_visible_meshes() -> void:
	var model_root := _get_model_root()
	if model_root == null:
		return

	var is_depleted := _is_resource_depleted()
	var active_lookup := _names_to_lookup(active_mesh_names)
	var depleted_lookup := _names_to_lookup(depleted_mesh_names)
	var disabled_lookup := _names_to_lookup(disabled_mesh_names)
	var controlled_names := {}
	controlled_names.merge(active_lookup, true)
	controlled_names.merge(depleted_lookup, true)
	controlled_names.merge(disabled_lookup, true)

	for mesh_instance in _collect_mesh_instances(model_root):
		var mesh_name := String(mesh_instance.name)
		if not controlled_names.has(mesh_name):
			continue

		if disabled_lookup.has(mesh_name):
			mesh_instance.visible = false
		elif is_depleted:
			mesh_instance.visible = depleted_lookup.has(mesh_name)
		else:
			mesh_instance.visible = active_lookup.has(mesh_name)


func _get_resource() -> Node:
	var parent := get_parent()
	if parent != null and parent.has_method("get_yield_data") and parent.has_method("can_gather"):
		return parent

	return null


func _is_resource_depleted() -> bool:
	var resource := _get_resource()
	return resource != null and resource.has_method("is_depleted") and bool(resource.call("is_depleted"))


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
