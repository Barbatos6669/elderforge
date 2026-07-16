## Applies character appearance choices to the reusable player prefab.
##
## The player keeps one stable scene path (`Visuals/BaseCharacter`) while this
## script swaps the imported male/female body scene under that path. Sockets for
## equipment are preserved when the body changes, so tools and weapons keep
## working after customization.
class_name PlayerVisualStyle
extends Node

const EQUIPMENT_ATTACHMENT_META := &"character_equipment_attachment"

## Root node of the visible imported character model.
@export var model_root_path: NodePath = NodePath("../Visuals/BaseCharacter")
## Local player instances can pull their look from PrototypeAuthSession.
@export var use_auth_session_appearance := false
## Selected base body scene.
@export_enum("male", "female") var body_type := "male"
## Body material fallback color used when an imported skin material has no texture.
@export var body_color: Color = Color(0.82, 0.62, 0.48, 1.0)
## Hair material color.
@export var hair_color: Color = Color(0.16, 0.11, 0.08, 1.0)
## Imported Universal Base Character hairstyle to show on the player.
@export_enum("none", "buzzed", "short", "long", "buns") var hair_style := "short"
## Rigged outfit to bind to the current body skeleton.
@export_enum("none", "starter_peasant", "ranger") var outfit_style := "starter_peasant"
## Eye material color.
@export var eye_color: Color = Color(0.95, 0.88, 0.58, 1.0)
## Character material style used by the player and remote player visuals.
@export_enum("experimental_shader", "standard_toon") var material_style := CharacterToonMaterials.STYLE_EXPERIMENTAL_SHADER
## Fine-tune imported hair after it is instanced.
@export var hair_position_offset := Vector3.ZERO
@export var hair_rotation_degrees_offset := Vector3.ZERO
@export var hair_scale_multiplier := Vector3.ONE

var _body_material: Material
var _head_only_body_material: Material
var _hair_material: Material
var _eye_material: Material
var _hair_root: Node3D
var _outfit_root: Node3D
var _equipment_outfit_replacements := {}


func _ready() -> void:
	# Apply immediately so deferred animation/equipment setup binds to the final
	# model skeleton instead of the placeholder scene.
	_apply_style()


## Applies appearance data loaded from the auth session or network state.
func apply_appearance(appearance: Dictionary) -> void:
	var next_body_type := CharacterAppearanceAssets.sanitize_body_type(String(appearance.get("body_type", body_type)))
	var next_body_color := _appearance_color(appearance.get("skin_color", body_color), body_color)
	var next_hair_style := CharacterAppearanceAssets.sanitize_hair_style(String(appearance.get("hair_style", hair_style)))
	var next_hair_color := _appearance_color(appearance.get("hair_color", hair_color), hair_color)
	var next_outfit_style := CharacterAppearanceAssets.sanitize_outfit_style(String(appearance.get("outfit_style", outfit_style)))
	if (
		body_type == next_body_type
		and _colors_match(body_color, next_body_color)
		and hair_style == next_hair_style
		and _colors_match(hair_color, next_hair_color)
		and outfit_style == next_outfit_style
		and _current_model_matches_body(next_body_type)
		and (hair_style == "none" or (_hair_root != null and is_instance_valid(_hair_root)))
		and (outfit_style == "none" or (_outfit_root != null and is_instance_valid(_outfit_root)))
	):
		return

	body_type = next_body_type
	body_color = next_body_color
	hair_style = next_hair_style
	hair_color = next_hair_color
	outfit_style = next_outfit_style
	_apply_style()


## Returns compact appearance data safe to include in prototype multiplayer state.
func get_network_appearance() -> Dictionary:
	return {
		"body_type": CharacterAppearanceAssets.sanitize_body_type(body_type),
		"skin_color": _sanitize_color(body_color).to_html(true),
		"hair_style": CharacterAppearanceAssets.sanitize_hair_style(hair_style),
		"hair_color": _sanitize_color(hair_color).to_html(true),
		"outfit_style": CharacterAppearanceAssets.sanitize_outfit_style(outfit_style),
	}


## Returns the body variant currently driving fitted equipment selection.
func get_body_type() -> String:
	return CharacterAppearanceAssets.sanitize_body_type(body_type)


