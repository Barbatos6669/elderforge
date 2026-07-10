## Applies character appearance choices to the reusable player prefab.
##
## The player keeps one stable scene path (`Visuals/BaseCharacter`) while this
## script swaps the imported male/female body scene under that path. Sockets for
## equipment are preserved when the body changes, so tools and weapons keep
## working after customization.
class_name PlayerVisualStyle
extends Node

const MALE_BODY_SCENE_PATH := "res://assets/characters/universal_base_character_package/Universal Base Characters[Standard]/Base Characters/Godot - UE/Superhero_Male_FullBody.gltf"
const FEMALE_BODY_SCENE_PATH := "res://assets/characters/universal_base_character_package/Universal Base Characters[Standard]/Base Characters/Godot - UE/Superhero_Female_FullBody.gltf"
const BODY_SCENE_META_KEY := &"appearance_body_scene_path"
const MODEL_ROOT_NAME := "BaseCharacter"
const SKELETON_PATH := NodePath("Armature/Skeleton3D")

const HAIR_SCENE_PATHS := {
	"short": "res://assets/characters/universal_base_character_package/Universal Base Characters[Standard]/Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/Hair_SimpleParted.gltf",
	"buzzed": "res://assets/characters/universal_base_character_package/Universal Base Characters[Standard]/Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/Hair_Buzzed.gltf",
	"buzzed_female": "res://assets/characters/universal_base_character_package/Universal Base Characters[Standard]/Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/Hair_BuzzedFemale.gltf",
	"long": "res://assets/characters/universal_base_character_package/Universal Base Characters[Standard]/Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/Hair_Long.gltf",
	"buns": "res://assets/characters/universal_base_character_package/Universal Base Characters[Standard]/Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/Hair_Buns.gltf",
}

## Root node of the visible imported character model.
@export var model_root_path: NodePath = NodePath("../Visuals/BaseCharacter")
## Local player instances can pull their look from PrototypeAuthSession.
@export var use_auth_session_appearance := false
## Selected base body scene.
@export_enum("male", "female") var body_type := "male"
## Body material color.
@export var body_color: Color = Color(0.42, 0.58, 0.64, 1.0)
## Hair material color.
@export var hair_color: Color = Color(0.16, 0.11, 0.08, 1.0)
## Imported Universal Base Character hairstyle to show on the player.
@export_enum("none", "buzzed", "short", "long", "buns") var hair_style := "short"
## Eye material color.
@export var eye_color: Color = Color(0.95, 0.88, 0.58, 1.0)
## Fine-tune imported hair after it is instanced.
@export var hair_position_offset := Vector3.ZERO
@export var hair_rotation_degrees_offset := Vector3.ZERO
@export var hair_scale_multiplier := Vector3.ONE

var _body_material: StandardMaterial3D
var _hair_material: StandardMaterial3D
var _eye_material: StandardMaterial3D
var _hair_root: Node3D


func _ready() -> void:
	# Apply immediately so deferred animation/equipment setup binds to the final
	# model skeleton instead of the placeholder scene.
	_apply_style()


## Applies appearance data loaded from the auth session or network state.
func apply_appearance(appearance: Dictionary) -> void:
	var next_body_type := _sanitize_body_type(String(appearance.get("body_type", body_type)))
	var next_body_color := _appearance_color(appearance.get("skin_color", body_color), body_color)
	var next_hair_style := _sanitize_hair_style(String(appearance.get("hair_style", hair_style)))
	var next_hair_color := _appearance_color(appearance.get("hair_color", hair_color), hair_color)
	if (
		body_type == next_body_type
		and _colors_match(body_color, next_body_color)
		and hair_style == next_hair_style
		and _colors_match(hair_color, next_hair_color)
		and _current_model_matches_body(next_body_type)
		and (hair_style == "none" or (_hair_root != null and is_instance_valid(_hair_root)))
	):
		return

	body_type = next_body_type
	body_color = next_body_color
	hair_style = next_hair_style
	hair_color = next_hair_color
	_apply_style()


## Returns compact appearance data safe to include in prototype multiplayer state.
func get_network_appearance() -> Dictionary:
	return {
		"body_type": _sanitize_body_type(body_type),
		"skin_color": _sanitize_color(body_color).to_html(true),
		"hair_style": _sanitize_hair_style(hair_style),
		"hair_color": _sanitize_color(hair_color).to_html(true),
	}


func _apply_style() -> void:
	_apply_auth_session_appearance()

	var model_root := _ensure_body_scene()
	if model_root == null:
		model_root = get_node_or_null(model_root_path) as Node3D
	if model_root == null:
		return

	_body_material = _create_toon_material(_body_color_for_preset())
	_hair_material = _create_toon_material(_sanitize_color(hair_color))
	_hair_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_eye_material = _create_toon_material(eye_color)

	_apply_to_meshes(model_root)
	_rebuild_hair_scene(model_root)
	_refresh_material_dependents()


