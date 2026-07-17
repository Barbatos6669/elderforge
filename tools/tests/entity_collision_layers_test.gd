extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/entities/EnemyMob.tscn")
const RAT_SCENE := preload("res://scenes/entities/animals/Rat.tscn")
const NPC_SCENE := preload("res://scenes/entities/npcs/AuctionHouseNpc.tscn")
const RESOURCE_SCENE := preload("res://scenes/gathering/trees/OakTreeT1.tscn")

const WORLD_LAYER := 1
const RESOURCE_OBSTACLE_LAYER := 2
const SELECTABLE_LAYER := 8
const ENTITY_LAYER := 16
const ENTITY_MOVEMENT_MASK := WORLD_LAYER | RESOURCE_OBSTACLE_LAYER


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	if String(ProjectSettings.get_setting("layer_names/3d_physics/layer_5", "")) != "Entity":
		_fail("Physics layer 5 should be named Entity.")
		return

	var player := PLAYER_SCENE.instantiate() as CharacterBody3D
	var enemy := ENEMY_SCENE.instantiate() as CharacterBody3D
	var rat := RAT_SCENE.instantiate() as CharacterBody3D
	if not _validate_moving_entity(player, "Player"):
		return
	if not _validate_moving_entity(enemy, "EnemyMob"):
		return
	if not _validate_moving_entity(rat, "Rat"):
		return

	var npc := NPC_SCENE.instantiate()
	var npc_body := npc.get_node_or_null("Body") as StaticBody3D
	if npc_body == null or npc_body.collision_layer != ENTITY_LAYER or npc_body.collision_mask != 0:
		_fail("NPC bodies should use Entity without blocking movement layers.")
		return

	var resource := RESOURCE_SCENE.instantiate()
	var resource_body := resource.get_node_or_null("Body") as StaticBody3D
	if resource_body == null or resource_body.collision_layer != RESOURCE_OBSTACLE_LAYER:
		_fail("Gathering resources should remain physical movement obstacles.")
		return
	if not await _validate_runtime_collision_behavior():
		return

	player.free()
	enemy.free()
	rat.free()
	npc.free()
	resource.free()
	print("Entity collision layer tests passed.")
	quit(0)


func _validate_moving_entity(body: CharacterBody3D, label: String) -> bool:
	if body == null:
		_fail("%s scene should instantiate a CharacterBody3D." % label)
		return false
	if body.collision_layer != ENTITY_LAYER or body.collision_mask != ENTITY_MOVEMENT_MASK:
		_fail("%s should collide with world obstacles but not other entities." % label)
		return false
	if body.get_collision_mask_value(5):
		_fail("%s movement mask should exclude the Entity layer." % label)
		return false
	var selectable := body.get_node_or_null("Selectable") as Area3D
	if selectable != null and selectable.collision_layer != SELECTABLE_LAYER:
		_fail("%s selection area should remain independently targetable." % label)
		return false
	return true


func _validate_runtime_collision_behavior() -> bool:
	var fixture := Node3D.new()
	fixture.name = "EntityCollisionFixture"
	root.add_child(fixture)

	var mover := _make_entity_body("Mover", Vector3.ZERO)
	var peer := _make_entity_body("Peer", Vector3(0.0, 0.0, -1.4))
	fixture.add_child(mover)
	fixture.add_child(peer)

	var wall := StaticBody3D.new()
	wall.name = "WorldWall"
	wall.position = Vector3(0.0, 0.0, -3.0)
	wall.collision_layer = WORLD_LAYER
	wall.collision_mask = 0
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(4.0, 2.0, 0.2)
	var wall_collision := CollisionShape3D.new()
	wall_collision.position.y = 1.0
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	fixture.add_child(wall)

	await physics_frame
	await physics_frame
	for _frame_index in range(90):
		mover.velocity = Vector3(0.0, 0.0, -6.0)
		mover.move_and_slide()
		await physics_frame

	var final_z := mover.global_position.z
	if final_z > -1.9:
		fixture.queue_free()
		await process_frame
		_fail("Entities should pass through other Entity-layer bodies.")
		return false
	if final_z < -2.95:
		fixture.queue_free()
		await process_frame
		_fail("Entities should still stop at World-layer collision.")
		return false

	fixture.queue_free()
	await process_frame
	return true


func _make_entity_body(label: String, body_position: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = label
	body.position = body_position
	body.collision_layer = ENTITY_LAYER
	body.collision_mask = ENTITY_MOVEMENT_MASK
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 1.0, 0.6)
	var collision := CollisionShape3D.new()
	collision.position.y = 0.5
	collision.shape = shape
	body.add_child(collision)
	return body


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
