extends SceneTree

const MASTER_MENU_SCENE := preload("res://scenes/ui/menu/MasterMenu.tscn")
const ENERGIZING_SHIELD_PATH := "res://assets/combat/abilities/energizing_shield.tres"
const TEST_GUARD_FOCUS_PATH := "res://tools/tests/fixtures/test_guard_focus.tres"


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	root.size = Vector2i(1280, 800)

	var fixture := Node.new()
	fixture.name = "MasterMenuInventoryFixture"
	root.add_child(fixture)
	current_scene = fixture

	var inventory := PlayerInventory.new()
	inventory.name = "PlayerInventory"
	inventory.persist_to_player_database = false
	inventory.slot_count = 12
	inventory.starting_silver = 1234
	inventory.debug_seed_item_ids = PackedStringArray(["timber_t1", "stone_t1"])
	inventory.debug_seed_quantity = 7
	inventory.debug_main_hand_item_id = "one_handed_sword_t1"
	inventory.debug_equipped_item_ids = PackedStringArray(["leather_helmet_t1"])
	fixture.add_child(inventory)
	var helmet_definition := inventory.get_definition("leather_helmet_t1")
	helmet_definition.set("ability_choices", {
		"d": PackedStringArray([ENERGIZING_SHIELD_PATH, TEST_GUARD_FOCUS_PATH]),
	})

	var menu := MASTER_MENU_SCENE.instantiate() as MasterMenu
	menu.inventory_path = NodePath("../PlayerInventory")
	fixture.add_child(menu)

	await process_frame
	await process_frame

	menu.open()
	menu.call("_open_detail_view", "inventory")
	await process_frame

	if not _inventory_page_rendered(menu):
		return
	if not await _helmet_selection_updates_spell_loadout(menu, inventory):
		return
	if not await _dragging_helmet_to_bag_unequips(menu, inventory):
		return
	if not await _dragging_bag_helmet_to_head_equips(menu, inventory):
		return
	if not await _weapon_loadout_shows_qwe_categories(menu):
		return

	fixture.queue_free()
	await process_frame
	print("Master menu inventory tests passed.")
	quit(0)


func _inventory_page_rendered(menu: MasterMenu) -> bool:
	var bag_grid := menu.find_child("BagSlotGrid", true, false) as GridContainer
	if bag_grid == null:
		_fail("Inventory detail should build a bag slot grid.")
		return false
	if bag_grid.get_child_count() < 12:
		_fail("Inventory detail should render every bound bag slot.")
		return false

	var first_slot := menu.find_child("BagSlot01", true, false) as Button
	if first_slot == null:
		_fail("Inventory detail should name bag slot buttons predictably.")
		return false
	if first_slot.find_child("ItemIcon", true, false) == null:
		_fail("Filled bag slots should render item icons.")
		return false
	if not first_slot.tooltip_text.contains("Oak Wood I"):
		_fail("The first seeded bag slot should show the Oak Wood item name.")
		return false

	var equipment_grid := menu.find_child("EquipmentSlotGrid", true, false) as GridContainer
	if equipment_grid == null:
		_fail("Inventory detail should build an equipment grid.")
		return false

	var head_slot := menu.find_child("HeadEquipmentSlot", true, false) as Button
	if head_slot == null:
		_fail("Inventory detail should render the helmet equipment slot.")
		return false
	if not head_slot.tooltip_text.contains("Wolfhide Hood I"):
		_fail("Equipped helmet should appear in the helmet equipment slot.")
		return false

	var silver_readout := menu.find_child("SilverReadout", true, false) as PanelContainer
	if silver_readout == null:
		_fail("Inventory detail should render carried silver.")
		return false

	return true


func _helmet_selection_updates_spell_loadout(
	menu: MasterMenu,
	inventory: PlayerInventory
) -> bool:
	var head_slot := menu.find_child("HeadEquipmentSlot", true, false) as Button
	if head_slot == null:
		_fail("Helmet slot should exist before selection.")
		return false

	head_slot.pressed.emit()
	await process_frame

	var loadout_list := menu.find_child("SpellLoadoutList", true, false) as VBoxContainer
	if loadout_list == null:
		_fail("Selecting spell-bearing gear should render its spell loadout.")
		return false

	var default_choice := menu.find_child("SpellChoiceD01", true, false) as Button
	var alternate_choice := menu.find_child("SpellChoiceD02", true, false) as Button
	if default_choice == null or alternate_choice == null:
		_fail("The D spell slot should render every available helmet spell.")
		return false
	if not default_choice.text.contains("Energizing Shield"):
		_fail("The helmet's authored default spell should be selected first.")
		return false

	alternate_choice.pressed.emit()
	await process_frame
	await process_frame

	var equipped_head := inventory.get_equipped_slot("head")
	var selected_paths := equipped_head.get("ability_paths", {}) as Dictionary
	if String(selected_paths.get("d", "")) != TEST_GUARD_FOCUS_PATH:
		_fail("Choosing a loadout spell should update the helmet's active D ability.")
		return false

	var spell_title := menu.find_child("SelectedSpellTitle", true, false) as Label
	if spell_title == null or spell_title.text != "Guard Focus":
		_fail("The right panel should focus the newly selected spell.")
		return false

	return true