## Applies the same character material treatment used by imported outfits.
func apply_equipment_materials(equipment_root: Node) -> void:
	for mesh_instance in CharacterRigAttachment.collect_mesh_instances(equipment_root):
		_apply_outfit_materials(mesh_instance)


## Records which built-in outfit pieces an equipped item visually replaces.
## Multiple slots can replace different pieces without overwriting each other.
func set_equipment_outfit_replacements(slot_id: String, part_markers: PackedStringArray) -> void:
	if slot_id.is_empty():
		return

	if part_markers.is_empty():
		_equipment_outfit_replacements.erase(slot_id)
	else:
		_equipment_outfit_replacements[slot_id] = part_markers.duplicate()
	_sync_equipment_outfit_part_visibility()


func _apply_style() -> void:
	_apply_auth_session_appearance()

	var model_root := _ensure_body_scene()
	if model_root == null:
		model_root = get_node_or_null(model_root_path) as Node3D
	if model_root == null:
		return

	_body_material = _create_toon_material(_body_color_for_preset())
	_head_only_body_material = CharacterToonMaterials.make_head_only_character_material(
		_body_color_for_preset(),
		material_style,
		CharacterAppearanceAssets.outfit_body_clip_min_y(outfit_style, body_type)
	)
	_hair_material = _create_toon_material(_sanitize_color(hair_color), true)
	_eye_material = _create_toon_material(eye_color)

	_apply_to_meshes(model_root)
	_rebuild_outfit_scene(model_root)
	_sync_base_body_mesh_visibility(model_root)
	_rebuild_hair_scene(model_root)
	_refresh_material_dependents()


func _ensure_body_scene() -> Node3D:
	var model_root := get_node_or_null(model_root_path) as Node3D
	var scene_path := CharacterAppearanceAssets.body_scene_path(body_type)
	if scene_path.is_empty():
		return model_root
	if model_root != null and _model_matches_scene_path(model_root, scene_path):
		model_root.set_meta(CharacterAppearanceAssets.BODY_SCENE_META_KEY, scene_path)
		return model_root

	if not ResourceLoader.exists(scene_path):
		push_warning("Could not find character body scene: %s" % scene_path)
		return model_root

	var body_scene := load(scene_path) as PackedScene
	var next_model := body_scene.instantiate() as Node3D if body_scene != null else null
	if next_model == null:
		push_warning("Character body scene root must be Node3D: %s" % scene_path)
		return model_root

	next_model.name = CharacterAppearanceAssets.MODEL_ROOT_NAME
	next_model.set_meta(CharacterAppearanceAssets.BODY_SCENE_META_KEY, scene_path)

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
	_outfit_root = null
	_refresh_model_dependents()
	return next_model


func _current_model_matches_body(next_body_type: String) -> bool:
	var model_root := get_node_or_null(model_root_path) as Node3D
	return model_root != null and _model_matches_scene_path(model_root, CharacterAppearanceAssets.body_scene_path(next_body_type))


func _model_matches_scene_path(model_root: Node3D, scene_path: String) -> bool:
	if String(model_root.get_meta(CharacterAppearanceAssets.BODY_SCENE_META_KEY, "")) == scene_path:
		return true
	return String(model_root.scene_file_path) == scene_path


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
	var skeleton := model_root.get_node_or_null(CharacterAppearanceAssets.SKELETON_PATH) as Skeleton3D
	if skeleton == null:
		push_warning("Character body is missing skeleton path %s." % CharacterAppearanceAssets.SKELETON_PATH)
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
	var equipment_visuals := get_node_or_null("../EquipmentVisuals")
	if equipment_visuals != null and equipment_visuals.has_method("refresh_materials"):
		equipment_visuals.call("refresh_materials")

	var occlusion_silhouette := get_node_or_null("../OcclusionSilhouette")
	if occlusion_silhouette != null and occlusion_silhouette.has_method("refresh_targets"):
		occlusion_silhouette.call("refresh_targets")


func _apply_to_meshes(node: Node) -> void:
	if bool(node.get_meta(EQUIPMENT_ATTACHMENT_META, false)):
		return
	if node.name in ["MainHandAttachment", "HairAttachment", "AppearanceHair", "AppearanceOutfit"]:
		return

	if node is MeshInstance3D:
		_apply_to_mesh_instance(node as MeshInstance3D)

	for child in node.get_children():
		_apply_to_meshes(child)


