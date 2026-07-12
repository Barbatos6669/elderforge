bl_info = {
	"name": "Elderforge Low Poly Rock Generator",
	"author": "Elderforge Project",
	"version": (0, 1, 0),
	"blender": (4, 0, 0),
	"location": "View3D > Sidebar > Elderforge > Low Poly Rocks",
	"description": "Generates editable low-poly rock and ore-node parts for Elderforge.",
	"category": "Add Mesh",
}

import math
import random

import bpy
from bpy.props import BoolProperty, FloatProperty, FloatVectorProperty, IntProperty
from mathutils import Vector


ROCK_MATERIAL_NAME = "EF_Rock_Body"
ROCK_DARK_MATERIAL_NAME = "EF_Rock_Dark_Facets"
ACCENT_MATERIAL_NAME = "EF_Rock_Accent"
CHIP_MATERIAL_NAME = "EF_Rock_Chips"


def _clamp01(value):
	return max(0.0, min(1.0, float(value)))


def _color_tuple(color):
	return (
		_clamp01(color[0]),
		_clamp01(color[1]),
		_clamp01(color[2]),
		_clamp01(color[3]) if len(color) > 3 else 1.0,
	)


def _shade_color(color, amount):
	color = _color_tuple(color)
	return (
		_clamp01(color[0] * amount),
		_clamp01(color[1] * amount),
		_clamp01(color[2] * amount),
		color[3],
	)


def _create_material(name, color):
	material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
	material.diffuse_color = _color_tuple(color)
	material.use_nodes = True

	bsdf = material.node_tree.nodes.get("Principled BSDF")
	if bsdf is not None:
		if "Base Color" in bsdf.inputs:
			bsdf.inputs["Base Color"].default_value = _color_tuple(color)
		if "Roughness" in bsdf.inputs:
			bsdf.inputs["Roughness"].default_value = 1.0
		if "Metallic" in bsdf.inputs:
			bsdf.inputs["Metallic"].default_value = 0.0

	return material


def _collection_name(seed):
	return "EF_LowPolyRock_%04d" % int(seed)


def _make_mesh_object(name, verts, faces, collection, materials, material_indices=None):
	mesh = bpy.data.meshes.new(name + "_Mesh")
	mesh.from_pydata(verts, [], faces)
	mesh.update()

	for polygon in mesh.polygons:
		polygon.use_smooth = False

	object_node = bpy.data.objects.new(name, mesh)
	collection.objects.link(object_node)

	for material in materials:
		object_node.data.materials.append(material)

	if material_indices is not None:
		for polygon_index, material_index in enumerate(material_indices):
			if polygon_index < len(object_node.data.polygons):
				object_node.data.polygons[polygon_index].material_index = material_index

	return object_node


def _noise_scale(rng, roughness):
	return rng.uniform(1.0 - roughness, 1.0 + roughness)


def _append_rock_blob(
	verts,
	faces,
	material_indices,
	center,
	radius,
	height,
	segments,
	rings,
	roughness,
	rng,
	body_material_index,
	dark_material_index,
):
	center = Vector(center)
	segments = max(5, int(segments))
	rings = max(3, int(rings))
	start_index = len(verts)

	top = center + Vector((0.0, 0.0, height))
	bottom = center
	verts.append(tuple(top + Vector((
		rng.uniform(-radius * 0.12, radius * 0.12),
		rng.uniform(-radius * 0.12, radius * 0.12),
		rng.uniform(-height * 0.05, height * 0.05),
	))))

	for ring in range(1, rings):
		t = ring / float(rings)
		phi = math.pi * t
		z = math.cos(phi) * height * 0.5 + height * 0.5
		ring_radius = math.sin(phi) * radius
		if ring == rings - 1:
			z = max(0.04, height * 0.06)
			ring_radius *= 1.08

		for segment in range(segments):
			theta = math.tau * segment / segments
			scale = _noise_scale(rng, roughness)
			x_stretch = rng.uniform(0.82, 1.22)
			y_stretch = rng.uniform(0.80, 1.20)
			point = Vector((
				math.cos(theta) * ring_radius * scale * x_stretch,
				math.sin(theta) * ring_radius * scale * y_stretch,
				z * rng.uniform(0.94, 1.06),
			))
			verts.append(tuple(center + point))

	bottom_index = len(verts)
	verts.append(tuple(bottom))

	first_ring = start_index + 1
	for segment in range(segments):
		next_segment = (segment + 1) % segments
		faces.append((start_index, first_ring + segment, first_ring + next_segment))
		material_indices.append(dark_material_index if segment % 3 == 0 else body_material_index)

	for ring in range(rings - 2):
		ring_a = start_index + 1 + ring * segments
		ring_b = ring_a + segments
		for segment in range(segments):
			next_segment = (segment + 1) % segments
			faces.append((ring_a + segment, ring_a + next_segment, ring_b + next_segment, ring_b + segment))
			material_indices.append(dark_material_index if (ring + segment) % 4 == 0 else body_material_index)

	last_ring = start_index + 1 + (rings - 2) * segments
	for segment in range(segments):
		next_segment = (segment + 1) % segments
		faces.append((last_ring + next_segment, last_ring + segment, bottom_index))
		material_indices.append(dark_material_index)


