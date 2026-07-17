extends SceneTree

const CombatHealthScript := preload("res://scripts/combat/combat_health.gd")
const ResourcePoolScript := preload("res://scripts/combat/resource_pool.gd")
const EnemyMobAIScript := preload("res://scripts/entities/enemy_mob_ai.gd")
const MobEquipmentLoadoutScript := preload("res://scripts/entities/mob_equipment_loadout.gd")
const DamageImmunityBubbleScene := preload("res://scenes/effects/DamageImmunityBubble3D.tscn")


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	if not await _test_loadout_unlocks_equipment_abilities():
		return
	if not await _test_sword_ability_lands_through_mob_ai():
		return
	if not await _test_sword_w_ability_lands_when_q_is_cooling_down():
		return
	if not await _test_helmet_shield_is_used_defensively():
		return
	if not await _test_boots_roll_repositions_mob():
		return
	if not await _test_chest_recovery_waits_for_out_of_combat():
		return

	print("Mob equipment ability tests passed.")
	quit(0)


func _test_loadout_unlocks_equipment_abilities() -> bool:
	var fixture := _make_fixture("MobAbilityLoadoutFixture")
	var mob_data := _spawn_mob(
		fixture,
		PackedStringArray([
			"one_handed_sword_t1",
			"leather_armor_t1",
			"leather_helmet_t1",
			"leather_boots_t1",
		])
	)
	await process_frame

	var ai := mob_data["ai"] as EnemyMobAI
	var expected := {
		&"q": "one_handed_sword_q",
		&"w": "one_handed_sword_w",
		&"r": "moonleaf_binding",
		&"d": "energizing_shield",
		&"f": "leather_boots_roll",
	}
	for slot_id in expected:
		var definition := ai.get_active_ability(slot_id)
		if definition == null or String(definition.get("ability_id")) != String(expected[slot_id]):
			_fail("Mob loadout did not unlock ability %s on slot %s." % [expected[slot_id], slot_id])
			return false

	fixture.queue_free()
	await process_frame
	return true


func _test_sword_ability_lands_through_mob_ai() -> bool:
	var fixture := _make_fixture("MobSwordAbilityFixture")
	var mob_data := _spawn_mob(fixture, PackedStringArray(["one_handed_sword_t1"]))
	var mob := mob_data["mob"] as CharacterBody3D
	var ai := mob_data["ai"] as EnemyMobAI
	var mana := mob_data["mana"] as ResourcePool
	await process_frame

	var target_data := _spawn_player_target(fixture, Vector3(0.0, 0.0, 1.5), 500.0)
	var target := target_data["target"] as CharacterBody3D
	var target_health := target_data["health"] as CombatHealth

	if ai.get_active_ability(&"q") == null:
		_fail("Mob sword loadout did not bind a Q ability before combat.")
		return false
	ai.set("_target", target)
	ai.call("_update_aggro", 0.1)
	if not is_equal_approx(mana.current_resource, 115.0):
		_fail("Mob sword ability should spend its item-authored energy cost.")
		return false
	if not is_equal_approx(target_health.current_health, 500.0):
		_fail(
			"Mob sword ability should wait for its impact frame before damage; target health was %s."
			% target_health.current_health
		)
		return false

	ai.call("_update_active_ability", 0.5)
	if not is_equal_approx(target_health.current_health, 400.0):
		_fail("Mob sword ability should deal its authored 100 damage through AI.")
		return false
	if ai.get_ability_cooldown_remaining(&"q") <= 0.0:
		_fail("Mob sword ability should start its own cooldown.")
		return false
	if mob.global_position.distance_to(Vector3.ZERO) > 0.01:
		_fail("Mob should hold position while casting Sword Slash in range.")
		return false

	fixture.queue_free()
	await process_frame
	return true


