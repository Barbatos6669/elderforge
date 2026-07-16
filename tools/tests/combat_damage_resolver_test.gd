extends SceneTree

const CombatHealthScript := preload("res://scripts/combat/combat_health.gd")
const DamageRequestScript := preload("res://scripts/combat/damage_request.gd")
const DamageResolverScript := preload("res://scripts/combat/damage_resolver.gd")

var _damage_taken_events := 0
var _last_damage_taken := 0.0


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

	fixture.queue_free()
	await process_frame
	print("Combat damage resolver tests passed.")
	quit(0)


func _on_damage_taken(amount: float) -> void:
	_damage_taken_events += 1
	_last_damage_taken = amount


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
