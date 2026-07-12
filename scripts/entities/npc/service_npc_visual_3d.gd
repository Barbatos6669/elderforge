## Reusable visual builder for non-combat service NPCs.
##
## Refining/crafting services still use their existing station scripts for
## recipe logic, but the world representation is now a humanoid NPC. This node
## instances the shared Universal Base Character body, binds optional hair and
## outfit meshes to that skeleton, applies the same toon material pipeline used
## by players, and exposes a small idle/walk animation bridge for ambient life.
class_name ServiceNpcVisual3D
extends Node3D

const DEFAULT_ANIMATION_SCENE := preload("res://assets/animations/universal_animation_library_1/UAL1_Standard.glb")

## Base body scene to instance.
@export_enum("male", "female") var body_type := "male"
## Visible skin material color.
@export var skin_color := Color(0.64, 0.48, 0.35, 1.0)
## Hair mesh from `CharacterAppearanceAssets`.
@export_enum("none", "buzzed", "short", "long", "buns") var hair_style := "short"
## Hair material color.
@export var hair_color := Color(0.16, 0.10, 0.06, 1.0)
## Outfit mesh from `CharacterAppearanceAssets`.
@export_enum("none", "starter_peasant", "ranger") var outfit_style := "starter_peasant"
## Color used when an imported outfit surface does not provide a texture/color.
@export var outfit_fallback_color := Color(0.52, 0.39, 0.24, 1.0)
## Optional stylistic tint per service role. Values near white keep source art.
@export var outfit_tint := Color.WHITE
## Eye material color.
@export var eye_color := Color(0.92, 0.86, 0.62, 1.0)
## Imported characters face backward relative to our gameplay convention.
@export var facing_rotation_degrees := Vector3(0.0, 180.0, 0.0)
## Root scale for quick scene-level proportion tuning.
@export var character_scale := Vector3.ONE
## Animation to loop while the NPC is standing.
@export var idle_animation_name: StringName = &"Idle"
## Animation to loop while an ambient behavior is moving the NPC.
@export var walk_animation_name: StringName = &"Walk"
## Speed multiplier for the walk animation. Service NPCs should stroll, not sprint.
@export_range(0.1, 3.0, 0.05) var walk_speed_scale := 0.75
## Blend time used when switching between idle and walk.
@export_range(0.0, 0.5, 0.01) var movement_blend_time := 0.12
## Source animation scene. Override this for specialized service idles later.
@export var source_animation_scene: PackedScene = DEFAULT_ANIMATION_SCENE
## Shared character material style.
@export_enum("experimental_shader", "standard_toon") var material_style := CharacterToonMaterials.STYLE_EXPERIMENTAL_SHADER

var _model_root: Node3D
var _body_material: Material
var _head_only_body_material: Material
var _hair_material: Material
var _eye_material: Material
var _hair_root: Node3D
var _outfit_root: Node3D
var _animation_player: AnimationPlayer
var _is_moving := false


func _ready() -> void:
	_rebuild_visual()


## Rebuilds the visible character from exported appearance settings.
func _rebuild_visual() -> void:
	for child in get_children():
		child.queue_free()

	_animation_player = null
	_model_root = _instantiate_body_scene()
	if _model_root == null:
		return

	_model_root.name = CharacterAppearanceAssets.MODEL_ROOT_NAME
	_model_root.rotation_degrees = facing_rotation_degrees
	_model_root.scale = character_scale
	add_child(_model_root)

	_body_material = _create_character_material(skin_color)
	_head_only_body_material = CharacterToonMaterials.make_head_only_character_material(
		skin_color,
		material_style,
		CharacterAppearanceAssets.head_only_clip_min_y(body_type)
	)
	_hair_material = _create_character_material(hair_color, true)
	_eye_material = _create_character_material(eye_color)

	_apply_body_materials(_model_root)
	_rebuild_outfit()
	_sync_base_body_mesh_visibility()
	_rebuild_hair()
	_setup_animation_player()


## Called by ambient NPC behaviors when the visible character starts or stops moving.
func set_moving(is_moving: bool) -> void:
	if is_moving == _is_moving:
		return

	_is_moving = is_moving
	_play_current_animation()


func _instantiate_body_scene() -> Node3D:
	var scene_path := CharacterAppearanceAssets.body_scene_path(body_type)
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path, "PackedScene"):
		push_warning("Service NPC body scene missing: %s" % scene_path)
		return null

	var body_scene := load(scene_path) as PackedScene
	var body_root := body_scene.instantiate() as Node3D if body_scene != null else null
	if body_root == null:
		push_warning("Service NPC body scene root must be Node3D: %s" % scene_path)
		return null

	body_root.set_meta(CharacterAppearanceAssets.BODY_SCENE_META_KEY, scene_path)
	return body_root


func _apply_body_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var material := _material_for_base_mesh(mesh_instance)
		_apply_material_to_mesh(mesh_instance, material)
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	for child in node.get_children():
		_apply_body_materials(child)


func _material_for_base_mesh(mesh_instance: MeshInstance3D) -> Material:
	var mesh_name := mesh_instance.name.to_lower()
	if mesh_name.contains("eye"):
		return _eye_material
	if mesh_name.contains("hair") or mesh_name.contains("eyebrow"):
		return _hair_material

	return _body_material


