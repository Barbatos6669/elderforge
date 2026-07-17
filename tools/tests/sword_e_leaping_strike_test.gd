extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const CombatHealthScript := preload("res://scripts/combat/combat_health.gd")
const DirectionalIndicatorScript := preload(
	"res://scripts/effects/directional_ability_indicator.gd"
)
const EnemyMobAIScript := preload("res://scripts/entities/enemy_mob_ai.gd")
const PlayerWeaponAbilitiesScript := preload(
	"res://scripts/player/combat/player_weapon_abilities.gd"
)
const PlayerMovementMotorScript := preload(
	"res://scripts/player/movement/player_movement_motor.gd"
)
const WeaponAbilityCatalogScript := preload(
	"res://scripts/combat/abilities/weapon_ability_catalog.gd"
)
const E_ABILITY_PATH := "res://assets/combat/abilities/one_handed_sword_e.tres"
const E_ANIMATION_PATH := (
	"res://assets/animations/abilities/one_handed_sword/sword_and_shield_attack.glb"
)
const E_ANIMATION_NAME := &"Sword_Leaping_Strike"
const E_SLOT := &"e"

var _movement_events := 0
var _movement_direction := Vector3.ZERO
var _movement_distance := 0.0
var _movement_duration := 0.0
var _landed_events := 0


class AreaTarget:
	extends Node3D

	func is_hostile() -> bool:
		return true


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var definition := load(E_ABILITY_PATH) as Resource
	if not _validate_definition(definition):
		return
	if not _validate_animation_asset():
		return
	if not _validate_player_animation_playback(definition):
		return

	var fixture := Node3D.new()
	fixture.name = "SwordELeapingStrikeFixture"
	root.add_child(fixture)
	current_scene = fixture
	await process_frame

	if not await _validate_player_cast(fixture, definition):
		return
	if not await _validate_forced_movement_distance(fixture):
		return
	if not await _validate_mob_cast(fixture, definition):
		return

	fixture.queue_free()
	await process_frame
	print("Sword E Leaping Strike tests passed.")
	quit(0)


func _validate_definition(definition: Resource) -> bool:
	if definition == null:
		return _fail("Sword E ability resource should load.")
	if (
		String(definition.get("ability_id")) != "one_handed_sword_e"
		or StringName(String(definition.get("input_slot"))) != E_SLOT
		or String(definition.get("targeting_mode")) != "direction"
		or String(definition.get("execution_type")) != "damage"
	):
		return _fail("Sword E should be a directional damage ability on E.")
	if (
		not is_equal_approx(float(definition.get("impact_fraction")), 0.53)
		or not is_equal_approx(float(definition.get("movement_distance")), 3.65)
		or not bool(definition.get("aim_landing_point"))
		or not is_equal_approx(float(definition.get("attack_range")), 1.75)
		or not is_equal_approx(float(definition.get("area_arc_degrees")), 360.0)
	):
		return _fail("Sword E should leap 3.65 meters into a 1.75-meter landing circle.")
	if (
		String(definition.get("animation_scene_path")) != E_ANIMATION_PATH
		or StringName(String(definition.get("animation_name"))) != E_ANIMATION_NAME
	):
		return _fail("Sword E should point at the retargeted Leaping Strike animation.")

	var family := load("res://assets/items/families/weapons/one_handed_sword.tres") as Resource
	var ability_paths := family.get("ability_path_templates") as Dictionary if family != null else {}
	if String(ability_paths.get("e", "")) != E_ABILITY_PATH:
		return _fail("Every one-handed sword tier should equip Leaping Strike on E.")
	if not WeaponAbilityCatalogScript.has_ability("one_handed_sword_e"):
		return _fail("Leaping Strike should be registered in the trusted ability catalog.")
	return true


func _validate_animation_asset() -> bool:
	var animation_scene := load(E_ANIMATION_PATH) as PackedScene
	if animation_scene == null:
		return _fail("Retargeted sword E animation scene should load.")
	var animation_root := animation_scene.instantiate()
	var source_player := _find_animation_player(animation_root)
	if source_player == null or not source_player.has_animation(E_ANIMATION_NAME):
		animation_root.free()
		return _fail("Retargeted sword E scene should expose Sword_Leaping_Strike.")
	var animation := source_player.get_animation(E_ANIMATION_NAME)
	if animation == null or not is_equal_approx(animation.length, 2.333333):
		animation_root.free()
		return _fail("Sword E should preserve the source clip's 2.33-second duration.")
	if animation.loop_mode != Animation.LOOP_NONE:
		animation_root.free()
		return _fail("Sword E animation should remain a non-looping one-shot.")
	if not _validate_retargeted_tracks(animation):
		animation_root.free()
		return false
	root.add_child(animation_root)
	if not _validate_in_place_jump(animation_root, source_player, animation):
		animation_root.free()
		return false
	animation_root.free()
	return true