def _append_crystal(
	verts,
	faces,
	center,
	radius,
	height,
	sides,
	rng,
):
	center = Vector(center)
	sides = max(4, int(sides))
	base_index = len(verts)
	tilt = Vector((rng.uniform(-0.22, 0.22), rng.uniform(-0.22, 0.22), 1.0)).normalized()
	top = center + tilt * height

	for segment in range(sides):
		theta = math.tau * segment / sides
		verts.append(tuple(center + Vector((
			math.cos(theta) * radius * rng.uniform(0.85, 1.12),
			math.sin(theta) * radius * rng.uniform(0.85, 1.12),
			0.0,
		))))

	mid_index = len(verts)
	for segment in range(sides):
		theta = math.tau * segment / sides
		verts.append(tuple(center + Vector((
			math.cos(theta) * radius * 0.68 * rng.uniform(0.86, 1.10),
			math.sin(theta) * radius * 0.68 * rng.uniform(0.86, 1.10),
			height * rng.uniform(0.48, 0.62),
		))))

	top_index = len(verts)
	verts.append(tuple(top))

	for segment in range(sides):
		next_segment = (segment + 1) % sides
		faces.append((base_index + segment, base_index + next_segment, mid_index + next_segment, mid_index + segment))
		faces.append((mid_index + segment, mid_index + next_segment, top_index))

	faces.append(tuple(reversed([base_index + segment for segment in range(sides)])))


def _append_chip(verts, faces, center, radius, height, rng):
	start = len(verts)
	center = Vector(center)
	points = [
		Vector((-0.9, -0.5, 0.0)),
		Vector((0.8, -0.4, 0.0)),
		Vector((0.4, 0.7, 0.0)),
		Vector((-0.6, 0.6, 0.0)),
		Vector((0.0, 0.0, 1.0)),
	]
	for point in points:
		verts.append(tuple(center + Vector((
			point.x * radius * rng.uniform(0.72, 1.18),
			point.y * radius * rng.uniform(0.72, 1.18),
			point.z * height * rng.uniform(0.76, 1.22),
		))))

	faces.extend([
		(start, start + 1, start + 2, start + 3),
		(start, start + 4, start + 1),
		(start + 1, start + 4, start + 2),
		(start + 2, start + 4, start + 3),
		(start + 3, start + 4, start),
	])


def _select_collection_objects(collection, active_object):
	for obj in bpy.context.selected_objects:
		obj.select_set(False)

	for obj in collection.objects:
		obj.select_set(True)
	bpy.context.view_layer.objects.active = active_object


