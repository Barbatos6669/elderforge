bl_info = {
	"name": "Elderforge Toon Modeling Shader",
	"author": "Elderforge Project",
	"version": (0, 1, 0),
	"blender": (4, 0, 0),
	"location": "View3D > Sidebar > Elderforge > Toon Modeling",
	"description": "Creates Elderforge-style toon preview materials for modeling.",
	"category": "Material",
}

import bpy
from bpy.props import FloatProperty, FloatVectorProperty


TOON_MATERIAL_NAME = "EF_Toon_Modeling"
OUTLINE_MATERIAL_NAME = "EF_Toon_Black_Outline"
OUTLINE_MODIFIER_NAME = "EF_Toon_Black_Outline_Preview"
PREVIEW_BASE_MATERIAL_NAME = "EF_Toon_Preview_Base"


PRESET_COLORS = {
	"EF_Toon_Character_Pale": (0.74, 0.86, 0.92, 1.0),
	"EF_Toon_Warm_Stone": (0.50, 0.47, 0.40, 1.0),
	"EF_Toon_Moonchalk_Rock": (0.62, 0.64, 0.62, 1.0),
	"EF_Toon_Silverneedle_Bark": (0.47, 0.28, 0.17, 1.0),
	"EF_Toon_Silverneedle_Needles": (0.35, 0.58, 0.48, 1.0),
	"EF_Toon_Hearth_Gold": (0.88, 0.62, 0.20, 1.0),
}


def _clamp01(value):
	return max(0.0, min(1.0, value))


def _color_tuple(color):
	return (
		_clamp01(float(color[0])),
		_clamp01(float(color[1])),
		_clamp01(float(color[2])),
		_clamp01(float(color[3]) if len(color) > 3 else 1.0),
	)


def _multiply_color(color, strength):
	return (
		_clamp01(color[0] * strength),
		_clamp01(color[1] * strength),
		_clamp01(color[2] * strength),
		color[3],
	)


def _mix_color(a, b, weight):
	weight = _clamp01(weight)
	return (
		_clamp01(a[0] * (1.0 - weight) + b[0] * weight),
		_clamp01(a[1] * (1.0 - weight) + b[1] * weight),
		_clamp01(a[2] * (1.0 - weight) + b[2] * weight),
		a[3] * (1.0 - weight) + b[3] * weight,
	)


def _set_node_location(node, x, y):
	node.location.x = x
	node.location.y = y


def _set_eevee_if_available():
	scene = bpy.context.scene
	for engine_name in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
		try:
			scene.render.engine = engine_name
			break
		except TypeError:
			continue


def create_toon_material(name=TOON_MATERIAL_NAME, base_color=(0.68, 0.62, 0.54, 1.0)):
	base_color = _color_tuple(base_color)
	material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
	material.use_nodes = True
	material.diffuse_color = base_color

	node_tree = material.node_tree
	nodes = node_tree.nodes
	links = node_tree.links
	nodes.clear()

	output = nodes.new(type="ShaderNodeOutputMaterial")
	diffuse = nodes.new(type="ShaderNodeBsdfDiffuse")
	shader_to_rgb = nodes.new(type="ShaderNodeShaderToRGB")
	ramp = nodes.new(type="ShaderNodeValToRGB")
	emission = nodes.new(type="ShaderNodeEmission")

	_set_node_location(diffuse, -620, 120)
	_set_node_location(shader_to_rgb, -400, 120)
	_set_node_location(ramp, -180, 120)
	_set_node_location(emission, 60, 120)
	_set_node_location(output, 280, 120)

	diffuse.inputs["Color"].default_value = base_color
	if "Roughness" in diffuse.inputs:
		diffuse.inputs["Roughness"].default_value = 1.0

	shadow_tint = (0.23, 0.25, 0.27, 1.0)
	highlight_tint = (0.95, 0.84, 0.54, 1.0)
	shadow_color = _mix_color(base_color, shadow_tint, 0.34)
	mid_color = base_color
	highlight_color = _mix_color(_multiply_color(base_color, 1.12), highlight_tint, 0.10)

	ramp.color_ramp.interpolation = "CONSTANT"
	ramp.color_ramp.elements[0].position = 0.0
	ramp.color_ramp.elements[0].color = shadow_color
	ramp.color_ramp.elements[1].position = 0.58
	ramp.color_ramp.elements[1].color = mid_color
	highlight_element = ramp.color_ramp.elements.new(0.86)
	highlight_element.color = highlight_color

	emission.inputs["Strength"].default_value = 1.0

	links.new(diffuse.outputs["BSDF"], shader_to_rgb.inputs["Shader"])
	links.new(shader_to_rgb.outputs["Color"], ramp.inputs["Fac"])
	links.new(ramp.outputs["Color"], emission.inputs["Color"])
	links.new(emission.outputs["Emission"], output.inputs["Surface"])
	return material


