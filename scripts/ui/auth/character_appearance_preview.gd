## 3D character preview used by the customization screen.
##
## The control owns a small SubViewport scene with its own camera, lights, and
## character model. It mirrors the same body/hair asset choices used by
## PlayerVisualStyle so the creator preview matches the in-game player.
class_name CharacterAppearancePreview
extends Control

const IDLE_ANIMATION_SCENE_PATH := "res://assets/animations/universal_animation_library_1/UAL1_Standard.glb"
const IDLE_ANIMATION_NAME := &"Idle"

@export_range(0.0, 1.0, 0.01) var zoom_ratio := 0.35:
	set(value):
		zoom_ratio = clampf(value, 0.0, 1.0)
		_update_camera()

var body_type := "male"
var skin_color := Color(0.74, 0.86, 0.92, 1.0)
var hair_style := "short"
var hair_color := Color(0.16, 0.11, 0.08, 1.0)
var outfit_style := "starter_peasant"

var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _world_root: Node3D
var _pivot: Node3D
var _character_root: Node3D
var _outfit_root: Node3D
var _camera: Camera3D
var _animation_player: AnimationPlayer
var _yaw_degrees := 20.0
var _is_dragging := false
var _last_drag_position := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_preview_scene()
	_rebuild_character()
	_update_camera()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			set_zoom_ratio(zoom_ratio + 0.08)
			accept_event()
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			set_zoom_ratio(zoom_ratio - 0.08)
			accept_event()
		elif mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = mouse_button.pressed
			_last_drag_position = mouse_button.position
			accept_event()
	elif event is InputEventMouseMotion and _is_dragging:
		var mouse_motion := event as InputEventMouseMotion
		rotate_preview_degrees(mouse_motion.relative.x * 0.35)
		_last_drag_position = mouse_motion.position
		accept_event()


func set_appearance(
	new_body_type: String,
	new_skin_color: Color,
	new_hair_style: String,
	new_hair_color: Color
) -> void:
	var next_body_type := CharacterAppearanceAssets.sanitize_body_type(new_body_type)
	var next_hair_style := CharacterAppearanceAssets.sanitize_hair_style(new_hair_style)
	var should_rebuild := next_body_type != body_type or next_hair_style != hair_style
	body_type = next_body_type
	skin_color = _sanitize_color(new_skin_color)
	hair_style = next_hair_style
	hair_color = _sanitize_color(new_hair_color)

	if should_rebuild:
		_rebuild_character()
	else:
		_apply_current_materials()


func rotate_preview_degrees(amount: float) -> void:
	_yaw_degrees = fposmod(_yaw_degrees + amount, 360.0)
	if _pivot != null:
		_pivot.rotation_degrees.y = _yaw_degrees


func reset_rotation() -> void:
	_yaw_degrees = 20.0
	if _pivot != null:
		_pivot.rotation_degrees.y = _yaw_degrees


func set_zoom_ratio(value: float) -> void:
	zoom_ratio = clampf(value, 0.0, 1.0)
	_update_camera()


func _build_preview_scene() -> void:
	_viewport_container = SubViewportContainer.new()
	_viewport_container.name = "PreviewViewportContainer"
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.name = "PreviewViewport"
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	_viewport_container.add_child(_viewport)

	_world_root = Node3D.new()
	_world_root.name = "PreviewWorld"
	_viewport.add_child(_world_root)

	var environment := WorldEnvironment.new()
	environment.name = "Environment"
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.07, 0.09, 0.1, 1.0)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.55, 0.64, 0.68, 1.0)
	environment.environment.ambient_light_energy = 0.58
	_world_root.add_child(environment)

	var key_light := DirectionalLight3D.new()
	key_light.name = "KeySun"
	key_light.light_color = Color(0.95, 0.86, 0.72, 1.0)
	key_light.light_energy = 1.55
	key_light.shadow_enabled = true
	key_light.shadow_opacity = 0.58
	key_light.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	_world_root.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.name = "SkyFill"
	fill_light.light_color = Color(0.42, 0.58, 0.95, 1.0)
	fill_light.light_energy = 0.48
	fill_light.shadow_enabled = false
	fill_light.rotation_degrees = Vector3(-24.0, -135.0, 0.0)
	_world_root.add_child(fill_light)

	var warmth_light := OmniLight3D.new()
	warmth_light.name = "SpawnWarmth"
	warmth_light.light_color = Color(1.0, 0.62, 0.34, 1.0)
	warmth_light.light_energy = 0.58
	warmth_light.shadow_enabled = false
	warmth_light.omni_range = 8.0
	warmth_light.position = Vector3(0.0, 3.5, 0.0)
	_world_root.add_child(warmth_light)

	var floor := MeshInstance3D.new()
	floor.name = "PreviewFloor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(3.3, 3.3)
	floor.mesh = plane
	floor.position = Vector3(0.0, -0.02, 0.0)
	floor.material_override = _make_floor_material()
	_world_root.add_child(floor)

	_pivot = Node3D.new()
	_pivot.name = "CharacterPivot"
	_pivot.rotation_degrees.y = _yaw_degrees
	_world_root.add_child(_pivot)

	_camera = Camera3D.new()
	_camera.name = "PreviewCamera"
	_camera.fov = 31.0
	_camera.current = true
	_world_root.add_child(_camera)


