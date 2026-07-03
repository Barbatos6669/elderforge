@tool
## Generates placeholder upgrade pieces for tiered refining station prefabs.
##
## Each tier scene still exists as its own prefab, so these generated pieces can
## be replaced later with authored Blender/GLB art without changing station code.
extends Node3D

const GENERATED_PREFIX := "TierVisual"

## Visual family hint used to choose a few family-specific upgrade details.
@export_enum("generic", "stonecutter", "smelter", "loom", "toolmaker") var family_style := "generic":
	set(value):
		family_style = value
		_rebuild_if_ready()

## Building tier represented by the owning prefab.
@export_range(1, 8, 1) var visual_tier := 1:
	set(value):
		visual_tier = clampi(value, 1, 8)
		_rebuild_if_ready()

## Main tier color used for trim, badges, and upgrade pieces.
@export var accent_color := Color(0.72, 0.72, 0.72, 1.0):
	set(value):
		accent_color = value
		_rebuild_if_ready()


func _ready() -> void:
	_rebuild()


func _rebuild_if_ready() -> void:
	if is_inside_tree():
		_rebuild()


func _rebuild() -> void:
	_clear_generated_children()

	var accent_material := _make_material(accent_color, 0.35, 0.38)
	var dark_material := _make_material(Color(0.12, 0.11, 0.095, 1.0), 0.0, 0.82)
	var warm_material := _make_material(Color(0.78, 0.44, 0.17, 1.0), 0.0, 0.64)

	if visual_tier >= 2:
		_add_box("TrimFront", Vector3(0.0, 0.2, -1.93), Vector3(3.85, 0.1, 0.12), accent_material)
		_add_box("TrimBack", Vector3(0.0, 0.2, 1.93), Vector3(3.85, 0.1, 0.12), accent_material)
		_add_box("TrimLeft", Vector3(-1.93, 0.2, 0.0), Vector3(0.12, 0.1, 3.85), accent_material)
		_add_box("TrimRight", Vector3(1.93, 0.2, 0.0), Vector3(0.12, 0.1, 3.85), accent_material)

	if visual_tier >= 3:
		for position in [
			Vector3(-1.55, 0.78, -1.35),
			Vector3(1.55, 0.78, -1.35),
			Vector3(-1.55, 0.78, 1.35),
			Vector3(1.55, 0.78, 1.35),
		]:
			_add_box("Post", position, Vector3(0.22, 1.1, 0.22), warm_material)

	if visual_tier >= 4:
		_add_box("Canopy", Vector3(0.0, 1.68, 0.0), Vector3(3.45, 0.14, 2.65), accent_material)
		_add_box("CanopyBeamFront", Vector3(0.0, 1.5, -1.32), Vector3(3.4, 0.12, 0.12), dark_material)
		_add_box("CanopyBeamBack", Vector3(0.0, 1.5, 1.32), Vector3(3.4, 0.12, 0.12), dark_material)

	if visual_tier >= 5:
		_add_family_upgrade(accent_material, dark_material)

	if visual_tier >= 6:
		_add_cylinder(
			"DriveWheel",
			Vector3(-1.76, 0.95, 0.0),
			0.36,
			0.12,
			Vector3(0.0, 0.0, 1.5708),
			accent_material
		)
		_add_cylinder(
			"DriveWheelRight",
			Vector3(1.76, 0.95, 0.0),
			0.36,
			0.12,
			Vector3(0.0, 0.0, 1.5708),
			accent_material
		)

	if visual_tier >= 7:
		_add_box("RoofRailFront", Vector3(0.0, 1.84, -1.25), Vector3(3.75, 0.09, 0.1), accent_material)
		_add_box("RoofRailBack", Vector3(0.0, 1.84, 1.25), Vector3(3.75, 0.09, 0.1), accent_material)
		_add_box("TierBanner", Vector3(0.0, 1.25, -1.82), Vector3(0.55, 0.46, 0.08), accent_material)

	if visual_tier >= 8:
		_add_box("MasterTowerLeft", Vector3(-1.74, 1.55, 1.2), Vector3(0.32, 1.35, 0.32), accent_material)
		_add_box("MasterTowerRight", Vector3(1.74, 1.55, 1.2), Vector3(0.32, 1.35, 0.32), accent_material)
		_add_cylinder(
			"MasterEmblem",
			Vector3(0.0, 1.42, -1.88),
			0.25,
			0.08,
			Vector3(1.5708, 0.0, 0.0),
			accent_material
		)


func _add_family_upgrade(accent_material: Material, dark_material: Material) -> void:
	match family_style:
		"stonecutter":
			_add_box("BlockRackLeft", Vector3(-1.15, 0.78, 1.35), Vector3(0.74, 0.34, 0.74), accent_material)
			_add_box("BlockRackRight", Vector3(1.15, 0.78, 1.35), Vector3(0.74, 0.34, 0.74), accent_material)
		"smelter":
			_add_box("HeatShield", Vector3(0.0, 1.38, -1.05), Vector3(1.7, 0.62, 0.12), accent_material)
			_add_cylinder("VentCap", Vector3(0.0, 2.15, 0.45), 0.32, 0.16, Vector3.ZERO, dark_material)
		"loom":
			_add_box("ThreadRack", Vector3(0.0, 1.12, 1.36), Vector3(2.55, 0.12, 0.16), accent_material)
			_add_box("ClothGuide", Vector3(0.0, 0.82, -1.22), Vector3(2.15, 0.12, 0.12), accent_material)
		"toolmaker":
			_add_box("ToolRack", Vector3(0.0, 1.16, 1.42), Vector3(2.7, 0.14, 0.16), accent_material)
			_add_box("ReinforcedAnvil", Vector3(0.0, 0.92, -0.78), Vector3(1.1, 0.22, 0.42), dark_material)
		_:
			_add_box("ReinforcedPlate", Vector3(0.0, 0.84, -1.42), Vector3(1.8, 0.24, 0.12), accent_material)


func _clear_generated_children() -> void:
	for child in get_children():
		if String(child.name).begins_with(GENERATED_PREFIX):
			remove_child(child)
			child.free()


func _add_box(box_name: String, box_position: Vector3, box_size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = box_size

	var instance := MeshInstance3D.new()
	instance.name = "%s%s" % [GENERATED_PREFIX, box_name]
	instance.position = box_position
	instance.mesh = mesh
	instance.set_surface_override_material(0, material)
	add_child(instance)


func _add_cylinder(
	cylinder_name: String,
	cylinder_position: Vector3,
	radius: float,
	height: float,
	cylinder_rotation: Vector3,
	material: Material
) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 1

	var instance := MeshInstance3D.new()
	instance.name = "%s%s" % [GENERATED_PREFIX, cylinder_name]
	instance.position = cylinder_position
	instance.rotation = cylinder_rotation
	instance.mesh = mesh
	instance.set_surface_override_material(0, material)
	add_child(instance)


func _make_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
