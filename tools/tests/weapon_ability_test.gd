extends SceneTree

const CombatHealthScript := preload("res://scripts/combat/combat_health.gd")
const PlayerWeaponAbilitiesScript := preload("res://scripts/player/combat/player_weapon_abilities.gd")
const WeaponAbilityDefinitionScript := preload(
	"res://scripts/combat/abilities/weapon_ability_definition.gd"
)
const Q_SLOT := &"q"

var _landed_events := 0
var _last_landed_damage := 0.0


class HostileTarget:
	extends Node3D

	func is_hostile() -> bool:
		return true


class StatsNode:
	extends Node

	var armor := 0.0

	func get_stat(stat_id: StringName) -> float:
		return armor if stat_id == &"armor" else 0.0


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var fixture := Node3D.new()
	fixture.name = "WeaponAbilityFixture"
	root.add_child(fixture)
	current_scene = fixture

	var attacker := Node3D.new()
	attacker.name = "Attacker"
	fixture.add_child(attacker)

	var abilities := PlayerWeaponAbilitiesScript.new()
	abilities.name = "WeaponAbilities"
	attacker.add_child(abilities)
	abilities.ability_cast_landed.connect(_on_ability_cast_landed)

	var target := HostileTarget.new()
	target.name = "ArmoredTarget"
	fixture.add_child(target)
	target.global_position = Vector3(1.0, 0.0, 0.0)

	var health := CombatHealthScript.new()
	health.name = "Health"
	health.max_health = 100.0
	health.current_health = 100.0
	target.add_child(health)

	var stats := StatsNode.new()
	stats.name = "Stats"
	stats.armor = 25.0
	target.add_child(stats)

	await process_frame
	await process_frame

	var definition := WeaponAbilityDefinitionScript.new()
	definition.ability_id = "resolver_route_test"
	definition.input_slot = Q_SLOT
	definition.targeting_mode = "selected_target"
	definition.execution_type = "damage"
	definition.damage_type = "physical"
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
	if not abilities.request_cast(Q_SLOT, target, attacker):
		_fail("Weapon ability should accept a hostile selected target.")
		return

	abilities.update_abilities(attacker, 0.0)
	abilities.update_abilities(attacker, 0.5)

	if _landed_events != 1:
		_fail("Weapon ability should emit one landed event after impact.")
		return
	if not is_equal_approx(_last_landed_damage, 80.0):
		_fail("Weapon ability damage should route through DamageResolver mitigation.")
		return
	if not is_equal_approx(health.current_health, 20.0):
		_fail("Weapon ability did not leave the expected health after armor mitigation.")
		return

	fixture.queue_free()
	await process_frame
	print("Weapon ability tests passed.")
	quit(0)


func _on_ability_cast_landed(_slot_id: StringName, _target: Node, damage: float) -> void:
	_landed_events += 1
	_last_landed_damage = damage


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
