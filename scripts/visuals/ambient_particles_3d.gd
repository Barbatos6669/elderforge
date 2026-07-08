## Creates lightweight ambient particle layers for playable levels.
##
## These are mood particles: moon motes, pollen, tiny leaf flecks, and similar
## atmosphere. Keep gameplay VFX such as spell casts and hits in their own
## systems later.
class_name AmbientParticles3D
extends Node3D

## Enables or disables all generated ambient particles.
@export var particles_enabled := true
## Half-size of the emission box around this node.
@export var emission_extents := Vector3(22.0, 3.4, 22.0)
## Height offset for the center of the emission volume.
@export_range(0.0, 10.0, 0.1) var emission_center_height := 1.8

@export_group("Moon Motes")
@export_range(0, 512, 1) var moon_mote_amount := 95
@export var moon_mote_color := Color(0.62, 0.88, 0.92, 0.32)
@export_range(0.01, 1.0, 0.01) var moon_mote_size := 0.09

@export_group("Leaf Flecks")
@export_range(0, 256, 1) var leaf_fleck_amount := 34
@export var leaf_fleck_color := Color(0.58, 0.74, 0.34, 0.24)
@export_range(0.01, 1.0, 0.01) var leaf_fleck_size := 0.13

var _generated_particles: Array[GPUParticles3D] = []


func _ready() -> void:
	_rebuild_particle_layers()


func _exit_tree() -> void:
	_clear_generated_particles()


func _rebuild_particle_layers() -> void:
	_clear_generated_particles()
	if not particles_enabled:
		return

	if moon_mote_amount > 0:
		_create_particle_layer(
			"MoonMotes",
			moon_mote_amount,
			8.5,
			moon_mote_color,
			moon_mote_size,
			Vector3(0.05, 0.11, 0.02),
			Vector3(0.0, 0.012, 0.0),
			0.02,
			0.12,
			true
		)

	if leaf_fleck_amount > 0:
		_create_particle_layer(
			"LeafFlecks",
			leaf_fleck_amount,
			10.0,
			leaf_fleck_color,
			leaf_fleck_size,
			Vector3(0.11, -0.03, 0.05),
			Vector3(0.0, -0.018, 0.0),
			0.05,
			0.18,
			false
		)


func _create_particle_layer(
	layer_name: String,
	amount: int,
	lifetime: float,
	color: Color,
	size: float,
	direction: Vector3,
	gravity: Vector3,
	min_velocity: float,
	max_velocity: float,
	glow: bool
) -> void:
	var particles := GPUParticles3D.new()
	particles.name = layer_name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = lifetime
	particles.randomness = 0.82
	particles.local_coords = true
	particles.visibility_aabb = AABB(
		Vector3(-emission_extents.x, -emission_extents.y, -emission_extents.z),
		emission_extents * 2.0
	)
	particles.process_material = _create_process_material(color, direction, gravity, min_velocity, max_velocity)
	particles.draw_pass_1 = _create_particle_quad(color, size, glow)
	particles.position = Vector3(0.0, emission_center_height, 0.0)
	particles.emitting = true
	add_child(particles)
	_generated_particles.append(particles)


func _create_process_material(
	color: Color,
	direction: Vector3,
	gravity: Vector3,
	min_velocity: float,
	max_velocity: float
) -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = emission_extents
	material.direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.UP
	material.spread = 180.0
	material.gravity = gravity
	material.initial_velocity_min = min_velocity
	material.initial_velocity_max = max_velocity
	material.angular_velocity_min = -18.0
	material.angular_velocity_max = 18.0
	material.damping_min = 0.01
	material.damping_max = 0.08
	material.scale_min = 0.55
	material.scale_max = 1.2
	material.color = color
	return material


func _create_particle_quad(color: Color, size: float, glow: bool) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = _create_particle_material(color, glow)
	return quad


func _create_particle_material(color: Color, glow: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glow:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b, 1.0)
		material.emission_energy_multiplier = 0.45
	return material


func _clear_generated_particles() -> void:
	for particles in _generated_particles:
		if particles != null and is_instance_valid(particles):
			particles.queue_free()
	_generated_particles.clear()
