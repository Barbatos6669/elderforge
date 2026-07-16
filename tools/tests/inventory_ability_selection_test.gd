extends SceneTree

const PlayerWeaponAbilitiesScript := preload(
	"res://scripts/player/combat/player_weapon_abilities.gd"
)
const PrototypeItemCatalogScript := preload(
	"res://scripts/inventory/prototype_item_catalog.gd"
)
const PlayerDatabaseScript := preload(
	"res://scripts/persistence/player_database.gd"
)
const ENERGIZING_SHIELD_PATH := "res://assets/combat/abilities/energizing_shield.tres"
const SWORD_SLASH_PATH := "res://assets/combat/abilities/one_handed_sword_q.tres"
const TEST_GUARD_FOCUS_PATH := "res://tools/tests/fixtures/test_guard_focus.tres"
const D_SLOT := &"d"


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	if not _tier_unlocks_filter_spell_choices():
		return

	var fixture := Node.new()
	fixture.name = "InventoryAbilitySelectionFixture"
	root.add_child(fixture)
	current_scene = fixture

	var inventory := PlayerInventory.new()
	inventory.name = "PlayerInventory"
	inventory.persist_to_player_database = false
	inventory.debug_equipped_item_ids = PackedStringArray(["leather_helmet_t1"])
	fixture.add_child(inventory)
	_author_test_helmet_choices(inventory)

	var abilities := PlayerWeaponAbilitiesScript.new()
	abilities.name = "WeaponAbilities"
	fixture.add_child(abilities)
	abilities.set_inventory(inventory)

	await process_frame
	await process_frame

	var default_definition := abilities.get_active_ability(D_SLOT)
	if (
		default_definition == null
		or String(default_definition.get("ability_id")) != "energizing_shield"
	):
		_fail("The helmet should begin with its authored default D spell.")
		return

	if inventory.can_select_item_ability(
		"leather_helmet_t1",
		"d",
		SWORD_SLASH_PATH
	):
		_fail("A Q ability resource should not be selectable in the helmet's D slot.")
		return

	if not inventory.select_item_ability(
		"leather_helmet_t1",
		"d",
		TEST_GUARD_FOCUS_PATH
	):
		_fail("The inventory rejected an authored alternate helmet spell.")
		return

	await process_frame

	var selected_head := inventory.get_equipped_slot("head")
	var selected_paths := selected_head.get("ability_paths", {}) as Dictionary
	if String(selected_paths.get("d", "")) != TEST_GUARD_FOCUS_PATH:
		_fail("The equipped item display did not expose the selected D spell.")
		return

	var rebound_definition := abilities.get_active_ability(D_SLOT)
	if (
		rebound_definition == null
		or String(rebound_definition.get("ability_id")) != "test_guard_focus"
	):
		_fail("Combat did not rebind when the inventory spell selection changed.")
		return

	var snapshot := inventory.get_network_snapshot()
	var snapshot_selections := snapshot.get("ability_selections", {}) as Dictionary
	var helmet_selection := snapshot_selections.get("leather_helmet_t1", {}) as Dictionary
	if String(helmet_selection.get("d", "")) != TEST_GUARD_FOCUS_PATH:
		_fail("The inventory snapshot did not retain the selected helmet spell.")
		return

	var database := PlayerDatabaseScript.new()
	var sanitized_snapshot := database.sanitize_inventory_snapshot(snapshot)
	database.free()
	var sanitized_selections := sanitized_snapshot.get("ability_selections", {}) as Dictionary
	var sanitized_helmet := sanitized_selections.get("leather_helmet_t1", {}) as Dictionary
	if String(sanitized_helmet.get("d", "")) != TEST_GUARD_FOCUS_PATH:
		_fail("PlayerDatabase sanitation stripped a valid spell selection.")
		return

	var restored_inventory := PlayerInventory.new()
	restored_inventory.name = "RestoredInventory"
	restored_inventory.persist_to_player_database = false
	fixture.add_child(restored_inventory)
	_author_test_helmet_choices(restored_inventory)
	restored_inventory.apply_network_snapshot(sanitized_snapshot)

	var restored_head := restored_inventory.get_equipped_slot("head")
	var restored_paths := restored_head.get("ability_paths", {}) as Dictionary
	if String(restored_paths.get("d", "")) != TEST_GUARD_FOCUS_PATH:
		_fail("Applying the inventory snapshot did not restore the spell selection.")
		return

	var invalid_snapshot := sanitized_snapshot.duplicate(true)
	invalid_snapshot["ability_selections"] = {
		"leather_helmet_t1": {"d": SWORD_SLASH_PATH},
	}
	restored_inventory.apply_network_snapshot(invalid_snapshot)
	var validated_head := restored_inventory.get_equipped_slot("head")
	var validated_paths := validated_head.get("ability_paths", {}) as Dictionary
	if String(validated_paths.get("d", "")) != ENERGIZING_SHIELD_PATH:
		_fail("Snapshot validation should fall back from an invalid D spell to the default.")
		return

	fixture.queue_free()
	await process_frame
	print("Inventory ability selection tests passed.")
	quit(0)


func _tier_unlocks_filter_spell_choices() -> bool:
	var templates := {
		"d": [
			{"path": TEST_GUARD_FOCUS_PATH, "min_tier": 4},
		],
	}
	var defaults := {"d": ENERGIZING_SHIELD_PATH}
	var tier_one := PrototypeItemCatalogScript._resolve_ability_choices(
		templates,
		1,
		defaults
	)
	var tier_four := PrototypeItemCatalogScript._resolve_ability_choices(
		templates,
		4,
		defaults
	)
	var tier_one_paths := PackedStringArray(tier_one.get("d", PackedStringArray()))
	var tier_four_paths := PackedStringArray(tier_four.get("d", PackedStringArray()))
	if (
		tier_one_paths != PackedStringArray([ENERGIZING_SHIELD_PATH])
		or not tier_four_paths.has(ENERGIZING_SHIELD_PATH)
		or not tier_four_paths.has(TEST_GUARD_FOCUS_PATH)
	):
		_fail("Tier-gated spell choices were not resolved correctly.")
		return false
	return true


func _author_test_helmet_choices(inventory: PlayerInventory) -> void:
	var helmet_definition := inventory.get_definition("leather_helmet_t1")
	helmet_definition.set("ability_choices", {
		"d": PackedStringArray([
			ENERGIZING_SHIELD_PATH,
			TEST_GUARD_FOCUS_PATH,
			SWORD_SLASH_PATH,
		]),
	})


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
