bl_info = {
	"name": "Elderforge Low Poly Tree Generator",
	"author": "Elderforge Project",
	"version": (0, 1, 0),
	"blender": (4, 0, 0),
	"location": "View3D > Sidebar > Elderforge > Low Poly Trees",
	"description": "Generates editable low-poly tree parts for Elderforge resource nodes.",
	"category": "Add Mesh",
}

import math
import random

import bpy
from bpy.props import BoolProperty, FloatProperty, FloatVectorProperty, IntProperty
from mathutils import Vector


BARK_MATERIAL_NAME = "EF_Tree_Bark"
CUT_MATERIAL_NAME = "EF_Tree_Cut_Face"
LEAF_MATERIAL_PREFIX = "EF_Tree_Leaves"


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


def _basis_from_direction(start, end):
	direction = end - start
	if direction.length <= 0.0001:
		direction = Vector((0.0, 0.0, 1.0))

	forward = direction.normalized()
	reference = Vector((0.0, 0.0, 1.0))
	if abs(forward.dot(reference)) > 0.92:
		reference = Vector((1.0, 0.0, 0.0))

	right = forward.cross(reference).normalized()
	up = right.cross(forward).normalized()
	return right, up


def _append_tapered_cylinder(
	verts,
	faces,
	start,
	end,
	base_radius,
	top_radius,
	sides,
	include_bottom_cap=True,
	include_top_cap=True,
):
	start = Vector(start)
	end = Vector(end)
	sides = max(3, int(sides))
	base_index = len(verts)
	right, up = _basis_from_direction(start, end)

	for i in range(sides):
		angle = (math.tau * i) / sides
		radial = (right * math.cos(angle)) + (up * math.sin(angle))
		verts.append(tuple(start + radial * base_radius))

	for i in range(sides):
		angle = (math.tau * i) / sides
		radial = (right * math.cos(angle)) + (up * math.sin(angle))
		verts.append(tuple(end + radial * top_radius))

	for i in range(sides):
		next_i = (i + 1) % sides
		faces.append((base_index + i, base_index + next_i, base_index + sides + next_i, base_index + sides + i))

	if include_bottom_cap:
		faces.append(tuple(reversed([base_index + i for i in range(sides)])))
	if include_top_cap:
		faces.append(tuple(base_index + sides + i for i in range(sides)))


def _append_leaf_blob(verts, faces, material_indices, center, radius, scale, rng, material_index):
	center = Vector(center)
	segments = 7
	rings = 4
	start_index = len(verts)
	scale_vector = Vector(scale)

	verts.append(tuple(center + Vector((0.0, 0.0, radius * scale_vector.z))))
	for ring in range(1, rings):
		phi = math.pi * ring / rings
		z = math.cos(phi)
		ring_radius = math.sin(phi)
		for segment in range(segments):
			theta = math.tau * segment / segments
			noise = rng.uniform(0.82, 1.16)
			point = Vector((
				math.cos(theta) * ring_radius * radius * scale_vector.x * noise,
				math.sin(theta) * ring_radius * radius * scale_vector.y * noise,
				z * radius * scale_vector.z * rng.uniform(0.88, 1.12),
			))
			verts.append(tuple(center + point))
	verts.append(tuple(center - Vector((0.0, 0.0, radius * scale_vector.z * rng.uniform(0.82, 1.08)))))

	top_index = start_index
	bottom_index = len(verts) - 1

	first_ring = start_index + 1
	for segment in range(segments):
		next_segment = (segment + 1) % segments
		faces.append((top_index, first_ring + segment, first_ring + next_segment))
		material_indices.append(material_index)

	for ring in range(rings - 2):
		ring_a = start_index + 1 + ring * segments
		ring_b = ring_a + segments
		for segment in range(segments):
			next_segment = (segment + 1) % segments
			faces.append((ring_a + segment, ring_a + next_segment, ring_b + next_segment, ring_b + segment))
			material_indices.append(material_index)

	last_ring = start_index + 1 + (rings - 2) * segments
	for segment in range(segments):
		next_segment = (segment + 1) % segments
		faces.append((last_ring + next_segment, last_ring + segment, bottom_index))
		material_indices.append(material_index)


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


