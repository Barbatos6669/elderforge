extends SceneTree

const PlayerStatsScript := preload("res://scripts/player/stats/player_stats.gd")
const EntityStatsScript := preload("res://scripts/stats/entity_stats.gd")
const EnemyMobScene := preload("res://scenes/entities/EnemyMob.tscn")


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var player_stats := PlayerStatsScript.new()
	player_stats.persist_to_player_database = false
	player_stats.reset_to_base_values()

	var entity_stats := EntityStatsScript.new()
	var shared_stat_ids := [
		PlayerStatsScript.MAX_HEALTH,
		PlayerStatsScript.HEALTH_REGENERATION,
		PlayerStatsScript.AUTO_ATTACK_DAMAGE,
		PlayerStatsScript.AUTO_ATTACK_SPEED,
		PlayerStatsScript.ARMOR,
		PlayerStatsScript.MAGICAL_RESISTANCE,
		PlayerStatsScript.MOVE_SPEED,
	]
	for stat_id in shared_stat_ids:
		if not entity_stats.has_stat(stat_id):
			_fail("EntityStats should expose player stat %s." % stat_id)
			return
		if not is_equal_approx(
			float(entity_stats.get_base_stat(stat_id)),
			float(player_stats.get_base_stat(stat_id))
		):
			_fail(
				"EntityStats %s should match PlayerStats base value %.2f, found %.2f."
				% [
					stat_id,
					float(player_stats.get_base_stat(stat_id)),
					float(entity_stats.get_base_stat(stat_id)),
				]
			)
			return

	var mob := EnemyMobScene.instantiate()
	if mob == null:
		_fail("EnemyMob scene should instantiate.")
		return

	var health := mob.get_node_or_null("Health")
	var stats := mob.get_node_or_null("Stats")
	var ai := mob.get_node_or_null("AI")
	if health == null or stats == null or ai == null:
		_fail("EnemyMob should include Health, Stats, and AI nodes.")
		mob.free()
		return

	if not _has_value(health, "max_health", player_stats.get_base_stat(PlayerStatsScript.MAX_HEALTH)):
		mob.free()
		return
	if not _has_value(health, "current_health", player_stats.get_base_stat(PlayerStatsScript.MAX_HEALTH)):
		mob.free()
		return
	if not _has_value(
		health,
		"health_regeneration_per_second",
		player_stats.get_base_stat(PlayerStatsScript.HEALTH_REGENERATION)
	):
		mob.free()
		return

	for stat_id in shared_stat_ids:
		if not is_equal_approx(
			float(stats.call("get_base_stat", stat_id)),
			float(player_stats.get_base_stat(stat_id))
		):
			_fail("EnemyMob Stats.%s should match PlayerStats base value." % stat_id)
			mob.free()
			return

	var fallback_expectations := {
		"attack_damage": PlayerStatsScript.AUTO_ATTACK_DAMAGE,
		"attack_speed": PlayerStatsScript.AUTO_ATTACK_SPEED,
		"movement_speed": PlayerStatsScript.MOVE_SPEED,
	}
	for property_name in fallback_expectations:
		var stat_id: StringName = fallback_expectations[property_name]
		if not _has_value(ai, property_name, player_stats.get_base_stat(stat_id)):
			mob.free()
			player_stats.free()
			entity_stats.free()
			return

	mob.free()
	player_stats.free()
	entity_stats.free()
	print("Mob base stats tests passed.")
	quit(0)


func _has_value(node: Node, property_name: String, expected: float) -> bool:
	var actual := float(node.get(property_name))
	if is_equal_approx(actual, expected):
		return true

	_fail(
		"%s.%s should be %.2f, found %.2f."
		% [node.name, property_name, expected, actual]
	)
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