func _apply_to_mesh_instance(mesh_instance: MeshInstance3D) -> void:
	var surface_count := mesh_instance.mesh.get_surface_count() if mesh_instance.mesh != null else 0

	for surface_index in range(surface_count):
		var material := _material_for_mesh(mesh_instance, _source_material_for_surface(mesh_instance, surface_index))
		mesh_instance.set_surface_override_material(surface_index, material)


func _material_for_mesh(mesh_instance: MeshInstance3D, source_material: Material) -> Material:
	var mesh_name := mesh_instance.name.to_lower()
	if mesh_name.contains("eye"):
		return _textured_material(source_material, eye_color)
	if mesh_name.contains("hair") or mesh_name.contains("eyebrow"):
		return _textured_material(source_material, _sanitize_color(hair_color))

	return _textured_material(source_material, _body_color_for_preset())


func _sync_base_body_mesh_visibility(model_root: Node) -> void:
	var has_outfit := _outfit_root != null and is_instance_valid(_outfit_root)
	for mesh_instance in CharacterRigAttachment.collect_mesh_instances(model_root):
		if _is_runtime_attachment_mesh(mesh_instance):
			continue

		if CharacterAppearanceAssets.is_full_body_base_mesh(mesh_instance):
			mesh_instance.visible = true
			if has_outfit:
				_apply_head_only_body_material_to_mesh(mesh_instance)
			else:
				_apply_to_mesh_instance(mesh_instance)
		elif CharacterAppearanceAssets.is_base_body_mesh(mesh_instance):
			mesh_instance.visible = not has_outfit