def create_outline_material():
	material = bpy.data.materials.get(OUTLINE_MATERIAL_NAME) or bpy.data.materials.new(OUTLINE_MATERIAL_NAME)
	material.use_nodes = True
	material.diffuse_color = (0.015, 0.012, 0.01, 1.0)
	material.use_backface_culling = False

	if hasattr(material, "blend_method"):
		material.blend_method = "BLEND"
	if hasattr(material, "surface_render_method"):
		material.surface_render_method = "BLENDED"

	node_tree = material.node_tree
	nodes = node_tree.nodes
	links = node_tree.links
	nodes.clear()

	output = nodes.new(type="ShaderNodeOutputMaterial")
	geometry = nodes.new(type="ShaderNodeNewGeometry")
	transparent = nodes.new(type="ShaderNodeBsdfTransparent")
	emission = nodes.new(type="ShaderNodeEmission")
	mix_shader = nodes.new(type="ShaderNodeMixShader")

	_set_node_location(geometry, -520, 70)
	_set_node_location(transparent, -320, 160)
	_set_node_location(emission, -320, -20)
	_set_node_location(mix_shader, -80, 80)
	_set_node_location(output, 160, 80)

	emission.inputs["Color"].default_value = (0.015, 0.012, 0.01, 1.0)
	emission.inputs["Strength"].default_value = 1.0

	links.new(geometry.outputs["Backfacing"], mix_shader.inputs[0])
	links.new(transparent.outputs["BSDF"], mix_shader.inputs[1])
	links.new(emission.outputs["Emission"], mix_shader.inputs[2])
	links.new(mix_shader.outputs["Shader"], output.inputs["Surface"])
	return material


def create_all_presets():
	_set_eevee_if_available()
	create_outline_material()
	for material_name, color in PRESET_COLORS.items():
		create_toon_material(material_name, color)
	return create_toon_material(TOON_MATERIAL_NAME, bpy.context.scene.elderforge_toon_base_color)


def _ensure_visible_base_material(obj):
	"""Keep the outline material out of slot 0 so it never paints the mesh black."""
	if len(obj.data.materials) == 0:
		obj.data.materials.append(create_toon_material(PREVIEW_BASE_MATERIAL_NAME, bpy.context.scene.elderforge_toon_base_color))
		return

	if len(obj.data.materials) == 1 and obj.data.materials[0] is not None and obj.data.materials[0].name == OUTLINE_MATERIAL_NAME:
		obj.data.materials[0] = create_toon_material(PREVIEW_BASE_MATERIAL_NAME, bpy.context.scene.elderforge_toon_base_color)


def _mesh_objects_from_selection():
	return [obj for obj in bpy.context.selected_objects if obj.type == "MESH"]


class ELDERFORGE_OT_create_toon_presets(bpy.types.Operator):
	bl_idname = "elderforge.create_toon_presets"
	bl_label = "Create Toon Presets"
	bl_description = "Create Elderforge toon preview materials in this Blender file"
	bl_options = {"REGISTER", "UNDO"}

	def execute(self, context):
		create_all_presets()
		self.report({"INFO"}, "Created Elderforge toon materials.")
		return {"FINISHED"}


class ELDERFORGE_OT_apply_toon_to_selected(bpy.types.Operator):
	bl_idname = "elderforge.apply_toon_to_selected"
	bl_label = "Apply Toon to Selected"
	bl_description = "Assign the Elderforge toon preview material to selected meshes"
	bl_options = {"REGISTER", "UNDO"}

	def execute(self, context):
		material = create_toon_material(TOON_MATERIAL_NAME, context.scene.elderforge_toon_base_color)
		objects = _mesh_objects_from_selection()
		if not objects:
			self.report({"WARNING"}, "Select at least one mesh object.")
			return {"CANCELLED"}

		for obj in objects:
			if not obj.data.materials:
				obj.data.materials.append(material)
			else:
				obj.data.materials[0] = material
			for polygon in obj.data.polygons:
				polygon.material_index = 0

		self.report({"INFO"}, "Applied Elderforge toon material to selected meshes.")
		return {"FINISHED"}


