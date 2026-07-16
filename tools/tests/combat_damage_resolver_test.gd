extends SceneTree

const CombatHealthScript := preload("res://scripts/combat/combat_health.gd")
const DamageRequestScript := preload("res://scripts/combat/damage_request.gd")
const DamageResolverScript := preload("res://scripts/combat/damage_resolver.gd")

var _damage_taken_events := 0
var _last_damage_taken := 0.0


class StatsNode:
	extends Node

	var armor := 0.0
	var magical_resistance := 0.0

	func get_stat(stat_id: StringName) -> float:
		match stat_id:
			&"armor":
				return armor
			&"magical_resistance":
				return magical_resistance
			_:
				return 0.0


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var fixture := Node3D.new()
	fixture.name = "DamageResolverFixture"
	root.add_child(fixture)
	current_scene = fixture

	var attacker := Node3D.new()
	attacker.name = "Attacker"
	fixture.add_child(attacker)

	var target := Node3D.new()
	target.name = "Target"
	fixture.add_child(target)

	var health := CombatHealthScript.new()
	health.name = "Health"
	health.max_health = 100.0
	health.current_health = 100.0
	target.add_child(health)
	health.damage_taken.connect(_on_damage_taken)

	await process_frame

	var resolver := DamageResolverScript.new()
	var request := DamageRequestScript.create(
		attacker,
		target,
		25.0,
		DamageRequestScript.TYPE_PHYSICAL
	)
	var result: Resource = resolver.call("resolve", request)
	if not result.was_applied():
		_fail("DamageResolver should apply positive damage to a target Health child.")
		return
	if not is_equal_approx(result.applied_damage, 25.0):
		_fail("DamageResolver did not report the applied damage amount.")
		return
	if result.source != attacker or result.target != target or result.target_health != health:
		_fail("DamageResolver result did not preserve source, target, and health references.")
		return
	if not is_equal_approx(health.current_health, 75.0):
		_fail("DamageResolver did not lower CombatHealth by the requested amount.")
		return
	if _damage_taken_events != 1 or not is_equal_approx(_last_damage_taken, 25.0):
		_fail("DamageResolver should keep CombatHealth.damage_taken as the confirmation point.")
		return

	var blocked_result: Resource = resolver.call(
		"resolve",
		DamageRequestScript.create(attacker, target, -10.0)
	)
	if blocked_result.was_applied() or _damage_taken_events != 1:
		_fail("DamageResolver should clamp negative damage and avoid false hit confirmation.")
		return

	var armored_fixture := _build_target(fixture, "ArmoredTarget", 25.0, 75.0)
	var armored_result: Resource = resolver.call(
		"resolve",
		DamageRequestScript.create(
			attacker,
			armored_fixture["target"],
			100.0,
			DamageRequestScript.TYPE_PHYSICAL
		)
	)
	if not is_equal_approx(armored_result.defense_value, 25.0):
		_fail("Physical damage should read armor from the target Stats node.")
		return
	if not is_equal_approx(armored_result.mitigated_damage, 80.0):
		_fail("Physical damage should be mitigated by armor before health application.")
		return
	if not is_equal_approx(armored_result.applied_damage, 80.0):
		_fail("Physical damage should report the mitigated applied amount.")
		return
	if not is_equal_approx(armored_fixture["health"].current_health, 20.0):
		_fail("Armor mitigation did not leave the expected remaining health.")
		return

	var warded_fixture := _build_target(fixture, "WardedTarget", 25.0, 50.0)
	var magical_result: Resource = resolver.call(
		"resolve",
		DamageRequestScript.create(
			attacker,
			warded_fixture["target"],
			90.0,
			DamageRequestScript.TYPE_MAGICAL
		)
	)
	if not is_equal_approx(magical_result.defense_value, 50.0):
		_fail("Magical damage should read magical resistance instead of armor.")
		return
	if not is_equal_approx(magical_result.mitigated_damage, 60.0):
		_fail("Magical damage should be mitigated by magical resistance.")
		return
	if not is_equal_approx(warded_fixture["health"].current_health, 40.0):
		_fail("Magical resistance mitigation did not leave the expected remaining health.")
		return

	var true_damage_fixture := _build_target(fixture, "TrueDamageTarget", 900.0, 900.0)
	var true_result: Resource = resolver.call(
		"resolve",
		DamageRequestScript.create(
			attacker,
			true_damage_fixture["target"],
			90.0,
			DamageRequestScript.TYPE_TRUE
		)
	)
	if not is_equal_approx(true_result.defense_value, 0.0):
		_fail("True damage should not read armor or magical resistance.")
		return
	if not is_equal_approx(true_result.applied_damage, 90.0):
		_fail("True damage should bypass mitigation.")
		return
	if not is_equal_approx(true_damage_fixture["health"].current_health, 10.0):
		_fail("True damage did not lower health by the raw requested amount.")
		return

	fixture.queue_free()
	await process_frame
	print("Combat damage resolver tests passed.")
	quit(0)


func _build_target(
	parent: Node,
	target_name: String,
	armor: float,
	magical_resistance: float
) -> Dictionary:
	var target := Node3D.new()
	target.name = target_name
	parent.add_child(target)

	var health := CombatHealthScript.new()
	health.name = "Health"
	health.max_health = 100.0
	health.current_health = 100.0
	target.add_child(health)

	var stats := StatsNode.new()
	stats.name = "Stats"
	stats.armor = armor
	stats.magical_resistance = magical_resistance
	target.add_child(stats)

	return {
		"target": target,
		"health": health,
		"stats": stats,
	}


func _on_damage_taken(amount: float) -> void:
	_damage_taken_events += 1
	_last_damage_taken = amount


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
