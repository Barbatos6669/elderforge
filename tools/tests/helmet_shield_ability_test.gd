extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const MultiplayerTestManagerScript := preload(
	"res://scripts/network/multiplayer_test_manager.gd"
)
const CharacterRigAttachmentScript := preload(
	"res://scripts/visuals/character_rig_attachment.gd"
)
const WeaponAbilityHudScript := preload("res://scripts/ui/hud/weapon_ability_hud.gd")
const D_SLOT := &"d"


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var fixture := Node3D.new()
	fixture.name = "HelmetShieldFixture"
	root.add_child(fixture)
	current_scene = fixture

	var inventory := PlayerInventory.new()
	inventory.name = "PlayerInventory"
	inventory.persist_to_player_database = false
	inventory.debug_equipped_item_ids = PackedStringArray(["leather_helmet_t1"])
	fixture.add_child(inventory)

	var player := PLAYER_SCENE.instantiate() as PlayerController
	var visual_style := player.get_node("VisualStyle") as PlayerVisualStyle
	visual_style.use_auth_session_appearance = false
	visual_style.body_type = "male"
	visual_style.outfit_style = "starter_peasant"
	player.get_node("HoverSelectionRing").process_mode = Node.PROCESS_MODE_DISABLED
	fixture.add_child(player)

	var abilities := player.get_node_or_null("WeaponAbilities") as PlayerWeaponAbilities
	var equipment_visuals := player.get_node_or_null("EquipmentVisuals") as PlayerEquipmentVisuals
	if abilities != null:
		abilities.set_inventory(inventory)
	if equipment_visuals != null:
		equipment_visuals.set_inventory(inventory)

	var hud := WeaponAbilityHudScript.new() as WeaponAbilityHud
	hud.ability_component_path = NodePath("../Player/WeaponAbilities")
	fixture.add_child(hud)

	await process_frame
	await process_frame
	await process_frame

	var health := player.get_node_or_null("Health") as CombatHealth
	var mana := player.get_node_or_null("Mana") as ResourcePool
	var shield := player.get_node_or_null("DamageImmunityBubble") as Node3D
	var hud_slot := hud.get_slot(D_SLOT)
	if (
		player == null
		or inventory == null
		or abilities == null
		or equipment_visuals == null
		or health == null
		or mana == null
		or shield == null
		or hud_slot == null
	):
		_fail("The helmet-shield fixture did not build every required node.")
		return

	health.health_regeneration_per_second = 0.0
	mana.regeneration_per_second = 0.0

	var head_item := inventory.get_equipped_slot("head")
	if String(head_item.get("id", "")) != "leather_helmet_t1":
		_fail("The battle test loadout should equip the tier-one leather helmet.")
		return

	var definition := abilities.get_active_ability(D_SLOT)
	if definition == null or String(definition.get("ability_id")) != "energizing_shield":
		_fail("Equipped leather helmet did not provide Energizing Shield in the D slot.")
		return
	if hud_slot.get_ability_definition() != definition:
		_fail("The D action-bar slot did not bind the equipped helmet ability.")
		return
	if not _has_expected_definition_data(definition):
		return
	if not _helmet_visual_is_bound(player):
		return

	var network_manager := MultiplayerTestManagerScript.new()
	var first_network_cast := bool(
		network_manager.call("_server_accept_ability_cooldown", 42, "energizing_shield")
	)
	var repeated_network_cast := bool(
		network_manager.call("_server_accept_ability_cooldown", 42, "energizing_shield")
	)
	network_manager.free()
	if not first_network_cast or repeated_network_cast:
		_fail("The server did not reject a repeated helmet cast during cooldown.")
		return

	health.set_current_health(health.max_health)
	mana.set_current_resource(60.0)
	hud_slot.ability_activation_requested.emit()
	if abilities.is_channeling_ability():
		_fail("Energizing Shield should be an instant self-cast, not a channel.")
		return
	if not health.has_absorb_shield() or not bool(shield.call("is_active")):
		_fail("Energizing Shield should immediately activate an absorb shield and bubble.")
		return
	if (
		not shield.has_method("get_active_protection_mode")
		or String(shield.call("get_active_protection_mode")) != "absorb_shield"
	):
		_fail("Energizing Shield should show absorb-shield bubble mode.")
		return
	if not is_equal_approx(health.get_absorb_shield_current(), 834.0):
		_fail("Energizing Shield should grant exactly 834 shield.")
		return
	if not is_equal_approx(mana.current_resource, 75.0):
		_fail("Energizing Shield should restore 25% of the wearer's missing energy.")
		return
	if not is_equal_approx(abilities.get_cooldown_remaining(D_SLOT), 21.14):
		_fail("Energizing Shield should begin its 21.14-second cooldown on activation.")
		return

	var protected_health := health.current_health
	if health.apply_damage(400.0) > 0.0:
		_fail("Damage should not change health while shield capacity remains.")
		return
	if not is_equal_approx(health.current_health, protected_health):
		_fail("Health changed while Energizing Shield still had capacity.")
		return
	if not is_equal_approx(health.get_absorb_shield_current(), 434.0):
		_fail("The shield should lose exactly the absorbed damage amount.")
		return
	if not is_equal_approx(health.apply_damage(500.0), 66.0):
		_fail("Shield overflow should damage health only after consuming the shield.")
		return
	if health.has_absorb_shield() or bool(shield.call("is_active")):
		_fail("The shield bubble should end after the absorb pool is depleted.")
		return
	if not is_equal_approx(health.current_health, protected_health - 66.0):
		_fail("Shield overflow did not apply the expected health damage.")
		return

	abilities.update_abilities(player, 21.14)
	mana.set_current_resource(0.0)
	if not player.request_ability_activation(D_SLOT):
		_fail("Energizing Shield did not become available after its cooldown elapsed.")
		return
	if not health.has_absorb_shield() or not bool(shield.call("is_active")):
		_fail("A later Energizing Shield cast should reactivate the absorb shield.")
		return
	if not is_equal_approx(mana.current_resource, 30.0):
		_fail("A later cast should restore 25% of fully missing energy.")
		return

	health.call("_process", 3.01)
	if health.has_absorb_shield() or bool(shield.call("is_active")):
		_fail("Energizing Shield should expire after three seconds.")
		return

	fixture.queue_free()
	await process_frame
	await process_frame
	print("Helmet shield ability tests passed.")
	quit(0)


