## Reusable, allocation-free blood burst for living combat entities.
##
## Attach this component beside CombatHealth. It keeps one dormant particle
## emitter per entity and restarts it whenever damage actually lowers health.
class_name BloodImpactEmitter3D
extends Node3D

## Health component that reports confirmed damage.
@export var health_path: NodePath = NodePath("../Health")
## Entity root used to place the burst in world space.
@export var source_path: NodePath = NodePath("..")
## World-space offset from the entity origin to its usual hit height.
@export var spawn_offset := Vector3(0.0, 1.05, 0.0)
## Small position variation so repeated hits do not look identical.
@export_range(0.0, 1.0, 0.01) var jitter_radius := 0.10
## Number of low-poly droplets in each burst.
@export_range(4, 48, 1) var burst_particle_count := 18
## How long droplets remain visible.
@export_range(0.1, 2.0, 0.05) var burst_lifetime := 0.60
## Minimum and maximum launch speed in meters per second.
@export var launch_speed := Vector2(1.8, 3.8)
## Upward cone width in degrees.
@export_range(0.0, 180.0, 1.0) var spread_degrees := 72.0
## Gravity applied to airborne droplets.
@export var gravity := Vector3(0.0, -7.5, 0.0)
## Main stylized blood color.
@export var blood_color := Color(0.58, 0.015, 0.025, 1.0)

var _health: CombatHealth
var _particles: GPUParticles3D
var _burst_count := 0


func _ready() -> void:
	# The burst stays where the hit occurred instead of following a moving target.
	top_level = true
	_build_particle_emitter()
	_health = get_node_or_null(health_path) as CombatHealth
	if _health == null:
		push_warning("BloodImpactEmitter3D could not find CombatHealth at %s." % health_path)
		return

	_health.damage_taken.connect(_on_damage_taken)


## Exposed for focused effect tests and future diagnostics.
func get_burst_count() -> int:
	return _burst_count


func is_emitting() -> bool:
	return _particles != null and _particles.emitting


func _on_damage_taken(_amount: float) -> void:
	var source := get_node_or_null(source_path) as Node3D
	if source == null or _particles == null:
		return

	global_position = source.global_position + spawn_offset + _random_jitter()
	global_rotation = Vector3(0.0, randf_range(-PI, PI), 0.0)
	_burst_count += 1
	_particles.restart()
	_particles.emitting = true


func _build_particle_emitter() -> void:
	_particles = GPUParticles3D.new()
	_particles.name = "BloodParticles"
	_particles.amount = burst_particle_count
	_particles.lifetime = burst_lifetime
	_particles.one_shot = true
	_particles.explosiveness = 1.0
	_particles.randomness = 0.45
	_particles.fixed_fps = 30
	_particles.interpolate = false
	_particles.visibility_aabb = AABB(Vector3(-3.0, -2.0, -3.0), Vector3(6.0, 6.0, 6.0))
	_particles.process_material = _create_process_material()
	_particles.draw_pass_1 = _create_droplet_mesh()
	add_child(_particles)


func _create_process_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.08
	material.direction = Vector3.UP
	material.spread = spread_degrees
	material.initial_velocity_min = minf(launch_speed.x, launch_speed.y)
	material.initial_velocity_max = maxf(launch_speed.x, launch_speed.y)
	material.gravity = gravity
	material.damping_min = 0.5
	material.damping_max = 1.2
	material.scale_min = 0.70
	material.scale_max = 1.35
	material.angle_min = -180.0
	material.angle_max = 180.0

	var color_gradient := Gradient.new()
	color_gradient.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	color_gradient.colors = PackedColorArray([
		blood_color.lightened(0.08),
		blood_color.darkened(0.18),
		Color(blood_color.r, blood_color.g, blood_color.b, 0.0),
	])
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = color_gradient
	material.color_ramp = color_ramp
	return material


func _create_droplet_mesh() -> SphereMesh:
	var droplet_material := StandardMaterial3D.new()
	droplet_material.albedo_color = Color.WHITE
	droplet_material.vertex_color_use_as_albedo = true
	droplet_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	droplet_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	droplet_material.roughness = 1.0

	var droplet_mesh := SphereMesh.new()
	droplet_mesh.radius = 0.052
	droplet_mesh.height = 0.14
	droplet_mesh.radial_segments = 5
	droplet_mesh.rings = 2
	droplet_mesh.material = droplet_material
	return droplet_mesh


func _random_jitter() -> Vector3:
	if jitter_radius <= 0.0:
		return Vector3.ZERO

	var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if offset.length_squared() > 1.0:
		offset = offset.normalized()
	return Vector3(offset.x, randf_range(-0.03, 0.08), offset.y) * jitter_radius
