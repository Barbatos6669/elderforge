extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const W_ABILITY_PATH := "res://assets/combat/abilities/one_handed_sword_w.tres"
const W_ANIMATION_PATH := (
	"res://assets/animations/abilities/one_handed_sword/sword_and_shield_slash.glb"
)
const W_ANIMATION_NAME := &"Sword_Whirling_Slash"


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var definition := load(W_ABILITY_PATH) as Resource
	if definition == null:
		_fail("Sword W ability resource should load.")
		return
	if (
		StringName(String(definition.get("input_slot"))) != &"w"
		or String(definition.get("animation_scene_path")) != W_ANIMATION_PATH
		or StringName(String(definition.get("animation_name"))) != W_ANIMATION_NAME
	):
		_fail("Sword W should point at the retargeted Whirling Slash animation.")
		return
	if (
		String(definition.get("targeting_mode")) != "direction"
		or PackedFloat32Array(definition.get("impact_fractions"))
		!= PackedFloat32Array([0.36, 0.72])
		or PackedFloat32Array(definition.get("impact_damage_scales"))
		!= PackedFloat32Array([0.5, 0.5])
		or not is_equal_approx(float(definition.get("attack_range")), 3.0)
		or not is_equal_approx(float(definition.get("area_arc_degrees")), 180.0)
	):
		_fail("Sword W should define a three-meter, two-hit directional semicircle.")
		return

	var animation_scene := load(W_ANIMATION_PATH) as PackedScene
	if animation_scene == null:
		_fail("Retargeted sword W animation scene should load.")
		return
	var animation_root := animation_scene.instantiate()
	var source_player := _find_animation_player(animation_root)
	if source_player == null or not source_player.has_animation(W_ANIMATION_NAME):
		_fail("Retargeted animation scene should expose Sword_Whirling_Slash.")
		return
	var source_animation := source_player.get_animation(W_ANIMATION_NAME)
	if source_animation == null or not is_equal_approx(source_animation.length, 3.533333):
		_fail("Retargeted sword W clip should preserve the source's 3.53-second duration.")
		return
	if source_animation.loop_mode != Animation.LOOP_NONE:
		_fail("Sword W animation should remain a non-looping one-shot.")
		return
	if not _tracks_target_elderforge_skeleton(source_animation):
		return
	animation_root.free()

	var fixture := Node3D.new()
	fixture.name = "SwordWAnimationFixture"
	root.add_child(fixture)
	current_scene = fixture
	var player := PLAYER_SCENE.instantiate() as CharacterBody3D
	player.process_mode = Node.PROCESS_MODE_DISABLED
	fixture.add_child(player)
	await process_frame
	await process_frame

	var animation_controller := player.get_node_or_null("Animation")
	if animation_controller == null or not animation_controller.has_method("play_weapon_ability"):
		_fail("Player should expose weapon ability animation playback.")
		return
	var playback_duration := float(animation_controller.call(
		"play_weapon_ability",
		W_ANIMATION_PATH,
		W_ANIMATION_NAME,
		float(definition.get("cast_duration_seconds"))
	))
	if not is_equal_approx(playback_duration, 1.8):
		_fail("Player animation controller should fit sword W playback to its 1.8-second cast.")
		return

	var runtime_player := player.find_child("RuntimeAnimationPlayer", true, false) as AnimationPlayer
	if runtime_player == null or runtime_player.current_animation != W_ANIMATION_NAME:
		_fail("Player runtime animation library should play the retargeted sword W clip.")
		return

	fixture.queue_free()
	await process_frame
	print("Sword W animation tests passed.")
	quit(0)


func _tracks_target_elderforge_skeleton(animation: Animation) -> bool:
	var required_bones := {
		"pelvis": false,
		"neck_01": false,
		"Head": false,
		"hand_r": false,
		"hand_l": false,
	}
	for track_index in range(animation.get_track_count()):
		var track_path := String(animation.track_get_path(track_index))
		if track_path.contains("mixamorig"):
			_fail("Retargeted sword W animation should not retain Mixamo bone paths.")
			return false
		if not track_path.begins_with("Armature/Skeleton3D:"):
			continue
		var bone_name := track_path.get_slice(":", 1)
		if animation.track_get_type(track_index) == Animation.TYPE_POSITION_3D and bone_name != "pelvis":
			_fail("Only the pelvis may carry translation in the in-place sword W clip.")
			return false
		if required_bones.has(bone_name):
			required_bones[bone_name] = true
	for bone_name in required_bones:
		if not bool(required_bones[bone_name]):
			_fail("Retargeted sword W animation is missing the %s track." % bone_name)
			return false
	return true


func _find_animation_player(root_node: Node) -> AnimationPlayer:
	if root_node is AnimationPlayer:
		return root_node as AnimationPlayer
	for child in root_node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
