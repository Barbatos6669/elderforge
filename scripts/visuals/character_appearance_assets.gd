## Shared asset catalog and small naming rules for Universal Base Characters.
##
## PlayerVisualStyle and the character creator preview both need the same
## body, hair, and outfit paths. Keeping those paths here makes future outfits
## or hairstyles a single data update instead of a multi-script hunt.
class_name CharacterAppearanceAssets
extends RefCounted

const BODY_SCENE_META_KEY := &"appearance_body_scene_path"
const MODEL_ROOT_NAME := "BaseCharacter"
const SKELETON_PATH := NodePath("Armature/Skeleton3D")
const CLEAN_MALE_SOURCE_BLEND_PATH := "res://assets/characters/base/source/Male_base_character_original_desktop.blend"

const MALE_BODY_SCENE_PATH := "res://assets/characters/universal_base_character_package/Universal Base Characters[Standard]/Base Characters/Godot - UE/Superhero_Male_FullBody.gltf"
const FEMALE_BODY_SCENE_PATH := "res://assets/characters/universal_base_character_package/Universal Base Characters[Standard]/Base Characters/Godot - UE/Superhero_Female_FullBody.gltf"

const HAIR_SCENE_PATHS := {
	"short": "res://assets/characters/universal_base_character_package/Universal Base Characters[Standard]/Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/Hair_SimpleParted.gltf",
	"buzzed": "res://assets/characters/universal_base_character_package/Universal Base Characters[Standard]/Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/Hair_Buzzed.gltf",
	"buzzed_female": "res://assets/characters/universal_base_character_package/Universal Base Characters[Standard]/Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/Hair_BuzzedFemale.gltf",
	"long": "res://assets/characters/universal_base_character_package/Universal Base Characters[Standard]/Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/Hair_Long.gltf",
	"buns": "res://assets/characters/universal_base_character_package/Universal Base Characters[Standard]/Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/Hair_Buns.gltf",
}

const OUTFIT_SCENE_PATHS := {
	"starter_peasant": {
		"male": "res://assets/characters/universal_base_character_package/Modular Character Outfits - Fantasy[Standard]/Exports/glTF (Godot-Unreal)/Outfits/Male_Peasant.gltf",
		"female": "res://assets/characters/universal_base_character_package/Modular Character Outfits - Fantasy[Standard]/Exports/glTF (Godot-Unreal)/Outfits/Female_Peasant.gltf",
	},
	"ranger": {
		"male": "res://assets/characters/universal_base_character_package/Modular Character Outfits - Fantasy[Standard]/Exports/glTF (Godot-Unreal)/Outfits/Male_Ranger.gltf",
		"female": "res://assets/characters/universal_base_character_package/Modular Character Outfits - Fantasy[Standard]/Exports/glTF (Godot-Unreal)/Outfits/Female_Ranger.gltf",
	},
}

const OUTFIT_BODY_MASKS := {
	"starter_peasant": {
		"male": {
			"local_y_clip_min": 1.56,
			"local_y_neck_min": 1.50,
			"local_x_neck_half_width": 0.135,
		},
		"female": {
			"local_y_clip_min": 1.51,
			"local_y_neck_min": 1.47,
			"local_x_neck_half_width": 0.10,
		},
	},
	"ranger": {
		"male": {
			"local_y_clip_min": 1.56,
			"local_y_neck_min": 1.50,
			"local_x_neck_half_width": 0.135,
		},
		"female": {
			"local_y_clip_min": 1.51,
			"local_y_neck_min": 1.47,
			"local_x_neck_half_width": 0.10,
		},
	},
}


static func body_scene_path(body_type: String) -> String:
	return FEMALE_BODY_SCENE_PATH if sanitize_body_type(body_type) == "female" else MALE_BODY_SCENE_PATH


static func hair_scene_path(hair_style: String, body_type: String) -> String:
	var style := sanitize_hair_style(hair_style)
	if style == "buzzed" and sanitize_body_type(body_type) == "female":
		return String(HAIR_SCENE_PATHS.get("buzzed_female", ""))

	return String(HAIR_SCENE_PATHS.get(style, ""))