class ELDERFORGE_OT_add_outline_preview(bpy.types.Operator):
	bl_idname = "elderforge.add_outline_preview"
	bl_label = "Add Black Outline Preview"
	bl_description = "Add a non-destructive Solidify outline preview to selected meshes"
	bl_options = {"REGISTER", "UNDO"}

	def execute(self, context):
		outline_material = create_outline_material()
		objects = _mesh_objects_from_selection()
		if not objects:
			self.report({"WARNING"}, "Select at least one mesh object.")
			return {"CANCELLED"}

		for obj in objects:
			_ensure_visible_base_material(obj)
			outline_slot = obj.data.materials.find(outline_material.name)
			if outline_slot == -1:
				obj.data.materials.append(outline_material)
				outline_slot = obj.data.materials.find(outline_material.name)

			modifier = obj.modifiers.get(OUTLINE_MODIFIER_NAME)
			if modifier is None:
				modifier = obj.modifiers.new(OUTLINE_MODIFIER_NAME, "SOLIDIFY")

			modifier.thickness = context.scene.elderforge_outline_width
			modifier.offset = 1.0
			modifier.use_flip_normals = False
			if hasattr(modifier, "use_quality_normals"):
				modifier.use_quality_normals = True
			if hasattr(modifier, "material_offset"):
				modifier.material_offset = max(0, outline_slot)
			if hasattr(modifier, "material_offset_rim"):
				modifier.material_offset_rim = max(0, outline_slot)

		self.report({"INFO"}, "Added Elderforge black outline preview.")
		return {"FINISHED"}


class ELDERFORGE_OT_remove_outline_preview(bpy.types.Operator):
	bl_idname = "elderforge.remove_outline_preview"
	bl_label = "Remove Black Outline Preview"
	bl_description = "Remove the Elderforge outline preview modifier from selected meshes"
	bl_options = {"REGISTER", "UNDO"}

	def execute(self, context):
		objects = _mesh_objects_from_selection()
		if not objects:
			self.report({"WARNING"}, "Select at least one mesh object.")
			return {"CANCELLED"}

		for obj in objects:
			modifier = obj.modifiers.get(OUTLINE_MODIFIER_NAME)
			if modifier is not None:
				obj.modifiers.remove(modifier)

		self.report({"INFO"}, "Removed Elderforge outline preview.")
		return {"FINISHED"}


class ELDERFORGE_PT_toon_modeling(bpy.types.Panel):
	bl_label = "Toon Modeling"
	bl_idname = "ELDERFORGE_PT_toon_modeling"
	bl_space_type = "VIEW_3D"
	bl_region_type = "UI"
	bl_category = "Elderforge"

	def draw(self, context):
		layout = self.layout
		scene = context.scene

		layout.operator("elderforge.create_toon_presets", icon="MATERIAL")
		layout.separator()
		layout.prop(scene, "elderforge_toon_base_color")
		layout.operator("elderforge.apply_toon_to_selected", icon="SHADING_RENDERED")
		layout.separator()
		layout.prop(scene, "elderforge_outline_width")
		layout.operator("elderforge.add_outline_preview", icon="MOD_SOLIDIFY")
		layout.operator("elderforge.remove_outline_preview", icon="X")


classes = (
	ELDERFORGE_OT_create_toon_presets,
	ELDERFORGE_OT_apply_toon_to_selected,
	ELDERFORGE_OT_add_outline_preview,
	ELDERFORGE_OT_remove_outline_preview,
	ELDERFORGE_PT_toon_modeling,
)


def register():
	for cls in classes:
		bpy.utils.register_class(cls)

	bpy.types.Scene.elderforge_toon_base_color = FloatVectorProperty(
		name="Base Color",
		description="Base albedo color for the Elderforge toon preview material",
		subtype="COLOR",
		size=4,
		default=(0.68, 0.62, 0.54, 1.0),
		min=0.0,
		max=1.0,
	)
	bpy.types.Scene.elderforge_outline_width = FloatProperty(
		name="Outline Width",
		description="Preview outline thickness. Keep this small for game-scale meshes",
		default=0.018,
		min=0.0,
		max=0.08,
		precision=3,
	)


def unregister():
	if hasattr(bpy.types.Scene, "elderforge_outline_width"):
		del bpy.types.Scene.elderforge_outline_width
	if hasattr(bpy.types.Scene, "elderforge_toon_base_color"):
		del bpy.types.Scene.elderforge_toon_base_color

	for cls in reversed(classes):
		bpy.utils.unregister_class(cls)


if __name__ == "__main__":
	register()