func _rebuild_character() -> void:
	if _pivot == null:
		return

	if _character_root != null and is_instance_valid(_character_root):
		_pivot.remove_child(_character_root)
		_character_root.queue_free()
		_character_root = null
		_outfit_root = null

	var body_scene_path := CharacterAppearanceAssets.body_scene_path(body_type)
	if body_scene_path.is_empty() or not ResourceLoader.exists(body_scene_path):
		push_warning("Missing preview body scene: %s" % body_scene_path)
		return

	var body_scene := load(body_scene_path) as PackedScene
	_character_root = body_scene.instantiate() as Node3D if body_scene != null else null
	if _character_root == null:
		return

	_character_root.name = "PreviewCharacter"
	_pivot.add_child(_character_root, true)
	_apply_current_materials()
	_add_outfit()
	_sync_base_body_mesh_visibility()
	_add_hair()
	_setup_idle_animation()


func _add_hair() -> void:
	if _character_root == null or hair_style == "none":
		return

	var target_skeleton := _character_root.get_node_or_null(CharacterAppearanceAssets.SKELETON_PATH) as Skeleton3D
	if target_skeleton == null:
		push_warning("Preview character is missing %s for hair binding." % CharacterAppearanceAssets.SKELETON_PATH)
		return

	var hair_scene_path := CharacterAppearanceAssets.hair_scene_path(hair_style, body_type)
	var hair_root := CharacterRigAttachment.bind_scene_to_skeleton(
		hair_scene_path,
		target_skeleton,
		"PreviewHair",
		"preview hair"
	)
	if hair_root == null:
		return

	var hair_material := _make_toon_material(hair_color, true)
	for mesh_instance in CharacterRigAttachment.collect_mesh_instances(hair_root):
		_apply_material_to_mesh(mesh_instance, hair_material)


func _add_outfit() -> void:
	if _character_root == null or outfit_style == "none":
		return

	var target_skeleton := _character_root.get_node_or_null(CharacterAppearanceAssets.SKELETON_PATH) as Skeleton3D
	if target_skeleton == null:
		push_warning("Preview character is missing %s for outfit binding." % CharacterAppearanceAssets.SKELETON_PATH)
		return

	var outfit_scene_path := CharacterAppearanceAssets.outfit_scene_path(outfit_style, body_type)
	_outfit_root = CharacterRigAttachment.bind_scene_to_skeleton(
		outfit_scene_path,
		target_skeleton,
		"PreviewOutfit",
		"preview outfit"
	)
	if _outfit_root == null:
		return

	for mesh_instance in CharacterRigAttachment.collect_mesh_instances(_outfit_root):
		_apply_outfit_materials(mesh_instance)


func _setup_idle_animation() -> void:
	if _character_root == null:
		return

	if _animation_player != null and is_instance_valid(_animation_player):
		_animation_player.queue_free()
		_animation_player = null

	if not ResourceLoader.exists(IDLE_ANIMATION_SCENE_PATH):
		push_warning("Missing preview idle animation scene: %s" % IDLE_ANIMATION_SCENE_PATH)
		return

	var animation_scene := load(IDLE_ANIMATION_SCENE_PATH) as PackedScene
	var source_root := animation_scene.instantiate() if animation_scene != null else null
	var source_player := _find_animation_player(source_root) if source_root != null else null
	if source_player == null or not source_player.has_animation(IDLE_ANIMATION_NAME):
		if source_root != null:
			source_root.queue_free()
		push_warning("Preview idle animation '%s' was not found." % IDLE_ANIMATION_NAME)
		return

	var idle_animation := source_player.get_animation(IDLE_ANIMATION_NAME).duplicate(true) as Animation
	idle_animation.loop_mode = Animation.LOOP_LINEAR

	var animation_library := AnimationLibrary.new()
	animation_library.add_animation(IDLE_ANIMATION_NAME, idle_animation)

	_animation_player = AnimationPlayer.new()
	_animation_player.name = "PreviewIdleAnimationPlayer"
	_animation_player.root_node = NodePath("..")
	_character_root.add_child(_animation_player)
	_animation_player.add_animation_library("", animation_library)
	_animation_player.play(IDLE_ANIMATION_NAME)

	source_root.queue_free()


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node == null:
		return null
	if node is AnimationPlayer:
		return node as AnimationPlayer

	for child in node.get_children():
		var animation_player := _find_animation_player(child)
		if animation_player != null:
			return animation_player

	return null