class ELDERFORGE_OT_generate_low_poly_rock(bpy.types.Operator):
	bl_idname = "elderforge.generate_low_poly_rock"
	bl_label = "Generate Low Poly Rock"
	bl_description = "Create an editable low-poly rock or ore-node collection at the 3D cursor"
	bl_options = {"REGISTER", "UNDO"}

	def execute(self, context):
		scene = context.scene
		rng = random.Random(scene.elderforge_rock_seed)
		collection = bpy.data.collections.new(_collection_name(scene.elderforge_rock_seed))
		context.scene.collection.children.link(collection)

		cursor_location = context.scene.cursor.location.copy()
		radius = max(0.2, scene.elderforge_rock_radius)
		height = max(0.15, scene.elderforge_rock_height)
		segments = max(5, scene.elderforge_rock_segments)
		rings = max(3, scene.elderforge_rock_rings)
		roughness = max(0.0, min(0.55, scene.elderforge_rock_roughness))

		body_material = _create_material(ROCK_MATERIAL_NAME, scene.elderforge_rock_body_color)
		dark_material = _create_material(ROCK_DARK_MATERIAL_NAME, _shade_color(scene.elderforge_rock_body_color, 0.68))
		accent_material = _create_material(ACCENT_MATERIAL_NAME, scene.elderforge_rock_accent_color)
		chip_material = _create_material(CHIP_MATERIAL_NAME, _shade_color(scene.elderforge_rock_body_color, 0.88))

		rock_verts = []
		rock_faces = []
		rock_material_indices = []
		lobe_count = max(1, scene.elderforge_rock_lobes)
		for lobe_index in range(lobe_count):
			if lobe_index == 0:
				center = Vector((0.0, 0.0, 0.0))
				lobe_radius = radius
				lobe_height = height
			else:
				angle = rng.uniform(0.0, math.tau)
				distance = rng.uniform(radius * 0.28, radius * 0.72)
				center = Vector((
					math.cos(angle) * distance,
					math.sin(angle) * distance,
					rng.uniform(0.0, height * 0.10),
				))
				lobe_radius = radius * rng.uniform(0.45, 0.78)
				lobe_height = height * rng.uniform(0.45, 0.82)

			_append_rock_blob(
				rock_verts,
				rock_faces,
				rock_material_indices,
				center,
				lobe_radius,
				lobe_height,
				segments,
				rings,
				roughness,
				rng,
				0,
				1,
			)

		rock = _make_mesh_object(
			collection.name + "_RockBody",
			rock_verts,
			rock_faces,
			collection,
			[body_material, dark_material],
			rock_material_indices,
		)
		rock.location = cursor_location
		rock["elderforge_rock_part"] = "body"
		rock["elderforge_resource_family"] = "stone"

		if scene.elderforge_rock_create_accent_crystals:
			crystal_verts = []
			crystal_faces = []
			for _index in range(max(1, scene.elderforge_rock_crystal_count)):
				angle = rng.uniform(0.0, math.tau)
				distance = rng.uniform(radius * 0.08, radius * 0.55)
				center = Vector((
					math.cos(angle) * distance,
					math.sin(angle) * distance,
					height * rng.uniform(0.42, 0.78),
				))
				_append_crystal(
					crystal_verts,
					crystal_faces,
					center,
					radius * rng.uniform(0.07, 0.14),
					height * rng.uniform(0.18, 0.34),
					5,
					rng,
				)

			crystals = _make_mesh_object(collection.name + "_AccentCrystals", crystal_verts, crystal_faces, collection, [accent_material])
			crystals.location = cursor_location
			crystals["elderforge_rock_part"] = "accent_crystals"
			crystals["elderforge_resource_family"] = "ore"

		if scene.elderforge_rock_chip_count > 0:
			chip_verts = []
			chip_faces = []
			for _index in range(scene.elderforge_rock_chip_count):
				angle = rng.uniform(0.0, math.tau)
				distance = rng.uniform(radius * 0.78, radius * 1.32)
				center = Vector((
					math.cos(angle) * distance,
					math.sin(angle) * distance,
					0.0,
				))
				_append_chip(
					chip_verts,
					chip_faces,
					center,
					radius * rng.uniform(0.06, 0.14),
					height * rng.uniform(0.05, 0.12),
					rng,
				)

			chips = _make_mesh_object(collection.name + "_LooseChips", chip_verts, chip_faces, collection, [chip_material])
			chips.location = cursor_location
			chips["elderforge_rock_part"] = "loose_chips"

		if scene.elderforge_rock_create_hidden_depleted_rubble:
			rubble_verts = []
			rubble_faces = []
			for rubble_index in range(max(3, scene.elderforge_rock_lobes + 2)):
				angle = math.tau * rubble_index / max(3, scene.elderforge_rock_lobes + 2) + rng.uniform(-0.28, 0.28)
				distance = rng.uniform(radius * 0.08, radius * 0.62)
				center = Vector((
					math.cos(angle) * distance,
					math.sin(angle) * distance,
					0.0,
				))
				_append_chip(
					rubble_verts,
					rubble_faces,
					center,
					radius * rng.uniform(0.12, 0.26),
					height * rng.uniform(0.08, 0.18),
					rng,
				)

			rubble = _make_mesh_object(collection.name + "_DepletedRubble", rubble_verts, rubble_faces, collection, [chip_material])
			rubble.location = cursor_location
			rubble.hide_viewport = True
			rubble.hide_render = True
			rubble["elderforge_rock_part"] = "depleted_rubble"

		_select_collection_objects(collection, rock)
		self.report({"INFO"}, "Generated %s." % collection.name)
		return {"FINISHED"}


class ELDERFORGE_OT_randomize_rock_seed(bpy.types.Operator):
	bl_idname = "elderforge.randomize_rock_seed"
	bl_label = "Randomize Rock Seed"
	bl_description = "Pick a new seed for the low-poly rock generator"
	bl_options = {"REGISTER", "UNDO"}

	def execute(self, context):
		context.scene.elderforge_rock_seed = random.randint(1, 9999)
		return {"FINISHED"}


