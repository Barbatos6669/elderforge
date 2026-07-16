extends SceneTree

const PlayerStatsScript := preload("res://scripts/player/stats/player_stats.gd")
const ARENA_PATH := "res://scenes/debug/combat/BattleTestArena.tscn"


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var packed_arena := load(ARENA_PATH) as PackedScene
	if packed_arena == null:
		_fail("Battle test arena scene should load.")
		return

	var arena := packed_arena.instantiate()
	root.add_child(arena)
	current_scene = arena

	await process_frame
	await process_frame

	var ability_raider := arena.get_node_or_null("World/LevelContent/Mobs/AbilityRaider")
	var loadout := arena.get_node_or_null("World/LevelContent/Mobs/AbilityRaider/EquipmentLoadout")
	var ai := arena.get_node_or_null("World/LevelContent/Mobs/AbilityRaider/AI")
	if ability_raider == null or loadout == null or ai == null:
		_fail("Battle arena should include the equipped Ability Raider.")
		return

	for raider_name in ["HeavyRaider", "StandardRaider", "SwiftRaider", "AbilityRaider"]:
		var raider := arena.get_node_or_null("World/LevelContent/Mobs/%s" % raider_name)
		if raider == null:
			_fail("Battle arena should include %s." % raider_name)
			return
		var raider_loadout := raider.get_node_or_null("EquipmentLoadout")
		if raider_loadout == null:
			_fail("%s should have an EquipmentLoadout override." % raider_name)
			return
		var raider_items := PackedStringArray(raider_loadout.get("equipped_item_ids"))
		if not raider_items.has("one_handed_sword_t1"):
			_fail("%s should equip a visible one-handed sword." % raider_name)
			return
		var hand_preview := raider.get_node_or_null(
			"Visuals/BaseCharacter/Armature/Skeleton3D/MainHandAttachment/MainHandPreview"
		)
		if hand_preview == null:
			_fail("%s should have an editor-visible sword preview." % raider_name)
			return
		if not _has_player_base_stats(raider, raider_name):
			return
		if not _has_debug_combat_zones(raider, raider_name):
			return

	var expected_item_ids := PackedStringArray([
		"one_handed_sword_t1",
		"leather_armor_t1",
		"leather_helmet_t1",
		"leather_boots_t1",
	])
	var equipped_item_ids := PackedStringArray(loadout.get("equipped_item_ids"))
	for item_id in expected_item_ids:
		if not equipped_item_ids.has(item_id):
			_fail("Ability Raider should equip %s." % item_id)
			return

	var expected_abilities := {
		&"q": "one_handed_sword_q",
		&"r": "moonleaf_binding",
		&"d": "energizing_shield",
		&"f": "leather_boots_roll",
	}
	for slot_id in expected_abilities:
		var definition: Resource = ai.call("get_active_ability", slot_id)
		if definition == null or String(definition.get("ability_id")) != String(expected_abilities[slot_id]):
			_fail("Ability Raider should bind %s on slot %s." % [expected_abilities[slot_id], slot_id])
			return

	var skeleton := ability_raider.get_node_or_null("Visuals/BaseCharacter/Armature/Skeleton3D")
	if skeleton == null:
		_fail("Ability Raider should expose a character skeleton for visible equipment.")
		return

	var expected_visual_nodes := {
		"MainHandAttachment/MainHandEquipment": "MainHandEquipment",
		"ChestEquipment": "ChestEquipment",
		"HeadEquipment": "HeadEquipment",
		"ShoesEquipment": "ShoesEquipment",
	}
	for equipment_path in expected_visual_nodes:
		if skeleton.get_node_or_null(equipment_path) == null:
			_fail(
				"Ability Raider should visibly equip %s. Skeleton children: %s"
				% [expected_visual_nodes[equipment_path], _child_names(skeleton)]
			)
			return

	arena.queue_free()
	await process_frame
	print("Battle arena mob loadout tests passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _child_names(node: Node) -> PackedStringArray:
	var names := PackedStringArray()
	for child in node.get_children():
		names.append(child.name)
	return names


func _has_player_base_stats(raider: Node, raider_name: String) -> bool:
	var health := raider.get_node_or_null("Health")
	var stats := raider.get_node_or_null("Stats")
	var ai := raider.get_node_or_null("AI")
	if health == null or stats == null or ai == null:
		_fail("%s should include Health, Stats, and AI nodes." % raider_name)
		return false

	var stat_ids := [
		PlayerStatsScript.MAX_HEALTH,
		PlayerStatsScript.HEALTH_REGENERATION,
		PlayerStatsScript.AUTO_ATTACK_DAMAGE,
		PlayerStatsScript.AUTO_ATTACK_SPEED,
		PlayerStatsScript.ARMOR,
		PlayerStatsScript.MAGICAL_RESISTANCE,
		PlayerStatsScript.MOVE_SPEED,
	]
	for stat_id in stat_ids:
		var expected_stat := _expected_player_stat(stat_id)
		var actual_stat := float(stats.call("get_base_stat", stat_id))
		if not is_equal_approx(actual_stat, expected_stat):
			_fail(
				"%s Stats.%s should be %.2f, found %.2f."
				% [raider_name, stat_id, expected_stat, actual_stat]
			)
			return false

	var expected_health := float(stats.call("get_stat", PlayerStatsScript.MAX_HEALTH))
	var expected_regeneration := float(stats.call("get_stat", PlayerStatsScript.HEALTH_REGENERATION))
	if not _has_value(health, "max_health", expected_health, raider_name):
		return false
	if not _has_value(health, "current_health", expected_health, raider_name):
		return false
	if not _has_value(health, "health_regeneration_per_second", expected_regeneration, raider_name):
		return false

	if not _has_value(
		ai,
		"attack_damage",
		_expected_player_stat(PlayerStatsScript.AUTO_ATTACK_DAMAGE),
		raider_name
	):
		return false
	if not _has_value(
		ai,
		"attack_speed",
		_expected_player_stat(PlayerStatsScript.AUTO_ATTACK_SPEED),
		raider_name
	):
		return false

	return true


func _has_debug_combat_zones(raider: Node, raider_name: String) -> bool:
	var ai := raider.get_node_or_null("AI")
	var aggro_zone := raider.get_node_or_null("DebugAggroZone")
	var deaggro_zone := raider.get_node_or_null("DebugLeashZone")
	var raider_3d := raider as Node3D
	var aggro_zone_3d := aggro_zone as Node3D
	var deaggro_zone_3d := deaggro_zone as Node3D
	if ai == null or aggro_zone == null or deaggro_zone == null:
		_fail("%s should include AI, DebugAggroZone, and DebugLeashZone nodes." % raider_name)
		return false
	if raider_3d == null or aggro_zone_3d == null or deaggro_zone_3d == null:
		_fail("%s debug combat zones should be 3D nodes." % raider_name)
		return false

	if not _has_debug_radius_zone(
		aggro_zone,
		ai,
		"aggro",
		"debug_show_aggro_zone",
		"aggro_radius",
		raider_name
	):
		return false

	var expected_aggro_radius := _expected_aggro_radius(raider_name)
	var actual_aggro_radius := float(ai.get("aggro_radius"))
	if not is_equal_approx(actual_aggro_radius, expected_aggro_radius):
		_fail(
			"%s aggro radius should use the tight arena tuning: %.3f, found %.3f."
			% [raider_name, expected_aggro_radius, actual_aggro_radius]
		)
		return false

	if not _has_debug_radius_zone(
		deaggro_zone,
		ai,
		"de-aggro",
		"debug_show_deaggro_zone",
		"leash_radius",
		raider_name
	):
		return false

	var expected_deaggro_radius := float(ai.get("aggro_radius")) * 0.25
	var actual_deaggro_radius := float(ai.get("leash_radius"))
	if not is_equal_approx(actual_deaggro_radius, expected_deaggro_radius):
		_fail(
			"%s de-aggro radius should use the tight leash tuning: %.3f, found %.3f."
			% [raider_name, expected_deaggro_radius, actual_deaggro_radius]
		)
		return false

	var expected_center := raider_3d.global_position
	if _horizontal_distance(aggro_zone_3d.global_position, expected_center) > 0.05:
		_fail("%s debug aggro zone should be centered on the mob." % raider_name)
		return false
	if _horizontal_distance(deaggro_zone_3d.global_position, expected_center) > 0.05:
		_fail("%s debug de-aggro zone should be centered on the mob home point." % raider_name)
		return false
	return true


func _has_debug_radius_zone(
	zone: Node,
	ai: Node,
	zone_label: String,
	enabled_property: String,
	radius_property: String,
	raider_name: String
) -> bool:
	if not zone.has_method("get_radius"):
		_fail("%s debug %s zone should expose its radius for tests." % [raider_name, zone_label])
		return false
	if not bool(ai.get(enabled_property)):
		_fail("%s should enable its debug %s zone in the battle arena." % [raider_name, zone_label])
		return false
	if not bool(zone.get("visible")):
		_fail("%s debug %s zone should be visible." % [raider_name, zone_label])
		return false

	var expected_radius := float(ai.get(radius_property))
	var actual_radius := float(zone.call("get_radius"))
	if not is_equal_approx(actual_radius, expected_radius):
		_fail(
			"%s debug %s zone radius should be %.2f, found %.2f."
			% [raider_name, zone_label, expected_radius, actual_radius]
		)
		return false
	return true


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _expected_aggro_radius(raider_name: String) -> float:
	if raider_name == "AbilityRaider":
		return 4.5
	return 4.0


func _expected_player_stat(stat_id: StringName) -> float:
	return float(PlayerStatsScript.BASE_STAT_VALUES.get(stat_id, 0.0))


func _has_value(node: Node, property_name: String, expected: float, owner_name: String) -> bool:
	var actual := float(node.get(property_name))
	if is_equal_approx(actual, expected):
		return true

	_fail(
		"%s %s.%s should be %.2f, found %.2f."
		% [owner_name, node.name, property_name, expected, actual]
	)
	return false
