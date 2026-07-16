extends SceneTree

const CombatHealthScript := preload("res://scripts/combat/combat_health.gd")
const EnemyMobAIScript := preload("res://scripts/entities/enemy_mob_ai.gd")
const SlashAbility := preload("res://assets/combat/abilities/one_handed_sword_q.tres")
const RollAbility := preload("res://assets/combat/abilities/leather_boots_roll.tres")


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var fixture := Node3D.new()
	fixture.name = "MobAbilityTelegraphFixture"
	root.add_child(fixture)
	current_scene = fixture

	var mob := CharacterBody3D.new()
	mob.name = "Mob"
	fixture.add_child(mob)

	var ai := EnemyMobAIScript.new()
	ai.name = "AI"
	ai.show_hostile_ability_telegraphs = true
	mob.add_child(ai)

	var target := CharacterBody3D.new()
	target.name = "Target"
	target.position = Vector3(1.0, 0.0, -1.0)
	fixture.add_child(target)

	var health := CombatHealthScript.new()
	health.name = "Health"
	health.max_health = 500.0
	health.current_health = 500.0
	target.add_child(health)

	await process_frame

	var slash_ability := SlashAbility.duplicate()
	slash_ability.set("energy_cost", 0.0)
	slash_ability.set("cast_duration_seconds", 120.0)
	slash_ability.set("impact_fraction", 1.0)
	if not bool(ai.call("_begin_target_ability", &"q", target, slash_ability)):
		_fail("Mob target ability should begin.")
		return

	var target_telegraph := fixture.get_node_or_null("HostileAbilityTelegraph")
	if not _is_showing_kind(target_telegraph, &"circle"):
		_fail("Mob target ability should show a circle telegraph.")
		return
	if _horizontal_distance(target_telegraph.global_position, target.global_position) > 0.02:
		_fail("Target telegraph should start under the targeted player.")
		return

	target.global_position = Vector3(2.0, 0.0, -2.0)
	target_telegraph.call("_process", 0.01)
	if _horizontal_distance(target_telegraph.global_position, target.global_position) > 0.02:
		_fail("Target telegraph should follow the selected target during wind-up.")
		return

	ai.call("_update_active_ability", 121.0)
	await process_frame
	if is_instance_valid(target_telegraph) and not target_telegraph.is_queued_for_deletion():
		_fail("Target telegraph should clear at ability impact.")
		return

	ai.call("_reset_active_ability_state")
	var roll_ability := RollAbility.duplicate()
	roll_ability.set("energy_cost", 0.0)
	if not bool(ai.call("_begin_dodge_ability", &"f", roll_ability, Vector3.FORWARD)):
		_fail("Mob dodge ability should begin.")
		return

	var direction_telegraph := fixture.get_node_or_null("HostileAbilityTelegraph")
	if not _is_showing_kind(direction_telegraph, &"direction"):
		_fail("Mob dodge ability should show a directional telegraph.")
		return

	ai.call("_update_dodge_ability", 1.0)
	await process_frame
	if is_instance_valid(direction_telegraph) and not direction_telegraph.is_queued_for_deletion():
		_fail("Directional telegraph should clear when the dodge finishes.")
		return

	fixture.queue_free()
	await process_frame
	print("Mob ability telegraph tests passed.")
	quit(0)


func _is_showing_kind(telegraph: Node, expected_kind: StringName) -> bool:
	return (
		telegraph != null
		and telegraph.has_method("is_showing")
		and bool(telegraph.call("is_showing"))
		and telegraph.has_method("get_telegraph_kind")
		and StringName(String(telegraph.call("get_telegraph_kind"))) == expected_kind
	)


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