func _has_expected_definition_data(definition: Resource) -> bool:
	var expected := (
		String(definition.get("targeting_mode")) == "self"
		and String(definition.get("execution_type")) == "shield"
		and is_equal_approx(float(definition.get("energy_cost")), 0.0)
		and is_equal_approx(float(definition.get("cast_duration_seconds")), 0.0)
		and is_equal_approx(float(definition.get("attack_range")), 0.0)
		and is_equal_approx(float(definition.get("cooldown_seconds")), 21.14)
		and is_equal_approx(float(definition.get("absorb_shield_amount")), 834.0)
		and is_equal_approx(float(definition.get("absorb_shield_duration_seconds")), 3.0)
		and is_equal_approx(float(definition.get("missing_energy_restore_percent")), 25.0)
	)
	if not expected:
		_fail("Energizing Shield data does not match the supplied base stats.")
	return expected


func _helmet_visual_is_bound(player: PlayerController) -> bool:
	var skeleton := player.get_node_or_null("Visuals/BaseCharacter/Armature/Skeleton3D") as Skeleton3D
	if skeleton == null:
		_fail("The player skeleton should exist after appearance setup.")
		return false

	var helmet_root := skeleton.get_node_or_null("HeadEquipment") as Node3D
	if helmet_root == null:
		_fail("Equipped helmet should create a HeadEquipment attachment.")
		return false

	var helmet_meshes := CharacterRigAttachmentScript.collect_mesh_instances(helmet_root)
	if helmet_meshes.is_empty():
		_fail("The helmet attachment should contain a skinned mesh.")
		return false
	for mesh_instance in helmet_meshes:
		if mesh_instance.get_node_or_null(mesh_instance.skeleton) != skeleton:
			_fail("Every helmet mesh should bind to the live player skeleton.")
			return false
		if not mesh_instance.visible:
			_fail("Equipped helmet should remain visible beside the starter outfit.")
			return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
