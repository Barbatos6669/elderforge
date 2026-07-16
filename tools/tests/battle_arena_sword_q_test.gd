extends SceneTree

const ARENA_PATH := "res://scenes/debug/combat/BattleTestArena.tscn"
const Q_SLOT := &"q"

var _landed_events := 0
var _last_landed_damage := 0.0


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var packed_arena := load(ARENA_PATH) as PackedScene
	if packed_arena == null:
		_fail("Battle test arena scene should load.")
		return

	var arena := packed_arena.instantiate()
	root.add_child(arena)
	current_scene = arena

	await process_frame
	await process_frame

	var player := arena.get_node_or_null("World/Player")
	var targeting := player.get_node_or_null("Targeting") if player != null else null
	var abilities := player.get_node_or_null("WeaponAbilities") if player != null else null
	var mana := player.get_node_or_null("Mana") if player != null else null
	var target := arena.get_node_or_null("World/LevelContent/Mobs/CenterTrainingTarget")
	var selectable := target.get_node_or_null("Selectable") if target != null else null
	var health := target.get_node_or_null("Health") if target != null else null

	if player == null or targeting == null or abilities == null or target == null or selectable == null or health == null:
		_fail("Battle arena should expose player, Q ability handler, and center training target.")
		return

	player.global_position = target.global_position + Vector3(0.0, 0.0, 1.0)
	if mana != null and mana.has_method("set_current_resource"):
		mana.call("set_current_resource", float(mana.get("max_resource")))

	abilities.ability_cast_landed.connect(_on_ability_cast_landed)
	targeting.call("set_current_target", selectable)

	var definition: Resource = abilities.call("get_active_ability", Q_SLOT)
	if definition == null:
		_fail("Equipped one-handed sword should bind Sword Slash to Q.")
		return
	if String(definition.get("ability_id")) != "one_handed_sword_q":
		_fail("Q slot should be bound to one_handed_sword_q.")
		return

	var starting_health := float(health.get("current_health"))
	if not bool(player.call("request_ability_activation", Q_SLOT)):
		_fail("PlayerController should accept Q against the selected hostile target.")
		return

	abilities.call("update_abilities", player, 0.0)
	abilities.call("update_abilities", player, 0.45)
	abilities.call("update_abilities", player, 1.0)

	if _landed_events != 1:
		_fail("Sword Q should land once after activation.")
		return
	if _last_landed_damage <= 0.0:
		_fail("Sword Q should report positive damage.")
		return
	if not float(health.get("current_health")) < starting_health:
		_fail("Sword Q should reduce the target health.")
		return

	arena.queue_free()
	await process_frame
	print("Battle arena sword Q tests passed.")
	quit(0)


func _on_ability_cast_landed(_slot_id: StringName, _target: Node, damage: float) -> void:
	_landed_events += 1
	_last_landed_damage = damage


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