static func outfit_scene_path(outfit_style: String, body_type: String) -> String:
	var style := sanitize_outfit_style(outfit_style)
	if style == "none":
		return ""

	var style_paths: Dictionary = OUTFIT_SCENE_PATHS.get(style, {})
	return String(style_paths.get(sanitize_body_type(body_type), ""))


static func outfit_hides_base_body(outfit_style: String, body_type: String) -> bool:
	return not outfit_scene_path(outfit_style, body_type).is_empty()


static func outfit_body_clip_min_y(outfit_style: String, body_type: String) -> float:
	var style := sanitize_outfit_style(outfit_style)
	var sanitized_body_type := sanitize_body_type(body_type)
	var style_masks: Dictionary = OUTFIT_BODY_MASKS.get(style, {})
	var body_mask: Dictionary = style_masks.get(sanitized_body_type, {})
	if body_mask.has("local_y_clip_min"):
		return float(body_mask["local_y_clip_min"])

	return head_only_clip_min_y(sanitized_body_type)


static func outfit_body_neck_min_y(outfit_style: String, body_type: String) -> float:
	var style := sanitize_outfit_style(outfit_style)
	var sanitized_body_type := sanitize_body_type(body_type)
	var style_masks: Dictionary = OUTFIT_BODY_MASKS.get(style, {})
	var body_mask: Dictionary = style_masks.get(sanitized_body_type, {})
	if body_mask.has("local_y_neck_min"):
		return float(body_mask["local_y_neck_min"])

	return 1.47 if sanitized_body_type == "female" else 1.50


static func outfit_body_neck_half_width(outfit_style: String, body_type: String) -> float:
	var style := sanitize_outfit_style(outfit_style)
	var sanitized_body_type := sanitize_body_type(body_type)
	var style_masks: Dictionary = OUTFIT_BODY_MASKS.get(style, {})
	var body_mask: Dictionary = style_masks.get(sanitized_body_type, {})
	if body_mask.has("local_x_neck_half_width"):
		return float(body_mask["local_x_neck_half_width"])

	return 0.10 if sanitized_body_type == "female" else 0.135


static func sanitize_body_type(value: String) -> String:
	return "female" if value.strip_edges().to_lower() == "female" else "male"


static func sanitize_hair_style(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if normalized in ["none", "buzzed", "short", "long", "buns"]:
		return normalized

	return "short"


static func sanitize_outfit_style(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if normalized in ["none", "starter_peasant", "ranger"]:
		return normalized

	return "starter_peasant"


static func is_base_body_mesh(mesh_instance: MeshInstance3D) -> bool:
	var mesh_name := mesh_instance.name.to_lower()
	if _is_head_or_full_body_mesh_name(mesh_name):
		return false

	return _is_hideable_body_section_name(mesh_name)


static func is_full_body_base_mesh(mesh_instance: MeshInstance3D) -> bool:
	var mesh_name := mesh_instance.name.to_lower()
	if mesh_name.contains("superhero"):
		return true

	var mesh := mesh_instance.mesh
	if mesh == null:
		return false

	for surface_index in range(mesh.get_surface_count()):
		var material := mesh.surface_get_material(surface_index)
		if material != null and material.resource_name.to_lower().contains("superhero"):
			return true

	return false


static func head_only_clip_min_y(body_type: String) -> float:
	# Full-body base meshes include head, torso, arms, and legs in one surface.
	# This fallback keeps the face and upper neck while hiding the torso, arms,
	# and legs under clothing. Prefer `outfit_body_clip_min_y()` for outfit-
	# specific tuning.
	return 1.51 if sanitize_body_type(body_type) == "female" else 1.56


static func _is_head_or_full_body_mesh_name(mesh_name: String) -> bool:
	for marker in ["head", "face", "eye", "hair", "brow", "fullbody", "full_body", "superhero"]:
		if mesh_name.contains(marker):
			return true

	return false


static func _is_hideable_body_section_name(mesh_name: String) -> bool:
	for marker in ["body", "torso", "chest", "arm", "hand", "leg", "foot"]:
		if mesh_name.contains(marker):
			return true

	return false


static func is_skin_material(source_material: Material) -> bool:
	if source_material == null:
		return false

	var material_name := source_material.resource_name.to_lower()
	return material_name.contains("regular") or material_name.contains("skin") or material_name.contains("superhero")
