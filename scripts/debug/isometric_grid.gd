@tool
extends Node3D

@export_range(1, 128, 1) var half_size: int = 16:
	set(value):
		half_size = max(value, 1)
		_rebuild_if_ready()

@export_range(0.25, 8.0, 0.25) var cell_size: float = 1.0:
	set(value):
		cell_size = max(value, 0.25)
		_rebuild_if_ready()

@export var y_offset: float = 0.02:
	set(value):
		y_offset = value
		_rebuild_if_ready()

@export var minor_line_color: Color = Color(0.82, 0.9, 0.85, 0.22):
	set(value):
		minor_line_color = value
		_rebuild_if_ready()

@export var major_line_color: Color = Color(0.95, 0.98, 0.88, 0.38):
	set(value):
		major_line_color = value
		_rebuild_if_ready()

@export var x_axis_color: Color = Color(0.95, 0.22, 0.18, 0.7):
	set(value):
		x_axis_color = value
		_rebuild_if_ready()

@export var z_axis_color: Color = Color(0.25, 0.52, 1.0, 0.7):
	set(value):
		z_axis_color = value
		_rebuild_if_ready()

@export_range(1, 16, 1) var major_line_interval: int = 4:
	set(value):
		major_line_interval = max(value, 1)
		_rebuild_if_ready()


func _ready() -> void:
	_rebuild()


func _rebuild_if_ready() -> void:
	if is_inside_tree():
		_rebuild()


func _rebuild() -> void:
	var mesh_instance := get_node_or_null("GridMesh") as MeshInstance3D
	if mesh_instance == null:
		return

	var grid_mesh := ImmediateMesh.new()
	grid_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_add_grid_lines(grid_mesh)
	grid_mesh.surface_end()

	mesh_instance.mesh = grid_mesh
	mesh_instance.material_override = _create_material()


func _add_grid_lines(grid_mesh: ImmediateMesh) -> void:
	var extent := float(half_size) * cell_size

	for index in range(-half_size, half_size + 1):
		var coordinate := float(index) * cell_size
		var line_color := _line_color_for_index(index)

		_add_line(
			grid_mesh,
			Vector3(coordinate, y_offset, -extent),
			Vector3(coordinate, y_offset, extent),
			z_axis_color if index == 0 else line_color
		)
		_add_line(
			grid_mesh,
			Vector3(-extent, y_offset, coordinate),
			Vector3(extent, y_offset, coordinate),
			x_axis_color if index == 0 else line_color
		)


func _add_line(
	grid_mesh: ImmediateMesh,
	start_position: Vector3,
	end_position: Vector3,
	line_color: Color
) -> void:
	grid_mesh.surface_set_color(line_color)
	grid_mesh.surface_add_vertex(start_position)
	grid_mesh.surface_add_vertex(end_position)


func _line_color_for_index(index: int) -> Color:
	if index % major_line_interval == 0:
		return major_line_color

	return minor_line_color


func _create_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