func _apply_current_materials() -> void:
	if _character_root == null:
		return

	var body_material := _make_toon_material(skin_color)
	var hair_material := _make_toon_material(hair_color)
	var eye_material := _make_toon_material(Color(0.95, 0.88, 0.58, 1.0))
	_apply_character_materials(_character_root, body_material, hair_material, eye_material)
	_refresh_outfit_materials()


func _apply_character_materials(
	node: Node,
	body_material: Material,
	hair_material: Material,
	eye_material: Material
) -> void:
	if node.name == "PreviewOutfit":
		return

	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var material := body_material
		var mesh_name := mesh_instance.name.to_lower()
		if mesh_name.contains("eye"):
			material = eye_material
		elif mesh_name.contains("hair") or mesh_name.contains("eyebrow"):
			material = hair_material
		_apply_material_to_mesh(mesh_instance, material)

	for child in node.get_children():
		_apply_character_materials(child, body_material, hair_material, eye_material)


func _sync_base_body_mesh_visibility() -> void:
	if _character_root == null:
		return

	var has_outfit := _outfit_root != null and is_instance_valid(_outfit_root)
	var head_only_material := CharacterToonMaterials.make_head_only_character_material(
		skin_color,
		CharacterToonMaterials.STYLE_EXPERIMENTAL_SHADER,
		CharacterAppearanceAssets.head_only_clip_min_y(body_type)
	)
	for mesh_instance in CharacterRigAttachment.collect_mesh_instances(_character_root):
		if _is_preview_attachment_mesh(mesh_instance):
			continue

		if CharacterAppearanceAssets.is_full_body_base_mesh(mesh_instance):
			mesh_instance.visible = true
			_apply_material_to_mesh(mesh_instance, head_only_material if has_outfit else _make_toon_material(skin_color))
		elif CharacterAppearanceAssets.is_base_body_mesh(mesh_instance):
			mesh_instance.visible = not has_outfit


func _is_preview_attachment_mesh(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance == null:
		return false

	return _outfit_root != null and is_instance_valid(_outfit_root) and _outfit_root.is_ancestor_of(mesh_instance)


func _refresh_outfit_materials() -> void:
	if _outfit_root == null or not is_instance_valid(_outfit_root):
		return

	for mesh_instance in CharacterRigAttachment.collect_mesh_instances(_outfit_root):
		_apply_outfit_materials(mesh_instance)


func _apply_outfit_materials(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return

	var body_material := _make_toon_material(skin_color)
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var source_material := mesh_instance.mesh.surface_get_material(surface_index)
		var material := body_material if CharacterAppearanceAssets.is_skin_material(source_material) else _make_outfit_material(source_material)
		mesh_instance.set_surface_override_material(surface_index, material)

	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _make_outfit_material(source_material: Material) -> Material:
	return CharacterToonMaterials.make_textured_character_material(
		source_material,
		Color(0.52, 0.39, 0.24, 1.0),
		CharacterToonMaterials.STYLE_EXPERIMENTAL_SHADER
	)


func _apply_material_to_mesh(mesh_instance: MeshInstance3D, material: Material) -> void:
	var surface_count := mesh_instance.mesh.get_surface_count() if mesh_instance.mesh != null else 0
	for surface_index in range(surface_count):
		mesh_instance.set_surface_override_material(surface_index, material)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _make_toon_material(color: Color, cull_disabled := false) -> Material:
	return CharacterToonMaterials.make_character_material(color, CharacterToonMaterials.STYLE_EXPERIMENTAL_SHADER, cull_disabled)


func _make_floor_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.26, 0.22, 1.0)
	material.roughness = 1.0
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	return material


func _update_camera() -> void:
	if _camera == null:
		return

	var distance := lerpf(3.6, 1.75, zoom_ratio)
	_camera.position = Vector3(0.0, 1.12, distance)
	_camera.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)


func _sanitize_color(color: Color) -> Color:
	if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a):
		return Color.WHITE
	return Color(
		clampf(color.r, 0.0, 1.0),
		clampf(color.g, 0.0, 1.0),
		clampf(color.b, 0.0, 1.0),
		clampf(color.a, 0.0, 1.0)
	)
