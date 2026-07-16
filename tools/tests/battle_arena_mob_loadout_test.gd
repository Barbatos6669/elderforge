extends SceneTree

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

	arena.queue_free()
	await process_frame
	print("Battle arena mob loadout tests passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
