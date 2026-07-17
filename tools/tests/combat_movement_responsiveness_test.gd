extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const CombatHealthScript := preload("res://scripts/combat/combat_health.gd")
const WeaponAbilityDefinitionScript := preload(
	"res://scripts/combat/abilities/weapon_ability_definition.gd"
)
const Q_SLOT := &"q"


class HostileTarget:
	extends Node3D

	func is_hostile() -> bool:
		return true


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var fixture := Node3D.new()
	fixture.name = "CombatMovementResponsivenessFixture"
	root.add_child(fixture)
	current_scene = fixture

	var player := PLAYER_SCENE.instantiate() as CharacterBody3D
	player.set_physics_process(false)
	fixture.add_child(player)
	var abilities := player.get_node_or_null("WeaponAbilities") as PlayerWeaponAbilities
	var motor := player.get_node_or_null("Movement") as PlayerMovementMotor
	if abilities == null or motor == null:
		_fail("Player should expose weapon abilities and its movement motor.")
		return

	var target := HostileTarget.new()
	target.name = "Target"
	target.position = Vector3(1.0, 0.0, 0.0)
	fixture.add_child(target)
	var health := CombatHealthScript.new() as CombatHealth
	health.name = "Health"
	health.max_health = 500.0
	health.current_health = 500.0
	target.add_child(health)

	await process_frame
	await process_frame
	await physics_frame
	var definition := WeaponAbilityDefinitionScript.new() as WeaponAbilityDefinition
	definition.ability_id = "movement_responsiveness_test"
	definition.input_slot = Q_SLOT
	definition.targeting_mode = "selected_target"
	definition.execution_type = "damage"
	definition.energy_cost = 0.0
	definition.cooldown_seconds = 0.0
	definition.cast_duration_seconds = 1.0
	definition.impact_fraction = 0.5
	definition.attack_range = 2.0
	definition.approach_distance = 1.35
	definition.impact_range_leeway = 0.0
	definition.base_damage = 100.0
	definition.damage_multiplier = 0.0
	abilities.set("_active_definitions", {String(Q_SLOT): definition})

	if not abilities.request_cast(Q_SLOT, target, player):
		_fail("Player should accept an in-range Q request.")
		return
	abilities.update_abilities(player, 0.0)
	abilities.cancel_current_action("Moved", false, false)
	motor.set_destination(Vector3(-2.0, 0.0, 0.0))
	player.call("_update_weapon_ability_movement")
	motor.move_to_destination(player, 1.0 / 60.0)
	if absf(player.global_position.x) > 0.001:
		_fail("Queued escape movement should not cancel a committed spell before impact.")
		return

	abilities.update_abilities(player, 0.5)
	if not is_equal_approx(health.current_health, 400.0):
		_fail("Q should still deal damage at its authored contact frame.")
		return
	if not abilities.is_casting():
		_fail("Q should retain recovery after its impact.")
		return
	player.call("_update_weapon_ability_movement")
	motor.move_to_destination(player, 1.0 / 60.0)
	if player.global_position.x >= -0.001:
		_fail("Queued escape movement should start on the first frame after impact.")
		return

	fixture.free()
	await process_frame
	print("Combat movement responsiveness tests passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