func _test_sword_w_ability_lands_when_q_is_cooling_down() -> bool:
	var fixture := _make_fixture("MobSwordWAbilityFixture")
	var mob_data := _spawn_mob(fixture, PackedStringArray(["one_handed_sword_t1"]))
	var ai := mob_data["ai"] as EnemyMobAI
	var mana := mob_data["mana"] as ResourcePool
	await process_frame

	var target_data := _spawn_player_target(fixture, Vector3(0.0, 0.0, 1.5), 500.0)
	var target := target_data["target"] as CharacterBody3D
	var target_health := target_data["health"] as CombatHealth
	var w_definition := ai.get_active_ability(&"w")
	if w_definition == null or String(w_definition.get("ability_id")) != "one_handed_sword_w":
		_fail("Mob sword loadout should bind Whirling Slash on W.")
		return false

	ai.set("_ability_cooldowns_by_id", {"one_handed_sword_q": 5.0})
	ai.set("_target", target)
	ai.call("_update_aggro", 0.1)
	if not is_equal_approx(mana.current_resource, 108.0):
		_fail("Mob Whirling Slash should spend its authored 12 energy.")
		return false
	if not is_equal_approx(target_health.current_health, 500.0):
		_fail("Mob Whirling Slash should wait for its late impact frame.")
		return false

	ai.call("_update_active_ability", 1.26)
	if not is_equal_approx(target_health.current_health, 390.0):
		_fail("Mob Whirling Slash should deal 80 plus 150% attack damage.")
		return false
	if ai.get_ability_cooldown_remaining(&"w") <= 0.0:
		_fail("Mob Whirling Slash should start its own cooldown.")
		return false

	fixture.queue_free()
	await process_frame
	return true


func _test_helmet_shield_is_used_defensively() -> bool:
	var fixture := _make_fixture("MobHelmetShieldFixture")
	var mob_data := _spawn_mob(fixture, PackedStringArray(["leather_helmet_t1"]), 60.0, 60.0)
	var ai := mob_data["ai"] as EnemyMobAI
	var health := mob_data["health"] as CombatHealth
	var bubble := mob_data["bubble"] as Node3D
	var mana := mob_data["mana"] as ResourcePool
	await process_frame
	health.set_current_health(60.0)
	mana.set_current_resource(60.0)

	var target_data := _spawn_player_target(fixture, Vector3(0.0, 0.0, 1.0), 500.0)
	var target := target_data["target"] as CharacterBody3D

	ai.set("_target", target)
	ai.call("_update_aggro", 0.1)
	if not health.has_absorb_shield():
		_fail("Low-health mob with a helmet should use Energizing Shield.")
		return false
	if not is_equal_approx(health.get_absorb_shield_current(), 834.0):
		_fail("Mob Energizing Shield should use the item-authored shield amount.")
		return false
	if bubble == null or not bubble.has_method("is_active") or not bool(bubble.call("is_active")):
		_fail("Mob Energizing Shield should show the absorb shield bubble.")
		return false
	if (
		not bubble.has_method("get_active_protection_mode")
		or String(bubble.call("get_active_protection_mode")) != "absorb_shield"
	):
		_fail("Mob Energizing Shield should show absorb-shield bubble mode.")
		return false
	if not is_equal_approx(mana.current_resource, 75.0):
		_fail("Mob Energizing Shield should restore 25% of missing energy.")
		return false
	if ai.get_ability_cooldown_remaining(&"d") <= 0.0:
		_fail("Mob Energizing Shield should start cooldown.")
		return false

	fixture.queue_free()
	await process_frame
	return true


