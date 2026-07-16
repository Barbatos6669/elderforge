## Ground preview for cursor-aimed directional abilities.
##
## Geometry is generated at runtime so every movement ability can choose its own
## distance and width without requiring a separate mesh asset.
class_name DirectionalAbilityIndicator
extends Node3D

@export var fill_color := Color(1.0, 0.78, 0.18, 0.30)
@export var outline_color := Color(1.0, 0.86, 0.35, 0.82)
@export_range(0.0, 0.5, 0.005) var ground_offset := 0.07

var _outline_mesh: MeshInstance3D
var _fill_mesh: MeshInstance3D
var _origin_disc: MeshInstance3D
var _last_distance := -1.0
var _last_width := -1.0


func _ready() -> void:
	position.y = ground_offset
	_build_nodes()
	hide_indicator()


## Shows an arrow aligned to a world-space horizontal direction.
func show_direction(direction: Vector3, distance: float, width: float) -> void:
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	if flat_direction.length_squared() <= 0.0001:
		return

	var safe_distance := maxf(distance, 0.5)
	var safe_width := maxf(width, 0.2)
	if not is_equal_approx(safe_distance, _last_distance) or not is_equal_approx(safe_width, _last_width):
		_rebuild_geometry(safe_distance, safe_width)

	flat_direction = flat_direction.normalized()
	rotation.y = atan2(-flat_direction.x, -flat_direction.z)
	visible = true


func hide_indicator() -> void:
	visible = false


func is_showing() -> bool:
	return visible


func _build_nodes() -> void:
	_outline_mesh = MeshInstance3D.new()
	_outline_mesh.name = "Outline"
	_outline_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_outline_mesh)

	_fill_mesh = MeshInstance3D.new()
	_fill_mesh.name = "Fill"
	_fill_mesh.position.y = 0.008
	_fill_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fill_mesh)

	_origin_disc = MeshInstance3D.new()
	_origin_disc.name = "OriginDisc"
	_origin_disc.position = Vector3(0.0, 0.004, -0.12)
	_origin_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var disc := CylinderMesh.new()
	disc.top_radius = 0.48
	disc.bottom_radius = 0.48
	disc.height = 0.012
	disc.radial_segments = 40
	disc.material = _make_material(Color(fill_color, minf(fill_color.a * 0.75, 1.0)))
	_origin_disc.mesh = disc
	add_child(_origin_disc)


func _rebuild_geometry(distance: float, width: float) -> void:
	_last_distance = distance
	_last_width = width
	_outline_mesh.mesh = _make_arrow_mesh(distance, width * 1.14, outline_color)
	_fill_mesh.mesh = _make_arrow_mesh(distance - 0.04, width, fill_color)


func _make_arrow_mesh(distance: float, width: float, color: Color) -> ArrayMesh:
	var start_distance := minf(0.42, distance * 0.20)
	var tip_length := clampf(distance * 0.28, 0.45, 1.0)
	var shaft_end := maxf(distance - tip_length, start_distance + 0.05)
	var shaft_half_width := width * 0.27
	var tip_half_width := width * 0.52
	var vertices := PackedVector3Array([
		Vector3(-shaft_half_width, 0.0, -start_distance),
		Vector3(shaft_half_width, 0.0, -start_distance),
		Vector3(-shaft_half_width, 0.0, -shaft_end),
		Vector3(shaft_half_width, 0.0, -shaft_end),
		Vector3(-tip_half_width, 0.0, -shaft_end),
		Vector3(tip_half_width, 0.0, -shaft_end),
		Vector3(0.0, 0.0, -distance),
	])
	var indices := PackedInt32Array([
		0, 2, 1,
		1, 2, 3,
		4, 6, 5,
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _make_material(color))
	return mesh


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 2
	return material