func _rebuild_outfit() -> void:
	_outfit_root = null
	if outfit_style == "none":
		return

	var target_skeleton := _target_skeleton()
	if target_skeleton == null:
		return

	var scene_path := CharacterAppearanceAssets.outfit_scene_path(outfit_style, body_type)
	_outfit_root = CharacterRigAttachment.bind_scene_to_skeleton(scene_path, target_skeleton, "ServiceOutfit", "outfit")
	if _outfit_root == null:
		return

	for mesh_instance in CharacterRigAttachment.collect_mesh_instances(_outfit_root):
		_apply_outfit_materials(mesh_instance)


func _apply_outfit_materials(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return

	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var source_material := mesh_instance.get_surface_override_material(surface_index)
		if source_material == null:
			source_material = mesh_instance.mesh.surface_get_material(surface_index)

		var material := _body_material
		if not CharacterAppearanceAssets.is_skin_material(source_material):
			material = CharacterToonMaterials.make_textured_character_material(
				source_material,
				_tinted_outfit_fallback(),
				material_style
			)
		mesh_instance.set_surface_override_material(surface_index, material)

	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _sync_base_body_mesh_visibility() -> void:
	var has_outfit := _outfit_root != null and is_instance_valid(_outfit_root)
	for mesh_instance in CharacterRigAttachment.collect_mesh_instances(_model_root):
		if _is_attachment_mesh(mesh_instance):
			continue

		if CharacterAppearanceAssets.is_full_body_base_mesh(mesh_instance):
			mesh_instance.visible = true
			_apply_material_to_mesh(mesh_instance, _head_only_body_material if has_outfit else _body_material)
		elif CharacterAppearanceAssets.is_base_body_mesh(mesh_instance):
			mesh_instance.visible = not has_outfit


func _rebuild_hair() -> void:
	_hair_root = null
	if hair_style == "none":
		return

	var target_skeleton := _target_skeleton()
	if target_skeleton == null:
		return

	var scene_path := CharacterAppearanceAssets.hair_scene_path(hair_style, body_type)
	_hair_root = CharacterRigAttachment.bind_scene_to_skeleton(scene_path, target_skeleton, "ServiceHair", "hair")
	if _hair_root == null:
		return

	for mesh_instance in CharacterRigAttachment.collect_mesh_instances(_hair_root):
		_apply_material_to_mesh(mesh_instance, _hair_material)
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _setup_animation_player() -> void:
	if _model_root == null or source_animation_scene == null:
		return

	var source_root := source_animation_scene.instantiate()
	var source_player := _find_animation_player(source_root)
	if source_player == null:
		if source_root != null:
			source_root.queue_free()
		return

	var animation_player := AnimationPlayer.new()
	animation_player.name = "ServiceAnimationPlayer"
	animation_player.root_node = NodePath("..")
	_model_root.add_child(animation_player)

	var animation_library := AnimationLibrary.new()
	_add_looping_animation(animation_library, source_player, idle_animation_name)
	_add_looping_animation(animation_library, source_player, walk_animation_name)
	animation_player.add_animation_library("", animation_library)
	_animation_player = animation_player
	_play_current_animation(true)

	source_root.queue_free()


func _add_looping_animation(
	animation_library: AnimationLibrary,
	source_player: AnimationPlayer,
	animation_name: StringName
) -> void:
	if animation_name == StringName("") or animation_library.has_animation(animation_name):
		return
	if not source_player.has_animation(animation_name):
		return

	var animation := source_player.get_animation(animation_name).duplicate(true) as Animation
	animation.loop_mode = Animation.LOOP_LINEAR
	animation_library.add_animation(animation_name, animation)


func _play_current_animation(force_restart := false) -> void:
	if _animation_player == null:
		return

	var animation_name := walk_animation_name if _is_moving else idle_animation_name
	if not _animation_player.has_animation(animation_name):
		animation_name = idle_animation_name
	if not _animation_player.has_animation(animation_name):
		return

	_animation_player.speed_scale = walk_speed_scale if _is_moving else 1.0
	if not force_restart and _animation_player.current_animation == animation_name:
		return

	_animation_player.play(animation_name, movement_blend_time)


func _target_skeleton() -> Skeleton3D:
	if _model_root == null:
		return null

	var skeleton := _model_root.get_node_or_null(CharacterAppearanceAssets.SKELETON_PATH) as Skeleton3D
	if skeleton == null:
		push_warning("Service NPC body is missing skeleton path %s." % CharacterAppearanceAssets.SKELETON_PATH)

	return skeleton


func _is_attachment_mesh(mesh_instance: MeshInstance3D) -> bool:
	return (
		mesh_instance != null
		and (
			(_hair_root != null and is_instance_valid(_hair_root) and _hair_root.is_ancestor_of(mesh_instance))
			or (_outfit_root != null and is_instance_valid(_outfit_root) and _outfit_root.is_ancestor_of(mesh_instance))
		)
	)


func _create_character_material(color: Color, cull_disabled := false) -> Material:
	return CharacterToonMaterials.make_character_material(color, material_style, cull_disabled)


func _apply_material_to_mesh(mesh_instance: MeshInstance3D, material: Material) -> void:
	if mesh_instance == null or mesh_instance.mesh == null or material == null:
		return

	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		mesh_instance.set_surface_override_material(surface_index, material)


func _tinted_outfit_fallback() -> Color:
	return Color(
		clampf(outfit_fallback_color.r * outfit_tint.r, 0.0, 1.0),
		clampf(outfit_fallback_color.g * outfit_tint.g, 0.0, 1.0),
		clampf(outfit_fallback_color.b * outfit_tint.b, 0.0, 1.0),
		clampf(outfit_fallback_color.a * outfit_tint.a, 0.0, 1.0)
	)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer

	for child in node.get_children():
		var animation_player := _find_animation_player(child)
		if animation_player != null:
			return animation_player

	return null