func _ensure_body_scene() -> Node3D:
	var model_root := get_node_or_null(model_root_path) as Node3D
	var scene_path := _body_scene_path_for_type(body_type)
	if scene_path.is_empty():
		return model_root
	if model_root != null and _model_matches_scene_path(model_root, scene_path):
		model_root.set_meta(BODY_SCENE_META_KEY, scene_path)
		return model_root

	if not ResourceLoader.exists(scene_path):
		push_warning("Could not find character body scene: %s" % scene_path)
		return model_root

	var body_scene := load(scene_path) as PackedScene
	var next_model := body_scene.instantiate() as Node3D if body_scene != null else null
	if next_model == null:
		push_warning("Character body scene root must be Node3D: %s" % scene_path)
		return model_root

	next_model.name = MODEL_ROOT_NAME
	next_model.set_meta(BODY_SCENE_META_KEY, scene_path)

	if model_root == null:
		var visuals := get_node_or_null("../Visuals") as Node3D
		if visuals == null:
			next_model.queue_free()
			return null
		visuals.add_child(next_model)
		_refresh_model_dependents()
		return next_model

	var visual_parent := model_root.get_parent()
	if visual_parent == null:
		next_model.queue_free()
		return model_root

	var old_transform := model_root.transform
	var old_index := model_root.get_index()
	var preserved_sockets := _detach_preserved_sockets(model_root)

	next_model.transform = old_transform
	visual_parent.remove_child(model_root)
	model_root.queue_free()
	visual_parent.add_child(next_model)
	visual_parent.move_child(next_model, mini(old_index, visual_parent.get_child_count() - 1))

	_attach_preserved_sockets(next_model, preserved_sockets)
	_hair_root = null
	_refresh_model_dependents()
	return next_model


func _current_model_matches_body(next_body_type: String) -> bool:
	var model_root := get_node_or_null(model_root_path) as Node3D
	return model_root != null and _model_matches_scene_path(model_root, _body_scene_path_for_type(next_body_type))


func _model_matches_scene_path(model_root: Node3D, scene_path: String) -> bool:
	if String(model_root.get_meta(BODY_SCENE_META_KEY, "")) == scene_path:
		return true
	return String(model_root.scene_file_path) == scene_path


func _body_scene_path_for_type(next_body_type: String) -> String:
	return FEMALE_BODY_SCENE_PATH if _sanitize_body_type(next_body_type) == "female" else MALE_BODY_SCENE_PATH


func _detach_preserved_sockets(model_root: Node) -> Dictionary:
	var sockets := {}
	for socket_data in [
		{"name": "MainHandAttachment", "bone": "hand_r"},
		{"name": "HairAttachment", "bone": "Head"},
	]:
		var socket := _find_child_by_name(model_root, String(socket_data["name"])) as Node3D
		if socket == null:
			continue
		var parent := socket.get_parent()
		if parent != null:
			parent.remove_child(socket)
		sockets[String(socket_data["name"])] = {
			"node": socket,
			"bone": String(socket_data["bone"]),
		}
	return sockets


func _attach_preserved_sockets(model_root: Node3D, sockets: Dictionary) -> void:
	var skeleton := model_root.get_node_or_null(SKELETON_PATH) as Skeleton3D
	if skeleton == null:
		push_warning("Character body is missing skeleton path %s." % SKELETON_PATH)
		return

	for socket_name in sockets.keys():
		var socket_data := sockets[socket_name] as Dictionary
		var socket := socket_data.get("node") as Node3D
		if socket == null:
			continue
		skeleton.add_child(socket)
		socket.name = String(socket_name)
		if socket is BoneAttachment3D:
			(socket as BoneAttachment3D).bone_name = String(socket_data.get("bone", ""))


func _refresh_model_dependents() -> void:
	var equipment_visuals := get_node_or_null("../EquipmentVisuals")
	if equipment_visuals != null and equipment_visuals.has_method("refresh_sockets"):
		equipment_visuals.call("refresh_sockets")

	var animation_controller := get_node_or_null("../Animation")
	if animation_controller != null and animation_controller.has_method("rebuild_animation_player"):
		animation_controller.call("rebuild_animation_player")


func _refresh_material_dependents() -> void:
	var occlusion_silhouette := get_node_or_null("../OcclusionSilhouette")
	if occlusion_silhouette != null and occlusion_silhouette.has_method("refresh_targets"):
		occlusion_silhouette.call("refresh_targets")


func _apply_to_meshes(node: Node) -> void:
	if node.name in ["MainHandAttachment", "HairAttachment"]:
		return

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


