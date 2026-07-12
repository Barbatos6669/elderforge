## Creates the shared character materials used by gameplay and creator preview.
##
## Keeping this in one place lets us experiment with new toon shaders without
## making the in-game player and character creation preview drift apart.
class_name CharacterToonMaterials
extends RefCounted

const STYLE_STANDARD_TOON := "standard_toon"
const STYLE_EXPERIMENTAL_SHADER := "experimental_shader"
const EXPERIMENTAL_TOON_SHADER := preload("res://assets/materials/characters/experimental_toon.gdshader")
const TOON_OUTLINE_SHADER := preload("res://assets/materials/characters/toon_black_outline.gdshader")


static func make_character_material(
	color: Color,
	style := STYLE_EXPERIMENTAL_SHADER,
	cull_disabled := false,
	use_outline := true,
	outline_width := 0.012,
	use_local_y_clip := false,
	local_y_clip_min := 0.0
) -> Material:
	var material: Material
	if style == STYLE_EXPERIMENTAL_SHADER:
		material = _make_experimental_shader_material(color, use_local_y_clip, local_y_clip_min)
	else:
		material = _make_standard_toon_material(color, cull_disabled)

	if use_outline:
		material.next_pass = make_outline_material(
			outline_width,
			Color(0.015, 0.012, 0.01, 1.0),
			use_local_y_clip,
			local_y_clip_min
		)

	return material


static func make_textured_character_material(
	source_material: Material,
	fallback_color := Color(0.68, 0.62, 0.54, 1.0),
	style := STYLE_EXPERIMENTAL_SHADER,
	use_outline := true,
	outline_width := 0.012
) -> Material:
	var material: Material
	if style == STYLE_EXPERIMENTAL_SHADER:
		material = _make_experimental_shader_material_from_source(source_material, fallback_color)
	else:
		material = _make_standard_toon_material_from_source(source_material, fallback_color)

	if use_outline:
		material.next_pass = make_outline_material(outline_width)

	return material


static func make_head_only_character_material(
	color: Color,
	style := STYLE_EXPERIMENTAL_SHADER,
	local_y_clip_min := 1.45,
	outline_width := 0.012
) -> Material:
	return make_character_material(color, style, false, true, outline_width, true, local_y_clip_min)


static func make_outline_material(
	outline_width := 0.012,
	outline_color := Color(0.015, 0.012, 0.01, 1.0),
	use_local_y_clip := false,
	local_y_clip_min := 0.0
) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TOON_OUTLINE_SHADER
	material.set_shader_parameter("outline_color", _sanitize_color(outline_color))
	material.set_shader_parameter("outline_width", maxf(outline_width, 0.0))
	material.set_shader_parameter("use_local_y_clip", use_local_y_clip)
	material.set_shader_parameter("local_y_clip_min", local_y_clip_min)
	return material


static func _make_experimental_shader_material(
	color: Color,
	use_local_y_clip := false,
	local_y_clip_min := 0.0
) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = EXPERIMENTAL_TOON_SHADER
	material.set_shader_parameter("albedo_color", _sanitize_color(color))
	material.set_shader_parameter("use_albedo_texture", false)
	material.set_shader_parameter("shade_steps", 3.0)
	material.set_shader_parameter("step_softness", 0.14)
	material.set_shader_parameter("shadow_color", Color(0.24, 0.26, 0.28, 1.0))
	material.set_shader_parameter("shadow_strength", 0.32)
	material.set_shader_parameter("use_rim", true)
	material.set_shader_parameter("rim_color", Color(0.95, 0.84, 0.55, 1.0))
	material.set_shader_parameter("rim_power", 3.2)
	material.set_shader_parameter("rim_strength", 0.10)
	material.set_shader_parameter("roughness", 1.0)
	material.set_shader_parameter("specular", 0.0)
	material.set_shader_parameter("use_local_y_clip", use_local_y_clip)
	material.set_shader_parameter("local_y_clip_min", local_y_clip_min)
	return material


static func _make_experimental_shader_material_from_source(source_material: Material, fallback_color: Color) -> ShaderMaterial:
	var material := _make_experimental_shader_material(_source_albedo_color(source_material, fallback_color))
	var albedo_texture := _source_albedo_texture(source_material)
	if albedo_texture != null:
		material.set_shader_parameter("use_albedo_texture", true)
		material.set_shader_parameter("albedo_texture", albedo_texture)
		material.set_shader_parameter("texture_blend", 1.0)
	material.set_shader_parameter("roughness", _source_roughness(source_material, 1.0))
	material.resource_name = "%s Toon" % _source_material_name(source_material, "Textured")
	return material


static func _make_standard_toon_material(color: Color, cull_disabled: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = _sanitize_color(color)
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.roughness = 1.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if cull_disabled:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


static func _make_standard_toon_material_from_source(source_material: Material, fallback_color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "%s Toon" % _source_material_name(source_material, "Textured")
	material.albedo_color = _source_albedo_color(source_material, fallback_color)
	material.albedo_texture = _source_albedo_texture(source_material)
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.roughness = _source_roughness(source_material, 1.0)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return material


static func _source_material_name(source_material: Material, fallback: String) -> String:
	if source_material == null or source_material.resource_name.is_empty():
		return fallback
	return source_material.resource_name


static func _source_albedo_color(source_material: Material, fallback_color: Color) -> Color:
	if source_material is BaseMaterial3D:
		return _sanitize_color((source_material as BaseMaterial3D).albedo_color)
	return _sanitize_color(fallback_color)


static func _source_albedo_texture(source_material: Material) -> Texture2D:
	if source_material is BaseMaterial3D:
		return (source_material as BaseMaterial3D).albedo_texture
	return null


static func _source_roughness(source_material: Material, fallback_roughness: float) -> float:
	if source_material is BaseMaterial3D:
		return maxf((source_material as BaseMaterial3D).roughness, fallback_roughness)
	return fallback_roughness


static func _sanitize_color(color: Color) -> Color:
	if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a):
		return Color.WHITE

	return Color(
		clampf(color.r, 0.0, 1.0),
		clampf(color.g, 0.0, 1.0),
		clampf(color.b, 0.0, 1.0),
		clampf(color.a, 0.0, 1.0)
	)
