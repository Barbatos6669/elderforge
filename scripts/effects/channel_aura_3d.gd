## Reusable aura that mirrors one ability-specific PlayerChanneling context.
##
## Gameplay systems own channel timing and cancellation. This component only
## displays that state, keeping the visual unable to outlive the real spell.
class_name ChannelAura3D
extends Node3D

const AURA_SHADER := preload(
	"res://assets/materials/effects/moonleaf_channel_aura.gdshader"
)

## PlayerChanneling component whose signals drive the local visual.
@export var channeling_path: NodePath = NodePath("../Channeling")
## Only a channel carrying this ability id activates the aura.
@export var ability_id: StringName = &"moonleaf_binding"
## Diameter of the soft ground glow in meters.
@export_range(0.5, 5.0, 0.05) var aura_diameter := 2.15
## Keeps the glow just above the floor to avoid depth flicker.
@export_range(0.0, 0.5, 0.005) var ground_offset := 0.045
## Main aura and particle color.
@export var aura_color := Color(0.23, 0.92, 0.34, 1.0)
## Number of lightweight upward motes around the wearer.
@export_range(0, 64, 1) var mote_count := 18

var _channeling: Node
var _ground_material: ShaderMaterial
var _motes: GPUParticles3D
var _transition: Tween
var _active := false


func _ready() -> void:
	_build_visuals()
	_bind_channeling()
	set_active(_is_matching_current_channel(), false)


## Returns gameplay-facing activity, independent of a short visual fade-out.
func is_active() -> bool:
	return _active


## Supports remote-player state snapshots without giving this effect authority.
func set_remote_channel_state(action_state: String, context: Dictionary) -> void:
	set_active(
		action_state == "equipment_ability" and _matches_channel_context(context)
	)


func set_active(should_be_active: bool, animate: bool = true) -> void:
	if _active == should_be_active and (not should_be_active or visible):
		return

	_active = should_be_active
	if _transition != null and _transition.is_valid():
		_transition.kill()

	if should_be_active:
		visible = true
		_set_intensity(0.0 if animate else 1.0)
		scale = Vector3.ONE * (0.86 if animate else 1.0)
		if _motes != null:
			_motes.emitting = true
			_motes.restart()
		if animate and is_inside_tree():
			_transition = create_tween().set_parallel(true)
			_transition.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_transition.tween_method(_set_intensity, 0.0, 1.0, 0.18)
			_transition.tween_property(self, "scale", Vector3.ONE, 0.18)
		return

	if _motes != null:
		_motes.emitting = false
	if not animate or not is_inside_tree():
		_set_intensity(0.0)
		visible = false
		scale = Vector3.ONE
		return

	_transition = create_tween()
	_transition.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_transition.tween_method(_set_intensity, _get_intensity(), 0.0, 0.16)
	_transition.tween_callback(_finish_fade_out)


func _build_visuals() -> void:
	var ground_glow := MeshInstance3D.new()
	ground_glow.name = "GroundGlow"
	ground_glow.position = Vector3(0.0, ground_offset, 0.0)
	ground_glow.rotation_degrees.x = -90.0
	ground_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var quad := QuadMesh.new()
	quad.size = Vector2(aura_diameter, aura_diameter)
	_ground_material = ShaderMaterial.new()
	_ground_material.shader = AURA_SHADER
	_ground_material.set_shader_parameter("aura_color", aura_color)
	_ground_material.set_shader_parameter("intensity", 0.0)
	quad.material = _ground_material
	ground_glow.mesh = quad
	add_child(ground_glow)

	_motes = GPUParticles3D.new()
	_motes.name = "MoonleafMotes"
	_motes.amount = mote_count
	_motes.lifetime = 1.15
	_motes.preprocess = 0.55
	_motes.randomness = 0.72
	_motes.local_coords = true
	_motes.fixed_fps = 30
	_motes.interpolate = false
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_motes.visibility_aabb = AABB(Vector3(-1.3, -0.1, -1.3), Vector3(2.6, 2.8, 2.6))
	_motes.process_material = _create_mote_process_material()
	_motes.draw_pass_1 = _create_mote_mesh()
	_motes.position = Vector3(0.0, aura_diameter * 0.25, 0.0)
	_motes.emitting = false
	add_child(_motes)


func _create_mote_process_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = aura_diameter * 0.23
	material.direction = Vector3.UP
	material.spread = 18.0
	material.initial_velocity_min = 0.28
	material.initial_velocity_max = 0.72
	material.gravity = Vector3(0.0, 0.08, 0.0)
	material.damping_min = 0.02
	material.damping_max = 0.12
	material.scale_min = 0.55
	material.scale_max = 1.15
	material.angle_min = -180.0
	material.angle_max = 180.0

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.22, 0.78, 1.0])
	gradient.colors = PackedColorArray([
		Color(aura_color.r, aura_color.g, aura_color.b, 0.0),
		aura_color.lightened(0.18),
		aura_color,
		Color(aura_color.r, aura_color.g, aura_color.b, 0.0),
	])
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	material.color_ramp = color_ramp
	return material


func _create_mote_mesh() -> SphereMesh:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = Color(aura_color.r, aura_color.g, aura_color.b, 1.0)
	material.emission_energy_multiplier = 0.65

	var mote := SphereMesh.new()
	mote.radius = 0.026
	mote.height = 0.10
	mote.radial_segments = 4
	mote.rings = 2
	mote.material = material
	return mote


func _bind_channeling() -> void:
	_channeling = get_node_or_null(channeling_path)
	if _channeling == null:
		push_warning("ChannelAura3D could not find PlayerChanneling at %s." % channeling_path)
		return

	if _channeling.has_signal("channel_started"):
		_channeling.connect("channel_started", Callable(self, "_on_channel_started"))
	if _channeling.has_signal("channel_completed"):
		_channeling.connect("channel_completed", Callable(self, "_on_channel_completed"))
	if _channeling.has_signal("channel_cancelled"):
		_channeling.connect("channel_cancelled", Callable(self, "_on_channel_cancelled"))


func _on_channel_started(_action_name: String, _duration: float, context: Dictionary) -> void:
	set_active(_matches_channel_context(context))


func _on_channel_completed(context: Dictionary) -> void:
	if _matches_channel_context(context):
		set_active(false)


func _on_channel_cancelled(_reason: String, context: Dictionary) -> void:
	if _matches_channel_context(context):
		set_active(false)


func _matches_channel_context(context: Dictionary) -> bool:
	return (
		String(context.get("type", "")) == "equipment_ability"
		and String(context.get("ability_id", "")) == String(ability_id)
	)


func _is_matching_current_channel() -> bool:
	return (
		_channeling != null
		and _channeling.has_method("is_channeling")
		and bool(_channeling.call("is_channeling"))
		and _channeling.has_method("get_context")
		and _matches_channel_context(_channeling.call("get_context"))
	)


func _set_intensity(value: float) -> void:
	if _ground_material != null:
		_ground_material.set_shader_parameter("intensity", clampf(value, 0.0, 1.0))


func _get_intensity() -> float:
	if _ground_material == null:
		return 0.0
	return float(_ground_material.get_shader_parameter("intensity"))


func _finish_fade_out() -> void:
	if not _active:
		visible = false
		scale = Vector3.ONE
