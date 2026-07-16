extends SceneTree

const ChatPanelScript := preload("res://scripts/ui/chat/chat_panel.gd")
const WeaponAbilityHudScript := preload("res://scripts/ui/hud/weapon_ability_hud.gd")


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	root.size = Vector2i(1024, 768)

	var fixture := Control.new()
	fixture.name = "HudLayoutFixture"
	fixture.size = Vector2(1024.0, 768.0)
	root.add_child(fixture)
	current_scene = fixture

	var chat := ChatPanelScript.new() as ChatPanel
	fixture.add_child(chat)

	var abilities := WeaponAbilityHudScript.new() as WeaponAbilityHud
	fixture.add_child(abilities)

	await process_frame
	await process_frame

	if not _chat_stays_clear_of_action_slots(chat, abilities):
		return

	fixture.queue_free()
	await process_frame
	print("HUD layout tests passed.")
	quit(0)


func _chat_stays_clear_of_action_slots(chat: ChatPanel, abilities: WeaponAbilityHud) -> bool:
	var chat_root := chat.get_node_or_null("ChatRoot") as Control
	var ability_root := abilities.get_node_or_null("WeaponAbilityHudRoot") as Control
	if chat_root == null or ability_root == null:
		_fail("Chat and ability HUD roots should be built.")
		return false

	var chat_rect := Rect2(chat_root.global_position, chat_root.size)
	for slot in ability_root.get_children():
		var slot_control := slot as Control
		if slot_control == null:
			continue
		var slot_rect := Rect2(slot_control.global_position, slot_control.size)
		if chat_rect.intersects(slot_rect):
			_fail(
				"Expanded chat should not overlap action slot %s. Chat=%s Slot=%s"
				% [slot_control.name, chat_rect, slot_rect]
			)
			return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