func _test_boots_roll_repositions_mob() -> bool:
	var fixture := _make_fixture("MobBootsRollFixture")
	var mob_data := _spawn_mob(fixture, PackedStringArray(["leather_boots_t1"]))
	var mob := mob_data["mob"] as CharacterBody3D
	var ai := mob_data["ai"] as EnemyMobAI
	var health := mob_data["health"] as CombatHealth
	var bubble := mob_data["bubble"] as Node3D
	await process_frame

	var target_data := _spawn_player_target(fixture, Vector3(0.0, 0.0, 3.0), 500.0)
	var target := target_data["target"] as CharacterBody3D

	ai.set("_target", target)
	ai.call("_update_aggro", 0.1)
	ai.call("_update_active_ability", 0.4)
	if mob.velocity.z <= 0.0:
		_fail("Mob boots ability should commit forward roll movement toward a reachable target.")
		return false
	if not health.is_damage_immune():
		_fail("Mob boots ability should apply its authored immunity window.")
		return false
	if bubble == null or not bubble.has_method("is_active") or not bool(bubble.call("is_active")):
		_fail("Mob boots ability should show the damage-immunity bubble during the roll.")
		return false
	if (
		not bubble.has_method("get_active_protection_mode")
		or String(bubble.call("get_active_protection_mode")) != "damage_immunity"
	):
		_fail("Mob boots ability should show damage-immunity bubble mode.")
		return false
	if ai.get_ability_cooldown_remaining(&"f") <= 0.0:
		_fail("Mob boots ability should start cooldown.")
		return false

	fixture.queue_free()
	await process_frame
	return true


func _test_chest_recovery_waits_for_out_of_combat() -> bool:
	var fixture := _make_fixture("MobChestRecoveryFixture")
	var mob_data := _spawn_mob(fixture, PackedStringArray(["leather_armor_t1"]), 40.0, 60.0)
	var ai := mob_data["ai"] as EnemyMobAI
	var health := mob_data["health"] as CombatHealth
	var mana := mob_data["mana"] as ResourcePool
	await process_frame
	health.set_current_health(40.0)
	mana.set_current_resource(60.0)

	if not bool(ai.call("_try_out_of_combat_recovery_ability")):
		_fail("Wounded out-of-combat mob with chest armor should start Moonleaf Binding.")
		return false
	ai.call("_update_active_ability", 1.0)
	if health.current_health <= 40.0 or mana.current_resource <= 60.0:
		_fail("Mob Moonleaf Binding should restore health and energy on a channel tick.")
		return false

	fixture.queue_free()
	await process_frame
	return true


func _make_fixture(fixture_name: String) -> Node3D:
	var fixture := Node3D.new()
	fixture.name = fixture_name
	root.add_child(fixture)
	current_scene = fixture
	return fixture


func _spawn_mob(
	fixture: Node,
	item_ids: PackedStringArray,
	current_health := 120.0,
	current_resource := 120.0
) -> Dictionary:
	var mob := CharacterBody3D.new()
	mob.name = "Mob"
	fixture.add_child(mob)

	var health := CombatHealthScript.new()
	health.name = "Health"
	health.max_health = 120.0
	health.current_health = current_health
	mob.add_child(health)

	var bubble := DamageImmunityBubbleScene.instantiate() as Node3D
	bubble.name = "DamageImmunityBubble"
	mob.add_child(bubble)

	var mana := ResourcePoolScript.new()
	mana.name = "Mana"
	mana.display_name = "Energy"
	mana.max_resource = 120.0
	mana.current_resource = current_resource
	mob.add_child(mana)

	var loadout := MobEquipmentLoadoutScript.new()
	loadout.name = "EquipmentLoadout"
	loadout.equipped_item_ids = item_ids
	mob.add_child(loadout)

	var ai := EnemyMobAIScript.new() as EnemyMobAI
	ai.name = "AI"
	ai.aggro_radius = 8.0
	ai.leash_radius = 20.0
	ai.set_physics_process(false)
	mob.add_child(ai)

	return {
		"mob": mob,
		"health": health,
		"bubble": bubble,
		"mana": mana,
		"loadout": loadout,
		"ai": ai,
	}


func _spawn_player_target(fixture: Node, position: Vector3, max_health: float) -> Dictionary:
	var target := CharacterBody3D.new()
	target.name = "PlayerTarget"
	target.position = position
	target.add_to_group("player")
	fixture.add_child(target)

	var health := CombatHealthScript.new()
	health.name = "Health"
	health.max_health = max_health
	health.current_health = max_health
	target.add_child(health)

	return {
		"target": target,
		"health": health,
	}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
