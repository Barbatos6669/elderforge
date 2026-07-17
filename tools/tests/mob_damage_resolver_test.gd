extends SceneTree

const CombatHealthScript := preload("res://scripts/combat/combat_health.gd")
const EnemyMobAIScript := preload("res://scripts/entities/enemy_mob_ai.gd")

var _damage_taken_events := 0
var _attack_started_events := 0
var _attack_landed_events := 0
var _last_damage_taken := 0.0
var _last_attack_speed := 0.0
var _last_attack_damage := 0.0


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var fixture := Node3D.new()
	fixture.name = "MobDamageResolverFixture"
	root.add_child(fixture)
	current_scene = fixture

	var mob := CharacterBody3D.new()
	mob.name = "Mob"
	fixture.add_child(mob)

	var ai := EnemyMobAIScript.new()
	ai.name = "AI"
	ai.attack_damage = 8.0
	ai.attack_speed = 2.0
	mob.add_child(ai)
	ai.attack_started.connect(_on_attack_started)
	ai.attack_landed.connect(_on_attack_landed)

	var target := CharacterBody3D.new()
	target.name = "Target"
	fixture.add_child(target)

	var health := CombatHealthScript.new()
	health.name = "Health"
	health.max_health = 50.0
	health.current_health = 50.0
	target.add_child(health)
	health.damage_taken.connect(_on_damage_taken)

	await process_frame

	ai.set("_target", target)
	ai.call("_update_attack", 0.1)

	if _damage_taken_events != 1 or _attack_landed_events != 1:
		_fail("Mob attack should confirm one health damage event and one landed attack.")
		return
	if _attack_started_events != 1 or not is_equal_approx(_last_attack_speed, 2.0):
		_fail("Mob attack should preserve the existing attack_started speed signal.")
		return
	if not is_equal_approx(_last_damage_taken, 8.0):
		_fail("Mob attack should preserve the current configured damage amount.")
		return
	if not is_equal_approx(_last_attack_damage, 8.0):
		_fail("Mob attack_landed should report DamageResolver applied damage.")
		return
	if not is_equal_approx(health.current_health, 42.0):
		_fail("Mob attack should lower target CombatHealth through the shared resolver.")
		return
	if not is_equal_approx(float(ai.get("_cooldown_remaining")), 0.5):
		_fail("Mob attack should preserve successful-hit cooldown behavior.")
		return
	if not _test_blocked_attack_keeps_aggro(ai, target, health):
		return

	fixture.queue_free()
	await process_frame
	print("Mob damage resolver tests passed.")
	quit(0)


func _test_blocked_attack_keeps_aggro(
	ai: EnemyMobAI,
	target: CharacterBody3D,
	health: CombatHealth
) -> bool:
	_reset_combat_events()
	health.set_current_health(50.0)
	health.grant_damage_immunity(1.0)
	ai.set("_cooldown_remaining", 0.0)
	ai.set("_target", target)
	ai.call("_update_attack", 0.1)

	if not is_equal_approx(health.current_health, 50.0):
		_fail("Damage immunity should block a mob auto-attack.")
		return false
	if ai.get("_target") != target:
		_fail("A blocked mob auto-attack should preserve aggro on its valid target.")
		return false
	if not is_equal_approx(float(ai.get("_cooldown_remaining")), 0.5):
		_fail("A blocked mob auto-attack should still consume its normal cooldown.")
		return false
	if _attack_started_events != 1 or _attack_landed_events != 0 or _damage_taken_events != 0:
		_fail("A blocked mob auto-attack should start without reporting a landed hit.")
		return false
	return true


func _reset_combat_events() -> void:
	_damage_taken_events = 0
	_attack_started_events = 0
	_attack_landed_events = 0
	_last_damage_taken = 0.0
	_last_attack_speed = 0.0
	_last_attack_damage = 0.0


func _on_damage_taken(amount: float) -> void:
	_damage_taken_events += 1
	_last_damage_taken = amount


func _on_attack_started(_target: Node, speed_scale: float) -> void:
	_attack_started_events += 1
	_last_attack_speed = speed_scale


func _on_attack_landed(_target: Node, damage: float) -> void:
	_attack_landed_events += 1
	_last_attack_damage = damage


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
