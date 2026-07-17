extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const W_ABILITY_PATH := "res://assets/combat/abilities/one_handed_sword_w.tres"
const W_ANIMATION_PATH := (
	"res://assets/animations/abilities/one_handed_sword/sword_and_shield_slash.glb"
)
const W_ANIMATION_NAME := &"Sword_Whirling_Slash"
const W_SLOT := &"w"


class HostileTarget:
	extends Node3D

	func is_hostile() -> bool:
		return true


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
	var animation_controller := player.get_node_or_null("Animation")
	if animation_controller == null or not animation_controller.has_method("play_weapon_ability"):
		_fail("Player should expose weapon ability animation playback.")
		return
	var immediate_playback_duration := float(animation_controller.call(
		"play_weapon_ability",
		W_ANIMATION_PATH,
		W_ANIMATION_NAME,
		float(definition.get("cast_duration_seconds"))
	))
	var runtime_player := player.find_child("RuntimeAnimationPlayer", true, false) as AnimationPlayer
	if (
		not is_equal_approx(immediate_playback_duration, 1.8)
		or runtime_player == null
		or runtime_player.current_animation != W_ANIMATION_NAME
	):
		_fail("A first-frame Whirling Slash cast should initialize and play immediately.")
		return

	await process_frame
	await process_frame

	var playback_duration := float(animation_controller.call(
		"play_weapon_ability",
		W_ANIMATION_PATH,
		W_ANIMATION_NAME,
		float(definition.get("cast_duration_seconds"))
	))
	if not is_equal_approx(playback_duration, 1.8):
		_fail("Player animation controller should fit sword W playback to its 1.8-second cast.")
		return

	runtime_player = player.find_child("RuntimeAnimationPlayer", true, false) as AnimationPlayer
	if runtime_player == null or runtime_player.current_animation != W_ANIMATION_NAME:
		_fail("Player runtime animation library should play the retargeted sword W clip.")
		return
	if (
		not animation_controller.has_method("is_playing_weapon_ability")
		or not bool(animation_controller.call("is_playing_weapon_ability"))
	):
		_fail("Animation controller should track an active weapon ability one-shot.")
		return
	animation_controller.call("play_attack", 1.0)
	if runtime_player.current_animation != W_ANIMATION_NAME:
		_fail("Auto-attack animation should not replace Whirling Slash before it finishes.")
		return
	runtime_player.seek(runtime_player.current_animation_length * 0.72, true)
	animation_controller.call("rebuild_animation_player")
	animation_controller.call("rebuild_animation_player")
	await process_frame
	await process_frame
	runtime_player = player.find_child("RuntimeAnimationPlayer", true, false) as AnimationPlayer
	if runtime_player == null or runtime_player.current_animation != W_ANIMATION_NAME:
		_fail("Rebuilding the character model should resume an active Whirling Slash.")
		return
	var resumed_progress := (
		runtime_player.current_animation_position / runtime_player.current_animation_length
	)
	if resumed_progress < 0.70 or resumed_progress > 0.74:
		_fail("Whirling Slash should resume from its pre-rebuild animation frame.")
		return

	var weapon_abilities := player.get_node("WeaponAbilities")
	weapon_abilities.set("_active_definitions", {String(W_SLOT): definition})
	if bool(player.call("request_ability_activation", W_SLOT)):
		_fail("A new ability should wait for Whirling Slash's final visual frame.")
		return

	var auto_attack := player.get_node("AutoAttack")
	var hostile := HostileTarget.new()
	hostile.name = "Hostile"
	hostile.position = Vector3(0.0, 0.0, -1.0)
	fixture.add_child(hostile)
	if not bool(auto_attack.call("start_attack", hostile, player)):
		_fail("Sword W regression fixture should be able to queue an auto-attack target.")
		return
	player.call("_on_weapon_ability_cast_started", W_SLOT, null, definition)
	if bool(auto_attack.call("has_active_target")):
		_fail("Committing Whirling Slash should cancel the overlapping auto-attack action.")
		return
	if runtime_player.current_animation != W_ANIMATION_NAME:
		_fail("Whirling Slash should still own animation playback after cancelling auto-attack.")
		return
	runtime_player.seek(runtime_player.current_animation_length - 0.001, true)
	runtime_player.advance(0.01)
	if bool(animation_controller.call("is_playing_weapon_ability")):
		_fail("Weapon ability animation ownership should release after the final frame.")
		return
	if not bool(player.call("request_ability_activation", W_SLOT)):
		_fail("A new ability should become available after Whirling Slash fully finishes.")
		return
	weapon_abilities.call("cancel_directional_targeting")
	animation_controller.call("play_attack", 1.0)
	if runtime_player.current_animation == W_ANIMATION_NAME:
		_fail("Auto-attack animation should resume after Whirling Slash fully finishes.")
		return

	var live_player := PLAYER_SCENE.instantiate() as CharacterBody3D
	live_player.name = "LiveCastPlayer"
	fixture.add_child(live_player)
	var live_abilities := live_player.get_node("WeaponAbilities")
	live_abilities.set("_active_definitions", {String(W_SLOT): definition})
	if (
		not bool(live_abilities.call("begin_directional_targeting", W_SLOT, live_player))
		or not bool(live_abilities.call("confirm_directional_cast", live_player))
	):
		_fail("A first-frame live Whirling Slash cast should commit successfully.")
		return
	var live_animation := live_player.get_node("Animation")
	var live_runtime := live_player.find_child(
		"RuntimeAnimationPlayer",
		true,
		false
	) as AnimationPlayer
	if live_runtime == null or live_runtime.current_animation != W_ANIMATION_NAME:
		_fail("A first-frame live cast should visibly start Whirling Slash.")
		return

	await create_timer(0.25).timeout
	live_animation.call("rebuild_animation_player")
	await process_frame
	await process_frame
	live_runtime = live_player.find_child("RuntimeAnimationPlayer", true, false) as AnimationPlayer
	if live_runtime == null or live_runtime.current_animation != W_ANIMATION_NAME:
		_fail("A live model rebuild should keep Whirling Slash playing.")
		return
	await create_timer(1.25).timeout
	if live_runtime.current_animation != W_ANIMATION_NAME:
		_fail("Live Whirling Slash playback should survive through its late animation frames.")
		return
	await create_timer(0.45).timeout
	if bool(live_animation.call("is_playing_weapon_ability")):
		_fail("Live Whirling Slash playback should release after its complete 1.8-second clip.")
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