func _is_runtime_attachment_mesh(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance == null:
		return false

	return (
		(_hair_root != null and is_instance_valid(_hair_root) and _hair_root.is_ancestor_of(mesh_instance))
		or (_outfit_root != null and is_instance_valid(_outfit_root) and _outfit_root.is_ancestor_of(mesh_instance))
		or _has_equipment_attachment_ancestor(mesh_instance)
	)


func _has_equipment_attachment_ancestor(node: Node) -> bool:
	var ancestor := node.get_parent()
	while ancestor != null:
		if bool(ancestor.get_meta(EQUIPMENT_ATTACHMENT_META, false)):
			return true
		ancestor = ancestor.get_parent()
	return false


func _create_toon_material(color: Color, cull_disabled := false) -> Material:
	return CharacterToonMaterials.make_character_material(color, material_style, cull_disabled)


func _apply_material_to_mesh(mesh_instance: MeshInstance3D, material: Material) -> void:
	if mesh_instance.mesh == null or material == null:
		return

	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		mesh_instance.set_surface_override_material(surface_index, material)


func _apply_head_only_body_material_to_mesh(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return

	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var material := CharacterToonMaterials.make_textured_character_material(
			_source_material_for_surface(mesh_instance, surface_index),
			_body_color_for_preset(),
			material_style,
			true,
			0.012,
			true,
			CharacterAppearanceAssets.outfit_body_clip_min_y(outfit_style, body_type),
			CharacterAppearanceAssets.outfit_body_neck_min_y(outfit_style, body_type),
			CharacterAppearanceAssets.outfit_body_neck_half_width(outfit_style, body_type)
		)
		mesh_instance.set_surface_override_material(surface_index, material)


func _source_material_for_surface(mesh_instance: MeshInstance3D, surface_index: int) -> Material:
	if mesh_instance == null or mesh_instance.mesh == null:
		return null
	return mesh_instance.mesh.surface_get_material(surface_index)


func _textured_material(source_material: Material, fallback_color: Color) -> Material:
	return CharacterToonMaterials.make_textured_character_material(
		source_material,
		fallback_color,
		material_style
	)


func _apply_auth_session_appearance() -> void:
	if not use_auth_session_appearance or not _is_local_player_visual():
		return

	var auth_session := get_node_or_null("/root/PrototypeAuthSession")
	if auth_session == null or not auth_session.has_method("get_character_appearance"):
		return

	var appearance: Dictionary = auth_session.call("get_character_appearance")
	body_type = CharacterAppearanceAssets.sanitize_body_type(String(appearance.get("body_type", body_type)))
	body_color = _appearance_color(appearance.get("skin_color", body_color), body_color)
	hair_style = CharacterAppearanceAssets.sanitize_hair_style(String(appearance.get("hair_style", hair_style)))
	hair_color = _appearance_color(appearance.get("hair_color", hair_color), hair_color)
	outfit_style = CharacterAppearanceAssets.sanitize_outfit_style(String(appearance.get("outfit_style", outfit_style)))


func _is_local_player_visual() -> bool:
	var parent := get_parent()
	if parent == null:
		return false

	var local_value: Variant = parent.get("is_local_player")
	return bool(local_value) if local_value is bool else false


func _body_color_for_preset() -> Color:
	return _sanitize_color(body_color)


func _rebuild_outfit_scene(model_root: Node) -> void:
	if _outfit_root != null and is_instance_valid(_outfit_root):
		_outfit_root.queue_free()
		_outfit_root = null

	if outfit_style == "none":
		return

	var target_skeleton := model_root.get_node_or_null(CharacterAppearanceAssets.SKELETON_PATH) as Skeleton3D
	if target_skeleton == null:
		push_warning("Character body is missing skeleton path %s for outfit binding." % CharacterAppearanceAssets.SKELETON_PATH)
		return

	var scene_path := CharacterAppearanceAssets.outfit_scene_path(outfit_style, body_type)
	_outfit_root = CharacterRigAttachment.bind_scene_to_skeleton(scene_path, target_skeleton, "AppearanceOutfit", "outfit")
	if _outfit_root == null:
		return

	for mesh_instance in CharacterRigAttachment.collect_mesh_instances(_outfit_root):
		_apply_outfit_materials(mesh_instance)
	_sync_equipment_outfit_part_visibility()


func _apply_outfit_materials(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return

	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var source_material := mesh_instance.get_surface_override_material(surface_index)
		if source_material == null:
			source_material = mesh_instance.mesh.surface_get_material(surface_index)

		var material := _textured_material(source_material, _body_color_for_preset()) if CharacterAppearanceAssets.is_skin_material(source_material) else _make_outfit_material(source_material)
		mesh_instance.set_surface_override_material(surface_index, material)

	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _make_outfit_material(source_material: Material) -> Material:
	return CharacterToonMaterials.make_textured_character_material(
		source_material,
		Color(0.52, 0.39, 0.24, 1.0),
		material_style
	)


func _sync_equipment_outfit_part_visibility() -> void:
	if _outfit_root == null or not is_instance_valid(_outfit_root):
		return

	var hidden_markers := PackedStringArray()
	for slot_id in _equipment_outfit_replacements.keys():
		for marker in PackedStringArray(_equipment_outfit_replacements[slot_id]):
			var normalized_marker := String(marker).strip_edges().to_lower()
			if not normalized_marker.is_empty() and not hidden_markers.has(normalized_marker):
				hidden_markers.append(normalized_marker)

	for mesh_instance in CharacterRigAttachment.collect_mesh_instances(_outfit_root):
		var mesh_name := mesh_instance.name.to_lower()
		var is_replaced := false
		for marker in hidden_markers:
			if mesh_name.contains(marker):
				is_replaced = true
				break
		mesh_instance.visible = not is_replaced


func _rebuild_hair_scene(model_root: Node) -> void:
	if _hair_root != null and is_instance_valid(_hair_root):
		_hair_root.queue_free()
		_hair_root = null

	if hair_style == "none":
		return

	var target_skeleton := model_root.get_node_or_null(CharacterAppearanceAssets.SKELETON_PATH) as Skeleton3D
	if target_skeleton == null:
		push_warning("Character body is missing skeleton path %s for hair binding." % CharacterAppearanceAssets.SKELETON_PATH)
		return

	var scene_path := CharacterAppearanceAssets.hair_scene_path(hair_style, body_type)
	_hair_root = CharacterRigAttachment.bind_scene_to_skeleton(scene_path, target_skeleton, "AppearanceHair", "hair")
	if _hair_root == null:
		return

	_apply_hair_materials(_hair_root)
	_apply_hair_attachment_tuning(_hair_root)


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
			mesh_instance.set_surface_override_material(
				surface_index,
				_textured_material(_source_material_for_surface(mesh_instance, surface_index), _sanitize_color(hair_color))
			)
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