def _make_branch_points(rng, height, trunk_radius, canopy_radius, branch_count):
	points = []
	for index in range(branch_count):
		angle = (math.tau * index / max(1, branch_count)) + rng.uniform(-0.32, 0.32)
		start_height = rng.uniform(height * 0.36, height * 0.78)
		start = Vector((
			rng.uniform(-trunk_radius * 0.20, trunk_radius * 0.20),
			rng.uniform(-trunk_radius * 0.20, trunk_radius * 0.20),
			start_height,
		))
		length = rng.uniform(canopy_radius * 0.48, canopy_radius * 0.88)
		end = start + Vector((
			math.cos(angle) * length,
			math.sin(angle) * length,
			rng.uniform(height * 0.02, height * 0.18),
		))
		points.append((start, end, angle))
	return points


def _tree_collection_name(seed):
	return "EF_LowPolyTree_%04d" % int(seed)


class ELDERFORGE_OT_generate_low_poly_tree(bpy.types.Operator):
	bl_idname = "elderforge.generate_low_poly_tree"
	bl_label = "Generate Low Poly Tree"
	bl_description = "Create an editable low-poly tree collection at the 3D cursor"
	bl_options = {"REGISTER", "UNDO"}

	def execute(self, context):
		scene = context.scene
		rng = random.Random(scene.elderforge_tree_seed)
		tree_name = _tree_collection_name(scene.elderforge_tree_seed)

		collection = bpy.data.collections.new(tree_name)
		context.scene.collection.children.link(collection)

		cursor_location = context.scene.cursor.location.copy()
		height = max(1.0, scene.elderforge_tree_height)
		trunk_radius = max(0.04, scene.elderforge_tree_trunk_radius)
		canopy_radius = max(0.25, scene.elderforge_tree_canopy_radius)
		sides = max(5, scene.elderforge_tree_trunk_sides)

		bark_material = _create_material(BARK_MATERIAL_NAME, scene.elderforge_tree_bark_color)
		cut_material = _create_material(CUT_MATERIAL_NAME, scene.elderforge_tree_cut_color)
		leaf_materials = [
			_create_material(LEAF_MATERIAL_PREFIX + "_Dark", _shade_color(scene.elderforge_tree_leaf_color, 0.72)),
			_create_material(LEAF_MATERIAL_PREFIX + "_Main", scene.elderforge_tree_leaf_color),
			_create_material(LEAF_MATERIAL_PREFIX + "_Light", _shade_color(scene.elderforge_tree_leaf_color, 1.18)),
		]

		trunk_top = Vector((
			rng.uniform(-trunk_radius * 0.45, trunk_radius * 0.45),
			rng.uniform(-trunk_radius * 0.45, trunk_radius * 0.45),
			height * rng.uniform(0.72, 0.82),
		))

		trunk_verts = []
		trunk_faces = []
		_append_tapered_cylinder(
			trunk_verts,
			trunk_faces,
			Vector((0.0, 0.0, 0.0)),
			trunk_top,
			trunk_radius,
			trunk_radius * rng.uniform(0.36, 0.48),
			sides,
			True,
			True,
		)
		trunk = _make_mesh_object(tree_name + "_Trunk", trunk_verts, trunk_faces, collection, [bark_material, cut_material])
		if len(trunk.data.polygons) > 0:
			trunk.data.polygons[-1].material_index = 1
		trunk.location = cursor_location
		trunk["elderforge_tree_part"] = "trunk"

		branch_verts = []
		branch_faces = []
		branch_points = _make_branch_points(
			rng,
			height,
			trunk_radius,
			canopy_radius,
			max(0, scene.elderforge_tree_branch_count),
		)
		for branch_index, branch_data in enumerate(branch_points):
			start, end, _angle = branch_data
			branch_radius = trunk_radius * rng.uniform(0.18, 0.30) * max(0.45, 1.0 - (branch_index * 0.025))
			_append_tapered_cylinder(
				branch_verts,
				branch_faces,
				start,
				end,
				branch_radius,
				branch_radius * rng.uniform(0.28, 0.46),
				max(4, sides - 2),
				False,
				True,
			)

		branches = _make_mesh_object(tree_name + "_Branches", branch_verts, branch_faces, collection, [bark_material])
		branches.location = cursor_location
		branches["elderforge_tree_part"] = "branches"

		leaf_verts = []
		leaf_faces = []
		leaf_material_indices = []
		leaf_cluster_count = max(1, scene.elderforge_tree_leaf_cluster_count)

		cluster_centers = [
			trunk_top + Vector((0.0, 0.0, height * 0.12)),
			trunk_top + Vector((canopy_radius * 0.20, canopy_radius * 0.10, 0.0)),
			trunk_top + Vector((-canopy_radius * 0.18, canopy_radius * 0.14, height * 0.02)),
		]
		for branch_start, branch_end, _angle in branch_points:
			cluster_centers.append(branch_end + Vector((0.0, 0.0, rng.uniform(height * 0.04, height * 0.12))))

		while len(cluster_centers) < leaf_cluster_count:
			angle = rng.uniform(0.0, math.tau)
			radius = rng.uniform(0.0, canopy_radius * 0.65)
			cluster_centers.append(Vector((
				math.cos(angle) * radius,
				math.sin(angle) * radius,
				height * rng.uniform(0.62, 0.96),
			)))

		for index, center in enumerate(cluster_centers[:leaf_cluster_count]):
			blob_radius = rng.uniform(canopy_radius * 0.38, canopy_radius * 0.58)
			blob_scale = (
				rng.uniform(0.74, 1.12),
				rng.uniform(0.72, 1.08),
				rng.uniform(0.62, 0.94),
			)
			_append_leaf_blob(
				leaf_verts,
				leaf_faces,
				leaf_material_indices,
				center,
				blob_radius,
				blob_scale,
				rng,
				index % len(leaf_materials),
			)

		leaves = _make_mesh_object(tree_name + "_Leaves", leaf_verts, leaf_faces, collection, leaf_materials, leaf_material_indices)
		leaves.location = cursor_location
		leaves["elderforge_tree_part"] = "leaves"
		leaves["elderforge_can_derender"] = True

		if scene.elderforge_tree_create_hidden_stump:
			stump_verts = []
			stump_faces = []
			_append_tapered_cylinder(
				stump_verts,
				stump_faces,
				Vector((0.0, 0.0, 0.0)),
				Vector((0.0, 0.0, height * 0.24)),
				trunk_radius * 1.04,
				trunk_radius * 0.74,
				sides,
				True,
				True,
			)
			stump = _make_mesh_object(tree_name + "_DepletedStump", stump_verts, stump_faces, collection, [bark_material, cut_material])
			if len(stump.data.polygons) > 0:
				stump.data.polygons[-1].material_index = 1
			stump.location = cursor_location
			stump.hide_viewport = True
			stump.hide_render = True
			stump["elderforge_tree_part"] = "depleted_stump"

		for obj in collection.objects:
			obj.select_set(True)
		context.view_layer.objects.active = trunk

		self.report({"INFO"}, "Generated %s." % tree_name)
		return {"FINISHED"}