func _validate_player_animation_playback(definition: Resource) -> bool:
	var player := PLAYER_SCENE.instantiate() as CharacterBody3D
	player.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(player)
	var animation_controller := player.get_node_or_null("Animation")
	if animation_controller == null:
		player.free()
		return _fail("Player should expose its animation controller.")
	var duration := float(animation_controller.call(
		"play_weapon_ability",
		E_ANIMATION_PATH,
		E_ANIMATION_NAME,
		float(definition.get("cast_duration_seconds"))
	))
	var runtime_player := player.find_child("RuntimeAnimationPlayer", true, false) as AnimationPlayer
	if (
		not is_equal_approx(duration, 1.8)
		or runtime_player == null
		or runtime_player.current_animation != E_ANIMATION_NAME
	):
		player.free()
		return _fail("Player should immediately play the complete E one-shot at cast speed.")
	player.free()
	return true


func _validate_player_cast(fixture: Node3D, source_definition: Resource) -> bool:
	var attacker := Node3D.new()
	attacker.name = "Attacker"
	fixture.add_child(attacker)

	var indicator := DirectionalIndicatorScript.new() as DirectionalAbilityIndicator
	indicator.name = "DirectionalIndicator"
	attacker.add_child(indicator)
	var abilities := PlayerWeaponAbilitiesScript.new() as PlayerWeaponAbilities
	abilities.name = "WeaponAbilities"
	abilities.directional_indicator_path = NodePath("../DirectionalIndicator")
	attacker.add_child(abilities)
	abilities.directional_movement_started.connect(_on_directional_movement_started)
	abilities.ability_cast_landed.connect(_on_ability_cast_landed)
	await process_frame

	var definition := source_definition.duplicate() as Resource
	definition.set("energy_cost", 0.0)
	abilities.set("_active_definitions", {String(E_SLOT): definition})

	var aimed_landing := Vector3(1.35, 0.0, -1.8)
	var aimed_direction := aimed_landing.normalized()
	var center_target := _add_target(fixture, "CenterTarget", aimed_landing)
	var side_target := _add_target(
		fixture,
		"SideTarget",
		aimed_landing + Vector3(1.2, 0.0, 0.9)
	)
	var outside_target := _add_target(
		fixture,
		"OutsideTarget",
		aimed_landing + Vector3(1.68, 0.0, 1.26)
	)
	if not abilities.begin_directional_targeting(E_SLOT, attacker):
		return _fail("Sword E should enter cursor-driven targeting.")
	abilities.update_directional_targeting(attacker, Vector3(0.0, 0.0, -8.0))
	if indicator.get_indicator_kind() != &"leap":
		return _fail("Sword E should preview both its travel path and landing circle.")
	var landing_fill := indicator.get_node_or_null("LandingFill") as MeshInstance3D
	if landing_fill == null or landing_fill.mesh == null or not landing_fill.visible:
		return _fail("Sword E landing preview should expose visible circle geometry.")
	var preview_center := indicator.to_global(landing_fill.position)
	if Vector2(preview_center.x, preview_center.z).distance_to(Vector2(0.0, -3.65)) > 0.001:
		return _fail("Sword E should clamp an out-of-range cursor to its maximum range.")
	abilities.update_directional_targeting(attacker, aimed_landing)
	preview_center = indicator.to_global(landing_fill.position)
	if Vector2(preview_center.x, preview_center.z).distance_to(
		Vector2(aimed_landing.x, aimed_landing.z)
	) > 0.001:
		return _fail("Sword E landing circle should follow an in-range cursor point.")
	if not abilities.confirm_directional_cast(attacker):
		return _fail("Sword E should commit after the player confirms its direction.")
	var expected_movement_duration := 1.8 * 0.53
	if (
		_movement_events != 1
		or _movement_direction.distance_to(aimed_direction) > 0.001
		or not is_equal_approx(_movement_distance, 2.25)
		or not is_equal_approx(_movement_duration, expected_movement_duration)
	):
		return _fail("Sword E should travel to its landing point before the strike frame.")

	attacker.position = aimed_landing
	abilities.update_abilities(attacker, expected_movement_duration - 0.01)
	if not is_equal_approx(_health(center_target).current_health, 500.0):
		return _fail("Sword E should not damage enemies before the landing frame.")
	abilities.update_abilities(attacker, 0.02)
	if (
		not is_equal_approx(_health(center_target).current_health, 340.0)
		or not is_equal_approx(_health(side_target).current_health, 340.0)
		or not is_equal_approx(_health(outside_target).current_health, 500.0)
		or _landed_events != 2
	):
		return _fail("Sword E should damage only enemies inside its landing circle.")
	if not abilities.is_directional_movement_active():
		return _fail("Sword E should preserve the motor handoff on its landing frame.")
	abilities.update_abilities(attacker, 0.01)
	if abilities.is_directional_movement_active() or not abilities.should_hold_position(attacker):
		return _fail("Sword E should hold its landing recovery instead of sliding afterward.")
	return true


