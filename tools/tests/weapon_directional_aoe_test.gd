extends SceneTree

const CombatHealthScript := preload("res://scripts/combat/combat_health.gd")
const AbilityImpactScheduleScript := preload(
	"res://scripts/combat/abilities/ability_impact_schedule.gd"
)
const DirectionalIndicatorScript := preload(
	"res://scripts/effects/directional_ability_indicator.gd"
)
const PlayerWeaponAbilitiesScript := preload(
	"res://scripts/player/combat/player_weapon_abilities.gd"
)
const WeaponAbilityDefinitionScript := preload(
	"res://scripts/combat/abilities/weapon_ability_definition.gd"
)
const W_SLOT := &"w"

var _landed_events := 0


class AreaTarget:
	extends Node3D

	var hostile := true

	func is_hostile() -> bool:
		return hostile


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var fixture := Node3D.new()
	fixture.name = "WeaponDirectionalAoeFixture"
	root.add_child(fixture)
	current_scene = fixture

	var attacker := Node3D.new()
	attacker.name = "Attacker"
	fixture.add_child(attacker)

	var indicator := DirectionalIndicatorScript.new() as DirectionalAbilityIndicator
	indicator.name = "DirectionalIndicator"
	attacker.add_child(indicator)

	var abilities := PlayerWeaponAbilitiesScript.new() as PlayerWeaponAbilities
	abilities.name = "WeaponAbilities"
	abilities.directional_indicator_path = NodePath("../DirectionalIndicator")
	attacker.add_child(abilities)
	abilities.ability_cast_landed.connect(_on_ability_cast_landed)

	var front := _spawn_target(fixture, "Front", Vector3(0.0, 0.0, -2.0))
	var escaping := _spawn_target(fixture, "Escaping", Vector3(1.5, 0.0, -1.5))
	var behind := _spawn_target(fixture, "Behind", Vector3(0.0, 0.0, 1.5))
	var outside := _spawn_target(fixture, "Outside", Vector3(0.0, 0.0, -3.5))
	var friendly := _spawn_target(fixture, "Friendly", Vector3(-1.0, 0.0, -1.0), false)

	await process_frame
	await process_frame

	var definition := WeaponAbilityDefinitionScript.new() as WeaponAbilityDefinition
	definition.ability_id = "directional_aoe_test"
	definition.input_slot = W_SLOT
	definition.targeting_mode = "direction"
	definition.execution_type = "damage"
	definition.damage_type = "physical"
	definition.energy_cost = 0.0
	definition.cooldown_seconds = 0.0
	definition.cast_duration_seconds = 1.0
	definition.impact_fraction = 0.36
	definition.impact_fractions = PackedFloat32Array([0.36, 0.72])
	definition.impact_damage_scales = PackedFloat32Array([0.5, 0.5])
	definition.attack_range = 3.0
	definition.impact_range_leeway = 0.0
	definition.area_arc_degrees = 180.0
	definition.base_damage = 100.0
	definition.damage_multiplier = 0.0
	abilities.set("_active_definitions", {String(W_SLOT): definition})

	var hitch_schedule = AbilityImpactScheduleScript.new()
	hitch_schedule.begin(definition, 1.0)
	if hitch_schedule.advance(1.0) != PackedInt32Array([0, 1]):
		_fail("A long frame should resolve both crossed swipe contacts in order.")
		return

	if not abilities.begin_directional_targeting(W_SLOT, attacker):
		_fail("Directional damage ability should enter cursor aiming.")
		return
	abilities.update_directional_targeting(attacker, Vector3(0.0, 0.0, -5.0))
	if not indicator.is_showing() or indicator.get_indicator_kind() != &"swing":
		_fail("Directional AoE aiming should show the swing area, not the dodge arrow.")
		return
	var swing_fill := (indicator.get_node("Fill") as MeshInstance3D).mesh
	indicator.show_direction(Vector3(0.0, 0.0, -1.0), 3.0, 3.0)
	var direction_fill := (indicator.get_node("Fill") as MeshInstance3D).mesh
	if indicator.get_indicator_kind() != &"direction" or direction_fill == swing_fill:
		_fail("Switching from a damage area should restore the movement arrow.")
		return
	abilities.update_directional_targeting(attacker, Vector3(0.0, 0.0, -5.0))
	var restored_swing_fill := (indicator.get_node("Fill") as MeshInstance3D).mesh
	if indicator.get_indicator_kind() != &"swing" or restored_swing_fill == direction_fill:
		_fail("Switching from a movement arrow should restore the damage area.")
		return
	if not abilities.confirm_directional_cast(attacker):
		_fail("Directional AoE should commit after aim confirmation.")
		return
	if not abilities.should_hold_position(attacker):
		_fail("A multi-hit spell should hold movement until every authored swipe lands.")
		return

	abilities.update_abilities(attacker, 0.35)
	if not _all_health_equals([front, escaping, behind, outside, friendly], 100.0):
		_fail("Whirling Slash should not deal damage before the first authored swipe.")
		return

	abilities.update_abilities(attacker, 0.01)
	if not is_equal_approx(_health(front).current_health, 50.0):
		_fail("The first swipe should damage a hostile in the aimed semicircle.")
		return
	if not is_equal_approx(_health(escaping).current_health, 50.0):
		_fail("The first swipe should hit every hostile inside the aimed area.")
		return
	if not abilities.should_hold_position(attacker):
		_fail("Whirling Slash should remain committed between its two swipe impacts.")
		return
	if (
		not is_equal_approx(_health(behind).current_health, 100.0)
		or not is_equal_approx(_health(outside).current_health, 100.0)
		or not is_equal_approx(_health(friendly).current_health, 100.0)
	):
		_fail("The directional swipe hit a friendly, rear, or out-of-range target.")
		return

	escaping.position = Vector3(0.0, 0.0, 1.5)
	abilities.update_abilities(attacker, 0.35)
	if not is_equal_approx(_health(front).current_health, 50.0):
		_fail("The second swipe should wait for its own authored contact frame.")
		return
	abilities.update_abilities(attacker, 0.01)
	if not is_equal_approx(_health(front).current_health, 0.0):
		_fail("A hostile remaining in the area should take both swipe hits.")
		return
	if not is_equal_approx(_health(escaping).current_health, 50.0):
		_fail("A hostile that leaves the area should avoid the second swipe.")
		return
	if _landed_events != 3:
		_fail("Two area pulses should emit one landed event per actual target hit.")
		return
	if abilities.should_hold_position(attacker):
		_fail("Whirling Slash should release movement immediately after its second swipe.")
		return
	if not abilities.is_casting():
		_fail("Whirling Slash recovery should continue after movement is released.")
		return

	fixture.queue_free()
	await process_frame
	print("Weapon directional AoE tests passed.")
	quit(0)


func _spawn_target(
	parent: Node,
	target_name: String,
	position: Vector3,
	hostile := true
) -> AreaTarget:
	var target := AreaTarget.new()
	target.name = target_name
	target.position = position
	target.hostile = hostile
	target.add_to_group("selectable_3d")
	parent.add_child(target)

	var health := CombatHealthScript.new() as CombatHealth
	health.name = "Health"
	health.max_health = 100.0
	health.current_health = 100.0
	target.add_child(health)
	return target


func _health(target: Node) -> CombatHealth:
	return target.get_node("Health") as CombatHealth


func _all_health_equals(targets: Array, expected: float) -> bool:
	for target in targets:
		if not is_equal_approx(_health(target).current_health, expected):
			return false
	return true


func _on_ability_cast_landed(_slot_id: StringName, _target: Node, _damage: float) -> void:
	_landed_events += 1


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