class ELDERFORGE_OT_randomize_tree_seed(bpy.types.Operator):
	bl_idname = "elderforge.randomize_tree_seed"
	bl_label = "Randomize Tree Seed"
	bl_description = "Pick a new seed for the low-poly tree generator"
	bl_options = {"REGISTER", "UNDO"}

	def execute(self, context):
		context.scene.elderforge_tree_seed = random.randint(1, 9999)
		return {"FINISHED"}


class ELDERFORGE_PT_low_poly_trees(bpy.types.Panel):
	bl_label = "Low Poly Trees"
	bl_idname = "ELDERFORGE_PT_low_poly_trees"
	bl_space_type = "VIEW_3D"
	bl_region_type = "UI"
	bl_category = "Elderforge"

	def draw(self, context):
		layout = self.layout
		scene = context.scene

		row = layout.row(align=True)
		row.prop(scene, "elderforge_tree_seed")
		row.operator("elderforge.randomize_tree_seed", text="", icon="FILE_REFRESH")

		layout.prop(scene, "elderforge_tree_height")
		layout.prop(scene, "elderforge_tree_trunk_radius")
		layout.prop(scene, "elderforge_tree_canopy_radius")
		layout.prop(scene, "elderforge_tree_trunk_sides")
		layout.prop(scene, "elderforge_tree_branch_count")
		layout.prop(scene, "elderforge_tree_leaf_cluster_count")
		layout.separator()
		layout.prop(scene, "elderforge_tree_bark_color")
		layout.prop(scene, "elderforge_tree_leaf_color")
		layout.prop(scene, "elderforge_tree_cut_color")
		layout.separator()
		layout.prop(scene, "elderforge_tree_create_hidden_stump")
		layout.operator("elderforge.generate_low_poly_tree", icon="OUTLINER_OB_FORCE_FIELD")


