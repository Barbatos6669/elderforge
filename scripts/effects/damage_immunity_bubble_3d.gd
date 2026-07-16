## Visualizes a CombatHealth node's temporary protection windows.
##
## The health component owns gameplay timing. This effect mirrors active
## immunity and finite absorb shields, so the visible bubble cannot drift away
## from actual protection.
class_name DamageImmunityBubble3D
extends Node3D

const BUBBLE_SHADER := preload(
	"res://assets/materials/effects/damage_immunity_bubble.gdshader"
)

## CombatHealth component whose protection signals drive this visual.
@export var health_path: NodePath = NodePath("../Health")
## Horizontal radius around the character.
@export_range(0.1, 5.0, 0.05) var bubble_radius := 0.82
## Vertical size of the shield bubble.
@export_range(0.2, 8.0, 0.05) var bubble_height := 2.05
## Height of the bubble's center above the character's feet.
@export_range(-2.0, 5.0, 0.05) var vertical_offset := 1.0
@export var shield_color := Color(0.28, 0.76, 1.0, 1.0)

var _health: CombatHealth
var _shield_mesh: MeshInstance3D
var _activation_tween: Tween


func _ready() -> void:
	_build_visual()
	_health = get_node_or_null(health_path) as CombatHealth
	if _health == null:
		push_warning("DamageImmunityBubble3D could not find CombatHealth at %s." % health_path)
		set_active(false)
		return

	if not _health.damage_immunity_changed.is_connected(_on_damage_immunity_changed):
		_health.damage_immunity_changed.connect(_on_damage_immunity_changed)
	if (
		_health.has_signal("absorb_shield_changed")
		and not _health.absorb_shield_changed.is_connected(_on_absorb_shield_changed)
	):
		_health.absorb_shield_changed.connect(_on_absorb_shield_changed)
	_refresh_active()


## Returns whether the shield is currently visible for tests and other visuals.
func is_active() -> bool:
	return visible


func set_active(is_active: bool) -> void:
	if _activation_tween != null and _activation_tween.is_valid():
		_activation_tween.kill()

	visible = is_active
	if not is_active or not is_inside_tree():
		scale = Vector3.ONE
		return

	scale = Vector3.ONE * 0.88
	_activation_tween = create_tween()
	_activation_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_activation_tween.tween_property(self, "scale", Vector3.ONE, 0.1)


func _build_visual() -> void:
	_shield_mesh = get_node_or_null("ShieldMesh") as MeshInstance3D
	if _shield_mesh == null:
		_shield_mesh = MeshInstance3D.new()
		_shield_mesh.name = "ShieldMesh"
		add_child(_shield_mesh)

	var sphere := SphereMesh.new()
	sphere.radius = bubble_radius
	sphere.height = bubble_height
	sphere.radial_segments = 32
	sphere.rings = 16
	_shield_mesh.mesh = sphere
	_shield_mesh.position = Vector3(0.0, vertical_offset, 0.0)
	_shield_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var material := ShaderMaterial.new()
	material.shader = BUBBLE_SHADER
	material.set_shader_parameter("shield_color", shield_color)
	_shield_mesh.material_override = material


func _on_damage_immunity_changed(is_active: bool, _remaining_seconds: float) -> void:
	if is_active:
		set_active(true)
	else:
		_refresh_active()


func _on_absorb_shield_changed(current_shield: float, _max_shield: float, _remaining_seconds: float) -> void:
	set_active(current_shield > 0.0 or _health.is_damage_immune())


func _refresh_active() -> void:
	var has_absorb_shield := (
		_health != null
		and _health.has_method("has_absorb_shield")
		and bool(_health.call("has_absorb_shield"))
	)
	set_active(_health != null and (_health.is_damage_immune() or has_absorb_shield))