func _dragging_helmet_to_bag_unequips(menu: MasterMenu, inventory: PlayerInventory) -> bool:
	var head_slot := menu.find_child("HeadEquipmentSlot", true, false) as Button
	var target_slot := menu.find_child("BagSlot03", true, false) as Button
	if head_slot == null or target_slot == null:
		_fail("Drag test requires the equipped helmet and an empty bag slot.")
		return false
	if not inventory.get_display_slots()[2].is_empty():
		_fail("The drag target bag slot should start empty.")
		return false
	if not String(head_slot.get_script().resource_path).ends_with("equipment_slot_button.gd"):
		_fail("Equipped items should use the shared equipment drag control.")
		return false
	if not String(target_slot.get_script().resource_path).ends_with("inventory_slot_button.gd"):
		_fail("Bag items should use the shared inventory drop control.")
		return false

	var drag_data: Variant = menu.call("get_gear_slot_drag_data", "head")
	if drag_data == null:
		_fail("An equipped helmet should provide drag data.")
		return false
	if not bool(target_slot.call("_can_drop_data", Vector2.ZERO, drag_data)):
		_fail("An empty bag slot should accept equipped helmet drag data.")
		return false

	target_slot.call("_drop_data", Vector2.ZERO, drag_data)
	await process_frame
	await process_frame

	if not inventory.get_equipped_slot("head").is_empty():
		_fail("Dropping equipped gear into the bag should clear its equipment slot.")
		return false

	var moved_slot := inventory.get_display_slots()[2] as Dictionary
	if String(moved_slot.get("id", "")) != "leather_helmet_t1":
		_fail("The unequipped helmet should move into the target bag slot.")
		return false

	var refreshed_target := menu.find_child("BagSlot03", true, false) as Button
	if refreshed_target == null or not refreshed_target.tooltip_text.contains("Wolfhide Hood I"):
		_fail("The fullscreen inventory should refresh after unequipping gear.")
		return false

	var spell_title := menu.find_child("SelectedSpellTitle", true, false) as Label
	if spell_title == null or spell_title.text != "Guard Focus":
		_fail("The moved helmet should retain its selected spell in the bag.")
		return false

	return true


func _dragging_bag_helmet_to_head_equips(menu: MasterMenu, inventory: PlayerInventory) -> bool:
	var source_slot := menu.find_child("BagSlot03", true, false) as Button
	var head_slot := menu.find_child("HeadEquipmentSlot", true, false) as Button
	var chest_slot := menu.find_child("ChestEquipmentSlot", true, false) as Button
	if source_slot == null or head_slot == null or chest_slot == null:
		_fail("Equip drag test requires the bag, helmet, and chest slots.")
		return false

	var drag_data: Variant = menu.call("get_slot_drag_data", 2)
	if drag_data == null:
		_fail("A bagged helmet should provide drag data.")
		return false
	if bool(chest_slot.call("_can_drop_data", Vector2.ZERO, drag_data)):
		_fail("A helmet should not be accepted by the chest equipment slot.")
		return false
	if not bool(head_slot.call("_can_drop_data", Vector2.ZERO, drag_data)):
		_fail("The helmet equipment slot should accept a bagged helmet.")
		return false

	head_slot.call("_drop_data", Vector2.ZERO, drag_data)
	await process_frame
	await process_frame

	if not inventory.get_display_slots()[2].is_empty():
		_fail("Equipping a bag item should clear its source bag slot.")
		return false

	var equipped_head := inventory.get_equipped_slot("head")
	if String(equipped_head.get("id", "")) != "leather_helmet_t1":
		_fail("Dropping the helmet onto its equipment slot should equip it.")
		return false

	var refreshed_head := menu.find_child("HeadEquipmentSlot", true, false) as Button
	if refreshed_head == null or not refreshed_head.tooltip_text.contains("Wolfhide Hood I"):
		_fail("The fullscreen equipment slot should refresh after equipping gear.")
		return false

	var spell_title := menu.find_child("SelectedSpellTitle", true, false) as Label
	if spell_title == null or spell_title.text != "Guard Focus":
		_fail("The re-equipped helmet should retain its selected spell.")
		return false

	return true


func _weapon_loadout_shows_qwe_categories(menu: MasterMenu) -> bool:
	var main_hand_slot := menu.find_child("MainHandEquipmentSlot", true, false) as Button
	if main_hand_slot == null:
		_fail("Weapon loadout test requires the equipped main-hand sword.")
		return false

	main_hand_slot.pressed.emit()
	await process_frame

	for slot_id in ["Q", "W", "E"]:
		if menu.find_child("SpellCategory%s" % slot_id, true, false) == null:
			_fail("Weapon loadouts should always render the %s spell category." % slot_id)
			return false

	var q_choice := menu.find_child("SpellChoiceQ01", true, false) as Button
	if q_choice == null or not q_choice.text.contains("Sword Slash"):
		_fail("The sword's authored Q spell should appear in the Q category.")
		return false
	if menu.find_child("SpellChoiceWEmpty", true, false) == null:
		_fail("The empty W category should remain visible until a spell unlocks.")
		return false
	if menu.find_child("SpellChoiceEEmpty", true, false) == null:
		_fail("The empty E category should remain visible until a spell unlocks.")
		return false

	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