func _validate_mob_cast(fixture: Node3D, source_definition: Resource) -> bool:
	var mob := CharacterBody3D.new()
	mob.name = "LeapingMob"
	fixture.add_child(mob)
	var mob_health := CombatHealthScript.new()
	mob_health.name = "Health"
	mob.add_child(mob_health)
	var ai := EnemyMobAIScript.new() as EnemyMobAI
	ai.name = "AI"
	ai.process_mode = Node.PROCESS_MODE_DISABLED
	mob.add_child(ai)

	var target := CharacterBody3D.new()
	target.name = "MobTarget"
	target.position = Vector3(0.0, 0.0, -4.0)
	target.add_to_group("player")
	fixture.add_child(target)
	var target_health := CombatHealthScript.new()
	target_health.name = "Health"
	target_health.max_health = 500.0
	target_health.current_health = 500.0
	target.add_child(target_health)
	await process_frame

	var definition := source_definition.duplicate() as Resource
	definition.set("energy_cost", 0.0)
	ai.set("_active_definitions", {String(E_SLOT): definition})
	ai.set("_target", target)
	target.position = Vector3(0.6, 0.0, -0.8)
	if ai.call("_best_ready_damage_ability") != null:
		return _fail("A sword mob should not waste its mobility E while point-blank.")
	target.position = Vector3(1.5, 0.0, -2.0)
	if ai.call("_best_ready_damage_ability") != definition:
		return _fail("A sword mob should choose E as a useful gap closer.")
	var mob_aim_direction := target.position.normalized()
	if not bool(ai.call("_begin_direction_damage_ability", E_SLOT, definition, mob_aim_direction)):
		return _fail("A sword mob should be able to begin Leaping Strike.")
	var telegraph := fixture.get_node_or_null("HostileAbilityTelegraph")
	if (
		telegraph == null
		or StringName(String(telegraph.call("get_telegraph_kind"))) != &"circle"
		or Vector2(telegraph.global_position.x, telegraph.global_position.z)
		.distance_to(Vector2(1.5, -2.0)) > 0.02
	):
		return _fail("Mob E should warn at its aimed landing point.")
	if (
		not is_equal_approx(float(ai.get("_ability_movement_remaining_seconds")), 1.8 * 0.53)
		or not is_equal_approx(
			float(ai.get("_ability_movement_speed")),
			2.5 / (1.8 * 0.53)
		)
	):
		return _fail("Mob E should move toward the warned landing point before impact.")
	for _frame_index in range(57):
		await physics_frame
		ai.call("_update_active_ability", 1.0 / 60.0)
	if target_health.current_health < 500.0:
		return _fail("Mob E should not deal damage before reaching its landing frame.")
	await physics_frame
	ai.call("_update_active_ability", 1.0 / 60.0)
	if (
		Vector2(mob.global_position.x, mob.global_position.z).distance_to(
			Vector2(1.5, -2.0)
		) > 0.12
		or not is_equal_approx(target_health.current_health, 340.0)
	):
		return _fail("Mob E should travel to its warning circle and damage on landing.")
	return true