classes = (
	ELDERFORGE_OT_generate_low_poly_tree,
	ELDERFORGE_OT_randomize_tree_seed,
	ELDERFORGE_PT_low_poly_trees,
)


def register():
	for cls in classes:
		bpy.utils.register_class(cls)

	bpy.types.Scene.elderforge_tree_seed = IntProperty(
		name="Seed",
		description="Deterministic seed for this tree shape",
		default=1001,
		min=1,
		max=9999,
	)
	bpy.types.Scene.elderforge_tree_height = FloatProperty(
		name="Height",
		description="Approximate tree height in Blender/Godot meters",
		default=4.2,
		min=1.0,
		max=12.0,
		precision=2,
	)
	bpy.types.Scene.elderforge_tree_trunk_radius = FloatProperty(
		name="Trunk Radius",
		default=0.22,
		min=0.04,
		max=1.0,
		precision=3,
	)
	bpy.types.Scene.elderforge_tree_canopy_radius = FloatProperty(
		name="Canopy Radius",
		default=1.05,
		min=0.25,
		max=4.0,
		precision=2,
	)
	bpy.types.Scene.elderforge_tree_trunk_sides = IntProperty(
		name="Trunk Sides",
		description="Lower values make chunkier low-poly trunks",
		default=7,
		min=5,
		max=12,
	)
	bpy.types.Scene.elderforge_tree_branch_count = IntProperty(
		name="Branches",
		default=7,
		min=0,
		max=24,
	)
	bpy.types.Scene.elderforge_tree_leaf_cluster_count = IntProperty(
		name="Leaf Clusters",
		default=10,
		min=1,
		max=32,
	)
	bpy.types.Scene.elderforge_tree_bark_color = FloatVectorProperty(
		name="Bark Color",
		subtype="COLOR",
		size=4,
		default=(0.47, 0.28, 0.17, 1.0),
		min=0.0,
		max=1.0,
	)
	bpy.types.Scene.elderforge_tree_leaf_color = FloatVectorProperty(
		name="Leaf Color",
		subtype="COLOR",
		size=4,
		default=(0.36, 0.58, 0.48, 1.0),
		min=0.0,
		max=1.0,
	)
	bpy.types.Scene.elderforge_tree_cut_color = FloatVectorProperty(
		name="Cut Face Color",
		subtype="COLOR",
		size=4,
		default=(0.92, 0.58, 0.24, 1.0),
		min=0.0,
		max=1.0,
	)
	bpy.types.Scene.elderforge_tree_create_hidden_stump = BoolProperty(
		name="Create Hidden Depleted Stump",
		description="Adds a hidden stump object to use when the resource is depleted",
		default=True,
	)


def unregister():
	for prop_name in (
		"elderforge_tree_create_hidden_stump",
		"elderforge_tree_cut_color",
		"elderforge_tree_leaf_color",
		"elderforge_tree_bark_color",
		"elderforge_tree_leaf_cluster_count",
		"elderforge_tree_branch_count",
		"elderforge_tree_trunk_sides",
		"elderforge_tree_canopy_radius",
		"elderforge_tree_trunk_radius",
		"elderforge_tree_height",
		"elderforge_tree_seed",
	):
		if hasattr(bpy.types.Scene, prop_name):
			delattr(bpy.types.Scene, prop_name)

	for cls in reversed(classes):
		bpy.utils.unregister_class(cls)


if __name__ == "__main__":
	register()