class ELDERFORGE_PT_low_poly_rocks(bpy.types.Panel):
	bl_label = "Low Poly Rocks"
	bl_idname = "ELDERFORGE_PT_low_poly_rocks"
	bl_space_type = "VIEW_3D"
	bl_region_type = "UI"
	bl_category = "Elderforge"

	def draw(self, context):
		layout = self.layout
		scene = context.scene

		row = layout.row(align=True)
		row.prop(scene, "elderforge_rock_seed")
		row.operator("elderforge.randomize_rock_seed", text="", icon="FILE_REFRESH")

		layout.prop(scene, "elderforge_rock_radius")
		layout.prop(scene, "elderforge_rock_height")
		layout.prop(scene, "elderforge_rock_lobes")
		layout.prop(scene, "elderforge_rock_segments")
		layout.prop(scene, "elderforge_rock_rings")
		layout.prop(scene, "elderforge_rock_roughness")
		layout.separator()
		layout.prop(scene, "elderforge_rock_body_color")
		layout.prop(scene, "elderforge_rock_accent_color")
		layout.separator()
		layout.prop(scene, "elderforge_rock_create_accent_crystals")
		if scene.elderforge_rock_create_accent_crystals:
			layout.prop(scene, "elderforge_rock_crystal_count")
		layout.prop(scene, "elderforge_rock_chip_count")
		layout.prop(scene, "elderforge_rock_create_hidden_depleted_rubble")
		layout.operator("elderforge.generate_low_poly_rock", icon="MESH_ICOSPHERE")


classes = (
	ELDERFORGE_OT_generate_low_poly_rock,
	ELDERFORGE_OT_randomize_rock_seed,
	ELDERFORGE_PT_low_poly_rocks,
)


def register():
	for cls in classes:
		bpy.utils.register_class(cls)

	bpy.types.Scene.elderforge_rock_seed = IntProperty(
		name="Seed",
		default=2001,
		min=1,
		max=9999,
	)
	bpy.types.Scene.elderforge_rock_radius = FloatProperty(
		name="Radius",
		default=1.05,
		min=0.2,
		max=5.0,
		precision=2,
	)
	bpy.types.Scene.elderforge_rock_height = FloatProperty(
		name="Height",
		default=0.85,
		min=0.15,
		max=4.0,
		precision=2,
	)
	bpy.types.Scene.elderforge_rock_lobes = IntProperty(
		name="Lobes",
		description="Extra overlapping rock masses",
		default=3,
		min=1,
		max=12,
	)
	bpy.types.Scene.elderforge_rock_segments = IntProperty(
		name="Segments",
		description="Lower values create chunkier silhouettes",
		default=8,
		min=5,
		max=18,
	)
	bpy.types.Scene.elderforge_rock_rings = IntProperty(
		name="Rings",
		default=5,
		min=3,
		max=10,
	)
	bpy.types.Scene.elderforge_rock_roughness = FloatProperty(
		name="Roughness",
		default=0.26,
		min=0.0,
		max=0.55,
		precision=2,
	)
	bpy.types.Scene.elderforge_rock_body_color = FloatVectorProperty(
		name="Body Color",
		subtype="COLOR",
		size=4,
		default=(0.58, 0.60, 0.57, 1.0),
		min=0.0,
		max=1.0,
	)
	bpy.types.Scene.elderforge_rock_accent_color = FloatVectorProperty(
		name="Accent Color",
		subtype="COLOR",
		size=4,
		default=(0.72, 0.84, 0.90, 1.0),
		min=0.0,
		max=1.0,
	)
	bpy.types.Scene.elderforge_rock_create_accent_crystals = BoolProperty(
		name="Accent Crystals",
		description="Creates separate crystal/ore accents on the rock",
		default=False,
	)
	bpy.types.Scene.elderforge_rock_crystal_count = IntProperty(
		name="Crystals",
		default=4,
		min=1,
		max=18,
	)
	bpy.types.Scene.elderforge_rock_chip_count = IntProperty(
		name="Loose Chips",
		default=5,
		min=0,
		max=32,
	)
	bpy.types.Scene.elderforge_rock_create_hidden_depleted_rubble = BoolProperty(
		name="Create Hidden Depleted Rubble",
		description="Adds hidden rubble to use when the resource is depleted",
		default=True,
	)


def unregister():
	for prop_name in (
		"elderforge_rock_create_hidden_depleted_rubble",
		"elderforge_rock_chip_count",
		"elderforge_rock_crystal_count",
		"elderforge_rock_create_accent_crystals",
		"elderforge_rock_accent_color",
		"elderforge_rock_body_color",
		"elderforge_rock_roughness",
		"elderforge_rock_rings",
		"elderforge_rock_segments",
		"elderforge_rock_lobes",
		"elderforge_rock_height",
		"elderforge_rock_radius",
		"elderforge_rock_seed",
	):
		if hasattr(bpy.types.Scene, prop_name):
			delattr(bpy.types.Scene, prop_name)

	for cls in reversed(classes):
		bpy.utils.unregister_class(cls)


if __name__ == "__main__":
	register()