func _validate_forced_movement_distance(fixture: Node3D) -> bool:
	var body := CharacterBody3D.new()
	body.name = "MovementBody"
	fixture.add_child(body)
	var motor := PlayerMovementMotorScript.new() as PlayerMovementMotor
	motor.name = "MovementMotor"
	body.add_child(motor)
	if not motor.start_forced_movement(Vector3.FORWARD, 3.65, 1.8 * 0.53):
		return _fail("Player movement motor should accept the E leap distance.")
	for _frame_index in range(58):
		await physics_frame
		motor.move_to_destination(body, 1.0 / 60.0)
	if absf(body.global_position.z + 3.65) > 0.02 or motor.is_forced_moving():
		return _fail("Player E should stop on the warned landing center without overshoot.")
	body.queue_free()
	await process_frame
	return true


func _validate_retargeted_tracks(animation: Animation) -> bool:
	var required_bones := {"pelvis": false, "Head": false, "hand_r": false, "hand_l": false}
	for track_index in range(animation.get_track_count()):
		var track_path := String(animation.track_get_path(track_index))
		if track_path.contains("mixamorig"):
			return _fail("Retargeted sword E animation should not retain Mixamo bone paths.")
		if not track_path.begins_with("Armature/Skeleton3D:"):
			continue
		var bone_name := track_path.get_slice(":", 1)
		if animation.track_get_type(track_index) == Animation.TYPE_POSITION_3D:
			if bone_name != "pelvis":
				return _fail("Only the pelvis may carry translation in the in-place sword E clip.")
		if required_bones.has(bone_name):
			required_bones[bone_name] = true
	for bone_name in required_bones:
		if not bool(required_bones[bone_name]):
			return _fail("Retargeted sword E animation is missing the %s track." % bone_name)
	return true


func _validate_in_place_jump(
	animation_root: Node,
	animation_player: AnimationPlayer,
	animation: Animation
) -> bool:
	var skeleton := _find_skeleton(animation_root)
	if skeleton == null:
		return _fail("Retargeted sword E scene should contain the Elderforge skeleton.")
	var pelvis_index := skeleton.find_bone("pelvis")
	if pelvis_index < 0:
		return _fail("Retargeted sword E skeleton should contain the pelvis bone.")

	animation_player.play(E_ANIMATION_NAME)
	var horizontal_origin := Vector2.ZERO
	var has_origin := false
	var horizontal_span := 0.0
	var height_min := INF
	var height_max := -INF
	for sample_index in range(21):
		var sample_time := animation.length * float(sample_index) / 20.0
		animation_player.seek(sample_time, true)
		animation_player.advance(0.0)
		var pelvis_position := skeleton.get_bone_global_pose(pelvis_index).origin
		var horizontal := Vector2(pelvis_position.x, pelvis_position.z)
		if not has_origin:
			horizontal_origin = horizontal
			has_origin = true
		else:
			horizontal_span = maxf(horizontal_span, horizontal.distance_to(horizontal_origin))
		height_min = minf(height_min, pelvis_position.y)
		height_max = maxf(height_max, pelvis_position.y)
	if horizontal_span > 0.02:
		return _fail("Sword E gameplay travel should not be duplicated by root motion.")
	if height_max - height_min < 0.5:
		return _fail("Sword E should preserve the source animation's visible jump height.")
	return true


func _add_target(parent: Node3D, target_name: String, target_position: Vector3) -> AreaTarget:
	var target := AreaTarget.new()
	target.name = target_name
	target.position = target_position
	target.add_to_group("selectable_3d")
	parent.add_child(target)
	var health := CombatHealthScript.new()
	health.name = "Health"
	health.max_health = 500.0
	health.current_health = 500.0
	target.add_child(health)
	return target


func _health(target: Node) -> CombatHealth:
	return target.get_node("Health") as CombatHealth


func _on_directional_movement_started(
	_slot_id: StringName,
	direction: Vector3,
	distance: float,
	duration_seconds: float
) -> void:
	_movement_events += 1
	_movement_direction = direction
	_movement_distance = distance
	_movement_duration = duration_seconds


func _on_ability_cast_landed(_slot_id: StringName, _target: Node, _damage: float) -> void:
	_landed_events += 1


func _find_animation_player(root_node: Node) -> AnimationPlayer:
	if root_node is AnimationPlayer:
		return root_node as AnimationPlayer
	for child in root_node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _find_skeleton(root_node: Node) -> Skeleton3D:
	if root_node is Skeleton3D:
		return root_node as Skeleton3D
	for child in root_node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
