## Expanding double-ring marker shown at click-to-move destinations.
##
## The effect builds its rings procedurally, fades them with a tween, then frees
## itself when the animation is finished.
extends Node3D

## Total lifetime of the indicator.
@export var duration: float = 0.42
## Starting scale radius before the expansion tween.
@export var start_radius: float = 0.12
## Ending scale radius for the expansion tween.
@export var end_radius: float = 0.8
## Raises the rings above the floor to avoid clipping.
@export var y_offset: float = 0.08
## Base ring color. Alpha is also multiplied per-ring in _create_material().
@export var indicator_color: Color = Color(1.0, 0.82, 0.1, 0.62)
## Number of segments used to approximate each ring.
@export_range(16, 128, 1) var ring_segments: int = 72
## Thickness of the outer ring.
@export var outer_ring_width: float = 0.08
## Thickness of the inner ring.
@export var inner_ring_width: float = 0.06
## Inner ring radius as a ratio of the procedural unit ring.
@export_range(0.1, 0.95, 0.05) var inner_ring_radius: float = 0.55

@onready var outer_ring: MeshInstance3D = $OuterRing
@onready var inner_ring: MeshInstance3D = $InnerRing


func _ready() -> void:
	scale = Vector3(start_radius, 1.0, start_radius)
	outer_ring.position.y = y_offset
	inner_ring.position.y = y_offset

	var outer_material := _create_material(1.0)
	var inner_material := _create_material(0.78)
	outer_ring.mesh = _create_ring_mesh(1.0, outer_ring_width)
	inner_ring.mesh = _create_ring_mesh(inner_ring_radius, inner_ring_width)
	outer_ring.material_override = outer_material
	inner_ring.material_override = inner_material

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(end_radius, 1.0, end_radius), duration) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(outer_material, "albedo_color:a", 0.0, duration) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(inner_material, "albedo_color:a", 0.0, duration) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)
	tween.finished.connect(queue_free)


func _create_ring_mesh(radius: float, width: float) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var outer_radius := radius
	var inner_radius := maxf(radius - width, 0.01)

	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(ring_segments):
		# Each segment is two triangles forming a small quad between the radii.
		var angle_a := TAU * float(index) / float(ring_segments)
		var angle_b := TAU * float(index + 1) / float(ring_segments)
		var outer_a := Vector3(cos(angle_a) * outer_radius, 0.0, sin(angle_a) * outer_radius)
		var outer_b := Vector3(cos(angle_b) * outer_radius, 0.0, sin(angle_b) * outer_radius)
		var inner_a := Vector3(cos(angle_a) * inner_radius, 0.0, sin(angle_a) * inner_radius)
		var inner_b := Vector3(cos(angle_b) * inner_radius, 0.0, sin(angle_b) * inner_radius)

		mesh.surface_add_vertex(outer_a)
		mesh.surface_add_vertex(outer_b)
		mesh.surface_add_vertex(inner_b)
		mesh.surface_add_vertex(outer_a)
		mesh.surface_add_vertex(inner_b)
		mesh.surface_add_vertex(inner_a)
	mesh.surface_end()

	return mesh


func _create_material(alpha_multiplier: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var color := indicator_color
	color.a *= alpha_multiplier
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