func _apply_auth_session_appearance() -> void:
	if not use_auth_session_appearance or not _is_local_player_visual():
		return

	var auth_session := get_node_or_null("/root/PrototypeAuthSession")
	if auth_session == null or not auth_session.has_method("get_character_appearance"):
		return

	var appearance: Dictionary = auth_session.call("get_character_appearance")
	body_type = _sanitize_body_type(String(appearance.get("body_type", body_type)))
	body_color = _appearance_color(appearance.get("skin_color", body_color), body_color)
	hair_style = _sanitize_hair_style(String(appearance.get("hair_style", hair_style)))
	hair_color = _appearance_color(appearance.get("hair_color", hair_color), hair_color)


func _is_local_player_visual() -> bool:
	var parent := get_parent()
	if parent == null:
		return false

	var local_value: Variant = parent.get("is_local_player")
	return bool(local_value) if local_value is bool else false


func _body_color_for_preset() -> Color:
	return _sanitize_color(body_color)


func _rebuild_hair_scene(model_root: Node) -> void:
	if _hair_root != null and is_instance_valid(_hair_root):
		_hair_root.queue_free()
		_hair_root = null

	if hair_style == "none":
		return

	var target_skeleton := model_root.get_node_or_null(SKELETON_PATH) as Skeleton3D
	if target_skeleton == null:
		push_warning("Character body is missing skeleton path %s for hair binding." % SKELETON_PATH)
		return

	var scene_path := _hair_scene_path_for_style()
	if scene_path.is_empty():
		return

	var scene := ResourceLoader.load(scene_path) as PackedScene
	if scene == null:
		push_warning("Could not load hair scene: %s" % scene_path)
		return

	var imported_root := scene.instantiate() as Node3D
	if imported_root == null:
		return

	var root := Node3D.new()
	root.name = "AppearanceHair"
	target_skeleton.add_child(root, true)
	root.add_child(imported_root, true)
	_hair_root = root

	var hair_meshes := _collect_mesh_instances(imported_root)
	for mesh_instance in hair_meshes:
		var source_transform := mesh_instance.transform
		var source_parent := mesh_instance.get_parent()
		if source_parent != null:
			source_parent.remove_child(mesh_instance)
		mesh_instance.owner = null
		root.add_child(mesh_instance, true)
		mesh_instance.transform = source_transform
		mesh_instance.skeleton = mesh_instance.get_path_to(target_skeleton)
		_apply_hair_materials(mesh_instance)

	imported_root.queue_free()
	_apply_hair_attachment_tuning(root)


func _hair_scene_path_for_style() -> String:
	var style := _sanitize_hair_style(hair_style)
	if style == "buzzed" and body_type == "female":
		return String(HAIR_SCENE_PATHS.get("buzzed_female", ""))

	return String(HAIR_SCENE_PATHS.get(style, ""))


func _collect_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances_recursive(node, meshes)
	return meshes


func _collect_mesh_instances_recursive(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)

	for child in node.get_children():
		_collect_mesh_instances_recursive(child, meshes)


func _apply_hair_attachment_tuning(hair_root: Node3D) -> void:
	hair_root.position += hair_position_offset
	hair_root.rotation_degrees += hair_rotation_degrees_offset
	hair_root.scale = Vector3(
		hair_root.scale.x * hair_scale_multiplier.x,
		hair_root.scale.y * hair_scale_multiplier.y,
		hair_root.scale.z * hair_scale_multiplier.z
	)


func _apply_hair_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var surface_count := mesh_instance.mesh.get_surface_count() if mesh_instance.mesh != null else 0
		for surface_index in range(surface_count):
			mesh_instance.set_surface_override_material(surface_index, _hair_material)
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	for child in node.get_children():
		_apply_hair_materials(child)


func _find_child_by_name(node: Node, child_name: String) -> Node:
	if node.name == child_name:
		return node

	for child in node.get_children():
		var found := _find_child_by_name(child, child_name)
		if found != null:
			return found

	return null


func _appearance_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return _sanitize_color(value as Color)
	if value is String:
		var text := String(value).strip_edges()
		if Color.html_is_valid(text):
			return _sanitize_color(Color.html(text))

	return _sanitize_color(fallback)


func _sanitize_body_type(value: String) -> String:
	return "female" if value.strip_edges().to_lower() == "female" else "male"


func _sanitize_hair_style(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if normalized in ["none", "buzzed", "short", "long", "buns"]:
		return normalized

	return "short"


func _sanitize_color(color: Color) -> Color:
	if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a):
		return Color.WHITE

	return Color(
		clampf(color.r, 0.0, 1.0),
		clampf(color.g, 0.0, 1.0),
		clampf(color.b, 0.0, 1.0),
		clampf(color.a, 0.0, 1.0)
	)


func _colors_match(left: Color, right: Color) -> bool:
	return (
		is_equal_approx(left.r, right.r)
		and is_equal_approx(left.g, right.g)
		and is_equal_approx(left.b, right.b)
		and is_equal_approx(left.a, right.a)
	)
